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
Return TCSqlExec("UPDATE COB SET COB_STATUS = 'pago', COB_DTPAG = '" + cDataFmt + "' WHERE R_E_C_N_O_ = " + Str(nRecno) + " AND D_E_L_E_T_ = ' '")
