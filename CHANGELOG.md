# Changelog

Mudanças notáveis do GesCon.

## [1.0.0] — 2026-08-01

Primeiro release formal. O sistema passa a ser **100% AdvPL com GUI
completa**: todo módulo implementado tem tela alcançável a partir do menu, e
o executável desktop é gerado para Linux, Windows e macOS.

### Portal web removido

O portal em Node/Express (`ui/`, `src/auditoria-rest.prw`, 9 endpoints REST)
foi construído antes de o próprio sistema AdvPL estar completo e passou a
competir por atenção com ele. Saiu do repositório — continua no histórico do
git, recuperável quando a fase voltar à pauta.

### Telas novas

Todo módulo que existia compilado mas sem caminho de menu ganhou tela:

- **Lançamentos** — lançamento manual (substitui um stub que retornava `.F.`
  com um TODO), despesa com rateio, editar histórico, excluir e consulta
- **Cobranças** — passa a ser submenu, com registro de pagamento
- **Boletos** — configuração bancária e emissão por cobrança
- **Avisos** — consultar, criar e arquivar
- **Auditoria** — auditar período, rodar validador individual (os 6),
  anomalias, alertas com marcação de visto, painel do período
- **Cadastros contábeis** — plano de contas, tipos de repartição,
  exercícios e abertura de exercício

### Correções de produção

Encontradas ao ligar as telas e ao consertar a suíte de testes — nenhuma
foi procurada:

- `End Try` em vez de `EndTry` fazia o compilador engolir o resto do
  arquivo: `GcGerarPortalAgenda`, `GcCriarAviso` e `GcArquivarAviso` nunca
  existiram em build nenhum
- `Date() + 2` perde o tipo data no AdvPP, e `GcGerarToken` gravava
  `VALIDO_ATE = "-- 10:23:45"` — todo token nascia inválido
- `schema.sql` em CP-1252 fazia toda grade do sistema exibir `T?tulo` no
  cabeçalho das colunas
- módulo de boleto não funcionava: `Replace()` inexistente no AdvPP, coluna
  `COB_NUMDOC` inexistente, vírgula faltando numa chamada, e `CToD` sobre
  data em formato `AAAAMMDD`
- `GcGerarToken` fazia `INNER JOIN` por `CON_UNI`, coluna que não existe
- 7 chamadas a `Rollback()`, que não existe no AdvPP, no caminho de erro
- duas `GcSqlLit` com contratos incompatíveis; qual vencia dependia da
  ordem de `#include`

### Infraestrutura

- **Encoding**: `schema.sql` passou a UTF-8 — não passa pelo `advplc`, e em
  CP-1252 os títulos do SX3 entravam corrompidos no banco, deixando o
  cabeçalho ilegível em toda grade do sistema. Fontes `.prw` foram
  uniformizados em UTF-8 por consistência (o `advplc` aceita os dois). 88
  caracteres já destruídos foram reconstruídos
- **Testes**: 13 suítes confiáveis, em banco descartável. Antes a suíte
  passava por não rodar — `portal-v2_test.prw` nunca havia executado uma
  linha e hoje roda 271
- **CI**: compila de verdade (antes era `grep`), roda a suíte e verifica
  alcance dos menus
- **`scripts/alcance.py`**: falha se alguma função de negócio ficar sem
  caminho de menu — o defeito que motivou este release
- **Release**: build nativo por plataforma, já que cross-compilar Fyne de
  Linux para Windows esbarra em conflito de headers do mingw

### Documentação

`GUIA_UTILIZACAO.md`, `MANUAL_USUARIO.md` e `docs/PADRAO_GUI.md` reescritos
para o sistema que existe hoje.
