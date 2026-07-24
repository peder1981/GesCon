#include "totvs.ch"

User Function GcCobrancas()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("COB")
    oBrowse:SetDescription("Cobranças")
    oBrowse:Activate()
Return

// GcRegistrarPagamento marca uma cobrança (identificada por R_E_C_N_O_)
// como paga, com a data informada.
User Function GcRegistrarPagamento(nRecno, dData)
    Local cData := DToS(dData)
    Local cDataFmt := Left(cData, 4) + "-" + SubStr(cData, 5, 2) + "-" + SubStr(cData, 7, 2)
Return TCSqlExec("UPDATE COB SET COB_STATUS = 'pago', COB_DTPAG = '" + cDataFmt + "' WHERE R_E_C_N_O_ = " + Str(nRecno) + " AND D_E_L_E_T_ = ' '")
