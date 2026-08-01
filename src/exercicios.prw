// src/exercicios.prw — cadastro de exercícios contábeis. O browse mostra o
// que existe; abrir um exercício novo passa por formulário, porque envolve
// regra (só um exercício ativo por vez) que o CRUD genérico do FWMBrowse
// não teria como aplicar.
#include "totvs.ch"

/*/{Protheus.doc} GcExercicios
    Abre a consulta de exercícios (browse sobre EXERCICIO).
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcExercicios()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("EXERCICIO")
    oBrowse:SetDescription("Exercícios Contábeis")
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcAbrirExercicio
    Abre um exercício novo e o torna o ativo. Formulário MsDialog seguindo
    docs/PADRAO_GUI.md: o writeback dos GET acontece mesmo no cancelamento,
    então nada é gravado antes de testar lOk.

    Regras aplicadas aqui, e não no browse:
      - código no formato YYYY-MM, obrigatório e único
      - datas de início e fim obrigatórias, no formato YYYYMMDD (o mesmo
        que GcFecharPeriodo grava via DtoS ao criar o período seguinte)
      - só um exercício ativo por vez: os demais são desativados
    @type Function
    @author GesCon
    @since 2026-07-31
    @return lOk, logical, .T. se o exercício foi criado
*/
User Function GcAbrirExercicio()
    Local oDlg
    Local cCodigo := ""
    Local cInicio := ""
    Local cFim    := ""
    Local lOk     := .F.
    Local aJa     := {}

    DEFINE MSDIALOG oDlg TITLE "Abrir Exercício" FROM 0,0 TO 220,420 PIXEL

    @ 10, 10 SAY "Código (AAAA-MM):"   PIXEL
    @ 10, 90 GET cCodigo SIZE 60,10               PIXEL
    @ 30, 10 SAY "Início (AAAAMMDD):"  PIXEL
    @ 30, 90 GET cInicio SIZE 70,10               PIXEL
    @ 50, 10 SAY "Fim (AAAAMMDD):"     PIXEL
    @ 50, 90 GET cFim SIZE 70,10                  PIXEL
    @ 85, 10 BUTTON "Confirmar" ACTION (lOk := .T.) SIZE 40,12 PIXEL
    @ 85, 90 BUTTON "Cancelar"                      SIZE 40,12 PIXEL

    ACTIVATE MSDIALOG oDlg CENTERED

    If !lOk
        Return .F.
    EndIf

    cCodigo := AllTrim(cCodigo)
    cInicio := AllTrim(cInicio)
    cFim    := AllTrim(cFim)

    If Empty(cCodigo) .Or. Empty(cInicio) .Or. Empty(cFim)
        MsgAlert("Código, início e fim são obrigatórios.", "Abrir Exercício")
        Return .F.
    EndIf

    If Len(cCodigo) != 7 .Or. SubStr(cCodigo, 5, 1) != "-"
        MsgAlert("Código deve estar no formato AAAA-MM (ex: 2026-01).", "Abrir Exercício")
        Return .F.
    EndIf

    If Len(cInicio) != 8 .Or. Len(cFim) != 8
        MsgAlert("Datas devem estar no formato AAAAMMDD (ex: 20260101).", "Abrir Exercício")
        Return .F.
    EndIf

    aJa := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_CODIGO = '" + ;
        GcSqlLit(cCodigo) + "' AND D_E_L_E_T_ = ' '")
    If Len(aJa) > 0
        MsgAlert("Exercício " + cCodigo + " já existe.", "Abrir Exercício")
        Return .F.
    EndIf

    // Um exercício ativo por vez
    TCSqlExec("UPDATE EXERCICIO SET EXE_ATIVO = 0 WHERE D_E_L_E_T_ = ' '")

    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + GcSqlLit(cCodigo) + "', '" + GcSqlLit(cInicio) + "', '" + ;
        GcSqlLit(cFim) + "', 1, 0, ' ')")

    MsgInfo("Exercício " + cCodigo + " aberto e definido como ativo.", "Abrir Exercício")
Return .T.
