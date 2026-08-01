# Padrão de GUI do GesCon

O GesCon roda como aplicação **desktop Fyne**: `advplc build` gera um
executável standalone e o launcher `./gescon` o abre em janela.

Este documento congela o padrão de tela. Tudo aqui foi **verificado
empiricamente** no alvo real (executável standalone + `ADVPP_FORCE_GUI=1`,
Fyne sobre X11), não deduzido da documentação do AdvPP.

---

## 1. Primitivas disponíveis

| Primitiva | Uso no GesCon |
|---|---|
| `FWMenuSelect(aItens, cTitulo)` | menus e submenus; devolve índice 1-based, `0` se fechado |
| `FWGetText(cPergunta, cPadrao)` | pergunta de campo único |
| `MsgInfo` / `MsgAlert` / `MsgStop` / `MsgYesNo` | feedback e confirmação |
| `FWMBrowse()` | grade CRUD sobre um alias, colunas vindas do SX3 |
| `DEFINE MSDIALOG` + `@ x,y SAY/GET/BUTTON` | **formulário multi-campo** |

Não existem em AdvPP: `TWindow`, `TSay`, `TGet`, `TButton`, `TComboBox`,
`TCheckBox`, `TListBox`, `MsGetDados`, `MsgBox`. Não tente usá-los.

---

## 2. O padrão de formulário

```advpl
User Function GcMinhaTela()
    Local oDlg
    Local cCampo := "valor inicial"
    Local nValor := 0
    Local lOk    := .F.

    DEFINE MSDIALOG oDlg TITLE "Título da Tela" FROM 0,0 TO 200,400 PIXEL

    @ 10, 10 SAY "Campo:" PIXEL
    @ 10, 70 GET cCampo   PIXEL
    @ 30, 10 SAY "Valor:" PIXEL
    @ 30, 70 GET nValor   PIXEL
    @ 80, 10 BUTTON "Confirmar" ACTION (lOk := .T.) SIZE 40,12 PIXEL
    @ 80, 70 BUTTON "Cancelar"                      SIZE 40,12 PIXEL

    ACTIVATE MSDIALOG oDlg CENTERED

    If !lOk
        Return
    EndIf

    // só aqui grava
Return
```

### O que está provado

| Comportamento | Resultado |
|---|---|
| `GET` escreve de volta na `Local` | **sim** — por nome de variável (`pkg/vm/dialog.go:185-198`) |
| Tipo numérico é preservado | **sim** — `nValor` volta `555`, não `"555"` |
| `ACTION (lOk := .T.)` escreve na `Local` do escopo | **sim** — codeblock captura por referência |
| Botão sem `ACTION` (Cancelar) devolve o controle | **sim** — `lOk` permanece `.F.` |
| Fechar a janela sem clicar botão | devolve o controle, nenhum `ACTION` roda |

### ⚠️ Regra não-negociável

**O writeback dos `GET` acontece mesmo quando o usuário cancela.** Após
`ACTIVATE`, as variáveis já contêm o que foi digitado, independentemente do
botão. Portanto:

- **Sempre** teste `lOk` antes de gravar qualquer coisa.
- **Nunca** presuma que as variáveis continuam com o valor anterior após um
  cancelamento. Se o valor original importar, guarde uma cópia antes do
  `DEFINE`.

---

## 3. ⚠️ Armadilha: MsDialog sozinho não liga a GUI

O executável standalone decide sozinho se precisa de UI, varrendo o bytecode
(`pkg/compiler/stub_template.go`, mapa `uiNatives`/`uiClasses`). Essa varredura
procura `MSDIALOG` como `OP_NEW_INSTANCE`, mas o parser desugara
`DEFINE MSDIALOG` para **chamada nativa** (`pkg/parser/expressions.go:2859`) —
e `MSDIALOG` não está na lista de nativas de UI.

Consequência: um programa cuja **única** primitiva de UI seja `MsDialog` é
classificado como headless, roda sem `UIProvider` e morre com:

```
Error: MSDIALOG: requer o modo web (advplc serve)
```

O GesCon não sofre disso porque `gescon.prw` chama `FWMenuSelect` antes de
qualquer formulário. **Toda tela nova deve continuar sendo alcançada por um
`FWMenuSelect`** — o que já é verdade por construção, já que toda tela nasce
de um item de menu.

Não escreva um `.prw` de teste contendo só um MsDialog: ele vai falhar e a
causa não é o seu código.

---

## 4. Como executar

```bash
scripts/build.sh          # gera GesConApp (advplc build --gui)
./gescon                  # abre a janela
./GesConApp               # idem — o binário já sabe que é app desktop
```

`scripts/build.sh` compila com `advplc build --gui`. A flag marca o programa
como app desktop e resolve duas coisas de uma vez:

