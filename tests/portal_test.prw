// tests/portal_test.prw � testes do portal do cond�mino (token auth + browse limitado).
// Os testes usam TCSqlQuery/TCSqlExec direto pois FWGetText � interativo.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito.
// `advplc run` escolhe sozinho o ponto de entrada: a primeira User
// Function cuja linha seja >= a primeira linha de codigo do arquivo raiz
// (pkg/compiler/codegen.go). Como #include cola o texto incluido no lugar,
// includes no topo empurram as funcoes dos modulos para antes do runner
// deste arquivo -- e a suite inteira roda em silencio, executando algo
// como GcSqlLit no lugar dos testes. Com os includes no fim, o runner
// abaixo e sempre a primeira funcao do compilado. scripts/test.sh
// confere isso a cada execucao.

/*/{Protheus.doc} RunPortalTests
    Ponto de entrada da suite do portal. Precisa ser a primeira User
    Function do arquivo -- ver a nota sobre includes no topo.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function RunPortalTests()
Return PortalTest()

/*/{Protheus.doc} TestaGcPortalAuthVazio
    Chamada com token vazio/n�o encontrado deve retornar .F.
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
    Cria um token v�lido na GCT_TOKEN, chama GcAuthPortalToken e verifica:
    (1) retorna .T., (2) marca USADO=1, (3) seta g_cUniPortal/g_cConPortal.
*/
User Function AT06TokenValido()
    Local lOk := .T.

    // Limpa token anterior se existir
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = 'test-token-0000-0000-0000-000000000001' AND D_E_L_E_T_ = ' '")

    // Cria unidade e cond�mino de teste se necess�rio
    Local aUni := TCSqlQuery("SELECT UNI_CODIGO FROM UNI WHERE UNI_CODIGO = '99' AND D_E_L_E_T_ = ' '")
    If Len(aUni) == 0
        TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_NOME, UNI_ENDERECO, UNI_BAIRRO, UNI_CIDADE, UNI_ESTADO, UNI_CEP, UNI_COMPLEMENTO, UNI_FONE) VALUES ('99', 'Teste', 'Rua Teste', 'Centro', 'S�o Paulo', 'SP', '00000-000', 'Apto 1', '11111111')")
    EndIf

    Local aCon := TCSqlQuery("SELECT CON_CODIGO FROM CON WHERE CON_CODIGO = 'C999' AND D_E_L_E_T_ = ' '")
    If Len(aCon) == 0
        TCSqlExec("INSERT INTO CON (CON_CODIGO, CON_NOME, CON_CPF, CON_EMAIL, CON_TEL) VALUES ('C999', 'Cond�mino Teste', '000.000.000-00', 'teste@teste.com', '11111111')")
    EndIf

    // Gera token v�lido com validade futura (data fixa para teste)
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

    // Verifica vari�veis globais
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
    Ap�s autentica��o, chama GcPortalCalcCobrancas e verifica que as
    cobran�as da unidade '99' s�o copiadas para RPT_COND_COBRANCAS.
*/
User Function AT06PortalCalc()
    Local lOk := .T.

    // Garante unidade e cond�mino de teste
    Local aUni := TCSqlQuery("SELECT UNI_CODIGO FROM UNI WHERE UNI_CODIGO = '99' AND D_E_L_E_T_ = ' '")
    If Len(aUni) == 0
        TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_NOME, UNI_ENDERECO, UNI_BAIRRO, UNI_CIDADE, UNI_ESTADO, UNI_CEP, UNI_COMPLEMENTO, UNI_FONE) VALUES ('99', 'Teste', 'Rua Teste', 'Centro', 'S�o Paulo', 'SP', '00000-000', 'Apto 1', '11111111')")
    EndIf

    // Garante cobran�a de teste para unidade 99
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = '99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('99', '2026-07', '150.00', '2026-07-10', 'aberto')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('99', '2026-08', '150.00', '2026-08-10', 'aberto')")
    // Cobran�a de outra unidade � N�O deve ser copiada
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('88', '2026-07', '200.00', '2026-07-10', 'aberto')")

    // Simula autentica��o portal
    g_cUniPortal := "99"
    g_cConPortal := "C999"
    g_lAutoPortal := .T.

    // Calcula cobran�as
    Local nQtd := GcPortalCalcCobrancas()
    ConOut("cobrancas_encontradas=" + Str(nQtd))
    If nQtd != 2
        lOk := .F.
    EndIf

    // Verifica que a cobran�a da unidade 88 n�o foi copiada
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
    Chama GcSairPortal e verifica que as vari�veis globais s�o zeradas.
*/
User Function AT06SairPortal()
    Local lOk := .T.

    // Simula sess�o ativa
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

    // Insere token j� marcado como usado
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = 'test-token-0008-0000-0000-000000000008' AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO) " + ;
        "VALUES ('test-token-0008-0000-0000-000000000008', 'admin', 'C999', '99', 'criptado', '" + ;
        "2099-12-31 23:59:59', 1)")

    // Autentica � deve falhar porque USADO=1
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

