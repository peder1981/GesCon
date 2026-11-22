// tests/portal_test.prw -- portal do condômino: token (inválido, válido,
// já usado), sessão da unidade, cobranças só da própria unidade e do
// próprio condomínio (consulta direta; a tabela de rascunho compartilhada
// deixava ver a de outra unidade), boleto só da própria unidade.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} PortalTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-07-31
*/
User Function PortalTest()
    Local nFalhas := 0 as numeric
    Local aQ      := {} as array
    Local aRec    := {} as array
    Local cTok    := "" as character
    Private g_cUniPortal := "", g_cConPortal := "", g_cFilialAtiva := "", g_lAutoPortal := .F., g_cCondNomePortal := ""

    TCSqlExec("DELETE FROM GCT_TOKEN")
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('E2E99', 'E2E88')")
    TCSqlExec("INSERT OR IGNORE INTO COND (COND_FILIAL, COND_NOME) VALUES ('090099', 'Condomínio E2E')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('E2E99', '2026-07', 500, '2099-07-10', 'pendente', '090099')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('E2E99', '2026-08', 550, '2099-08-10', 'pendente', '090099')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG, FILIAL) VALUES ('E2E99', '2026-06', 120, '2026-06-15', 'pago', '2026-06-14', '090099')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('E2E88', '2026-07', 999, '2099-07-10', 'pendente', '090099')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('E2E99', '2026-07', 777, '2099-07-10', 'pendente', '010101')")

    nFalhas += Confere("token inexistente", GcAuthPortalToken(Replicate("0", 64)), .F.)
    cTok := GcGerarTokenId()
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, FILIAL) VALUES ('" + cTok + ;
        "', 'admin', 'CE2E', 'E2E99', datetime('now'), datetime('now', '+1 day'), 0, '090099')")
    nFalhas += Confere("token valido", GcAuthPortalToken(cTok), .T.)
    nFalhas += Confere("sessao: unidade", g_cUniPortal, "E2E99")
    nFalhas += Confere("sessao: condominio", g_cFilialAtiva, "090099")
    nFalhas += Confere("sessao: nome do condominio", g_cCondNomePortal, "Condomínio E2E")
    nFalhas += Confere("token marcado como usado", TCSqlQuery("SELECT USADO FROM GCT_TOKEN WHERE TOKEN = '" + cTok + "'")[1]:USADO, "1")
    nFalhas += Confere("token ja usado recusado", GcAuthPortalToken(cTok), .F.)

    aQ := GcQPortalCobrancas(g_cUniPortal)
    nFalhas += Confere("3 cobrancas da unidade, so deste condominio", Len(aQ[2]), 3)
    nFalhas += Confere("outra unidade nao aparece", aScan(aQ[2], {|l| l[3] == "999,00"}), 0)
    nFalhas += Confere("pago preservado", aScan(aQ[2], {|l| l[5] == "pago" .And. l[6] == "14/06/2026"}) > 0, .T.)

    TCSqlExec("INSERT INTO CFG_BOLETO (CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA, FILIAL) VALUES ('341', '0057', '12345', '', '110', '090099')")
    aRec := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = 'E2E88' AND FILIAL = '090099'")
    nFalhas += Confere("boleto de outra unidade recusado", GcBoletoDados(Val(aRec[1]:R_E_C_N_O_), g_cUniPortal)[1], .F.)
    aRec := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = 'E2E99' AND COB_STATUS = 'pendente' AND FILIAL = '090099' ORDER BY R_E_C_N_O_")
    nFalhas += Confere("boleto da propria unidade", Len(GcBoletoDados(Val(aRec[1]:R_E_C_N_O_), g_cUniPortal)[3]), 54)
    aRec := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = 'E2E99' AND COB_STATUS = 'pago' AND FILIAL = '090099'")
    nFalhas += Confere("boleto de cobranca paga recusado", GcBoletoDados(Val(aRec[1]:R_E_C_N_O_), g_cUniPortal)[1], .F.)

    TCSqlExec("DELETE FROM CFG_BOLETO WHERE FILIAL = '090099'")
    TCSqlExec("DELETE FROM GCT_TOKEN")
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('E2E99', 'E2E88')")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL = '090099'")
    RpcSetEnv("      ")
    If nFalhas == 0
        ConOut("portal: todos os casos ok")
    Else
        ConOut("FALHA portal: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/boleto.prw"
#include "../src/usuarios.prw"
#include "../src/portal.prw"
#include "../src/consultas.prw"
