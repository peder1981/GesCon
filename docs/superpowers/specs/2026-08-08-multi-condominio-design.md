# Design: Multi-condomínio no GesCon (via FILIAL, estilo Protheus)

**Data:** 2026-08-08
**Escopo:** Um banco único atendendo vários condomínios, com isolamento garantido no motor
**Status:** Design aprovado, pronto para o plano de implementação

---

## Visão Geral

Hoje o GesCon administra **um condomínio por instância** — todo dado (unidades, cobranças, contabilidade, boletos, avisos, tokens) vive num banco SQLite sem noção de "de qual prédio é isso". O pedido: permitir que uma **administradora de condomínios** rode uma instância só atendendo vários prédios, com:

- Um **super admin** que enxerga/opera todos os condomínios.
- **Síndicos** vinculados a um ou mais condomínios específicos, com poder de admin só dentro do(s) seu(s).
- O **token do portal do condômino** já resolvendo sozinho a qual condomínio pertence — sem precisar que o admin abra tela nenhuma pra "apontar" o condômino certo.

A investigação técnica descartou a ideia inicial (um arquivo `.db` por condomínio, trocado dentro da mesma sessão): o AdvPP abre um único banco por processo, decidido antes da janela existir, e não há comando pra reabrir outro banco em runtime. A saída — confirmada com o usuário — é **banco único + coluna de particionamento em cada tabela**, usando a convenção real do Protheus: campo **`FILIAL`**, 6 caracteres alfanuméricos (`GG` grupo de empresas + `UU` unidade de negócio + `FF` filial), e as funções `FWxFilial(cAlias)` / `RpcSetEnv(cFilial)` para lê-la e defini-la.

Isso significa que **parte deste trabalho é no motor AdvPP** (outro repositório, mesmo mantenedor), não só no GesCon. As duas frentes estão descritas separadamente abaixo.

---

## Decisões de Design

| Aspecto | Decisão | Motivo |
|---|---|---|
| **Arquitetura de banco** | Único, com coluna `FILIAL` por tabela | AdvPP não troca de banco em runtime — descoberto testando o VM (`SetDBFactory` roda uma vez, antes do `Run()`) |
| **Formato da chave** | 6 chars: `GG`+`UU`+`FF`, convenção Protheus | Pedido explícito — deixa a estrutura pronta pra hierarquia futura (regional/administradora) sem novo schema |
| **Escopo do super admin** | Vê/opera todos os condomínios, sem filtro | Um único login pra quem administra a carteira toda |
| **Escopo do síndico** | 1+ condomínios, via tabela de vínculo | Site real: um síndico pode responder por mais de um prédio |
| **Nível de compartilhamento** | Todas as 22 tabelas em nível 6 (100% exclusivas) | Decisão explícita do usuário — nenhuma tabela do GesCon hoje deve ser compartilhada entre condomínios |
| **Token do portal** | Sem mudança de formato — continua opaco/aleatório | `GCT_TOKEN` ganha `FILIAL`; a busca já devolve tudo junto via JOIN, sem precisar codificar nada no texto do token |
| **Telas `FWMBrowse` (Unidades, Condôminos, Despesas, Cobranças)** | Filtro automático no motor, não em SQL/view | Testado empiricamente: uma VIEW + trigger `INSTEAD OF` não funciona — o motor usa `WHERE rowid = ?` pra Alterar/Excluir, e view não tem rowid; Alterar/Excluir viravam no-op silencioso |
| **Migração dos dados reais** | Vira automaticamente o condomínio nº 1 | Banco já instalado (v1.0.10, 359 cobranças) não pode exigir passo manual pra continuar funcionando |
| **`TCLink`/`TCUnlink`** | Fora de escopo | Resolvem conexão com OUTRO banco/servidor — problema que o GesCon (um `.db` SQLite só) não tem. Ficam como iniciativa própria do AdvPP, não amarrados a esta feature |

---

## Frente 1 — AdvPP (motor)

### Estado de sessão

Novo campo na `VM` (mesmo nível de `dbEngine`/`uiProvider`): `filialAtiva string`.

- **`RpcSetEnv(cFilial)`** — grava a filial ativa da sessão (6 chars). Chamada uma vez, no login do GesCon (ou troca de condomínio).
- **`FWxFilial(cAlias)`** — devolve a filial ativa **truncada/espaçada conforme o nível de compartilhamento configurado pra `cAlias`**. É sempre esse valor que entra numa comparação de igualdade — nunca lógica condicional por nível.

### Nível de compartilhamento

Uma tabela de configuração, consultada pela própria native via o `dbEngine` corrente:

