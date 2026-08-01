# Changelog

Mudanças notáveis do GesCon.

## [1.0.5] — 2026-08-01

### Corrigido

- **O executável não abria quando lançado de `Program Files`.** Tela vazia,
  sem mensagem, tanto como administrador quanto como usuário comum. O
  diretório de trabalho de um duplo clique é a própria pasta de instalação,
  onde ninguém escreve: o SQLite não criava o banco, a fábrica devolvia
  `nil`, o primeiro `TCSqlExec` do bootstrap derrubava o programa, e o stub
  fechava a janela antes de ela pintar.

  Confirmado pelo usuário sem querer: o mesmo `.exe`, lançado pelo
  `diagnostico.bat` a partir da Área de Trabalho, subiu normalmente — a única
  diferença era o diretório de trabalho gravável.

  Corrigido no compilador (AdvPP 2.0.11): o banco de um app distribuído passa
  a morar sempre na pasta de dados do usuário, e erro na partida mantém a
  janela aberta com a mensagem em vez de sumir.

### Adicionado

- `scripts/windows/diagnostico.bat` — coleta `ERRORLEVEL`, saída redirecionada
  (única forma de ver o stderr de um app GUI), execução com a janela Fyne
  desligada e com o Mesa forçado, e os erros de aplicativo do log do Windows.

### Atenção

- O banco agora fica em `%AppData%\advpp\GesCon\advpp.db`, que é **por
  usuário do Windows**. Numa máquina onde síndico e gestor usam contas
  diferentes, cada um veria o seu. Para banco compartilhado, defina
  `ADVPP_DB` apontando para um caminho comum.

## [1.0.4] — 2026-08-01

### Corrigido

- **O executável distribuído abria contra um banco vazio.** Quem criava as
  tabelas era `scripts/bootstrap-db.sh` — shell mais `sqlite3`, nenhum dos
  dois presente num Windows comum. O `ResolveDatabasePath` do AdvPP cria
  `advpp.db` no diretório de trabalho e nada mais: reproduzido no Linux com o
  binário da 1.0.3, `.tables` voltava vazio. O defeito do OpenGL escondia
  este; o release do Windows nunca foi utilizável de ponta a ponta.

  O `schema.sql` passa a viajar dentro do executável (`src/schema-embed.prw`,
  gerado por `scripts/gen-schema-embed.sh`) e é aplicado no arranque, antes de
  qualquer tela. Como o schema é idempotente por contrato — e `check.sh`
  reprova o build se deixar de ser — ele roda sempre, o que também faz
  aparecerem sozinhas as tabelas novas de um release novo em banco antigo.
  `check.sh` ganhou a trava que reprova o gerado fora de sincronia.

### Adicionado

- **Instalador do Windows** (`GesCon-Setup-<versão>.exe`, Inno Setup).
  Resolve o que o zip não resolvia: pasta de dados gravável e compartilhada
  em `C:\ProgramData\GesCon` — o banco é do condomínio, não de cada conta do
  Windows —, atalho no menu Iniciar, desinstalação, e o Mesa3D como opção
  marcada na instalação, pré-selecionada quando não há driver OpenGL
  registrado. O `.zip` continua publicado.

## [1.0.3] — 2026-08-01

### Corrigido

- **O `.exe` não abria em Windows sem driver de vídeo.** Em um Windows 10
  recém-instalado o programa morria com *"Fyne error: window creation error
  — WGL: The driver does not appear to support OpenGL"*. Sem driver real, o
  Windows usa o *Microsoft Basic Display Adapter*, que oferece OpenGL 1.1; o
  Fyne exige 2.0+. Não dá para o programa se defender: o Fyne chama
  `os.Exit(1)` dentro do próprio driver glfw, antes de qualquer código nosso.

  O release do Windows passa a ser um **zip** com o `.exe`, a pasta `mesa\`
  (Mesa3D) e `GesCon-modo-compativel.bat`, que copia o Mesa para junto do
  executável e abre o programa em renderização por software. O Mesa fica
  fora da raiz de propósito: o `opengl32.dll` dele substitui o driver em vez
  de encadear, então na raiz tiraria a aceleração por hardware de todo mundo.

## [1.0.2] — 2026-08-01

### Corrigido

- **Cabeçalhos de coluna colidiam nas grades.** Em Despesas lia-se
  `CompetênciaData Lançamento`; em Unidades, `Fração Ideal` encostava em
  `Cód. Condômino`. A largura da coluna vinha só do `X3_TAMANHO`, que
  descreve o dado e não o título. Corrigido no compilador (AdvPP 2.0.8): a
  largura passa a ser o maior entre os dois.

## [1.0.1] — 2026-08-01

Release corretivo. Duas falhas do 1.0.0 que só apareciam em uso real.

### O executável Windows não mostrava formulário

O `.exe` do 1.0.0 abria, exibia os menus e quebrava em toda tela de cadastro
com "MSDIALOG: requer o modo web". A causa estava no subsistema do binário:
o `advplc build` linkava um executável de console, e no Windows o
duplo-clique num app de console aloca um console — então o programa via
`stdin` como terminal, escolhia a interface de terminal (que não implementa
diálogos) e nenhum formulário funcionava. Não havia contorno: a válvula de
escape era a variável `ADVPP_FORCE_GUI`, e quem clica num `.exe` não tem
shell para exportá-la.

Corrigido no compilador (AdvPP 2.0.7) com `advplc build --gui`, que marca o
programa como app desktop: a janela abre sempre, e no Windows o binário sai
no subsistema GUI, sem console atrás. O launcher `./gescon` virou
conveniência — `./GesConApp` direto também funciona, em qualquer plataforma.

### Títulos de coluna corrompidos em todas as grades

As grades mostravam `Fra??o Ideal` e `C?d. Cond?mino`. O `schema.sql` já
estava correto em UTF-8; o problema era o banco. Os títulos do `SX3` vinham
de um bootstrap antigo, de quando o arquivo estava em CP-1252, e nunca eram
substituídos: o `DELETE` que precede o `INSERT` listava 11 dos 24
`X3_ARQUIVO`, então as outras 13 tabelas mantinham o texto velho e ainda
acumulavam uma cópia nova a cada execução — o banco de desenvolvimento tinha
4 cópias de cada coluna de `AVISOS`.

Trocado por `DELETE FROM SX3`: é metadado, o arquivo o reconstrói por
inteiro. Reaplicar o schema também falhava em dois `ALTER TABLE ADD COLUMN`
(o SQLite não aceita `IF NOT EXISTS` neles) e em quatro `CREATE INDEX` — as
colunas foram para o `CREATE TABLE` e os índices ganharam a cláusula. O
`bootstrap-db.sh` passou a usar `sqlite3 -bail`, que aborta no primeiro erro
em vez de deixar o schema meio aplicado.

O `check.sh` ganhou um guard: monta um banco descartável, aplica o schema
duas vezes e reprova campo `SX3` duplicado ou título com byte não-UTF-8.

**Ao atualizar, rode `scripts/bootstrap-db.sh`** — o banco existente precisa
ser recarregado para os títulos saírem corretos.

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
