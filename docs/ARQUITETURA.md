# Arquitetura técnica — GesCon

Visão técnica para quem vai manter o código. Uso das telas: [Manual do
usuário](../MANUAL_USUARIO.md); padrão de tela: [PADRAO_GUI.md](PADRAO_GUI.md).

## Stack

- **Linguagem**: AdvPL/TLPP (fontes UTF-8).
- **Compilador/runtime**: [AdvPP](https://github.com/peder1981/AdvPP) — GesCon
  requer **`advplc` v4.8.6** (fixado em `ADVPP_VERSION`; a CI, o release, o
  deploy e `scripts/test.sh` conferem).
- **Interface**: web, componentes PO-UI (`PoApp`, `PoPage`, `PoTable`,
  `PoWidget`...) servidos pelo `advplc serve gescon.prw`. Cada sessão do
  navegador é um programa próprio; o estado da sessão fica nas `Private` de
  `GesCon()`.
- **Banco de dados**: SQLite (`ADVPP_DB` ou `--db-path`), schema embutido no
  programa (`src/schema-embed.prw`, gerado de `schema.sql`) e aplicado em
  todo boot com as migrações de `src/db.prw`.
- **Distribuição**: `packaging/` — iniciador em Go (só biblioteca padrão) que
  sobe o servidor em 127.0.0.1 e abre o navegador, pacotes por plataforma com
  o `advplc` da release e instalador Windows NSIS. Servidor: `deploy/`.

## Estrutura de arquivos

| Caminho | Conteúdo |
|---|---|
| `gescon.prw` | Ponto de entrada: estado da sessão, boot do banco, `GcUI()` |
| `src/ui.prw` | Interface (páginas, menu por perfil, sessão, portal) |
| `src/consultas.prw` | Consultas `{colunas, linhas}` das tabelas e relatórios |
| `src/cadastros.prw` | Gravação validada: condômino, unidade, despesa, condomínio; CPF/CNPJ |
| `src/operacoes.prw` | Token do portal, dados bancários, exercício, usuários, plano de contas, lançamento manual |
| `src/seguranca.prw` | Senha (Argon2id), bloqueio, política, primeiro acesso, perfis (`GcPode`) |
| `src/fechamento.prw` | Fechamento mensal (rateio, cobranças, contabilização) |
| `src/cobrancas.prw` | Registro de pagamento |
| `src/boleto.prw` | Código de barras e linha digitável (Itaú e Bradesco) |
| `src/contabil.prw` | Lançamentos, exercício ativo, integridade, fechamento de período |
| `src/auditoria*.prw` | Validadores e registro de anomalias |
| `src/malas.prw` | Mala direta |
| `src/portal.prw`, `src/auth-primitives.prw`, `src/portal-v2.prw` | Autenticação do portal por token; primitivas e geradores para um portal REST futuro |
| `src/db.prw`, `src/schema-embed.prw`, `schema.sql` | Banco, migrações, schema |
| `tests/*_test.prw` | Suíte (`scripts/test.sh`) |
| `scripts/` | Testes, checagens (sintaxe, alcance, filial, migração), bootstrap |
| `packaging/` | Iniciador, pacotes, instalador |
| `deploy/` | Servidor Debian (LXC), Cloudflare Tunnel, backup |

## Interface e dados

Três camadas (detalhe em [PADRAO_GUI.md](PADRAO_GUI.md)): a tela só monta e
repassa; a gravação devolve `""` ou o motivo; a leitura devolve `{colunas,
linhas}` direto da consulta. Até a 1.2 os relatórios e o portal gravavam
tabelas de rascunho (`RPT_*`) compartilhadas por condomínio: na web, sessões
simultâneas sobrescreviam umas às outras, e no portal um condômino podia ver
a cobrança de outra unidade. As tabelas continuam no schema (bancos antigos),
mas nada as usa.

## Segurança

- Senha: `argon2id$v1$` + base64 do digest (64 MiB, 2 iterações, 2 lanes, 32
  bytes) com salt aleatório por usuário; o hash SHA-256 antigo entra uma
  última vez e é regravado.
- Login único sem diferenciar maiúsculas (índice `UQ_USR_LOGIN`); 5 erros
  seguidos bloqueiam por 15 minutos; usuário inexistente e senha errada dão a
  mesma resposta e o mesmo custo.
- Primeiro acesso só com `GESCON_ADMIN_SENHA` (sem senha padrão), com troca
  obrigatória.
- Perfis: SUPERADMIN (tudo) e SINDICO (condomínios vinculados em `USR_COND`,
  sem cadastro de condomínio nem criação de super). O menu filtra e cada
  operação confere de novo.
- Sessão encerrada após 30 minutos sem ação.
- Token do portal: 64 hex de `UUIDRandom`, uso único consumido num
  `UPDATE ... RETURNING`, 48 horas.
- Isolamento por condomínio: todo comando SQL em tabela de condomínio filtra
  `FILIAL` (`scripts/check-filial.py`, comando a comando).

## Boleto bancário

Pelos manuais CNAB 400 do Itaú (jan/2017) e do Bradesco (abr/2022): código de
barras de 44 posições, DAC módulo 11 (pesos 2 a 9), linha digitável com DVs
módulo 10, fator de vencimento com base 07/10/1997 e reinício em 1000 a partir
de 22/02/2025. Nosso número = `R_E_C_N_O_` da cobrança. `tests/boleto_test.prw`
confere com os exemplos numéricos dos manuais.

## Modelo de dados

18 tabelas (11 operacionais + 7 contábeis), todas com a convenção de
exclusão lógica estilo Protheus (`R_E_C_N_O_`/`D_E_L_E_T_`/`R_E_C_D_E_L_`) —
ver `schema.sql` para o DDL completo.

| Tabela | Campos de negócio | Papel |
|---|---|---|
| `CON` | `CON_CODIGO`, `CON_NOME`, `CON_CPF`, `CON_EMAIL`, `CON_TEL` | Condômino |
| `UNI` | `UNI_CODIGO`, `UNI_BLOCO`, `UNI_FRACAO`, `UNI_CONDOMINO` | Unidade — `UNI_CONDOMINO` é o `CON_CODIGO` do responsável, texto livre |
| `DES` | `DES_DESCR`, `DES_CATEG`, `DES_VALOR`, `DES_COMPET`, `DES_DTLANC` | Despesa lançada numa competência ("YYYY-MM") |
| `COB` | `COB_UNIDADE`, `COB_COMPET`, `COB_VALOR`, `COB_VENCTO`, `COB_STATUS`, `COB_DTPAG` | Cobrança — gerada só pelo Fechamento Mensal |
| `USR` | `USR_LOGIN`, `USR_SENHA`, `USR_PERFIL` | Usuário administrador — `USR_SENHA` guarda hash SHA-256 (`FWHash`), nunca texto puro; `USR_PERFIL` em `'ADMIN'` |
| `RPT_INADIM` (sem uso desde a 1.3) | `RIN_UNIDADE`, `RIN_COMPET`, `RIN_VALOR`, `RIN_VENCTO`, `RIN_ATRASO` | Snapshot do relatório de Inadimplência — recalculado a cada abertura |
| `RPT_EXTRATO` (sem uso desde a 1.3) | `REX_COMPET`, `REX_VALOR`, `REX_VENCTO`, `REX_STATUS`, `REX_DTPAG` | Snapshot do Extrato por Unidade — recalculado a cada abertura |
| `RPT_DESCAT` (sem uso desde a 1.3) | `RDC_CATEG`, `RDC_TOTAL` | Snapshot de Despesas por Categoria — recalculado a cada abertura |
| `CFG_BOLETO` | `CFG_BANCO`, `CFG_AGENCIA`, `CFG_CONTA`, `CFG_COBRT`, `CFG_CARTEIRA` | Configuração de boleto bancário (código banco, agência, conta, carta/cartão, carteira) |
| `GCT_TOKEN` | `TOKEN`, `USR_LOGIN`, `CON_CODIGO`, `UNI_CODIGO`, `CRIPTADO`, `VALIDO_ATE`, `USADO` | Token temporário de acesso do condômino ao portal — válido por 48h, marcado como usado na autenticação |
| `RPT_COND_COBRANCAS` (sem uso desde a 1.3) | `RCC_UNIDADE`, `RCC_COMPET`, `RCC_VALOR`, `RCC_VENCTO`, `RCC_STATUS`, `RCC_DTPAG` | Snapshot das cobranças do condômino no portal — gerado a partir de `COB` filtrado pela unidade do token |

**Tabelas do Sistema Contábil (Partida Dupla):**

| Tabela | Campos de negócio | Papel |
|---|---|---|
| `PLANO_CONTAS` | `PLA_CODIGO`, `PLA_NOME`, `PLA_TIPO`, `PLA_ATIVO` | Plano de contas: ativo, passivo, receita, despesa (20 contas seed) |
| `EXERCICIO` | `EXE_CODIGO`, `EXE_INICIO`, `EXE_FIM`, `EXE_ATIVO`, `EXE_FECHADO` | Período contábil (mês) — formato "YYYY-MM", um ativo por vez |
| `LANCAMENTOS` | `LAN_DATA`, `LAN_CONTA_DEB`, `LAN_CONTA_CRED`, `LAN_VALOR`, `LAN_TIPO`, `LAN_EXERCICIO` | Lançamentos contábeis: manual, automatico_despesa, automatico_rateio |
| `RATEIO_DETALHE` | `RAT_LANCAMENTO`, `RAT_UNIDADE`, `RAT_VALOR`, `RAT_PERCENTUAL` | Detalhes de rateio por unidade (FK → LANCAMENTOS) |
| `REPARTICAO` | `REP_CODIGO`, `REP_NOME`, `REP_ATIVO` | Tipos de repartição: FRACAO, METRAGEM, FIXO |
| `AUDITORIA` | `AUD_TIPO`, `AUD_DESCRICAO`, `AUD_SEVERIDADE`, `AUD_EXERCICIO` | Trilha de auditoria: desequilibrio, lan_orfao, cob_orfao (severidades: CRITICA, AVISO, INFO) |
| `RPT_BALANCETE` (sem uso desde a 1.3) | `RPT_EXERCICIO`, `RPT_RECEITAS`, `RPT_DESPESAS`, `RPT_SALDO`, `RPT_DATA_GERACAO` | Snapshot do balancete: saldo = receitas - despesas, gerado ao fechar período |

Relacionamentos: `UNI.UNI_CONDOMINO → CON.CON_CODIGO` (texto livre, sem
FK/combo — ver "Limitações conhecidas"). `COB.COB_UNIDADE →
UNI.UNI_CODIGO`. `DES` não se relaciona com unidade — despesas são do
condomínio como um todo, rateadas por fração ideal no fechamento. `GCT_TOKEN.UNI_CODIGO → UNI.UNI_CODIGO` (vincula token à unidade). `GCT_TOKEN.CON_CODIGO → CON.CON_CODIGO` (vincula token ao condômino). As tabelas `RPT_*` e `RPT_COND_COBRANCAS` não têm relacionamento formal — são só a área de
staging de cada relatório/tabulação.

A tabela `SX3` (compartilhada com outras ferramentas AdvPP) guarda
metadados de coluna (título amigável, tipo, tamanho) que o antigo `FWMBrowse`
usa para renderizar as colunas — sem essas linhas o browse cai no
fallback de mostrar toda coluna física como texto cru.

## Ponte entre Fechamento Mensal e Contabilidade formal

Apontada pelo Wilson Kraft em QA (2026-08-21): o fluxo operacional
(Despesas → `GcFecharMes` → Cobranças, `src/fechamento.prw`) lia e gravava
inteiramente nas tabelas `DES`/`COB` — nunca tocava `LANCAMENTOS`. Já o
módulo de Contabilidade formal (`GcNovoLancamento`/`GcGerarBalancetePeriodo`,
`src/contabil.prw`) só enxergava o que era lançado manualmente. Fechar um
mês inteiro de despesas e cobranças pelo fluxo normal não movia o
Balancete — eram dois trilhos paralelos que nunca se cruzavam.

Existia até uma segunda ponte já pronta e desconectada: o menu
Contabilidade → Lançamentos → "Lançar Despesa com Rateio"
(`GcLancarDespesaUI`/`GcLancarDespesaContabil`) já gravava tanto
`LANCAMENTOS` quanto `COB` para uma despesa avulsa — só não era o caminho
que o fechamento em lote usava.

**Decisão (2026-08-21):** `GcFecharMes` agora também grava `LANCAMENTOS`
(débito Despesa Comum 4000/crédito Caixa 1000 por despesa da competência;
débito Contas a Receber 5000/crédito Receita Condominial 3000 por unidade
rateada), reaproveitando o mesmo padrão contábil de `GcLancarDespesaContabil`,
*condicionado a existir um `EXERCICIO` aberto com `EXE_CODIGO` igual à
competência* — `LANCAMENTOS` tem FK obrigatória para `EXERCICIO`. O Fluxo B
(`GcLancarDespesaUI`) continua existindo para lançamento avulso, sem alteração
de propósito.

**Refinamentos (Wilson Kraft, QA 2026-08-23,
`Wilson/Proposta_Integracao_Contabil_Condominial_GesCon.doc`):**

- **Sem exercício aberto**, o fechamento segue gerando só as Cobranças (como
  sempre fez), mas agora avisa com `MsgAlert` visível na tela — antes só
  logava via `ConOut`, uma falha silenciosa pro síndico.
- **Anti-duplicidade:** `DES.DES_LANCADO_CONTABIL` é marcado (`= 1`) em cada
  linha de `DES` processada por `GcFecharMes`. `GcLancarDespesaContabil`
  ("Lançar Despesa com Rateio") não lê de `DES` — é só para ajustes pontuais
  fora do fluxo normal; a flag existe pra dar rastreabilidade de que aquela
  despesa já foi contabilizada pelo fechamento em lote, evitando que alguém
  lance a mesma despesa duas vezes por engano entre os dois caminhos.
- **Conta por categoria:** a nova tabela `CATEG_CONTA` mapeia
  `DES_CATEG` (texto livre, já usado pelo relatório "Despesas por
  Categoria") para uma conta de despesa do Plano de Contas
  (`GcContaDespesaPorCategoria`, `src/contabil.prw`). `GcFecharMes` usa o
  mapeamento por despesa; sem categoria ou sem linha cadastrada em
  `CATEG_CONTA`, cai no fallback histórico (4000). `GcLancarDespesaContabil`
  continua debitando 4000 fixo — não recebe categoria como parâmetro (não
  vem de uma linha de `DES`), fora de escopo estender essa tela agora.
- **Escrita cruzada em `COB`:** `GcLancarDespesaContabil` também grava
  diretamente em `COB` além de `LANCAMENTOS` — comportamento intencional
  (mantém as duas visões sincronizadas), sem indicação na UI. Mantido como
  está por decisão explícita; documentado aqui pra não ficar implícito.

**QA v1.2.0 (Wilson Kraft, 2026-10-10,
`Wilson/Relatorio_QA_GesCon_v1.2.0_20261010.md`) — o que mudou nesta ponte:**

- `GcFecharMes` agora só grava as Cobranças e delega a contabilidade a
  `GcContabilizarCompetencia(cCompet)` (`src/fechamento.prw`), que é
  **idempotente**: a despesa entra só com `DES_LANCADO_CONTABIL = 0`
  (lançamento + flag numa transação `BEGIN…COMMIT`), e o rateio de cada
  unidade só se ainda não existe o lançamento `Rateio <compet> - Unidade <x>`.
  Re-executar após falha parcial não duplica (achado A2).
- Sem exercício aberto, o Fechamento **pergunta antes** de gravar (A5). Se a
  competência já foi fechada e `GcCompetenciaPendenteContabil` acusa que
  nunca foi contabilizada (exercício aberto, cobranças existentes, nenhum
  lançamento `FECHAMENTO_MENSAL`), fechar de novo oferece contabilizar.
- A flag passou a ser **lida**: `GcDespesaJaLancada` (`src/contabil.prw`) faz
  `GcLancarDespesaContabil` recusar despesa idêntica já contabilizada, e o
  lançamento manual registra a despesa em `DES` já com a flag `1` (A3). A
  flag não está no SX3 — não é editável pelo usuário (A8).
- `GcAjustarResiduoRateio` (`src/db.prw`) soma o resíduo de arredondamento na
  unidade de maior fração, só quando as frações somam ~100% (A6).
- Migração de bancos antigos (`src/db.prw`): `GcAdicionarColunaSeFaltar`
  para colunas novas de tabelas existentes (**toda coluna nova de tabela
  pré-existente deve ser registrada em `GcBootstrapDB`, além do
  `schema.sql`**); `GcSemearMigracaoFilialPadrao` sanea `FILIAL` **antes** de
  restaurar as `_OLD` (a trigger de `UNI` exige `CON.FILIAL`) e também quando
  sobrou `_OLD` de uma migração interrompida (A1); `GcSanearDadosLegados`
  normaliza `DES_COMPET` e arredonda valores (A4, A7).
- Teste de upgrade: `scripts/check-migracao-filial.sh` monta banco **antigo**
  com unidade vinculada a condômino, `DES` sem a coluna nova, competência
  `MM/AAAA` e dízima, e também um banco **já travado** pelo A1. Sugestão do
  Wilson ainda não implementada: comparar `pragma_table_info` de cada tabela
  entre "schema anterior + atual" e "banco novo" para pegar coluna futura
  declarada só no `CREATE TABLE`.

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

Desde o AdvPP 4.8.6, erro de SQL volta ao programa (`TCSqlExec` = `.F.`,
mensagem em `TCSqlError()`); gravação que precisa ser tudo-ou-nada vai num
único comando (ex.: as cobranças do Fechamento num `INSERT` de várias
linhas). Leitura para tela: `src/consultas.prw`.

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

## Testes

`scripts/test.sh` roda cada `tests/*_test.prw` num banco descartável montado
de `schema.sql` e reprova saída com `FALHA`/`FAIL`/`Error` ou vazia; recusa
`advplc` diferente de `ADVPP_VERSION`. `scripts/check.sh`: sintaxe de todos os
fontes, alcance (toda função de negócio tem caminho a partir de `GesCon()`,
exceto as diferidas com motivo em `scripts/alcance.py`) e filial.
`packaging/launcher`: `go test`. A interface foi conferida no navegador
(Playwright) a cada fase.