/*/{Protheus.doc} PortalTest
    Fixture end-to-end do fluxo completo de token + portal:
    1) Reset state (limpa variaveis globais do portal)
    2) Cria usuario admin e condômino
    3) Cria unidade e dados de cobranca
    4) Gera token via GcGerarTokenId e grava em GCT_TOKEN
    5) Autentica como condômino via GcAuthPortalToken
    6) Verifica RPT_COND_COBRANCAS com as cobranças corretas
    7) Teardown (limpeza completa)
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return lTodosOk, logical, .T. se todos os passos passaram
*/
User Function PortalTest()
    Local lTodosOk := .T.
    Local cTokenTest := "e2e-" + GcGerarTokenId()
    Local dValidade  := Date() + 2
    Local cValidade  := GcDateToIso(dValidade) + " 23:59:59"

    // ========================================
    // Step 0: Reset state (teardown prévio)
    // ========================================
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN LIKE 'e2e-%' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM RPT_COND_COBRANCAS WHERE RCC_UNIDADE = 'E2E99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM COB      WHERE COB_UNIDADE = 'E2E99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM CON      WHERE CON_CODIGO  = 'CE2E99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM UNI      WHERE UNI_CODIGO  = 'E2E99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM USR      WHERE USR_LOGIN   = 'e2eadmin' AND D_E_L_E_T_ = ' '")
    g_cUniPortal   := ""
    g_cConPortal   := ""
    g_lAutoPortal  := .F.
    ConOut("--- E2E: reset state ok ---")

    // ========================================
    // Step 1: Criar admin de teste
    // ========================================
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('e2eadmin', '" + FWHash("e2esenha") + "', 'ADMIN')")
    Local aAdmin := TCSqlQuery("SELECT USR_LOGIN FROM USR WHERE USR_LOGIN = 'e2eadmin' AND D_E_L_E_T_ = ' '")
    If Len(aAdmin) != 1
        lTodosOk := .F.
        ConOut("FAIL: Step 1 - admin nao criado")
    Else
        ConOut("PASS: Step 1 - admin criado")
    EndIf

    // ========================================
    // Step 2: Criar unidade de teste
    // ========================================
    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_BLOCO, UNI_FRACAO) VALUES ('E2E99', 'A', 0.50)")
    Local aUni := TCSqlQuery("SELECT UNI_CODIGO FROM UNI WHERE UNI_CODIGO = 'E2E99' AND D_E_L_E_T_ = ' '")
    If Len(aUni) != 1
        lTodosOk := .F.
        ConOut("FAIL: Step 2 - unidade nao criada")
    Else
        ConOut("PASS: Step 2 - unidade criada")
    EndIf

    // ========================================
    // Step 3: Criar condômino vinculado à unidade
    // ========================================
    TCSqlExec("INSERT INTO CON (CON_CODIGO, CON_NOME, CON_CPF, CON_EMAIL) VALUES ('CE2E99', 'Condômino E2E Teste', '000.000.000-00', 'e2e@teste.com')")
    Local aCon := TCSqlQuery("SELECT CON_CODIGO FROM CON WHERE CON_CODIGO = 'CE2E99' AND D_E_L_E_T_ = ' '")
    If Len(aCon) != 1
        lTodosOk := .F.
        ConOut("FAIL: Step 3 - condômino nao criado")
    Else
        ConOut("PASS: Step 3 - condômino criado")
    EndIf

    // ========================================
    // Step 4: Criar cobranças de teste para unidade E2E99
    // ========================================
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('E2E99', '2026-07', '500.00', '2026-07-10', 'aberto')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('E2E99', '2026-08', '550.00', '2026-08-10', 'aberto')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('E2E99', '2026-07', '120.00', '2026-07-15', 'pago')")
    ConOut("PASS: Step 4 - cobranças criadas")

    // ========================================
    // Step 5: Simular geração de token
    // ========================================
    Local aTokenCheck := TCSqlQuery("SELECT COUNT(*) AS QTD FROM GCT_TOKEN WHERE TOKEN LIKE 'e2e-%' AND D_E_L_E_T_ = ' ' AND USADO = 0")
    If Len(aTokenCheck) > 0 .And. Val(aTokenCheck[1]:QTD) == 0
        TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO) " + ;
            "VALUES ('" + GcSqlLit(cTokenTest) + "', 'e2eadmin', 'CE2E99', 'E2E99', '" + ;
            GcSqlLit(DtoC(Date()) + " " + Left(Time(), 8)) + "', '" + GcSqlLit(cValidade) + "', 0)")
    EndIf

    aTokenCheck := TCSqlQuery("SELECT COUNT(*) AS QTD FROM GCT_TOKEN WHERE TOKEN = '" + GcSqlLit(Left(cTokenTest, 40)) + "' AND USADO = 0 AND D_E_L_E_T_ = ' '")
    If Len(aTokenCheck) > 0 .And. Val(aTokenCheck[1]:QTD) == 1
        ConOut("PASS: Step 5 - token gravado na GCT_TOKEN")
    Else
        lTodosOk := .F.
        ConOut("FAIL: Step 5 - token nao gravado corretamente")
    EndIf

    // ========================================
    // Step 6: Autenticar como condômino via token
    // ========================================
    Local lAutenticado := GcAuthPortalToken(Left(cTokenTest, 40))
    If !lAutenticado
        lTodosOk := .F.
        ConOut("FAIL: Step 6 - autenticacao falhou")
    Else
        ConOut("PASS: Step 6 - autenticacao ok")
    EndIf

    // Verifica que variáveis globais foram preenchidas
    If !Empty(g_cUniPortal) .And. !Empty(g_cConPortal) .And. g_lAutoPortal == .T.
        ConOut("PASS: Step 6b - variaveis globais portal preenchidas (uni=" + g_cUniPortal + ", con=" + g_cConPortal + ")")
    Else
        lTodosOk := .F.
        ConOut("FAIL: Step 6b - variaveis globais NAO preenchidas")
    EndIf

    // Verifica que token foi marcado como USADO=1
    Local aUsado := TCSqlQuery("SELECT USADO FROM GCT_TOKEN WHERE TOKEN = '" + GcSqlLit(Left(cTokenTest, 40)) + "' AND D_E_L_E_T_ = ' '")
    If Len(aUsado) > 0 .And. aUsado[1]:USADO == 1
        ConOut("PASS: Step 6c - token marcado como usado")
    Else
        lTodosOk := .F.
        ConOut("FAIL: Step 6c - token NAO marcado como usado")
    EndIf

    // ========================================
    // Step 7: Calcular cobranças do portal
    // ========================================
    Local nQtd := GcPortalCalcCobrancas()
    If nQtd == 3
        ConOut("PASS: Step 7 - portal calc cobrancas = " + Str(nQtd) + " (esperado 3)")
    Else
        lTodosOk := .F.
        ConOut("FAIL: Step 7 - portal calc cobrancas = " + Str(nQtd) + " (esperado 3)")
    EndIf

    // Verifica conteúdo: todas as 3 cobranças estão em RPT_COND_COBRANCAS
    Local aContagem := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_COND_COBRANCAS WHERE RCC_UNIDADE = 'E2E99' AND D_E_L_E_T_ = ' '")
    If Len(aContagem) > 0 .And. Val(aContagem[1]:QTD) == 3
        ConOut("PASS: Step 7b - RPT_COND_COBRANCAS tem 3 linhas para unidade E2E99")
    Else
        lTodosOk := .F.
        Local nCountB := 0
        If Len(aContagem) > 0
            nCountB := Val(aContagem[1]:QTD)
        EndIf
        ConOut("FAIL: Step 7b - RPT_COND_COBRANCAS tem " + Str(nCountB) + " linhas")
    EndIf

    // Verifica que não há cobranças de outra unidade
    Local aOutra := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_COND_COBRANCAS WHERE RCC_UNIDADE <> 'E2E99' AND D_E_L_E_T_ = ' '")
    If Len(aOutra) > 0 .And. Val(aOutra[1]:QTD) == 0
        ConOut("PASS: Step 7c - sem cobranças de outras unidades")
    Else
        Local nCountC := 0
        If Len(aOutra) > 0
            nCountC := Val(aOutra[1]:QTD)
        EndIf
        lTodosOk := .F.
        ConOut("FAIL: Step 7c - found " + Str(nCountC) + " cobranças de outras unidades")
    EndIf

    // Verifica status preservado
    Local aStatusPago := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_COND_COBRANCAS WHERE RCC_STATUS = 'pago' AND RCC_UNIDADE = 'E2E99' AND D_E_L_E_T_ = ' '")
    If Len(aStatusPago) > 0 .And. Val(aStatusPago[1]:QTD) == 1
        ConOut("PASS: Step 7d - status pago preservado")
    Else
        lTodosOk := .F.
        ConOut("FAIL: Step 7d - status pago não preservado")
    EndIf

    // ========================================
    // Step 8: Teardown — limpeza completa
    // ========================================
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN LIKE 'e2e-%' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM RPT_COND_COBRANCAS WHERE D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM COB      WHERE COB_UNIDADE = 'E2E99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM CON      WHERE CON_CODIGO  = 'CE2E99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM UNI      WHERE UNI_CODIGO  = 'E2E99' AND D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM USR      WHERE USR_LOGIN   = 'e2eadmin' AND D_E_L_E_T_ = ' '")
    g_cUniPortal   := ""
    g_cConPortal   := ""
    g_lAutoPortal  := .F.
    ConOut("--- E2E: teardown completo ---")

    // ========================================
    // Resultado final
    // ========================================
    If lTodosOk
        ConOut("PORTAL_TEST_OK")
    Else
        ConOut("PORTAL_TEST_FAIL")
    EndIf
Return lTodosOk

#include "../src/db.prw"
#include "../src/portal.prw"
#include "../src/usuarios.prw"
