# Arquitetura técnica — GesCon

Este documento descreve como o GesCon é construído por dentro: stack,
estrutura de arquivos, modelo de dados, grafo de dependências entre
fontes, e as decisões técnicas (e limitações conhecidas) que moldaram a
implementação. Para o que o sistema faz do ponto de vista de quem usa,
ver [`FUNCIONAL.md`](FUNCIONAL.md).

## Stack

- **Linguagem**: AdvPL/TLPP (dialeto Clipper/xBase usado no ecossistema
  TOTVS Protheus).
- **Compilador/runtime**: [AdvPP](https://github.com/peder1981/AdvPP)
  — compilador e VM open-source para AdvPL/TLPP, escrito em Go. GesCon
  requer **`advplc` v1.23.1+**.
- **Banco de dados**: SQLite, via a camada de banco compartilhada do
  AdvPP (mesmo arquivo `.db` usado por outras ferramentas AdvPP —
  `~/.advpp/ADVPP.db` por padrão) — igual nos dois modos de UI abaixo,
  então dados cadastrados por um aparecem no outro.
- **UI, duas formas, mesmo `.prw`**:
  - **Web** (`advplc serve gescon.prw`) — as telas usam `FWMBrowse`
    (framework MVC do AdvPP), renderizado como PO-UI/Angular no
    navegador.
  - **Desktop** (`advplc build gescon.prw -o GesConApp`) — executável
    nativo standalone (Fyne), sem navegador nem servidor à parte; usa o
    mesmo bytecode compilado, embutido no binário.
  - Em ambos, a navegação entre telas usa `FWMenuSelect`/`FWGetText`
    (capacidades próprias do AdvPP, sem equivalente em Protheus real,
    motivadas por este projeto — v1.23.0) e um tema visual próprio
    (azul-petróleo, não o roxo padrão do PO-UI/Fyne — v1.23.1). Não há
    frontend separado do GesCon em si; o `.prw` é a única fonte da UI
    nos dois modos — a diferença de aparência vem inteiramente do
    renderer escolhido no AdvPP.
- **E-mail**: `TMailMessage` (classe nativa do AdvPP, `net/smtp` da
  stdlib do Go — sem dependência externa).

## Estrutura de arquivos

```
GesCon/
├── gescon.prw              # ponto de entrada — advplc serve gescon.prw
├── schema.sql               # DDL das 11 tabelas + metadados SX3 (labels)
├── scripts/
│   └── bootstrap-db.sh      # aplica schema.sql no banco compartilhado
├── src/
│   ├── db.prw                # GcSqlLit — escape de literal SQL
│   ├── login.prw             # GcLogin, GcCriarAdmin, GcAutenticar, GcCredenciaisValidas,
│   │                         #    GcTrocarSenha — gate de acesso e troca de senha
│   ├── condominos.prw        # GcCondominos — cadastro (browse sobre CON)
│   ├── unidades.prw          # GcUnidades — cadastro (browse sobre UNI)
│   ├── despesas.prw          # GcDespesas — lançamento (browse sobre DES)
│   ├── fechamento.prw        # GcFecharMes, GcProximoVencimento, GcAtualizarInadimplentes
│   ├── cobrancas.prw         # GcCobrancas, GcRegistrarPagamento
│   ├── malas.prw             # GcMalaDireta — mala direta com envio real
│   ├── relatorios.prw        # Balancete/Inadimplência/Extrato/Despesas por categoria
│   ├── usuarios.prw          # GcMenuUsuarios, GcGerarToken, GcRevogarToken, GcCriarUsuario,
│   │                         #    GcCriarAdminNovo, GcDateToIso, GcGerarTokenId
│   ├── portal.prw            # GcPortalCondmino, GcAuthPortalToken, GcPortalBrowse,
│   │                         #    GcPortalCalcCobrancas, GcSairPortal
│   └── boleto.prw            # GcGeraBoleto, GcFormatLinhaDigitavel, GcGeraCodigoBarras
│                           #    (Itaú/Bradesco)
├── tests/
│   ├── db_test.prw
│   ├── login_test.prw
│   ├── fechamento_test.prw
│   ├── pagamento_test.prw
│   ├── malas_test.prw
│   ├── relatorios_test.prw
│   └── portal_test.prw       # fixture end-to-end do portal (token+auth+cobranças)
└── docs/
    ├── ARQUITETURA.md        # este arquivo
    ├── FUNCIONAL.md
    └── superpowers/           # histórico de design/planejamento (spec, plano, ledger)
```

Cada arquivo em `src/` tem uma responsabilidade única: uma tela/rotina
de negócio. `db.prw` é a única exceção — é a camada de escape de SQL
usada por qualquer outro arquivo que precise interpolar texto numa
query.

## Modelo de dados

11 tabelas, todas com a convenção de exclusão lógica estilo Protheus
(`R_E_C_N_O_`/`D_E_L_E_T_`/`R_E_C_D_E_L_`) — ver `schema.sql` para o DDL
completo.

| Tabela | Campos de negócio | Papel |
|---|---|---|
| `CON` | `CON_CODIGO`, `CON_NOME`, `CON_CPF`, `CON_EMAIL`, `CON_TEL` | Condômino |
| `UNI` | `UNI_CODIGO`, `UNI_BLOCO`, `UNI_FRACAO`, `UNI_CONDOMINO` | Unidade — `UNI_CONDOMINO` é o `CON_CODIGO` do responsável, texto livre |
| `DES` | `DES_DESCR`, `DES_CATEG`, `DES_VALOR`, `DES_COMPET`, `DES_DTLANC` | Despesa lançada numa competência ("YYYY-MM") |
| `COB` | `COB_UNIDADE`, `COB_COMPET`, `COB_VALOR`, `COB_VENCTO`, `COB_STATUS`, `COB_DTPAG` | Cobrança — gerada só pelo Fechamento Mensal |
| `USR` | `USR_LOGIN`, `USR_SENHA`, `USR_PERFIL` | Usuário administrador — `USR_SENHA` guarda hash SHA-256 (`FWHash`), nunca texto puro; `USR_PERFIL` em `'ADMIN'` |
| `RPT_INADIM` | `RIN_UNIDADE`, `RIN_COMPET`, `RIN_VALOR`, `RIN_VENCTO`, `RIN_ATRASO` | Snapshot do relatório de Inadimplência — recalculado a cada abertura |
| `RPT_EXTRATO` | `REX_COMPET`, `REX_VALOR`, `REX_VENCTO`, `REX_STATUS`, `REX_DTPAG` | Snapshot do Extrato por Unidade — recalculado a cada abertura |
| `RPT_DESCAT` | `RDC_CATEG`, `RDC_TOTAL` | Snapshot de Despesas por Categoria — recalculado a cada abertura |
| `CFG_BOLETO` | `CFG_BANCO`, `CFG_AGENCIA`, `CFG_CONTA`, `CFG_COBRT`, `CFG_CARTEIRA` | Configuração de boleto bancário (código banco, agência, conta, carta/cartão, carteira) |
| `GCT_TOKEN` | `TOKEN`, `USR_LOGIN`, `CON_CODIGO`, `UNI_CODIGO`, `CRIPTADO`, `VALIDO_ATE`, `USADO` | Token temporário de acesso do condômino ao portal — válido por 48h, marcado como usado na autenticação |
| `RPT_COND_COBRANCAS` | `RCC_UNIDADE`, `RCC_COMPET`, `RCC_VALOR`, `RCC_VENCTO`, `RCC_STATUS`, `RCC_DTPAG` | Snapshot das cobranças do condômino no portal — gerado a partir de `COB` filtrado pela unidade do token |

Relacionamentos: `UNI.UNI_CONDOMINO → CON.CON_CODIGO` (texto livre, sem
FK/combo — ver "Limitações conhecidas"). `COB.COB_UNIDADE →
UNI.UNI_CODIGO`. `DES` não se relaciona com unidade — despesas são do
condomínio como um todo, rateadas por fração ideal no fechamento. `GCT_TOKEN.UNI_CODIGO → UNI.UNI_CODIGO` (vincula token à unidade). `GCT_TOKEN.CON_CODIGO → CON.CON_CODIGO` (vincula token ao condômino). As tabelas `RPT_*` e `RPT_COND_COBRANCAS` não têm relacionamento formal — são só a área de
staging de cada relatório/tabulação.

A tabela `SX3` (compartilhada com outras ferramentas AdvPP) guarda
metadados de coluna (título amigável, tipo, tamanho) que o `FWMBrowse`
usa para renderizar as colunas — sem essas linhas o browse cai no
fallback de mostrar toda coluna física como texto cru.

## Relatórios: por que uma tabela de snapshot, não uma VIEW

`FWMBrowse` só sabe abrir uma tabela física por um alias fixo — o
Go por trás (`pkg/vm/browse.go`) monta a query como
`SELECT rowid AS browse_recno_, * FROM <alias>` e as ações de
Editar/Excluir como `UPDATE/DELETE ... WHERE rowid = ?`. Não dá pra
passar parâmetro nenhum (competência, unidade) nem apontar pra uma
consulta agregada direto — e uma `VIEW` do SQLite não tem `rowid`
próprio (views não têm armazenamento), então `UPDATE`/`DELETE` contra
ela falhariam.

Solução adotada, consistente com como `GcFecharMes` já grava
`Cobrança`: cada relatório tabular (Inadimplência, Extrato por
Unidade, Despesas por Categoria) e o portal do condômino têm sua própria
tabela `RPT_*` de "snapshot" — a função recalcula o conteúdo do zero
(`DELETE` + `INSERT`) toda vez que é aberto, então nunca fica
desatualizado, e o `FWMBrowse` funciona sem nenhuma mudança no AdvPP.
Balancete Mensal é a exceção: é um resumo de 3 números (receitas/despesas/saldo),
não uma lista — mostrado via `MsgInfo`, sem tabela nenhuma.

Cada relatório tabular vem em duas funções — `GcXxxCalc()` (só grava o
snapshot, testável via `advplc run`) e `GcXxx()` (chama a `Calc` e abre
o browse, só funciona em `advplc serve`/`build`) — mesmo motivo de
`GcCondominos`/`GcUnidades`/etc nunca serem testadas via `advplc run`:
`FWMBrowse:Activate()` exige uma sessão de UI de verdade.

## Grafo de dependências (`#include`)

```
gescon.prw ──include──> src/db.prw
           ──include──> src/login.prw       (que também inclui db.prw)
           ──include──> src/unidades.prw
           ──include──> src/condominos.prw
           ──include──> src/despesas.prw
           ──include──> src/cobrancas.prw
           ──include──> src/fechamento.prw  (que também inclui db.prw)
           ──include──> src/malas.prw       (que também inclui db.prw)
           ──include──> src/relatorios.prw  (que também inclui db.prw)
           ──include──> src/usuarios.prw   (que também inclui db.prw)
           ──include──> src/portal.prw     (que também inclui db.prw)
           ──include──> src/boleto.prw     (GcGeraBoleto — Itaú/Bradesco)
```

`gescon.prw` inclui todas as telas — é o único arquivo raiz real do
projeto (`advplc serve gescon.prw`), então precisa trazer tudo que
`GesCon()` (a única função declarada diretamente nele) usa, direta ou
transitivamente.

**Gotcha real do AdvPP, documentado em código onde apareceu**: `#include`
é resolvido **relativo ao diretório do arquivo RAIZ compilado**, não de
quem faz o `#include`. Um `#include "db.prw"` (sem caminho) dentro de
`src/fechamento.prw` só resolve quando a raiz está em `src/` — de
`tests/`, o mesmo símbolo precisa de um include explícito com caminho
relativo à raiz (`#include "../src/db.prw"`), mesmo que pareça
redundante com o include que `fechamento.prw` já faz. Ver comentário em
`tests/fechamento_test.prw`. Isso não é peculiaridade do GesCon — é
como o preprocessor do AdvPP resolve includes hoje.

**Ponto de entrada implícito**: um `.prw` sem código de nível superior
roda implicitamente a primeira `User Function` declarada no arquivo
raiz (ignorando funções trazidas por `#include`) — corrigido no AdvPP
v1.22.1 depois de descoberto durante este projeto (antes disso, uma lib
auxiliar de uma função só podia virar, sem aviso, o "programa"
executado no lugar da função real). Por isso `gescon.prw` e cada
arquivo de teste têm exatamente uma `User Function` própria, declarada
depois de todos os `#include`s.

## Referência de funções

| Função | Arquivo | Assinatura | Retorno |
|---|---|---|---|
| `GesCon` | `gescon.prw` | `GesCon()` | — (ponto de entrada; loop de menu via `FWMenuSelect`/`FWGetText`, AdvPP v1.23.0+) |
| `GcSqlLit` | `src/db.prw` | `GcSqlLit(cValor)` | `character` — valor com aspas simples escapadas |
| `GcLogin` | `src/login.prw` | `GcLogin()` | `logical` — `.T.` se autenticado |
| `GcCriarAdmin` | `src/login.prw` | `GcCriarAdmin()` | `logical` — bootstrap do 1º acesso |
| `GcAutenticar` | `src/login.prw` | `GcAutenticar()` | `logical` — confere login/senha (hash) |
| `GcCredenciaisValidas` | `src/login.prw` | `GcCredenciaisValidas(cLogin, cSenha)` | `logical` |
| `GcTrocarSenha` | `src/login.prw` | `GcTrocarSenha()` | `logical` — `.T.` se trocou |
| `GcCondominos` | `src/condominos.prw` | `GcCondominos()` | — (abre browse) |
| `GcUnidades` | `src/unidades.prw` | `GcUnidades()` | — (abre browse) |
| `GcDespesas` | `src/despesas.prw` | `GcDespesas()` | — (abre browse) |
| `GcFecharMes` | `src/fechamento.prw` | `GcFecharMes(cCompetencia, nDiaVenc)` | `logical` — `.T.` se fechou |
| `GcProximoVencimento` | `src/fechamento.prw` | `GcProximoVencimento(cCompetencia)` | `character` — "YYYY-MM-DD" |
| `GcAtualizarInadimplentes` | `src/fechamento.prw` | `GcAtualizarInadimplentes()` | — (promove pendentes→atrasados) |
| `GcCobrancas` | `src/cobrancas.prw` | `GcCobrancas()` | — (abre browse) |
| `GcRegistrarPagamento` | `src/cobrancas.prw` | `GcRegistrarPagamento(nRecno, dData)` | `logical` |
| `GcMalaDireta` | `src/malas.prw` | `GcMalaDireta(cCompetencia)` | `numeric` — quantidade enviada |
| `GcBalanceteMensal` | `src/relatorios.prw` | `GcBalanceteMensal(cCompetencia)` | `numeric` — saldo (receitas − despesas); mostra `MsgInfo` |
| `GcInadimplenciaCalc` / `GcInadimplencia` | `src/relatorios.prw` | `GcInadimplenciaCalc()` / `GcInadimplencia()` | `numeric` (Calc) / — (abre browse) |
| `GcExtratoUnidadeCalc` / `GcExtratoUnidade` | `src/relatorios.prw` | `GcExtratoUnidadeCalc(cUnidade)` / `GcExtratoUnidade(cUnidade)` | `numeric` (Calc) / — (abre browse) |
| `GcDespesasCategoriaCalc` / `GcDespesasCategoria` | `src/relatorios.prw` | `GcDespesasCategoriaCalc(cCompetencia)` / `GcDespesasCategoria(cCompetencia)` | `numeric` (Calc) / — (abre browse) |
| `GcMenuRelatorios` | `gescon.prw` | `GcMenuRelatorios()` | — (submenu de Relatórios) |
| `GcMenuUsuarios` | `src/usuarios.prw` | `GcMenuUsuarios()` | — (submenu de usuários: gerar token, revogar, criar) |
| `GcGerarToken` | `src/usuarios.prw` | `GcGerarToken()` | — (gera token para condômino, lista CON-UNI) |
| `GcRevogarToken` | `src/usuarios.prw` | `GcRevogarToken()` | — (revoga token ativo por DELETE lógico) |
| `GcCriarUsuario` | `src/usuarios.prw` | `GcCriarUsuario()` | — (cria novo usuário admin) |
| `GcCriarAdminNovo` | `src/usuarios.prw` | `GcCriarAdminNovo()` | `logical` |
| `GcDateToIso` | `src/usuarios.prw` | `GcDateToIso(dData)` | `character` — data em ISO (YYYY-MM-DD) |
| `GcGerarTokenId` | `src/usuarios.prw` | `GcGerarTokenId()` | `character` — token UUID-like 36 chars |
| `GcPortalCondmino` | `src/portal.prw` | `GcPortalCondmino()` | `logical` — gateway do portal |
| `GcAuthPortalToken` | `src/portal.prw` | `GcAuthPortalToken(cToken)` | `logical` — valida e marca token como usado |
| `GcPortalBrowse` | `src/portal.prw` | `GcPortalBrowse()` | — (abre browse de cobranças da unidade) |
| `GcPortalCalcCobrancas` | `src/portal.prw` | `GcPortalCalcCobrancas()` | `numeric` — qtd linhas geradas em RPT_COND_COBRANCAS |
| `GcSairPortal` | `src/portal.prw` | `GcSairPortal()` | — (limpa estado do portal) |
| `GcGeraBoleto` | `src/boleto.prw` | `GcGeraBoleto(nRecnoCob)` | `logical` — abre diálogo de configuração do boleto |
| `GcFormatLinhaDigitavel` | `src/boleto.prw` | `GcFormatLinhaDigitavel(cBanco, cAgencia, cConta, cCobrta, cCarteira, nFatorVenc, nValor, cDV)` | `character` — linha digitável formatada |
| `GcGeraCodigoBarras` | `src/boleto.prw` | `GcGeraCodigoBarras(cBanco, cAgencia, cConta, cCobrta, cCarteira, nFatorVenc, nValor, cDV)` | `character` — 44 digits do código de barras |

## Acesso a dados

Todo acesso ao banco é via `TCSqlExec`/`TCSqlQuery` (SQL direto, nativos
do AdvPP) — não a API clássica de work-area (`DbAppend`/`RecLock`/
`FieldPut`/`MsUnlock`). Escolha deliberada: o Fechamento Mensal e a Mala
Direta gravam a partir de lógica de negócio em loop (uma `Cobrança` por
unidade, um e-mail por condômino), não de clique de UI — `TCSqlExec`
serve melhor esse padrão do que a API record-at-a-time.

Todo valor de texto interpolado numa query passa por `GcSqlLit()`
(escapa aspas simples — não há parâmetros bind na API atual). Valores
numéricos/data não passam por `GcSqlLit` porque seu tipo já garante
ausência de aspas/caracteres de escape.

As telas (`GcCondominos`, `GcUnidades`, `GcDespesas`, `GcCobrancas`) não
usam SQL direto — usam `FWMBrowse`, que grava via código Go interno do
AdvPP (não pelo `TCSqlExec`/work-area), acionado por clique na UI web.

## Gestão de usuários (Plano 2)

`GcMenuUsuarios()` abre submenu com 3 opções: gerar token, revogar token
e criar novo admin. `GcCriarUsuario()` → `GcCriarAdminNovo()` insere na
tabela `USR` com `USR_PERFIL = 'ADMIN'` e hash SHA-256 da senha — mesmo
padrão do login principal mas via `FWGetText cSenha` normal (sem
máscara, já que o campo de senha mascarado exige `bIsPassword=.T.`).

## Portal do condômino (Plano 2)

GcPortalCondmino() autentica um token na tabela `GCT_TOKEN`, marca como
usado (`USADO = 1`) e abre `FWMBrowse` sobre `RPT_COND_COBRANCAS`, que
é um snapshot recalculado do zero pela função `GcPortalCalcCobrancas()`
(contém só as cobranças da unidade vinculada ao token). O token é válido
por 48h e pode ser revogado a qualquer momento pelo admin via
`GcRevogarToken()` (DELETE lógico em `GCT_TOKEN`).

O fluxo de geração de token (`GcGerarToken()`) lista condôminos com sua
unidade, o admin seleciona por índice, e o sistema gera um token
UUID-like via `GcGerarTokenId()` (SHA-256 de timestamp + random AdvPL).
O token é mostrado ao admin em `MsgInfo` para repassar ao condômino.

## Boleto bancário (Plano 2)

`GcGeraBoleto(nRecnoCob)` abre diálogo para preencher parâmetros do
boleto (banco, agência, conta, carta/cedente, carteira, fator vencimento,
valor, DV), depois monta a linha digitável com DV via
`GcFormatLinhaDigitavel()` e o código de barras em 44 dígitos via
`GcGeraCodigoBarras()` — suportando bancos Itaú (341/237) e Bradesco
(237).

## Decisões e limitações conhecidas

- **Cobrança é editável pela UI.** `GcCobrancas()` usa o mesmo
  `FWMBrowse` editável das outras telas — nada impede editar/excluir uma
  `Cobrança` (inclusive `COB_VALOR`) fora do fluxo de Fechamento
  Mensal/Registrar Pagamento. A garantia "valor travado no fechamento" é
  imposta pela lógica de negócio, **não pela UI**. O AdvPP tem um campo
  `ReadOnly` em `FWFormBrowse` (`pkg/mvc/browse.go`), mas ele não está
  ligado a nada (nem dispatch nativo, nem renderer web) — tornar isso
  real exigiria trabalho novo no compilador. Aceito para a v1 (login
  único, uso pessoal/piloto).
- **`GetMV()` é um stub no AdvPP** — sempre retorna o valor padrão
  passado, nunca lê configuração real (confirmado em teste direto:
  `GetMV("X", .F., "y")` retorna `.F.`, não `"y"`). Por isso a
  configuração SMTP da mala direta usa `GetEnv()` (variáveis de
  ambiente), não `GetMV()`.
- **Sem transação em volta do loop de `INSERT` do Fechamento Mensal.**
  Se `TCSqlExec` falhar no meio do loop (uma unidade gravada, outra
  não), a trava de duplicidade impede qualquer nova tentativa de fechar
  a competência — não há caminho de recuperação automática. A
  infraestrutura de banco do GesCon (via `TCSqlExec`) não expõe
  `Begin/End Transaction`; corrigir isso exigiria trabalho no AdvPP.
- **Vínculo Unidade→Condômino é texto livre**, sem combo/lookup — o
  `FWMBrowse` não expõe esse tipo de campo relacionado na integração
  atual. Aceitável para o volume de dados de um condomínio.
- **`advplc check` não pega tudo.** Validação de sintaxe por arquivo não
  garante que um símbolo trazido por `#include` transitivo resolve de
  fato em tempo de execução — sempre rodar `advplc run` nos testes, não
  só `advplc check`.

## Testes

Estratégia dupla:

- `advplc check <arquivo>` em todo `.prw` — gate de sintaxe.
- Fixtures end-to-end via `advplc run tests/*.prw`, cobrindo o fluxo de
  negócio real (não mocks): cadastrar → lançar despesa → fechar mês →
  conferir cálculo → registrar pagamento → conferir status, e mala
  direta contra um handshake SMTP real. Todo teste isola seus próprios
  dados (códigos como `T01`/`PAGTEST`/`MALATEST`) com `DELETE` no setup
  **e no teardown** — o banco usado é o mesmo compartilhado da aplicação
  real (`~/.advpp/ADVPP.db`), não há banco de teste isolado, então o
  teardown não é opcional.

## Bugs reais e capacidades novas encontradas/motivadas no AdvPP

Este projeto é, deliberadamente, um caso real de validação do
compilador (não só uso). Achados reais durante o desenvolvimento:

**Bugs corrigidos:**

1. `DbAppend`/`RecLock`/`FieldPut`/`MsUnlock` não persistiam dado
   nenhum de verdade — só `FWMBrowse` gravava (código Go interno
   acionado por clique de UI). Corrigido no AdvPP v1.22.0.
2. `Begin Sequence...Recover` sem `Using oErr` corrompia o slot local 0
   da função com o objeto de erro — qualquer variável declarada
   primeiro, sem relação nenhuma com o catch. Corrigido no v1.22.0.
3. Ponto de entrada implícito (arquivo sem código de nível superior)
   escolhia a primeira `User Function` declarada em vez da própria do
   arquivo raiz, quando havia `#include` de uma lib auxiliar. Corrigido
   no v1.22.1.
4. Comparar uma variável nunca atribuída a `Nil` derrubava a VM com
   `SIGSEGV` (`Local x` sem inicializador, ou parâmetro não passado).
   Corrigido no v1.22.1 — achado junto com o bug 3.
5. `MsgInfo`/`MsgAlert`/`MsgStop` não bloqueavam no backend desktop
   (Fyne) — a VM seguia em frente sem esperar o usuário ver o diálogo,
   empilhando telas num loop de menu. Corrigido no v1.23.2.

**Capacidades novas motivadas por necessidade real deste projeto:**

- `TCSqlExec`/`TCSqlQuery` (v1.22.0) — SQL direto pra lógica de
  negócio, usado pelo Fechamento Mensal e pela Mala Direta.
- `TMailMessage` (v1.22.0) — envio real de e-mail via `net/smtp`,
  usado pela Mala Direta.
- `FWMenuSelect`/`FWGetText` (v1.23.0) — navegação multi-tela em
  `advplc serve`, usado pelo menu de `gescon.prw`.
- Identidade visual própria + menu com ícone por item, em web e
  desktop (v1.23.1) — antes disso o menu era uma pilha de botões
  cheios sem nenhum ícone, na paleta roxa padrão do PO-UI/Fyne.
  `advplc build` também ganhou título de janela real (o nome do fonte,
  não mais "AdvPP" genérico).
- `FWHash` (v1.23.5) — hash SHA-256 (stdlib do Go), usado pelo login
  pra nunca gravar senha em texto puro; o AdvPP não tinha função de
  hash nenhuma antes disso.
- `FWGetText` com 3º arg `bIsPassword` (v1.24.0) — campo de senha
  mascarado em web e desktop, usado pela tela de login e criação de
  admin.

Ver o `CHANGELOG.md` do [AdvPP](https://github.com/peder1981/AdvPP)
para o detalhe técnico completo de cada um.

## Histórico de design

O processo completo de design (perguntas, alternativas consideradas,
decisões e por quê) está em `docs/superpowers/specs/` e
`docs/superpowers/plans/` — útil para entender o *raciocínio* por trás
de uma decisão, não só o resultado final documentado aqui.
