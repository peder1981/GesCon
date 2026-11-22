// tests/token_test.prw -- token de acesso do condômino: aleatório
// criptográfico (64 hex), único, e de uso único mesmo consumido duas vezes.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} TokenTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function TokenTest()
    Local nFalhas := 0 as numeric
    Local cTok1   := GcGerarTokenId() as character
    Local cTok2   := GcGerarTokenId() as character
    Local nI      := 0 as numeric
    Local lHex    := .T. as logical
    Private g_cUniPortal      := ""
    Private g_cConPortal      := ""
    Private g_lAutoPortal     := .F.
    Private g_cFilialAtiva    := ""
    Private g_cCondNomePortal := ""

    nFalhas += Confere("token com 64 caracteres", Len(cTok1), 64)
    For nI := 1 To Len(cTok1)
        If !(SubStr(cTok1, nI, 1) $ "0123456789abcdef")
            lHex := .F.
        EndIf
    Next nI
    nFalhas += Confere("token so hexadecimal", lHex, .T.)
    nFalhas += Confere("dois tokens diferentes", cTok1 != cTok2, .T.)

    TCSqlExec("DELETE FROM GCT_TOKEN WHERE USR_LOGIN = 'tokentest'")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, FILIAL) " + ;
        "VALUES ('" + cTok1 + "', 'tokentest', 'C1', 'U1', datetime('now'), datetime('now', '+1 day'), 0, '010101')")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, FILIAL) " + ;
        "VALUES ('" + cTok2 + "', 'tokentest', 'C1', 'U1', datetime('now', '-2 day'), datetime('now', '-1 day'), 0, '010101')")

    nFalhas += Confere("1o uso autentica", GcAuthPortalToken(cTok1), .T.)
    nFalhas += Confere("unidade da sessao", g_cUniPortal, "U1")
    nFalhas += Confere("2o uso recusado", GcAuthPortalToken(cTok1), .F.)
    nFalhas += Confere("token expirado recusado", GcAuthPortalToken(cTok2), .F.)
    nFalhas += Confere("token vazio recusado", GcAuthPortalToken(""), .F.)
    nFalhas += Confere("token com aspas recusado", GcAuthPortalToken("' OR '1'='1"), .F.)

    TCSqlExec("DELETE FROM GCT_TOKEN WHERE USR_LOGIN = 'tokentest'")
    RpcSetEnv("      ")

    If nFalhas == 0
        ConOut("token: todos os casos ok")
    Else
        ConOut("FALHA token: " + cValToChar(nFalhas) + " caso(s)")
    EndIf
Return

/*/{Protheus.doc} Confere
    Compara obtido x esperado e imprime ok/FALHA.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param cNome, character, nome do caso
    @param xObtido, variant, valor obtido
    @param xEsperado, variant, valor esperado
    @return numeric, 0 se bateu, 1 se falhou
*/
Static Function Confere(cNome, xObtido, xEsperado)
    If ValType(xObtido) == ValType(xEsperado) .And. xObtido == xEsperado
        ConOut("ok    " + cNome)
        Return 0
    EndIf
    ConOut("FALHA " + cNome + ": obtido [" + cValToChar(xObtido) + "] esperado [" + cValToChar(xEsperado) + "]")
Return 1

#include "../src/db.prw"
#include "../src/usuarios.prw"
#include "../src/portal.prw"
