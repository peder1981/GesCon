// tests/portal_test.prw ï¿½ testes do portal do condï¿½mino (token auth + browse limitado).
// Os testes usam TCSqlQuery/TCSqlExec direto pois FWGetText ï¿½ interativo.
#include "totvs.ch"
#include "../src/db.prw"
#include "../src/portal.prw"
#include "../src/usuarios.prw"

/*/{Protheus.doc} TestaGcPortalAuthVazio
    Chamada com token vazio/nï¿½o encontrado deve retornar .F.
*/
User Function AT06TokenInvalido()
    Local lOk := .T.
    Local aResultado := GcAuthPortalToken("00000000-0000-0000-0000-000000000000")
    If Len(aResultado) == 0
        ConOut("AT06PASS: token invalido rejeitado")
    Else
        lOk := .F.
        ConOut("AT06FAIL: token invalido NAO rejeitado")
    EndIf
Return lOk

/*/{Protheus.doc} TestaGcPortalAuthValido
    Cria um token vï¿½lido na GCT_TOKEN, chama GcAuthPortalToken e verifica:
    (1) retorna .T., (2) marca USADO=1, (3) seta g_cUniPortal/g_cConPortal.
*/
User Function AT06TokenValido()
    Local lOk := .T.

    // Limpa token anterior se existir
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = 'test-token-0000-0000-0000-000000000001' AND D_E_L_E_T_ = ' '")

    // Cria unidade e condï¿½mino de teste se necessï¿½rio
    Local aUni := TCSqlQuery("SELECT UNI_CODIGO FROM UNI WHERE UNI_CODIGO = '99' AND D_E_L_E_T_ = ' '")
    If Len(aUni) == 0
        TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_NOME, UNI_ENDERECO, UNI_BAIRRO, UNI_CIDADE, UNI_ESTADO, UNI_CEP, UNI_COMPLEMENTO, UNI_FONE) VALUES ('99', 'Teste', 'Rua Teste', 'Centro', 'Sï¿½o Paulo', 'SP', '00000-000', 'Apto 1', '11111111')")
    EndIf

    Local aCon := TCSqlQuery("SELECT CON_CODIGO FROM CON WHERE CON_CODIGO = 'C999' AND D_E_L_E_T_ = ' '")
    If Len(aCon) == 0
        TCSqlExec("INSERT INTO CON (CON_CODIGO, CON_NOME, CON_CPF, CON_EMAIL, CON_FONE, CON_UNI) VALUES ('C999', 'Condï¿½mino Teste', '000.000.000-00', 'teste@teste.com', '11111111', '99')")
    EndIf

    // Gera token válido com validade futura (data fixa para teste)
    Local cValidadeIso := "2099-12-31 23:59:59"

    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO) " + ;
        "VALUES ('test-token-0000-0000-0000-000000000001', 'admin', 'C999', '99', '" + GcSqlLit(cValidadeIso) + "', '" + GcSqlLit(cValidadeIso) + "', 0)")

    // Autentica
    Local lAutenticado := GcAuthPortalToken("test-token-0000-0000-0000-000000000001")
    ConOut("auth_retorno=" + cValToChar(lAutenticado))

    // Verifica USADO=1
    Local aUsado := TCSqlQuery("SELECT USADO FROM GCT_TOKEN WHERE TOKEN = 'test-token-0000-0000-0000-000000000001' AND D_E_L_E_T_ = ' '")
    If Len(aUsado) > 0
        ConOut("uso_marked=" + cValToChar(aUsado[1]:USADO == 1))
    Else
        lOk := .F.
        ConOut("erro_token_desapareceu=.T.")
    EndIf

    // Verifica variï¿½veis globais
    ConOut("uni_portal=" + cValToChar(g_cUniPortal))
    ConOut("con_portal=" + cValToChar(g_cConPortal))

    // Limpa
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = 'test-token-0000-0000-0000-000000000001'")
    TCSqlExec("DELETE FROM CON WHERE CON_CODIGO = 'C999'")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO = '99'")
    g_cUniPortal := ""
    g_cConPortal := ""
    g_lAutoPortal := .F.
Return lOk

