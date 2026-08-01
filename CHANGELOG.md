# Changelog

Mudanças notáveis do GesCon.

## [1.0.9] — 2026-08-01

### Removido

- **O executável lançador.** Ele existia para transportar uma string — o
  caminho do banco compartilhado — e em troca trouxe processo intermediário,
  herança de handles e falhas próprias. A última delas: mostrar caixa de erro
  `0x80070057` para um programa que tinha aberto normalmente, com a janela na
  tela e o menu esperando clique.

  O caminho do banco passa a ir em `advpp-db.txt`, um arquivo de texto ao lado
  do executável que o próprio programa lê (AdvPP 2.0.15). Ler um arquivo não
  falha pela metade.

### Alterado

- **Instalação plana e Mesa3D ativo por padrão.** Executável, DLLs do Mesa e
  scripts todos em `{app}`; o ícone aponta direto para o executável, sem
  intermediário. Sem OpenGL de verdade — o caso de qualquer VM, e desta com
  QXL em particular — o Fyne não cria janela nenhuma, então o Mesa é o padrão
  e não a exceção. `Desativar-renderizacao-por-software.bat` renomeia os DLLs
  para `.off` e o `Ativar` desfaz, reversível nos dois sentidos.

## [1.0.8] — 2026-08-01

### Corrigido

- **O lançador passa a resolver o OpenGL sozinho, em execução.** Nem instalar
  nem deixar de instalar o Mesa3D acerta sempre: nesta VM QEMU/QXL o
  `advpp-ide` morre no carregador quando o Mesa está ao lado dele, e o GesCon
  só abre quando está — a mesma máquina precisa de respostas opostas para dois
  binários. E o instalador não tem como decidir: adivinhar pelo registro se há
  driver de vídeo já errou, porque o QXL registra driver e não oferece OpenGL.

  Agora o lançador executa o programa, e se ele falhar reclamando de OpenGL
  (`WGL`, `window creation error`, `APIUnavailable`), copia o Mesa de `mesa\`
  para junto do executável e tenta de novo. Máquina com OpenGL nunca carrega
  o Mesa; máquina sem ele se conserta na primeira execução, sem checkbox e sem
  ninguém decidir nada. O instalador deixa `{app}\app` gravável para o usuário
  comum exatamente por isso.

  Erro não reconhecido continua virando caixa de diálogo com a saída do
  programa, gravada também em `ProgramData\GesCon\gescon-erro.txt`.

## [1.0.7] — 2026-08-01

### Corrigido

- **O Mesa3D instalado junto do executável era o motivo de nada abrir.**
  `opengl32.dll` é import **estático** do binário: o Windows o carrega na
  criação do processo, antes de qualquer código nosso. Numa VM QEMU/QXL o
  Mesa não inicializa e o processo morre no carregador — sem janela, sem
  saída, sem log.

  A pista estava nos dados desde o começo e eu li na ordem errada: o único
  executável que abriu nessa máquina foi `app\GesConApp-windows-amd64.exe`
  chamado direto, e é justamente o que **não** tinha o Mesa ao lado. O
  sintoma mudou de erro visível para silêncio total exatamente na 1.0.3, que
  foi onde o Mesa entrou.

  Agora ele é instalado em `{app}\mesa\`, fora do caminho de busca de DLL, e
  só entra em jogo por `Ativar-renderizacao-por-software.bat` — com o script
  que desfaz ao lado, porque a falha desse caminho é justamente aquela em que
  nada abre para explicar o que houve. A heurística que adivinhava pelo
  registro se havia driver OpenGL foi removida: ela errou nessa VM, e o preço
  do erro era "não abre e não diz nada".

## [1.0.6] — 2026-08-01

### Corrigido

- **O lançador engolia a saída do programa.** `exec.Command` sem `Stdout`
  definido descarta tudo. O binário existia para acabar com o "não abre e não
  diz nada" e produzia exatamente isso: o programa escrevia o motivo da falha
  e ninguém via — inclusive no `diagnostico.bat`, que por isso registrou saída
  vazia e `ERRORLEVEL=0` (o código do lançador, não o do programa).

  Agora captura `stdout` e `stderr`, espera o filho terminar e, em falha,
  mostra o código de saída e o texto capturado numa caixa de diálogo,
  gravando também em `C:\ProgramData\GesCon\gescon-erro.txt` — relato que não
  dá para colar numa conversa não ajuda ninguém. Saída vazia com morte
  imediata ganha mensagem própria apontando falha de carregamento de DLL: o
  `opengl32.dll` é import **estático** do executável (confirmado na tabela de
  imports do binário publicado), então o Windows o carrega antes de qualquer
  código nosso rodar.

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

### Alterado

- **O banco instalado voltou a ser compartilhado entre as contas do Windows.**
  O AdvPP 2.0.11 passou a guardar o banco de um app distribuído em
  `%AppData%\advpp\<app>\` — estável, e errado aqui: o banco é do condomínio,
  não da conta de quem abriu.

  Quem resolve é um **lançador compilado**, `GesCon.exe`
  (`installer/launcher/`, Go puro sem CGO, subsistema GUI). Ele aponta
  `ADVPP_DB` para `C:\ProgramData\GesCon\GesCon.db`, cria a pasta e sobe o
  programa. Uma variável de ambiente da máquina não serviria: `ADVPP_DB` vale
  para toda ferramenta AdvPP e sequestraria também `advplc`, `adveditor` e
  `advpp-ide`, que devem seguir usando o banco do diretório de projeto.
  `ADVPP_DB` já definida é respeitada — quem apontou para outro banco de
  propósito não é sobrescrito.

  O programa passa a ser instalado em `{app}\app\`, então **não existe ícone
  clicável que pule o lançador** — o furo que a primeira tentativa, com um
  `.cmd` ao lado do `.exe`, deixava aberto. Os DLLs do Mesa acompanham o
  programa nessa subpasta, porque o Windows procura DLL na pasta do
  executável.

  Falha do lançador vira caixa de diálogo, não silêncio: ele nasceu para
  consertar um caso de "não abre e não diz nada".

- `scripts/check-installer.py` confere que o caminho compilado no lançador e o
  `[Files]` do instalador concordam, e que nenhum atalho aponta direto para o
  programa. São dois arquivos que ninguém edita junto, e a divergência só
  apareceria numa máquina Windows.

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
