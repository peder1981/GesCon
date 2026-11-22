// src/cobrancas.prw — consulta de cobranças e registro de pagamento. Ver
// spec, "Decisões explícitas registradas": o browse é editável pelo mesmo
// FWMBrowse dos demais cadastros (limitação conhecida e aceita na v1).
#include "totvs.ch"

/*/{Protheus.doc} GcRegistrarPagamento
    Marca uma cobrança (identificada por R_E_C_N_O_) como paga, com a
    data informada. Só altera COB_STATUS/COB_DTPAG -- nunca COB_VALOR.
    Recusa data vazia ou futura e cobrança já paga. Devolve .T. só se uma
    linha mudou (antes devolvia o sucesso do comando, .T. mesmo sem
    alterar nada, e a tela dizia "Pagamento registrado").
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param nRecno, numeric, R_E_C_N_O_ da cobrança em COB
    @param dData, date, data do pagamento
    @return logical, .T. se a cobrança passou a constar como paga
*/
User Function GcRegistrarPagamento(nRecno, dData)
    Local cData := "" as character

    If ValType(nRecno) != "N" .Or. nRecno <= 0 .Or. ValType(dData) != "D" .Or. Empty(dData) .Or. dData > Date()
        Return .F.
    EndIf
    cData := DToS(dData)
Return Len(TCSqlQuery("UPDATE COB SET COB_STATUS = 'pago', COB_DTPAG = '" + ;
    Left(cData, 4) + "-" + SubStr(cData, 5, 2) + "-" + SubStr(cData, 7, 2) + "' " + ;
    "WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + " AND COB_STATUS <> 'pago' AND D_E_L_E_T_ = ' ' " + ;
    "AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "' RETURNING R_E_C_N_O_")) > 0