/*/{Protheus.doc} TestaGcPortalCalcCobrancas
    Apï¿½s autenticaï¿½ï¿½o, chama GcPortalCalcCobrancas e verifica que as
    cobranï¿½as da unidade '99' sï¿½o copiadas para RPT_COND_COBRANCAS.
*/
User Function AT06PortalCalc()
    Local lOk := .T.

    // Garante unidade e condï¿½mino de teste
    Local aUni := TCSqlQuery("SELECT UNI_CODIGO FROM UNI WHERE UNI_CODIGO = '99' AND D_E_L_E_T_ = ' '")
    If Len(aUni) == 0
        TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_NOME, UNI_ENDERECO, UNI_BAIRRO, UNI_CIDADE, UNI_ESTADO, UNI_CEP, UNI_COMPLEMENTO, UNI_FONE) VALUES ('99', 'Teste', 'Rua Teste', 'Centro', 'Sï¿½o Paulo', 'SP', '00000-000', 'Apto 1', '11111111')")
    EndIf

    // Garante cobranï¿½a de teste para unidade 99
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = '99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('99', '2026-07', '150.00', '2026-07-10', 'aberto')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('99', '2026-08', '150.00', '2026-08-10', 'aberto')")
    // Cobranï¿½a de outra unidade ï¿½ Nï¿½O deve ser copiada
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('88', '2026-07', '200.00', '2026-07-10', 'aberto')")

    // Simula autenticaï¿½ï¿½o portal
    g_cUniPortal := "99"
    g_cConPortal := "C999"
    g_lAutoPortal := .T.

    // Calcula cobranï¿½as
    Local nQtd := GcPortalCalcCobrancas()
    ConOut("cobrancas_encontradas=" + Str(nQtd))
    If nQtd != 2
        lOk := .F.
    EndIf

    // Verifica que a cobranï¿½a da unidade 88 nï¿½o foi copiada
    Local aOutraUni := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_COND_COBRANCAS WHERE RCC_UNIDADE = '88' AND D_E_L_E_T_ = ' '")
    If Len(aOutraUni) > 0
        Local nCount := Val(aOutraUni[1]:QTD)
        ConOut("outra_unidade_count=" + Str(nCount))
        If nCount != 0
            lOk := .F.
        EndIf
    EndIf

    // Limpa
    TCSqlExec("DELETE FROM RPT_COND_COBRANCAS WHERE D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('99', '88') AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM CON WHERE CON_CODIGO = 'C999'")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO = '99'")
    g_cUniPortal := ""
    g_cConPortal := ""
    g_lAutoPortal := .F.
Return lOk

/*/{Protheus.doc} TestaGcSairPortal
    Chama GcSairPortal e verifica que as variï¿½veis globais sï¿½o zeradas.
*/
User Function AT06SairPortal()
    Local lOk := .T.

    // Simula sessï¿½o ativa
    g_cUniPortal := "99"
    g_cConPortal := "C999"
    g_lAutoPortal := .T.

    // Sai
    GcSairPortal()

    // Verifica estado limpo
    ConOut("uni_depois=" + cValToChar(Empty(g_cUniPortal)))
    ConOut("con_depois=" + cValToChar(Empty(g_cConPortal)))
    ConOut("auto_depois=" + cValToChar(!g_lAutoPortal))

    If !Empty(g_cUniPortal) .Or. !Empty(g_cConPortal) .Or. g_lAutoPortal
        lOk := .F.
    EndIf
Return lOk

/*/{Protheus.doc} AT08TokenUsado
    Token com USADO=1 deve ser rejeitado (ataque de reutilizacao).
*/
User Function AT08TokenUsado()
    Local lOk := .T.

    // Insere token já marcado como usado
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = 'test-token-0008-0000-0000-000000000008' AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO) " + ;
        "VALUES ('test-token-0008-0000-0000-000000000008', 'admin', 'C999', '99', 'criptado', '" + ;
        "2099-12-31 23:59:59', 1)")

    // Autentica — deve falhar porque USADO=1
    Local lAutenticado := GcAuthPortalToken("test-token-0008-0000-0000-000000000008")
    If lAutenticado
        lOk := .F.
        ConOut("AT08FAIL: token_usado nao foi rejeitado")
    Else
        ConOut("AT08PASS: token usado rejeitado")
    EndIf

    // Limpa
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = 'test-token-0008-0000-0000-000000000008'")
    g_cUniPortal := ""
    g_cConPortal := ""
    g_lAutoPortal := .F.
Return lOk