```sql
CREATE TABLE IF NOT EXISTS X2_FILIAL_COMPART (
    TABELA TEXT PRIMARY KEY,
    NIVEL  INTEGER NOT NULL  -- 6=exclusiva, 4=grupo+unidade, 2=só grupo, 0=compartilhada com todos
);
```

Se a tabela não existir, ou não houver linha pra `cAlias`, o default é **6 (mais restritivo)** — falha segura. `FWxFilial(cAlias)` trunca a filial ativa aos primeiros `NIVEL` caracteres e completa o resto com espaço até 6:

```
filialAtiva = "010101"
NIVEL=6 -> "010101"
NIVEL=4 -> "0101  "
NIVEL=2 -> "01    "
NIVEL=0 -> "      "
```

Mesma regra vale pro valor GRAVADO em cada linha — é por isso que uma comparação de igualdade simples (`WHERE FILIAL = FWxFilial(cAlias)`) funciona pra qualquer nível sem `CASE`/lógica condicional.

### `browse.go` — auto-filtro em `FWMBrowse`

Mesmo mecanismo que já existe pra `D_E_L_E_T_` (`hasDelete`), agora também pra `FILIAL`:

- `browseColumns` detecta se a tabela física tem coluna `FILIAL` (`hasFilial`).
- `browseItems`: se `hasFilial`, o `SELECT` ganha `AND FILIAL = ?` (bind em `FWxFilial(alias)`).
- `browseSave`: no Incluir (`Recno == 0`), estampa `FILIAL = FWxFilial(alias)` automaticamente — mesmo padrão que já estampa `D_E_L_E_T_ = ' '`. No Alterar, mantém `WHERE rowid = ?` como hoje (o registro só chega até aqui se já passou pelo filtro do SELECT).

Isso resolve o ponto cego que a VIEW não resolveu: Incluir/Alterar/Excluir continuam batendo direto na tabela real, sem simulação nenhuma, e o filtro fica garantido pelo motor mesmo quando a tela é um `FWMBrowse` cru sem nenhuma query escrita à mão.

### Versionamento

Este trabalho sai como uma versão nova do AdvPP (o `ADVPP_VERSION` do GesCon já pina isso hoje — mesmo mecanismo usado pra travar a versão usada no release).

---

## Frente 2 — GesCon (aplicação)

### Dados novos

**Tabela `COND`** — cadastro de condomínios:
```sql
CREATE TABLE IF NOT EXISTS COND (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    COND_FILIAL TEXT UNIQUE NOT NULL,  -- GGUUFF, 6 chars
    COND_NOME TEXT NOT NULL,
    COND_CNPJ TEXT,
    COND_ENDERECO TEXT,
    COND_ATIVO NUMERIC DEFAULT 1
);
```

**Tabela `USR_COND`** — vínculo síndico↔condomínio (muitos-pra-muitos; super admin não precisa de linha aqui):
```sql
CREATE TABLE IF NOT EXISTS USR_COND (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    USR_LOGIN TEXT NOT NULL,
    FILIAL TEXT NOT NULL
);
```

**Coluna `FILIAL TEXT NOT NULL`** em todas as 22 tabelas dependentes de condomínio (todas menos `SX3` e `USR`, que continuam globais):
`CON`, `UNI`, `DES`, `COB`, `RPT_INADIM`, `RPT_EXTRATO`, `RPT_DESCAT`, `CFG_BOLETO`, `GCT_TOKEN`, `RPT_COND_COBRANCAS`, `PLANO_CONTAS`, `REPARTICAO`, `EXERCICIO`, `LANCAMENTOS`, `RATEIO_DETALHE`, `AUDITORIA`, `RPT_BALANCETE`, `AVISOS`, `RPT_PORTAL_EXTRATOS`, `RPT_PORTAL_AGENDA`, `ANOMALIA_LOG`, `ALERTA`, `DASHBOARD_CACHE`.

Todas entram em `X2_FILIAL_COMPART` com `NIVEL=6` (explícito, mesmo sendo o default — mesmo espírito de já gravar SX3 pra toda coluna mesmo quando o tipo é óbvio).

**Unicidade que precisa virar composta** (SQLite não altera `UNIQUE` de coluna existente via `ALTER TABLE` — a migração recria essas 4 tabelas): `UNI_CODIGO`, `PLA_CODIGO`, `REP_CODIGO`, `EXE_CODIGO` passam de `UNIQUE` global pra `UNIQUE(FILIAL, campo)`.

### Login e sessão

Depois de `GcAutenticar()` batido:

