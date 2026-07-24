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
  requer **`advplc` v1.22.1+**.
- **Banco de dados**: SQLite, via a camada de banco compartilhada do
  AdvPP (mesmo arquivo `.db` usado por outras ferramentas AdvPP —
  `~/.advpp/ADVPP.db` por padrão).
- **UI**: web, servida pelo próprio `advplc serve` — as telas usam
  `FWMBrowse` (framework MVC do AdvPP), renderizado como PO-UI no
  navegador. Não há frontend separado; o `.prw` é a única fonte da UI.
- **E-mail**: `TMailMessage` (classe nativa do AdvPP, `net/smtp` da
  stdlib do Go — sem dependência externa).

## Estrutura de arquivos

```
GesCon/
├── gescon.prw              # ponto de entrada — advplc serve gescon.prw
├── schema.sql               # DDL das 5 tabelas + metadados SX3 (labels)
├── scripts/
│   └── bootstrap-db.sh      # aplica schema.sql no banco compartilhado
├── src/
│   ├── db.prw                # GcSqlLit — escape de literal SQL
│   ├── condominos.prw        # GcCondominos — cadastro (browse sobre CON)
│   ├── unidades.prw          # GcUnidades — cadastro (browse sobre UNI)
│   ├── despesas.prw          # GcDespesas — lançamento (browse sobre DES)
│   ├── fechamento.prw        # GcFecharMes, GcProximoVencimento
│   ├── cobrancas.prw         # GcCobrancas, GcRegistrarPagamento
│   └── malas.prw             # GcMalaDireta — mala direta com envio real
├── tests/
│   ├── db_test.prw
│   ├── fechamento_test.prw
│   ├── pagamento_test.prw
│   └── malas_test.prw
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

5 tabelas, todas com a convenção de exclusão lógica estilo Protheus
(`R_E_C_N_O_`/`D_E_L_E_T_`/`R_E_C_D_E_L_`) — ver `schema.sql` para o DDL
completo.

| Tabela | Campos de negócio | Papel |
|---|---|---|
| `CON` | `CON_CODIGO`, `CON_NOME`, `CON_CPF`, `CON_EMAIL`, `CON_TEL` | Condômino |
| `UNI` | `UNI_CODIGO`, `UNI_BLOCO`, `UNI_FRACAO`, `UNI_CONDOMINO` | Unidade — `UNI_CONDOMINO` é o `CON_CODIGO` do responsável, texto livre |
| `DES` | `DES_DESCR`, `DES_CATEG`, `DES_VALOR`, `DES_COMPET`, `DES_DTLANC` | Despesa lançada numa competência ("YYYY-MM") |
| `COB` | `COB_UNIDADE`, `COB_COMPET`, `COB_VALOR`, `COB_VENCTO`, `COB_STATUS`, `COB_DTPAG` | Cobrança — gerada só pelo Fechamento Mensal |
| `USR` | `USR_LOGIN`, `USR_SENHA` | Usuário administrador único (login ainda não implementado na UI) |

Relacionamentos: `UNI.UNI_CONDOMINO → CON.CON_CODIGO` (texto livre, sem
FK/combo — ver "Limitações conhecidas"). `COB.COB_UNIDADE →
UNI.UNI_CODIGO`. `DES` não se relaciona com unidade — despesas são do
condomínio como um todo, rateadas por fração ideal no fechamento.

A tabela `SX3` (compartilhada com outras ferramentas AdvPP) guarda
metadados de coluna (título amigável, tipo, tamanho) que o `FWMBrowse`
usa para renderizar as colunas — sem essas linhas o browse cai no
fallback de mostrar toda coluna física como texto cru.

## Grafo de dependências (`#include`)

```
gescon.prw ──include──> src/unidades.prw
src/fechamento.prw ──include──> src/db.prw
src/malas.prw ──include──> src/db.prw
src/cobrancas.prw            (sem include próprio — só totvs.ch)
src/condominos.prw           (sem include próprio — só totvs.ch)
src/despesas.prw             (sem include próprio — só totvs.ch)
```

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
| `GesCon` | `gescon.prw` | `GesCon()` | — (ponto de entrada) |
| `GcSqlLit` | `src/db.prw` | `GcSqlLit(cValor)` | `character` — valor com aspas simples escapadas |
| `GcCondominos` | `src/condominos.prw` | `GcCondominos()` | — (abre browse) |
| `GcUnidades` | `src/unidades.prw` | `GcUnidades()` | — (abre browse) |
| `GcDespesas` | `src/despesas.prw` | `GcDespesas()` | — (abre browse) |
| `GcFecharMes` | `src/fechamento.prw` | `GcFecharMes(cCompetencia)` | `logical` — `.T.` se fechou |
| `GcProximoVencimento` | `src/fechamento.prw` | `GcProximoVencimento(cCompetencia)` | `character` — "YYYY-MM-DD" |
| `GcCobrancas` | `src/cobrancas.prw` | `GcCobrancas()` | — (abre browse) |
| `GcRegistrarPagamento` | `src/cobrancas.prw` | `GcRegistrarPagamento(nRecno, dData)` | `logical` |
| `GcMalaDireta` | `src/malas.prw` | `GcMalaDireta(cCompetencia)` | `numeric` — quantidade enviada |

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

## Histórico de design

O processo completo de design (perguntas, alternativas consideradas,
decisões e por quê) está em `docs/superpowers/specs/` e
`docs/superpowers/plans/` — útil para entender o *raciocínio* por trás
de uma decisão, não só o resultado final documentado aqui.
