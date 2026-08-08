// src/cobrancas.prw — consulta de cobranças e registro de pagamento. Ver
// spec, "Decisões explícitas registradas": o browse é editável pelo mesmo
// FWMBrowse dos demais cadastros (limitação conhecida e aceita na v1).
#include "totvs.ch"

/*/{Protheus.doc} GcCobrancas
    Abre a consulta de cobranças (browse sobre COB — CRUD editável pelo
    mesmo FWMBrowse dos demais cadastros; ver limitação conhecida acima).
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcCobrancas()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("COB")
    oBrowse:SetDescription("Cobranças")
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcRegistrarPagamento
    Marca uma cobrança (identificada por R_E_C_N_O_) como paga, com a
    data informada. Só altera COB_STATUS/COB_DTPAG — nunca COB_VALOR.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param nRecno, numeric, R_E_C_N_O_ da cobrança em COB
    @param dData, date, data do pagamento
    @return lOk, logical, .T. se o UPDATE afetou alguma linha
*/
User Function GcRegistrarPagamento(nRecno, dData)
    Local cData := DToS(dData)
    Local cDataFmt := Left(cData, 4) + "-" + SubStr(cData, 5, 2) + "-" + SubStr(cData, 7, 2)
Return TCSqlExec("UPDATE COB SET COB_STATUS = 'pago', COB_DTPAG = '" + cDataFmt + "' WHERE R_E_C_N_O_ = " + Str(nRecno) + " AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")

/*/{Protheus.doc} GcSelecionarCobranca
    Lista cobranças num menu e devolve o R_E_C_N_O_ da escolhida.
    Existe porque FWMBrowse não devolve a linha selecionada ao chamador:
    para qualquer ação sobre "a cobrança que o usuário escolheu" (gerar
    boleto, registrar pagamento) é preciso um seletor próprio.
    @type Function
    @author GesCon
    @since 2026-07-31
    @param cStatus, character, filtra por COB_STATUS (vazio = todas)
    @param cTitulo, character, título do menu
    @return nRecno, numeric, R_E_C_N_O_ da cobrança escolhida, ou 0
*/
User Function GcSelecionarCobranca(cStatus, cTitulo)
    Local cSql    := ""
    Local aCob    := {}
    Local aItens  := {}
    Local nI      := 0
    Local nEscolha := 0

    If cTitulo == Nil
        cTitulo := "Selecione a cobrança"
    EndIf

    cSql := "SELECT R_E_C_N_O_, COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS " + ;
        "FROM COB WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "' "
    If !Empty(cStatus)
        cSql += "AND COB_STATUS = '" + GcSqlLit(cStatus) + "' "
    EndIf
    cSql += "ORDER BY COB_COMPET, COB_UNIDADE"

    aCob := TCSqlQuery(cSql)

    If Len(aCob) == 0
        MsgAlert("Nenhuma cobrança encontrada.", cTitulo)
        Return 0
    EndIf

    For nI := 1 To Len(aCob)
        AAdd(aItens, "Un " + AllTrim(aCob[nI]["COB_UNIDADE"]) + ;
            "  " + AllTrim(aCob[nI]["COB_COMPET"]) + ;
            "  R$ " + AllTrim(aCob[nI]["COB_VALOR"]) + ;
            "  venc " + AllTrim(aCob[nI]["COB_VENCTO"]) + ;
            "  (" + AllTrim(aCob[nI]["COB_STATUS"]) + ")")
    Next nI
    AAdd(aItens, "Voltar")

    nEscolha := FWMenuSelect(aItens, cTitulo)

    If nEscolha <= 0 .Or. nEscolha > Len(aCob)
        Return 0
    EndIf
Return Val(aCob[nEscolha]["R_E_C_N_O_"])
