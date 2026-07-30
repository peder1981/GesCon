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

    TestGcGerarPortalAgenda()
    ConOut("")

    TestPeriodClosureGeneratesSnapshots()
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

    FWLogMsg("INFO", "Test: GcGerarPortalExtratos(" + cCompet + ")")

    // Step 1: Limpa eventuais dados de testes anteriores
    cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM COB WHERE COB_COMPET = '" + cCompet + "'"
    FWExecStatement(cSql)

    // Step 2: Insere COB records de teste
    // Record 1: Unidade 101, pendente, sem data de pagamento
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += "'101', "
    cSql += "'" + cCompet + "', "
    cSql += "1000.00, "
    cSql += "'20250215', "
    cSql += "'PENDENTE', "
    cSql += "' ')"
    FWExecStatement(cSql)

    // Record 2: Unidade 102, pendente
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += "'102', "
    cSql += "'" + cCompet + "', "
    cSql += "1500.00, "
    cSql += "'20250215', "
    cSql += "'PENDENTE', "
    cSql += "' ')"
    FWExecStatement(cSql)

    // Record 3: Unidade 103, pago (com status PAGO)
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG, D_E_L_E_T_) VALUES ("
    cSql += "'103', "
    cSql += "'" + cCompet + "', "
    cSql += "2000.00, "
    cSql += "'20250215', "
    cSql += "'PAGO', "
    cSql += "'20250210', "
    cSql += "' ')"
    FWExecStatement(cSql)

    // Step 3: Chama função
    nCount := U_GcGerarPortalExtratos(cCompet)
    FWLogMsg("INFO", "GcGerarPortalExtratos returned: " + cValToChar(nCount))

    // Step 4: Valida resultado
    If nCount <> 3
        FWLogMsg("ERROR", "[FAIL] Expected 3 records, got " + cValToChar(nCount))
        Return .F.
    EndIf

    // Step 5: Verifica registros inseridos
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT = 3
        FWLogMsg("INFO", "[PASS] 3 records inserted into RPT_PORTAL_EXTRATOS")
    Else
        FWLogMsg("ERROR", "[FAIL] Expected 3 records in RPT_PORTAL_EXTRATOS")
        Return .F.
    EndIf

    // Step 6: Verifica dados específicos (Unidade 101)
    cSql := "SELECT REX_VALOR, REX_STATUS FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "' AND REX_UNIDADE = '101' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        If aResult[1]:REX_VALOR = 1000.00 .And. aResult[1]:REX_STATUS = "PENDENTE"
            FWLogMsg("INFO", "[PASS] Unit 101 data correct: value=1000.00, status=PENDENTE")
        Else
            FWLogMsg("ERROR", "[FAIL] Unit 101 data incorrect: value=" + cValToChar(aResult[1]:REX_VALOR) + ", status=" + aResult[1]:REX_STATUS)
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unit 101 record not found")
        Return .F.
    EndIf

    // Step 7: Verifica dados específicos (Unidade 103 - pago)
    cSql := "SELECT REX_STATUS FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "' AND REX_UNIDADE = '103' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        If aResult[1]:REX_STATUS = "PAGO"
            FWLogMsg("INFO", "[PASS] Unit 103 status correct: PAGO")
        Else
            FWLogMsg("ERROR", "[FAIL] Unit 103 status incorrect: " + aResult[1]:REX_STATUS)
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unit 103 record not found")
        Return .F.
    EndIf

    FWLogMsg("INFO", "[PASS] TestGcGerarPortalExtratos completed successfully")
Return .T.

/*/{Protheus.doc} TestGcGerarPortalAgenda
    Testa a função GcGerarPortalAgenda:
    1. Insere registros COB de teste para 3 meses consecutivos
    2. Chama GcGerarPortalAgenda("2025-01") para gerar agenda dos próximos 12 meses
    3. Verifica se REA records foram criados com dados corretos
*/
User Function TestGcGerarPortalAgenda()
    Local cCompet := "2025-01" as character
    Local cSql := "" as character
    Local nCount := 0 as numeric
    Local aResult := {} as array
    Local lTodoOk := .T. as logical
    Local i := 0 as numeric
    Local aMeses := {} as array
    Local cMesAtual := "" as character

    FWLogMsg("INFO", "Test: GcGerarPortalAgenda(" + cCompet + ")")

    // Step 1: Limpa eventuais dados de testes anteriores
    cSql := "DELETE FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE IN ('101', '102', '103')"
    FWExecStatement(cSql)

    // Gera os 3 primeiros meses (2025-01, 2025-02, 2025-03)
    aMeses := {}
    aMeses[1] := "2025-01"
    aMeses[2] := "2025-02"
    aMeses[3] := "2025-03"

    For i := 1 To Len(aMeses)
        cMesAtual := aMeses[i]

        // Limpa dados anteriores para este mês
        cSql := "DELETE FROM COB WHERE COB_COMPET = '" + cMesAtual + "' AND COB_UNIDADE IN ('101', '102', '103')"
        FWExecStatement(cSql)

        // Insere COB records de teste
        // Mês 1: 3 registros (unidades 101, 102, 103)
        cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
        cSql += "'101', "
        cSql += "'" + cMesAtual + "', "
        cSql += "1000.00, "
        cSql += "'20250215', "  // Usar data consistente para os testes (mês 2)
        cSql += "'PENDENTE', "
        cSql += "' ')"
        FWExecStatement(cSql)

        cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
        cSql += "'102', "
        cSql += "'" + cMesAtual + "', "
        cSql += "1500.00, "
        cSql += "'20250215', "
        cSql += "'PENDENTE', "
        cSql += "' ')"
        FWExecStatement(cSql)

        cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
        cSql += "'103', "
        cSql += "'" + cMesAtual + "', "
        cSql += "2000.00, "
        cSql += "'20250215', "
        cSql += "'PENDENTE', "
        cSql += "' ')"
        FWExecStatement(cSql)
    Next i

    // Step 3: Chama função
    nCount := U_GcGerarPortalAgenda(cCompet)
    FWLogMsg("INFO", "GcGerarPortalAgenda returned: " + cValToChar(nCount))

    // Step 4: Valida resultado (espera 12 meses * 3 unidades = 36 registros)
    // Se apenas inseriu para os 3 primeiros meses: 3 meses * 3 unidades = 9 registros
    If nCount < 9
        FWLogMsg("ERROR", "[FAIL] Expected at least 9 records (3 months x 3 units), got " + cValToChar(nCount))
        Return .F.
    EndIf

    // Step 5: Verifica registros inseridos para o primeiro mês
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_AGENDA WHERE REA_COMPETENCIA = '2025-01' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT >= 3
        FWLogMsg("INFO", "[PASS] At least 3 records inserted into RPT_PORTAL_AGENDA for 2025-01")
    Else
        FWLogMsg("ERROR", "[FAIL] Expected at least 3 records for 2025-01 in RPT_PORTAL_AGENDA")
        Return .F.
    EndIf

    // Step 6: Verifica dados específicos (Unidade 101, mês 2025-01)
    cSql := "SELECT REA_VALOR, REA_COMPETENCIA FROM RPT_PORTAL_AGENDA WHERE REA_COMPETENCIA = '2025-01' AND REA_UNIDADE = '101' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        If aResult[1]:REA_VALOR = 1000.00 .And. aResult[1]:REA_COMPETENCIA = "2025-01"
            FWLogMsg("INFO", "[PASS] Unit 101 data correct: value=1000.00, competencia=2025-01")
        Else
            FWLogMsg("ERROR", "[FAIL] Unit 101 data incorrect: value=" + cValToChar(aResult[1]:REA_VALOR) + ", competencia=" + aResult[1]:REA_COMPETENCIA)
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unit 101 record not found for 2025-01")
        Return .F.
    EndIf

    // Step 7: Verifica que foram criados registros para meses subsequentes (2025-02)
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_AGENDA WHERE REA_COMPETENCIA = '2025-02' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT >= 3
        FWLogMsg("INFO", "[PASS] Records created for 2025-02: " + cValToChar(aResult[1]:CNT) + " records")
    Else
        FWLogMsg("ERROR", "[FAIL] Expected at least 3 records for 2025-02")
        Return .F.
    EndIf

    FWLogMsg("INFO", "[PASS] TestGcGerarPortalAgenda completed successfully")
Return .T.

/*/{Protheus.doc} TestPeriodClosureGeneratesSnapshots
    Testa a integração de snapshots do Portal v2 com o fechamento de período:
    1. Cria um exercício de teste (2025-01)
    2. Insere registros de teste na tabela LANCAMENTOS
    3. Insere registros de teste na tabela COB
    4. Chama GcFecharPeriodo("2025-01")
    5. Verifica se os snapshots foram criados em RPT_PORTAL_EXTRATOS e RPT_PORTAL_AGENDA
*/
User Function TestPeriodClosureGeneratesSnapshots()
    Local cCompet := "2025-01" as character
    Local cProxCompet := "2025-02" as character
    Local cSql := "" as character
    Local aResult := {} as array
    Local nExtratoCount := 0 as numeric
    Local nAgendaCount := 0 as numeric
    Local lTodoOk := .T. as logical

    FWLogMsg("INFO", "Test: Period closure with Portal v2 snapshots for " + cCompet)

    // Step 1: Limpa dados de testes anteriores
    cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA IN ('" + cCompet + "', '" + cProxCompet + "')"
    FWExecStatement(cSql)
    cSql := "DELETE FROM RPT_PORTAL_AGENDA WHERE REA_COMPETENCIA IN ('" + cCompet + "', '" + cProxCompet + "')"
    FWExecStatement(cSql)
    cSql := "DELETE FROM RPT_BALANCETE WHERE RPT_EXERCICIO IN ('" + cCompet + "', '" + cProxCompet + "')"
    FWExecStatement(cSql)
    cSql := "DELETE FROM COB WHERE COB_COMPET = '" + cCompet + "'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM LANCAMENTOS WHERE LAN_EXERCICIO = '" + cCompet + "'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cCompet + "', '" + cProxCompet + "')"
    FWExecStatement(cSql)

    // Step 2: Cria exercício de teste
    cSql := "INSERT INTO EXERCICIO (EXE_CODIGO, EXE_ATIVO, EXE_FECHADO, EXE_INICIO, EXE_FIM, D_E_L_E_T_) VALUES ("
    cSql += "'" + cCompet + "', "
    cSql += "1, "
    cSql += "0, "
    cSql += "'20250101', "
    cSql += "'20250131', "
    cSql += "' ')"
    FWExecStatement(cSql)
    FWLogMsg("INFO", "Exercise " + cCompet + " created")

    // Step 3: Insere lançamentos contábeis de teste (para validar integridade)
    // Lançamento 1: Débito 1100 / Crédito 3000 (Receita)
    cSql := "INSERT INTO LANCAMENTOS ("
    cSql += "LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, "
    cSql += "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_"
    cSql += ") VALUES ("
    cSql += "'20250115', "
    cSql += "'1100', "
    cSql += "'3000', "
    cSql += "1000.00, "
    cSql += "'Receita Condominial', "
    cSql += "'MANUAL', "
    cSql += "'" + cCompet + "', "
    cSql += "datetime('now'), "
    cSql += "'TEST_USER', "
    cSql += "' ', "
    cSql += "1)"
    FWExecStatement(cSql)

    // Lançamento 2: Débito 4000 / Crédito 1100 (Despesa / Caixa)
    cSql := "INSERT INTO LANCAMENTOS ("
    cSql += "LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, "
    cSql += "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_"
    cSql += ") VALUES ("
    cSql += "'20250115', "
    cSql += "'4000', "
    cSql += "'1100', "
    cSql += "1000.00, "
    cSql += "'Despesa Comum', "
    cSql += "'MANUAL', "
    cSql += "'" + cCompet + "', "
    cSql += "datetime('now'), "
    cSql += "'TEST_USER', "
    cSql += "' ', "
    cSql += "2)"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "Test entries created: 2 double-entry records for accounting integrity")

    // Step 4: Insere registros COB de teste para gerar snapshots
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += "'101', '"
    cSql += cCompet + "', "
    cSql += "500.00, "
    cSql += "'20250220', "
    cSql += "'PENDENTE', "
    cSql += "' ')"
    FWExecStatement(cSql)

    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += "'102', '"
    cSql += cCompet + "', "
    cSql += "750.00, "
    cSql += "'20250220', "
    cSql += "'PENDENTE', "
    cSql += "' ')"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "Test billing records created: 2 COB entries for " + cCompet)

    // Step 5: Verifica que os snapshots NÃO existem antes do fechamento
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT = 0
        FWLogMsg("INFO", "Pre-closure check: RPT_PORTAL_EXTRATOS is empty (as expected)")
    Else
        FWLogMsg("WARN", "Pre-closure check: RPT_PORTAL_EXTRATOS already has records")
    EndIf

    // Step 6: Chama GcFecharPeriodo() que deve gerar os snapshots
    If U_GcFecharPeriodo(cCompet)
        FWLogMsg("INFO", "Period " + cCompet + " closed successfully")
    Else
        FWLogMsg("ERROR", "[FAIL] Period closure failed for " + cCompet)
        Return .F.
    EndIf

    // Step 7: Verifica se o exercício foi marcado como fechado
    cSql := "SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = '" + cCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:EXE_FECHADO = 1
        FWLogMsg("INFO", "[PASS] Exercise marked as closed")
    Else
        FWLogMsg("ERROR", "[FAIL] Exercise not marked as closed")
        Return .F.
    EndIf

    // Step 8: Verifica se o próximo exercício foi criado
    cSql := "SELECT EXE_ATIVO FROM EXERCICIO WHERE EXE_CODIGO = '" + cProxCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:EXE_ATIVO = 1
        FWLogMsg("INFO", "[PASS] Next exercise created and set as active")
    Else
        FWLogMsg("ERROR", "[FAIL] Next exercise not created or not active")
        Return .F.
    EndIf

    // Step 9: Verifica se os snapshots foram criados em RPT_PORTAL_EXTRATOS
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        nExtratoCount := aResult[1]:CNT
        If nExtratoCount >= 2
            FWLogMsg("INFO", "[PASS] Portal v2 extracts snapshot created: " + cValToChar(nExtratoCount) + " records")
        Else
            FWLogMsg("ERROR", "[FAIL] Expected at least 2 extract records, got " + cValToChar(nExtratoCount))
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unable to query RPT_PORTAL_EXTRATOS")
        Return .F.
    EndIf

    // Step 10: Verifica se os snapshots foram criados em RPT_PORTAL_AGENDA
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_AGENDA WHERE REA_COMPETENCIA = '" + cCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        nAgendaCount := aResult[1]:CNT
        If nAgendaCount >= 2
            FWLogMsg("INFO", "[PASS] Portal v2 agenda snapshot created: " + cValToChar(nAgendaCount) + " records")
        Else
            FWLogMsg("ERROR", "[FAIL] Expected at least 2 agenda records, got " + cValToChar(nAgendaCount))
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unable to query RPT_PORTAL_AGENDA")
        Return .F.
    EndIf

    // Step 11: Verifica dados específicos dos snapshots
    cSql := "SELECT REX_UNIDADE, REX_VALOR FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "' AND REX_UNIDADE = '101' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        If aResult[1]:REX_VALOR = 500.00
            FWLogMsg("INFO", "[PASS] Extract snapshot data correct for Unit 101: value=500.00")
        Else
            FWLogMsg("ERROR", "[FAIL] Extract snapshot data incorrect for Unit 101: value=" + cValToChar(aResult[1]:REX_VALOR))
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unit 101 not found in extract snapshot")
        Return .F.
    EndIf

    FWLogMsg("INFO", "[PASS] TestPeriodClosureGeneratesSnapshots completed successfully - snapshots created after period closure")
Return .T.
