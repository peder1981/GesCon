# Padrão de tela do GesCon (PO-UI no AdvPP)

Como escrever tela neste projeto. A interface é uma aplicação `PoApp`
servida pelo `advplc serve gescon.prw`; cada sessão do navegador é um
programa próprio.

## Camadas

| Arquivo | Faz | Não faz |
|---|---|---|
| `src/ui.prw` | Monta páginas e repassa ações | Regra de negócio, SQL de gravação |
| `src/cadastros.prw`, `src/operacoes.prw`, módulos de negócio | Gravam com validação e devolvem `""` ou o motivo da recusa | Diálogo (`MsgInfo`, `FWGetText`) |
| `src/consultas.prw` | Devolvem `{colunas, linhas}` para uma `PoTable`, direto da consulta e filtrados pela filial | Gravar em tabela de rascunho |
| `src/seguranca.prw` | Autenticação, senha, perfil (`GcPode`) | — |

Assim a regra é testável com `advplc run` (sem navegador) e a tela só mostra.

## Página nova

1. Escreva a consulta em `src/consultas.prw` com `GcConsulta(aCols, cSql)`.
   Coluna: `{campo, rótulo[, formato]}`, formato `"R$"`, `"number"`, `"data"`
   (DD/MM/AAAA) ou `"comp"` (MM/AAAA). Filtre sempre por
   `FILIAL = FWxFilial(...)` — `scripts/check-filial.py` confere comando a
   comando.
2. Escreva a gravação devolvendo `""` ou o motivo.
3. Monte a página em `src/ui.prw` e registre em `GcUIPaginas()` com a ação de
   permissão (`GcPode(perfil, ação)`): o menu só mostra o que o perfil pode.
4. Recarga de dados: `GcUIRegistra(oPg, {|| ...})` — roda ao montar e a cada
   visita pelo menu (dado fresco).
5. Toda ação chama `GcUIToque()` (base da expiração da sessão) e mostra o
   resultado com `oApp:Notify` (ou `GcUIMsg(oApp, cMotivo, cOk)`).

Cadastro simples: `GcUICadastro(oApp, titulo, bConsulta, aCampos, bGravar,
bExcluir, ajuda)` — tabela à esquerda, formulário à direita, linha clicada
preenche o formulário. Campo: `{rótulo, "C" | "N" | "K" (chave oculta) |
{opções}, coluna da tabela, padrão}`.

## Armadilhas (verificadas no navegador)

- **Campo numérico:** o `PoNumber` é `type=number` com passo inteiro — não
  aceita vírgula (0,025; 1.234,56). Use `PoInput` e converta com `GcNum`.
- **Opções de `PoSelect` não mudam depois de montado** (AdvPP 4.8.6:
  `Set("options", ...)` não converte `JsonObject`). Lista que muda (plano de
  contas) vira campo de código com validação.
- **Opção com valor vazio não aparece selecionada** no `PoSelect`: dê um
  valor ("todas") e traduza na consulta.
- **Tipo de coluna desconhecido esconde a coluna** da `PoTable`: só `"number"`
  vai para a definição; os outros formatos são aplicados no valor.
- **`PoInfo`** muda com `SetValue` (valor) e `Set("label", ...)` (rótulo) —
  use para resultados que se atualizam, em vez de criar outro a cada clique.
- **Diálogos bloqueantes** (`MsgYesNo`, `MsgAlert`) funcionam dentro das ações
  da `PoApp` (aparecem como modal), mas a camada de dados não deve usá-los.
- Bloco de código dentro de laço captura a variável, não o valor: monte o
  item numa função própria (ver `GcUIMenuItem`).
- `IIF` é proibido no projeto (SonarQube CA4000): use `If/Else`.