- **`SUPERADMIN`** (o primeiro admin, criado no bootstrap — vira esse perfil automaticamente): lista todos os `COND` ativos.
- **`SINDICO`**: lista só os vinculados via `USR_COND`.
- Exatamente 1 condomínio disponível → seleciona sozinho, sem tela.
- Zero disponível (síndico sem vínculo) → bloqueia login com mensagem clara.
- Condomínio escolhido: `Private g_cFilialAtiva := cFilial` (mesmo padrão de `g_cUniPortal`/`g_cConPortal` já usado hoje) **e** `RpcSetEnv(cFilial)` — os dois precisam ficar em sincronia, o `Private` pra exibição (título de menu etc.), o native pra todo filtro de fato.
- Item novo no menu principal, **"Trocar Condomínio"** — reabre o mesmo picker sem deslogar.

`GcCriarAdminNovo` (Usuários → Criar Usuário) ganha a pergunta de perfil (Super Admin / Síndico) e, se Síndico, a seleção de 1+ condomínios pra gravar em `USR_COND`. Tanto super admin quanto síndico podem cadastrar condomínio novo (tela nova, "Condomínios", no menu principal) — síndico que cadastra nasce vinculado ao que criou.

### Queries manuais

Toda query hoje escrita à mão (`db.prw`, `cobrancas.prw`, `fechamento.prw`, etc.) ganha `" AND FILIAL = '" + GcSqlLit(FWxFilial(cAlias)) + "'"` — mesma frase que qualquer fonte Protheus real já carrega, só que aqui de verdade em vez de assumida. Todo `INSERT` grava `FILIAL = FWxFilial(cAlias)` na criação da linha.

### Token do portal

`GCT_TOKEN` ganha `FILIAL` (copiado de `CON.FILIAL` ao gerar o token). A consulta que resolve token→condômino→unidade ganha `JOIN COND` e devolve o nome do condomínio junto — pronto pra cabeçalho da tela do portal, sem mudar o formato do token.

### Migração dos dados reais

No `GcBootstrapDB()` (já roda em todo start, idempotente):
```sql
INSERT OR IGNORE INTO COND (COND_FILIAL, COND_NOME) VALUES ('010101', 'Condomínio 1');
UPDATE <tabela> SET FILIAL = '010101' WHERE FILIAL IS NULL OR FILIAL = '';
-- repete pra cada uma das 22 tabelas
```
O `.exe` já instalado (v1.0.10) sobe direto no condomínio nº 1 sem passo manual.

---

## Fora de Escopo

- **`TCLink`/`TCUnlink`** — não resolvem um problema que o GesCon tem hoje (um banco só). Ficam como iniciativa própria do AdvPP.
- **Hierarquia real de grupo/unidade/filial na UI** — o formato de 6 caracteres fica pronto, mas nenhuma tela trata os 3 níveis separadamente agora; GesCon usa a chave inteira como um código de condomínio opaco.
- **Compartilhamento parcial (níveis 0/2/4)** — o motor suporta, mas nenhuma tabela do GesCon usa por decisão explícita nesta rodada. Fica disponível pro dia em que fizer sentido (ex.: um plano de contas modelo compartilhado).
- **Relatórios agregados entre condomínios** (ex.: receita total da carteira da administradora) — cada relatório continua por condomínio ativo.
- **Permissões finas por funcionalidade** (ex.: síndico sem acesso a Contabilidade) — endereçado como limitação conhecida separada, não faz parte desta feature.

---

## Testes Esperados

**AdvPP:**
- ✅ `RpcSetEnv`/`FWxFilial` — sessão isolada, nível 6 devolve os 6 chars, nível 4/2/0 truncam e espaçam corretamente
- ✅ `browse.go`: Incluir estampa `FILIAL` correta; Listar só mostra linhas da filial ativa; Alterar/Excluir seguem funcionando (não eram o caso quebrado da VIEW)
- ✅ Tabela sem `FILIAL` (a maioria dos programas AdvPP fora do GesCon) — comportamento inalterado

**GesCon:**
- ✅ Dois condomínios com unidade de mesmo código (`101`) coexistindo sem colisão
- ✅ Síndico vinculado a 1 condomínio não vê o outro em nenhuma tela
- ✅ Super admin vê os dois, troca entre eles pelo menu
- ✅ Token gerado num condomínio resolve pro condomínio certo no portal
- ✅ Migração: banco real (359 cobranças) sobe no condomínio nº 1 sem intervenção
- ✅ `scripts/check-triggers.sh`-style: tentativa de link cruzado (`UNI_CONDOMINO` de um condomínio referenciando `CON` de outro) continua rejeitada

---

## Referências

- Investigação de arquitetura desta spec (banco único vs arquivo por condomínio, VIEW quebrada) — conversa de design, 2026-08-08
- `docs/FUNCIONAL.md` — limitações conhecidas anteriores a esta feature
- AdvPP `pkg/vm/browse.go`, `pkg/vm/vm.go` — mecanismo atual de `FWMBrowse` e estado de sessão da VM
