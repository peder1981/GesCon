# Guia de Utilização — GesCon

Instalação, compilação e execução do GesCon.
Para o passo a passo de cada tela, veja [MANUAL_USUARIO.md](MANUAL_USUARIO.md).

---

## 1. O que é

Sistema de gestão condominial escrito em AdvPL, compilado pelo
[AdvPP](https://github.com/peder1981/AdvPP) e executado como **aplicação
desktop** em janela nativa.

Não há servidor, navegador ou banco externo: o executável é autocontido e os
dados ficam num arquivo SQLite.

---

## 2. Pré-requisitos

| Item | Para quê |
|---|---|
| `advplc` (AdvPP) | compilar os fontes |
| Go 1.24+ | `advplc build` gera um binário Go com o bytecode embutido |
| `sqlite3` | criar o banco a partir de `schema.sql` |
| Checkout do AdvPP | o stub gerado importa o módulo; aponte `ADVPP_SRC` |

---

## 3. Instalação

**No Windows, use o instalador.** O release publica
`GesCon-Setup-<versão>.exe`: cria atalho no menu Iniciar, instala em pasta
com permissão de escrita, e traz a opção de renderização por software para
máquina sem driver de vídeo (seção 7). O `.zip` continua publicado para quem
prefere descompactar e rodar.

Para desenvolver, a partir do fonte:

```bash
# 1. Banco de dados — opcional desde a 1.0.4: o executável aplica o schema
#    sozinho no arranque. Este script continua útil para preparar um banco
#    antes de rodar qualquer coisa.
scripts/bootstrap-db.sh

# 2. Executável
export ADVPP_SRC=~/Projetos/AdvPP
scripts/build.sh                    # gera ./GesConApp

# 3. Primeiro administrador
#    O login inicial é criado pela própria tela de login na primeira
#    execução, quando ainda não existe nenhum usuário.
```

O banco padrão é `~/.advpp/ADVPP.db`. Para usar outro, defina `ADVPP_DB`.

---

## 4. Execução

```bash
./gescon
```

`./GesConApp` direto também funciona: o build usa `advplc build --gui`, que
marca o programa como app desktop — a janela abre mesmo a partir de um
terminal, e no Windows o `.exe` sai no subsistema GUI, sem console atrás.
O launcher `./gescon` ficou como conveniência. O porquê está em
[docs/PADRAO_GUI.md](docs/PADRAO_GUI.md), seção 4.

No Windows, o release publica um **zip** — `GesConApp-windows-amd64.zip` —
com o `.exe`, a pasta `mesa\` e o `GesCon-modo-compativel.bat`. Extraia tudo
para a mesma pasta e execute o `.exe`. O `.bat` só é necessário em máquina
sem driver de vídeo; veja a seção 7.

---

## 5. Verificação

```bash
scripts/check.sh    # encoding, sintaxe de todos os fontes, alcance dos menus
scripts/test.sh     # 13 suítes de teste, em banco descartável
scripts/build.sh    # executável
```

`check.sh` recusa fonte que não seja UTF-8 e acusa qualquer função de negócio
que tenha ficado sem caminho de menu. `test.sh` monta um banco novo a cada
execução, então não depende do estado do seu banco de desenvolvimento.

---

## 6. Estrutura

```
gescon.prw          ponto de entrada: login e menus
src/                módulos por área (contábil, boleto, portal, auditoria…)
tests/              13 suítes, uma por área
schema.sql          tabelas, índices e dicionário SX3
scripts/            check, test, build, bootstrap do banco
docs/PADRAO_GUI.md  como escrever tela neste projeto
```

Regra de módulo: **nenhum arquivo de `src/` inclui outro**. O AdvPP não tem
include guard, então incluir em cadeia cola o mesmo arquivo várias vezes no
compilado. Quem lista os módulos é `gescon.prw` (ou o arquivo de teste), uma
vez cada.

---

## 7. Problemas comuns

**"MSDIALOG: requer o modo web"** — o executável foi compilado sem
`--gui` (ou é anterior ao AdvPP 2.0.7). Recompile com `scripts/build.sh`,
ou contorne rodando por `./gescon`, que exporta `ADVPP_FORCE_GUI=1`.

**"Fyne error: window creation error / WGL: The driver does not appear to
support OpenGL"** (Windows) — o Windows está sem driver de vídeo real:
máquina recém-instalada, ou máquina virtual sem aceleração. Nesse estado o
sistema oferece só OpenGL 1.1 pelo *Microsoft Basic Display Adapter*, e o
Fyne exige 2.0+. O programa não consegue se defender disso — o Fyne chama
`os.Exit(1)` dentro do próprio driver, antes de qualquer código nosso rodar.

Duas saídas, nesta ordem:

1. **Instale o driver de vídeo** (Windows Update → *Drivers opcionais*, ou o
   site do fabricante). É a melhor: mantém a aceleração por hardware.
2. **Renderização por software** com o Mesa3D — CPU pura, suficiente para as
   grades e formulários deste sistema, e a única saída no Hyper-V, que não
   oferece OpenGL nenhum. Pelo instalador, marque *Renderização por software*
   (ele já vem marcado quando não encontra driver registrado); se o GesCon já
   estiver instalado, rode o instalador de novo e marque a opção. Pelo zip,
   execute `GesCon-modo-compativel.bat`, que copia os DLLs de `mesa\` para
   junto do `.exe`.

O Mesa fica em `mesa\` e não na raiz justamente porque o `opengl32.dll` dele
substitui o driver em vez de encadear: na raiz, todo usuário perderia a placa
de vídeo, inclusive quem tem uma boa.

**Acentos aparecem trocados** — algum fonte voltou a CP-1252.
`scripts/check.sh` acusa qual. Os fontes deste projeto são UTF-8; a
convenção CP-1252 do Protheus real não se aplica ao AdvPP.

**"Nenhum exercício ativo"** — abra um em *Contabilidade > Abrir Exercício*.
Lançamentos, rateio e fechamento dependem de um exercício aberto.

**Uma tela abre sem colunas** — falta metadado SX3 da tabela em
`schema.sql`. O `FWMBrowse` monta as colunas a partir do dicionário.

**`advplc build` falha** — confira `ADVPP_SRC` e se o Go está instalado.

---

## 8. Fora do escopo por enquanto

O **portal do condômino** — acesso externo por token, extratos e agenda pela
web — está adiado. O código de autenticação já existe em
`src/auth-primitives.prw`, compilado e testado, mas sem tela: é a base de
quando a fase for retomada. Dentro do app, o condômino já acessa suas
cobranças pela opção *Sou condômino* na tela inicial.
