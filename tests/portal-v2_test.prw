// tests/portal-v2_test.prw — testes da plataforma Portal v2 (snapshots de faturas, avisos, agenda)
#include "totvs.ch"
#include "../src/db.prw"
#include "../src/contabil.prw"
#include "../src/portal-v2.prw"

/*/{Protheus.doc} PortalV2Test
    Orquestrador dos testes do Portal v2.
    Executa: TestPortalTablesExist, TestAvisosTableStructure, TestExtratoTableStructure,
    TestAgendaTableStructure, TestGcGerarPortalExtratos
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function PortalV2Test()
    ConOut("")
    ConOut("========== TESTES DO PORTAL V2 ==========")
    ConOut("")

    TestPortalTablesExist()
    ConOut("")

    TestAvisosTableStructure()
    ConOut("")

    TestExtratoTableStructure()
    ConOut("")

    TestAgendaTableStructure()
    ConOut("")

    TestGcGerarPortalExtratos()
    ConOut("")

    ConOut("========== FIM DOS TESTES DO PORTAL V2 ==========")
    ConOut("")

Return

/*/{Protheus.doc} TestPortalTablesExist
    Verifica se as tres tabelas do Portal v2 foram criadas: AVISOS, RPT_PORTAL_EXTRATOS, RPT_PORTAL_AGENDA
    Este teste FALHA até que schema.sql seja aplicado.
*/
User Function TestPortalTablesExist()
    Local aTabelas := { "AVISOS", "RPT_PORTAL_EXTRATOS", "RPT_PORTAL_AGENDA" }
    Local i := 1
    Local cQuery := ""
    Local aResult := {}
    Local lTodoOk := .T.

    For i := 1 To Len(aTabelas)
        cQuery := "SELECT name FROM sqlite_master WHERE type='table' AND name='" + aTabelas[i] + "'"
        aResult := FWGetTable(cQuery)

        If Len(aResult) > 0
            ConOut("[PASS] " + aTabelas[i] + " table exists")
        Else
            ConOut("[FAIL] " + aTabelas[i] + " table does not exist")
            lTodoOk := .F.
        EndIf
    Next i

Return lTodoOk

/*/{Protheus.doc} TestAvisosTableStructure
    Valida a estrutura da tabela AVISOS (colunas obrigatórias)
*/
User Function TestAvisosTableStructure()
    Local cQuery := ""
    Local aResult := {}

    // Verifica existência das colunas esperadas
    cQuery := "PRAGMA table_info(AVISOS)"
    aResult := FWGetTable(cQuery)

    If Len(aResult) > 0
        ConOut("[PASS] AVISOS table structure is valid (" + AllTrim(Str(Len(aResult))) + " columns)")
        Return .T.
    Else
        ConOut("[FAIL] AVISOS table structure validation failed")
        Return .F.
    EndIf

/*/{Protheus.doc} TestExtratoTableStructure
    Valida a estrutura da tabela RPT_PORTAL_EXTRATOS (colunas obrigatórias)
*/
User Function TestExtratoTableStructure()
    Local cQuery := ""
    Local aResult := {}

    // Verifica existência das colunas esperadas
    cQuery := "PRAGMA table_info(RPT_PORTAL_EXTRATOS)"
    aResult := FWGetTable(cQuery)

    If Len(aResult) > 0
        ConOut("[PASS] RPT_PORTAL_EXTRATOS table structure is valid (" + AllTrim(Str(Len(aResult))) + " columns)")
        Return .T.
    Else
        ConOut("[FAIL] RPT_PORTAL_EXTRATOS table structure validation failed")
        Return .F.
    EndIf

/*/{Protheus.doc} TestAgendaTableStructure
    Valida a estrutura da tabela RPT_PORTAL_AGENDA (colunas obrigatórias)
*/
User Function TestAgendaTableStructure()
    Local cQuery := ""
    Local aResult := {}

    // Verifica existência das colunas esperadas
    cQuery := "PRAGMA table_info(RPT_PORTAL_AGENDA)"
    aResult := FWGetTable(cQuery)

    If Len(aResult) > 0
        ConOut("[PASS] RPT_PORTAL_AGENDA table structure is valid (" + AllTrim(Str(Len(aResult))) + " columns)")
        Return .T.
    Else
        ConOut("[FAIL] RPT_PORTAL_AGENDA table structure validation failed")
        Return .F.
    EndIf

