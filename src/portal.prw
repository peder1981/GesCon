// src/portal.prw — autenticação do condômino via token + portal de leitura.
// O condômino cola o token recebido do admin, acessa apenas as cobranças
// da sua unidade em modo read-only.
#include "totvs.ch"

/*/{Protheus.doc} GcPortalCondmino
    Gateway do portal do condômino. Pede o token, valida, autentica e
    abre o browse limitado de cobranças da unidade vinculada.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return lOk, logical, .T. se autenticado com sucesso
*/
User Function GcPortalCondmino()
    Local cToken := FWGetText("Cole o token recebido do administrador:", "")
    If Empty(cToken)
        Return .F.
    EndIf

    Local lAutenticado := GcAuthPortalToken(cToken)
    If !lAutenticado
        MsgStop("Token inválido, expirado ou já utilizado.", "Portal Condômino")
        Return .F.
    EndIf

    GcPortalBrowse()
Return .T.

/*/{Protheus.doc} GcAuthPortalToken
    Autentica um token na tabela GCT_TOKEN.
    Verifica: TOKEN existente, D_E_L_E_T_=' ', VALIDO_ATE > agora, USADO=0.
    Se válido: marca USADO=1, busca uni_codigo pela tabela, retorna .T.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cToken, character, token UUID 36 chars
    @return lOk, logical
*/
User Function GcAuthPortalToken(cToken)
    Local aToken := TCSqlQuery("SELECT TOKEN, UNI_CODIGO, CON_CODIGO, VALIDO_ATE, USADO " + ;
        "FROM GCT_TOKEN " + ;
        "WHERE TOKEN = '" + GcSqlLit(cToken) + "' " + ;
        "AND D_E_L_E_T_ = ' ' " + ;
        "AND USADO = 0 " + ;
        "AND VALIDO_ATE > datetime('now')")

    If Len(aToken) == 0
        Return .F.
    EndIf

    // Marca como usado
    TCSqlExec("UPDATE GCT_TOKEN SET USADO = 1 WHERE TOKEN = '" + GcSqlLit(cToken) + "' AND D_E_L_E_T_ = ' '")

    // Salva unidade e condômino no escopo da sessão
    g_cUniPortal := aToken[1]:UNI_CODIGO
    g_cConPortal := aToken[1]:CON_CODIGO
    g_lAutoPortal := .T.

    MsgInfo("Autenticado como condômino " + g_cConPortal + ". Bem-vindo!", "Portal Condômino")
Return .T.

/*/{Protheus.doc} GcPortalBrowse
    Abre browse limitado: apenas cobranças da unidade do condômino autenticado.
    Recalcula RPT_COND_COBRANCAS antes do browse.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcPortalBrowse()
    // Recalcula o snapshot da unidade atual
    Local nQtd := GcPortalCalcCobrancas()
    Local cMsg := "Cobranças encontradas: " + Str(nQtd)

    MsgInfo(cMsg + Chr(10) + "Selecione 'Sair' no menu para encerrar.", "Portal Condômino")

    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("RPT_COND_COBRANCAS")
    oBrowse:SetDescription("Minhas Cobranças — " + g_cConPortal + " (Portal Condômino)")
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcPortalCalcCobrancas
    Recalcula RPT_COND_COBRANCAS do zero: filtra COB por unidade do portal.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return nQtd, numeric, quantidade de linhas geradas
*/
User Function GcPortalCalcCobrancas()
    If Empty(g_cUniPortal)
        Return 0
    EndIf

    TCSqlExec("DELETE FROM RPT_COND_COBRANCAS WHERE D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO RPT_COND_COBRANCAS (RCC_UNIDADE, RCC_COMPET, RCC_VALOR, RCC_VENCTO, RCC_STATUS, RCC_DTPAG) " + ;
        "SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG " + ;
        "FROM COB WHERE COB_UNIDADE = '" + GcSqlLit(g_cUniPortal) + "' AND D_E_L_E_T_ = ' ' " + ;
        "ORDER BY COB_VENCTO")

    Local aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_COND_COBRANCAS WHERE D_E_L_E_T_ = ' '")
Return Val(aQtd[1]:QTD)

/*/{Protheus.doc} GcSairPortal
    Limpa estado do portal e retorna ao menu principal.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcSairPortal()
    g_cUniPortal := ""
    g_cConPortal := ""
    g_lAutoPortal := .F.
    MsgInfo("Sessão do portal encerrada.", "Portal Condômino")
Return
