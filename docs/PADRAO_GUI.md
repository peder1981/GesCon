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
scripts/build.sh          # gera GesConApp
./gescon                  # abre a janela (exporta ADVPP_FORCE_GUI=1)
```

`ADVPP_FORCE_GUI=1` é obrigatório. Sem ele, o executável lançado de um
terminal detecta o TTY e escolhe a UI de terminal (`TerminalUIProvider`), que
**não implementa diálogos** — os menus funcionam, os formulários quebram.
Por isso o launcher existe; não chame `./GesConApp` direto.

Modos alternativos, para desenvolvimento:

| Comando | UI |
|---|---|
| `./gescon` | Fyne (alvo de produção) |
| `advplc serve gescon.prw` | navegador — útil para inspecionar layout |
| `advplc run tests/x_test.prw` | headless, sem UI — é como os testes rodam |

---

## 5. Encoding: UTF-8, não CP-1252

Os fontes do GesCon são **UTF-8**. O AdvPP é escrito em Go e lê os fontes
como UTF-8; um `.prw` em CP-1252 compila normalmente, mas todo acento sai
como mojibake na tela — menus, mensagens e títulos de coluna.

Isto já aconteceu aqui: `Condôminos` aparecia como `Cond&#244;minos` no menu,
e `Título` como `T&#237;tulo` no cabeçalho dos browses (o SX3 vem de
`schema.sql`, que também precisa ser UTF-8).

A regra vale para `.prw` **e** para `schema.sql`. `scripts/check.sh` recusa
qualquer fonte que não seja UTF-8 válido, ou que contenha U+FFFD — sinal de
texto já destruído por uma conversão anterior, que nenhuma reconversão
recupera.

> A convenção CP-1252 do Protheus real (RPO) **não se aplica** a este
> projeto. É uma exigência do compilador da TOTVS, não do AdvPP.

---

## 6. Limitações conhecidas do layout

As coordenadas `@ linha,coluna` **não** posicionam em pixel no Fyne. O VM
agrupa os controles em linhas por proximidade de `y` (tolerância de 8px,
`buildDialogSpec`) e o Fyne empacota cada linha num `HBox`. Na prática:

- a **ordem** (linhas de cima para baixo, campos da esquerda para a direita)
  é respeitada;
- a **largura** dos campos não é; `SIZE` em `GET` é ignorado e os campos saem
  estreitos;
- `@ ... BOX` é puramente decorativo e não renderiza.

Escreva os formulários pensando em ordem, não em pixel. Um `SAY` antes de
cada `GET` na mesma linha é o que produz um rótulo à esquerda do campo.