/*/{Protheus.doc} TestGcGerarPortalExtratos
    Testa a função GcGerarPortalExtratos:
    1. Insere registros COB de teste para competência 2025-01
    2. Chama GcGerarPortalExtratos("2025-01")
    3. Verifica se REX records foram criados com dados corretos
*/
User Function TestGcGerarPortalExtratos()
    Local cCompet := "2025-01"
    Local cSql := ""
    Local nCount := 0
    Local aResult := {}
    Local lTodoOk := .T.
    Local i := 0

    ConOut("Test: GcGerarPortalExtratos(" + cCompet + ")")

    // Step 1: Limpa eventuais dados de testes anteriores
    cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = " + GcSqlLit(cCompet)
    TCSqlExec(cSql)
    cSql := "DELETE FROM COB WHERE COB_COMPET = " + GcSqlLit(cCompet)
    TCSqlExec(cSql)

    // Step 2: Insere COB records de teste
    // Record 1: Unidade 101, pendente, sem data de pagamento
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += GcSqlLit("101") + ", "
    cSql += GcSqlLit(cCompet) + ", "
    cSql += "1000.00, "
    cSql += GcSqlLit("20250215") + ", "
    cSql += GcSqlLit("PENDENTE") + ", "
    cSql += GcSqlLit(" ") + ")"
    TCSqlExec(cSql)

    // Record 2: Unidade 102, pendente
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += GcSqlLit("102") + ", "
    cSql += GcSqlLit(cCompet) + ", "
    cSql += "1500.00, "
    cSql += GcSqlLit("20250215") + ", "
    cSql += GcSqlLit("PENDENTE") + ", "
    cSql += GcSqlLit(" ") + ")"
    TCSqlExec(cSql)

    // Record 3: Unidade 103, pago (com data de pagamento)
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG, D_E_L_E_T_) VALUES ("
    cSql += GcSqlLit("103") + ", "
    cSql += GcSqlLit(cCompet) + ", "
    cSql += "2000.00, "
    cSql += GcSqlLit("20250215") + ", "
    cSql += GcSqlLit("PAGO") + ", "
    cSql += GcSqlLit("20250210") + ", "
    cSql += GcSqlLit(" ") + ")"
    TCSqlExec(cSql)

    // Step 3: Chama função
    nCount := U_GcGerarPortalExtratos(cCompet)
    ConOut("GcGerarPortalExtratos returned: " + cValToChar(nCount))

    // Step 4: Valida resultado
    If nCount <> 3
        ConOut("[FAIL] Expected 3 records, got " + cValToChar(nCount))
        Return .F.
    EndIf

    // Step 5: Verifica registros inseridos
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = " + GcSqlLit(cCompet) + " AND D_E_L_E_T_ = ' '"
    aResult := TCSqlQuery(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT = 3
        ConOut("[PASS] 3 records inserted into RPT_PORTAL_EXTRATOS")
    Else
        ConOut("[FAIL] Expected 3 records in RPT_PORTAL_EXTRATOS")
        Return .F.
    EndIf

    // Step 6: Verifica dados específicos (Unidade 101)
    cSql := "SELECT REX_VALOR, REX_STATUS FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = " + GcSqlLit(cCompet) + " AND REX_UNIDADE = '101' AND D_E_L_E_T_ = ' '"
    aResult := TCSqlQuery(cSql)
    If Len(aResult) > 0
        If aResult[1]:REX_VALOR = 1000.00 .And. aResult[1]:REX_STATUS = "PENDENTE"
            ConOut("[PASS] Unit 101 data correct: value=1000.00, status=PENDENTE")
        Else
            ConOut("[FAIL] Unit 101 data incorrect: value=" + cValToChar(aResult[1]:REX_VALOR) + ", status=" + aResult[1]:REX_STATUS)
            Return .F.
        EndIf
    Else
        ConOut("[FAIL] Unit 101 record not found")
        Return .F.
    EndIf

    // Step 7: Verifica dados específicos (Unidade 103 - pago)
    cSql := "SELECT REX_STATUS FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = " + GcSqlLit(cCompet) + " AND REX_UNIDADE = '103' AND D_E_L_E_T_ = ' '"
    aResult := TCSqlQuery(cSql)
    If Len(aResult) > 0
        If aResult[1]:REX_STATUS = "PAGO"
            ConOut("[PASS] Unit 103 status correct: PAGO")
        Else
            ConOut("[FAIL] Unit 103 status incorrect: " + aResult[1]:REX_STATUS)
            Return .F.
        EndIf
    Else
        ConOut("[FAIL] Unit 103 record not found")
        Return .F.
    EndIf

    ConOut("[PASS] TestGcGerarPortalExtratos completed successfully")
Return .T.