- **A janela abre sempre**, mesmo lançado de um terminal. Sem ela o
  executável detecta o TTY e escolhe a UI de terminal
  (`TerminalUIProvider`), que **não implementa diálogos** — os menus
  funcionam e os formulários quebram com "MSDIALOG: requer o modo web".
- **No Windows o `.exe` sai no subsistema GUI** (`-ldflags -H=windowsgui`).
  Sem isso ele é um executável de console: o duplo-clique aloca um console,
  o `stdin` passa a parecer um TTY e cai exatamente na mesma armadilha — só
  que lá não há como exportar variável de ambiente antes de clicar.

O launcher `./gescon` continua existindo por conveniência e ainda exporta
`ADVPP_FORCE_GUI=1`, que é o mesmo efeito por variável de ambiente — cinto de
segurança para binário antigo, compilado antes da flag existir.

Modos alternativos, para desenvolvimento:

| Comando | UI |
|---|---|
| `./gescon` | Fyne (alvo de produção) |
| `advplc serve gescon.prw` | navegador — útil para inspecionar layout |
| `advplc run tests/x_test.prw` | headless, sem UI — é como os testes rodam |

---

## 5. Encoding

O projeto inteiro é **UTF-8**, mas por motivos diferentes em cada tipo de
arquivo — e só um deles é obrigatório.

### `.prw` — convenção, não exigência

O `advplc` converte fontes CP-1252 para UTF-8 **antes de lexar**
(`convertToUTF8` em `cmd/advplc/main.go`), então fonte nos dois encodings
compila e renderiza acento corretamente. Verificado comparando a saída byte
a byte: idêntica.

Padronizamos em UTF-8 por consistência, não porque CP-1252 quebre.

> A regra CP-1252 do Protheus real (RPO) é exigência do compilador da TOTVS.
> O AdvPP não a compartilha.

### `schema.sql` — **obrigatoriamente** UTF-8

Este arquivo não passa pelo `advplc`: o `sqlite3` grava os bytes literais no
banco, e o Fyne renderiza esperando UTF-8. Com `schema.sql` em CP-1252, os
títulos do SX3 entram no banco como bytes inválidos e **toda grade do
sistema** mostra o cabeçalho corrompido — foi o que acontecia com `Título`.

### U+FFFD é sempre defeito

O caractere de substituição (`\uFFFD`) indica texto já destruído por uma
conversão anterior; nenhuma reconversão recupera. Havia 88 deles neste
projeto, reconstruídos palavra a palavra.

`scripts/check.sh` recusa qualquer arquivo que não seja UTF-8 válido ou que
contenha U+FFFD.

---

## 6. Limitações conhecidas do layout

As coordenadas `@ linha,coluna` **não** posicionam em pixel no Fyne. O VM
agrupa os controles em linhas por proximidade de `y` (tolerância de 8px,
`buildDialogSpec`) e o Fyne empacota cada linha num `HBox`. Na prática:

- a **ordem** (linhas de cima para baixo, campos da esquerda para a direita)
  é respeitada;
- a **largura** do campo vem do `SIZE`, não da coluna;
- `@ ... BOX` é puramente decorativo e não renderiza.

Escreva os formulários pensando em ordem, não em pixel. Um `SAY` antes de
cada `GET` na mesma linha é o que produz um rótulo à esquerda do campo.

### Declare `SIZE` em todo `GET`

```advpl
@ 10, 10 SAY "Data (AAAAMMDD):" PIXEL
@ 10,120 GET cData SIZE 70,10   PIXEL
@ 90, 10 SAY "Histórico:"       PIXEL
@ 90,120 GET cDescr SIZE 220,10 PIXEL
```

A largura sai do `SIZE`; sem ele, o AdvPP cai no tamanho da `PICTURE` e
depois no valor atual, com um piso. Um campo de data e um de histórico
livre não devem ter o mesmo tamanho — dimensione pelo conteúdo esperado.

Referência usada neste projeto:

| Conteúdo | `SIZE` |
|---|---|
| dia do mês (`10`) | 40 |
| código de banco/carteira (`237`) | 50 |
| competência (`2026-03`), conta (`1100`) | 60 |
| data `AAAAMMDD`, agência | 70 |
| valor (`1500,50`) | 80 |
| conta corrente, convênio | 90 |
| descrição / histórico livre | 220 |

> Honrar o `SIZE` no Fyne foi implementado no AdvPP em
> `pkg/vm/dialog.go` (`AT_GET` captura a cláusula) e `pkg/ui/msdialog.go`
> (`entryWidth`). Antes disso a cláusula era descartada e todo campo saía
> com dois ou três caracteres de largura.
