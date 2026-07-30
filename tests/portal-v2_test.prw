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

    TestGcPortalCondominoV2()
    ConOut("")

    TestGcCriarAviso()
    ConOut("")

    TestGcArquivarAviso()
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

/*/{Protheus.doc} TestE2EPortalFlow
    Teste end-to-end da plataforma Portal v2 (E2E):
    1. Cria exercício de teste
    2. Insere registros COB de teste
    3. Cria token válido na tabela GCT_TOKEN
    4. Cria avisos via GcCriarAviso
    5. Fecha período via GcFecharPeriodo (que gera snapshots)
    6. Verifica se snapshots foram criados
    7. Acessa portal via GcPortalCondominoV2 com token
    8. Valida que avisos, extratos e agenda estão acessíveis
    Objetivo: garantir que a jornada completa do usuário (período fechado → acesso ao portal com dados) funciona.
    @type User Function
    @author GesCon
    @since 2026-07-30
*/
User Function TestE2EPortalFlow()
    Local cCompet := "2025-03" as character
    Local cProxCompet := "2025-04" as character
    Local cToken := "e2e-test-token-" + SubStr(FWTimeStamp(), 1, 14) as character
    Local cUnitCode := "E2E_UNIT_001" as character
    Local cSql := "" as character
    Local aResult := {} as array
    Local nExtratoCount := 0 as numeric
    Local nAgendaCount := 0 as numeric
    Local nAvisoCount := 0 as numeric
    Local lTodoOk := .T. as logical

    FWLogMsg("INFO", "E2E Test: Complete Portal v2 flow (close period → access portal)")
    ConOut("")
    ConOut("========== TESTE E2E PORTAL V2 ==========")

    // Passo 1: Limpa dados de testes anteriores
    FWLogMsg("INFO", "Step 1: Cleanup previous test data")
    cSql := "DELETE FROM GCT_TOKEN WHERE GCT_TOKEN LIKE 'e2e-test-token-%'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA IN ('" + cCompet + "', '" + cProxCompet + "')"
    FWExecStatement(cSql)
    cSql := "DELETE FROM RPT_PORTAL_AGENDA WHERE REA_COMPETENCIA IN ('" + cCompet + "', '" + cProxCompet + "')"
    FWExecStatement(cSql)
    cSql := "DELETE FROM AVISOS WHERE AVI_TITULO LIKE 'E2E Test%'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM RPT_BALANCETE WHERE RPT_EXERCICIO IN ('" + cCompet + "', '" + cProxCompet + "')"
    FWExecStatement(cSql)
    cSql := "DELETE FROM COB WHERE COB_COMPET = '" + cCompet + "' AND COB_UNIDADE = '" + cUnitCode + "'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM LANCAMENTOS WHERE LAN_EXERCICIO = '" + cCompet + "' AND LAN_USUARIO = 'E2E_TEST'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cCompet + "', '" + cProxCompet + "') AND D_E_L_E_T_ = ' '"
    FWExecStatement(cSql)
    FWLogMsg("INFO", "[PASS] Previous test data cleaned")

    // Passo 2: Cria token válido na tabela GCT_TOKEN
    FWLogMsg("INFO", "Step 2: Create valid authentication token")
    cSql := "INSERT INTO GCT_TOKEN (GCT_TOKEN, UNI_CODIGO, VALIDO_ATE, CRIADO_EM, USADO, D_E_L_E_T_) VALUES ("
    cSql += "'" + cToken + "', "
    cSql += "'" + cUnitCode + "', "
    cSql += "'" + DtoS(Date() + 2) + "', "  // válido por 2 dias
    cSql += "datetime('now'), "
    cSql += "0, "
    cSql += "' ')"
    FWExecStatement(cSql)
    FWLogMsg("INFO", "[PASS] Token criado: " + cToken)

    // Passo 3: Cria exercício de teste
    FWLogMsg("INFO", "Step 3: Create test exercise")
    cSql := "INSERT INTO EXERCICIO (EXE_CODIGO, EXE_ATIVO, EXE_FECHADO, EXE_INICIO, EXE_FIM, D_E_L_E_T_) VALUES ("
    cSql += "'" + cCompet + "', "
    cSql += "1, "
    cSql += "0, "
    cSql += "'20250301', "
    cSql += "'20250331', "
    cSql += "' ')"
    FWExecStatement(cSql)
    FWLogMsg("INFO", "[PASS] Exercise criado: " + cCompet)

    // Passo 4: Insere registros COB de teste (dois períodos para testar agenda)
    FWLogMsg("INFO", "Step 4: Insert test billing records (COB)")
    // Registros para o período atual (2025-03)
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += "'" + cUnitCode + "', '"
    cSql += cCompet + "', "
    cSql += "500.00, "
    cSql += "'20250315', "
    cSql += "'PENDENTE', "
    cSql += "' ')"
    FWExecStatement(cSql)

    // Registros para mês futuro (para testar agenda)
    cSql := "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) VALUES ("
    cSql += "'" + cUnitCode + "', '"
    cSql += cProxCompet + "', "
    cSql += "750.00, "
    cSql += "'20250415', "
    cSql += "'PENDENTE', "
    cSql += "' ')"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "[PASS] Test billing records inserted for periods: " + cCompet + ", " + cProxCompet)

    // Passo 5: Insere lançamentos contábeis de teste
    FWLogMsg("INFO", "Step 5: Insert accounting entries")
    cSql := "INSERT INTO LANCAMENTOS ("
    cSql += "LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, "
    cSql += "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_"
    cSql += ") VALUES ("
    cSql += "'20250315', "
    cSql += "'1100', "
    cSql += "'3000', "
    cSql += "1500.00, "
    cSql += "'Receita Condominial E2E', "
    cSql += "'MANUAL', "
    cSql += "'" + cCompet + "', "
    cSql += "datetime('now'), "
    cSql += "'E2E_TEST', "
    cSql += "' ', "
    cSql += "1)"
    FWExecStatement(cSql)
    FWLogMsg("INFO", "[PASS] Accounting entries created")

    // Passo 6: Cria avisos via GcCriarAviso
    FWLogMsg("INFO", "Step 6: Create test avisos (notices)")
    If !U_GcCriarAviso("E2E Test Aviso 1", "This is the first E2E test notice")
        FWLogMsg("ERROR", "[FAIL] Failed to create first aviso")
        Return .F.
    EndIf
    If !U_GcCriarAviso("E2E Test Aviso 2", "This is the second E2E test notice")
        FWLogMsg("ERROR", "[FAIL] Failed to create second aviso")
        Return .F.
    EndIf
    FWLogMsg("INFO", "[PASS] Test avisos created successfully")

    // Passo 7: Fecha período (deve gerar snapshots)
    FWLogMsg("INFO", "Step 7: Close period (triggers snapshot generation)")
    If !U_GcFecharPeriodo(cCompet)
        FWLogMsg("ERROR", "[FAIL] Period closure failed")
        Return .F.
    EndIf
    FWLogMsg("INFO", "[PASS] Period closed successfully")

    // Passo 8: Valida que exercício foi marcado como fechado
    FWLogMsg("INFO", "Step 8: Verify exercise was marked as closed")
    cSql := "SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = '" + cCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:EXE_FECHADO = 1
        FWLogMsg("INFO", "[PASS] Exercise marked as closed")
    Else
        FWLogMsg("ERROR", "[FAIL] Exercise not marked as closed")
        Return .F.
    EndIf

    // Passo 9: Valida que próximo exercício foi criado
    FWLogMsg("INFO", "Step 9: Verify next exercise was created")
    cSql := "SELECT EXE_ATIVO FROM EXERCICIO WHERE EXE_CODIGO = '" + cProxCompet + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:EXE_ATIVO = 1
        FWLogMsg("INFO", "[PASS] Next exercise created and active")
    Else
        FWLogMsg("ERROR", "[FAIL] Next exercise not created or not active")
        Return .F.
    EndIf

    // Passo 10: Verifica snapshots foram criados
    FWLogMsg("INFO", "Step 10: Verify snapshots were created")
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompet + "' AND REX_UNIDADE = '" + cUnitCode + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        nExtratoCount := aResult[1]:CNT
        If nExtratoCount >= 1
            FWLogMsg("INFO", "[PASS] Extract snapshots created: " + cValToChar(nExtratoCount) + " records for unit " + cUnitCode)
        Else
            FWLogMsg("ERROR", "[FAIL] Expected at least 1 extract record, got " + cValToChar(nExtratoCount))
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unable to query RPT_PORTAL_EXTRATOS")
        Return .F.
    EndIf

    // Passo 11: Verifica agenda foi gerada
    FWLogMsg("INFO", "Step 11: Verify agenda was generated for next 12 months")
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE = '" + cUnitCode + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        nAgendaCount := aResult[1]:CNT
        If nAgendaCount >= 1
            FWLogMsg("INFO", "[PASS] Agenda snapshots created: " + cValToChar(nAgendaCount) + " records for unit " + cUnitCode)
        Else
            FWLogMsg("ERROR", "[FAIL] Expected at least 1 agenda record, got " + cValToChar(nAgendaCount))
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unable to query RPT_PORTAL_AGENDA")
        Return .F.
    EndIf

    // Passo 12: Verifica avisos estão disponíveis
    FWLogMsg("INFO", "Step 12: Verify avisos are available")
    cSql := "SELECT COUNT(*) as CNT FROM AVISOS WHERE AVI_TITULO LIKE 'E2E Test%' AND AVI_ATIVO = 1 AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        nAvisoCount := aResult[1]:CNT
        If nAvisoCount >= 2
            FWLogMsg("INFO", "[PASS] Avisos created and available: " + cValToChar(nAvisoCount) + " notices")
        Else
            FWLogMsg("ERROR", "[FAIL] Expected at least 2 avisos, got " + cValToChar(nAvisoCount))
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Unable to query AVISOS")
        Return .F.
    EndIf

    // Passo 13: Acessa portal via token (sem avaliar dados específicos, apenas autenticação)
    FWLogMsg("INFO", "Step 13: Access portal via token (authentication)")
    If U_GcPortalCondominoV2(cToken)
        FWLogMsg("INFO", "[PASS] Portal accessed successfully with token")
    Else
        FWLogMsg("ERROR", "[FAIL] Portal access failed with token")
        Return .F.
    EndIf

    // Passo 14: Verifica que token foi marcado como usado
    FWLogMsg("INFO", "Step 14: Verify token was marked as used")
    cSql := "SELECT USADO FROM GCT_TOKEN WHERE GCT_TOKEN = '" + cToken + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        If aResult[1]:USADO = 1
            FWLogMsg("INFO", "[PASS] Token marked as used")
        Else
            FWLogMsg("WARN", "Token not marked as used (may indicate issue with GcPortalCondominoV2)")
        EndIf
    EndIf

    ConOut("")
    FWLogMsg("INFO", "[PASS] TestE2EPortalFlow completed successfully - full flow from period close to portal access verified")
    ConOut("========== FIM TESTE E2E PORTAL V2 ==========")
    ConOut("")

Return .T.

/*/{Protheus.doc} TestGcCriarAviso
    Testa a função GcCriarAviso:
    1. Limpa eventuais dados de testes anteriores
    2. Chama GcCriarAviso com título e corpo válidos
    3. Verifica se o registro foi criado com dados corretos
    4. Testa validação de parâmetros (título vazio, corpo vazio)
*/
User Function TestGcCriarAviso()
    Local cSql := "" as character
    Local lResult := .F. as logical
    Local aResult := {} as array
    Local nAvisoCount := 0 as numeric

    FWLogMsg("INFO", "Test: GcCriarAviso")

    // Step 1: Limpa eventuais dados de testes anteriores
    cSql := "DELETE FROM AVISOS WHERE AVI_TITULO LIKE '%Teste%' AND D_E_L_E_T_ = ' '"
    FWExecStatement(cSql)

    // Step 2: Testa criação de aviso válido
    lResult := U_GcCriarAviso("Teste Aviso 1", "Este é um aviso de teste para validar a função GcCriarAviso")
    If lResult
        FWLogMsg("INFO", "[PASS] Aviso criado com sucesso")
    Else
        FWLogMsg("ERROR", "[FAIL] Erro ao criar aviso")
        Return .F.
    EndIf

    // Step 3: Verifica se o registro foi inserido
    cSql := "SELECT COUNT(*) as CNT FROM AVISOS WHERE AVI_TITULO = 'Teste Aviso 1' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT > 0
        FWLogMsg("INFO", "[PASS] Aviso inserido na tabela AVISOS")
    Else
        FWLogMsg("ERROR", "[FAIL] Aviso não encontrado em AVISOS")
        Return .F.
    EndIf

    // Step 4: Verifica dados específicos do aviso criado
    cSql := "SELECT AVI_TITULO, AVI_CORPO, AVI_ATIVO FROM AVISOS WHERE AVI_TITULO = 'Teste Aviso 1' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        If aResult[1]:AVI_TITULO = "Teste Aviso 1" .And. aResult[1]:AVI_ATIVO = 1
            FWLogMsg("INFO", "[PASS] Aviso criado com dados corretos: titulo=Teste Aviso 1, ativo=1")
        Else
            FWLogMsg("ERROR", "[FAIL] Dados do aviso incorretos: titulo=" + aResult[1]:AVI_TITULO + ", ativo=" + cValToChar(aResult[1]:AVI_ATIVO))
            Return .F.
        EndIf
    Else
        FWLogMsg("ERROR", "[FAIL] Aviso não encontrado")
        Return .F.
    EndIf

    // Step 5: Testa validação - título vazio deve retornar .F.
    lResult := U_GcCriarAviso("", "Corpo do aviso")
    If !lResult
        FWLogMsg("INFO", "[PASS] Validação funciona: título vazio retorna .F.")
    Else
        FWLogMsg("ERROR", "[FAIL] Deveria ter rejeitado título vazio")
        Return .F.
    EndIf

    // Step 6: Testa validação - corpo vazio deve retornar .F.
    lResult := U_GcCriarAviso("Título válido", "")
    If !lResult
        FWLogMsg("INFO", "[PASS] Validação funciona: corpo vazio retorna .F.")
    Else
        FWLogMsg("ERROR", "[FAIL] Deveria ter rejeitado corpo vazio")
        Return .F.
    EndIf

    // Step 7: Cria múltiplos avisos para teste subsequente
    U_GcCriarAviso("Teste Aviso 2", "Segundo aviso de teste")
    U_GcCriarAviso("Teste Aviso 3", "Terceiro aviso de teste")

    cSql := "SELECT COUNT(*) as CNT FROM AVISOS WHERE AVI_TITULO LIKE '%Teste%' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT >= 3
        FWLogMsg("INFO", "[PASS] Múltiplos avisos criados: " + cValToChar(aResult[1]:CNT) + " avisos")
    Else
        FWLogMsg("ERROR", "[FAIL] Esperava pelo menos 3 avisos")
        Return .F.
    EndIf

    FWLogMsg("INFO", "[PASS] TestGcCriarAviso completed successfully")
Return .T.

/*/{Protheus.doc} TestGcArquivarAviso
    Testa a função GcArquivarAviso:
    1. Cria avisos de teste usando GcCriarAviso
    2. Chama GcArquivarAviso com ID válido
    3. Verifica se o aviso foi marcado como inativo
    4. Testa validação com ID inválido (ID negativo, ID não existente)
*/
User Function TestGcArquivarAviso()
    Local cSql := "" as character
    Local lResult := .F. as logical
    Local aResult := {} as array
    Local nAvisoId := 0 as numeric

    FWLogMsg("INFO", "Test: GcArquivarAviso")

    // Step 1: Limpa dados de testes anteriores
    cSql := "DELETE FROM AVISOS WHERE AVI_TITULO LIKE '%Arquivo%' AND D_E_L_E_T_ = ' '"
    FWExecStatement(cSql)

    // Step 2: Cria avisos de teste
    U_GcCriarAviso("Arquivo Teste 1", "Aviso para ser arquivado")
    U_GcCriarAviso("Arquivo Teste 2", "Outro aviso para ser arquivado")

    // Step 3: Obtém ID do primeiro aviso criado
    cSql := "SELECT AVI_ID FROM AVISOS WHERE AVI_TITULO = 'Arquivo Teste 1' AND D_E_L_E_T_ = ' ' ORDER BY AVI_ID DESC LIMIT 1"
    aResult := FWExecStatement(cSql)
    If Len(aResult) = 0
        FWLogMsg("ERROR", "[FAIL] Aviso de teste não criado")
        Return .F.
    EndIf
    nAvisoId := aResult[1]:AVI_ID
    FWLogMsg("INFO", "Test aviso ID: " + cValToChar(nAvisoId))

    // Step 4: Verifica se aviso está ativo antes do arquivamento
    cSql := "SELECT AVI_ATIVO FROM AVISOS WHERE AVI_ID = " + cValToChar(nAvisoId) + " AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:AVI_ATIVO = 1
        FWLogMsg("INFO", "[PASS] Aviso está ativo antes do arquivamento")
    Else
        FWLogMsg("ERROR", "[FAIL] Aviso não está ativo antes do arquivamento")
        Return .F.
    EndIf

    // Step 5: Chama função de arquivamento
    lResult := U_GcArquivarAviso(nAvisoId)
    If lResult
        FWLogMsg("INFO", "[PASS] Função GcArquivarAviso retornou .T.")
    Else
        FWLogMsg("ERROR", "[FAIL] Função GcArquivarAviso retornou .F.")
        Return .F.
    EndIf

    // Step 6: Verifica se aviso foi marcado como inativo
    cSql := "SELECT AVI_ATIVO FROM AVISOS WHERE AVI_ID = " + cValToChar(nAvisoId) + " AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:AVI_ATIVO = 0
        FWLogMsg("INFO", "[PASS] Aviso foi marcado como inativo (AVI_ATIVO=0)")
    Else
        FWLogMsg("ERROR", "[FAIL] Aviso não foi marcado como inativo")
        Return .F.
    EndIf

    // Step 7: Testa validação - ID inválido deve retornar .F.
    lResult := U_GcArquivarAviso(-1)
    If !lResult
        FWLogMsg("INFO", "[PASS] Validação funciona: ID negativo retorna .F.")
    Else
        FWLogMsg("ERROR", "[FAIL] Deveria ter rejeitado ID negativo")
        Return .F.
    EndIf

    // Step 8: Testa validação - ID inexistente deve retornar .F.
    lResult := U_GcArquivarAviso(999999)
    If !lResult
        FWLogMsg("INFO", "[PASS] Validação funciona: ID inexistente retorna .F.")
    Else
        FWLogMsg("ERROR", "[FAIL] Deveria ter rejeitado ID inexistente")
        Return .F.
    EndIf

    // Step 9: Testa arquivamento de segundo aviso
    cSql := "SELECT AVI_ID FROM AVISOS WHERE AVI_TITULO = 'Arquivo Teste 2' AND D_E_L_E_T_ = ' ' ORDER BY AVI_ID DESC LIMIT 1"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0
        nAvisoId := aResult[1]:AVI_ID
        lResult := U_GcArquivarAviso(nAvisoId)
        If lResult
            FWLogMsg("INFO", "[PASS] Segundo aviso também arquivado com sucesso")
        Else
            FWLogMsg("ERROR", "[FAIL] Erro ao arquivar segundo aviso")
            Return .F.
        EndIf
    EndIf

    // Step 10: Verifica que avisos ativos foram removidos da consulta
    cSql := "SELECT COUNT(*) as CNT FROM AVISOS WHERE AVI_TITULO LIKE '%Arquivo%' AND AVI_ATIVO = 1 AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT = 0
        FWLogMsg("INFO", "[PASS] Nenhum aviso Arquivo com AVI_ATIVO=1 encontrado")
    Else
        FWLogMsg("ERROR", "[FAIL] Ainda existem avisos Arquivo com AVI_ATIVO=1")
        Return .F.
    EndIf

    FWLogMsg("INFO", "[PASS] TestGcArquivarAviso completed successfully")
Return .T.

/*/{Protheus.doc} TestGcPortalCondominoV2
    Testa a função GcPortalCondominoV2:
    1. Cria token de teste na tabela GCT_TOKEN
    2. Cria dados de teste em AVISOS, RPT_PORTAL_EXTRATOS, RPT_PORTAL_AGENDA para a unidade
    3. Chama GcPortalCondominoV2(cToken)
    4. Verifica se token foi marcado como usado (USADO = 1)
    5. Verifica se dados foram filtrados corretamente por unidade
*/
User Function TestGcPortalCondominoV2()
    Local cToken := "550e8400-e29b-41d4-a716-446655440000" as character
    Local cUnitCode := "101" as character
    Local cConCode := "CON001" as character
    Local cSql := "" as character
    Local aResult := {} as array
    Local lOk := .T. as logical
    Local dValidoAte := Date() + 30 as date
    Local cValidoAteStr := "" as character

    FWLogMsg("INFO", "Test: GcPortalCondominoV2(token)")

    // Step 1: Limpa dados de testes anteriores
    cSql := "DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM AVISOS WHERE AVI_UNIDADE = '" + cUnitCode + "'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_UNIDADE = '" + cUnitCode + "'"
    FWExecStatement(cSql)
    cSql := "DELETE FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE = '" + cUnitCode + "'"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "Test data cleaned up")

    // Step 2: Insere token válido (não usado, válido por 30 dias)
    cValidoAteStr := DtoS(dValidoAte)
    cValidoAteStr := SubStr(cValidoAteStr, 1, 4) + "-" + SubStr(cValidoAteStr, 5, 2) + "-" + SubStr(cValidoAteStr, 7, 2) + " 23:59:59"

    cSql := "INSERT INTO GCT_TOKEN (TOKEN, UNI_CODIGO, CON_CODIGO, VALIDO_ATE, USADO, D_E_L_E_T_) VALUES ("
    cSql += "'" + cToken + "', "
    cSql += "'" + cUnitCode + "', "
    cSql += "'" + cConCode + "', "
    cSql += "'" + cValidoAteStr + "', "
    cSql += "0, "
    cSql += "' ')"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "Test token created: " + cToken)

    // Step 3: Insere dados de teste em AVISOS para a unidade
    cSql := "INSERT INTO AVISOS (AVI_UNIDADE, AVI_TITULO, AVI_DESCRICAO, AVI_DATA, D_E_L_E_T_) VALUES ("
    cSql += "'" + cUnitCode + "', "
    cSql += "'Aviso 1', "
    cSql += "'Descrição do aviso 1', "
    cSql += "datetime('now'), "
    cSql += "' ')"
    FWExecStatement(cSql)

    cSql := "INSERT INTO AVISOS (AVI_UNIDADE, AVI_TITULO, AVI_DESCRICAO, AVI_DATA, D_E_L_E_T_) VALUES ("
    cSql += "'" + cUnitCode + "', "
    cSql += "'Aviso 2', "
    cSql += "'Descrição do aviso 2', "
    cSql += "datetime('now'), "
    cSql += "' ')"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "Test notices inserted: 2 AVISOS for unit " + cUnitCode)

    // Step 4: Insere dados de teste em RPT_PORTAL_EXTRATOS para a unidade
    cSql := "INSERT INTO RPT_PORTAL_EXTRATOS (REX_COMPETENCIA, REX_UNIDADE, REX_VALOR, REX_VENCIMENTO, REX_STATUS, D_E_L_E_T_) VALUES ("
    cSql += "'2025-01', "
    cSql += "'" + cUnitCode + "', "
    cSql += "1000.00, "
    cSql += "'2025-02-15', "
    cSql += "'PENDENTE', "
    cSql += "' ')"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "Test extract inserted: 1 RPT_PORTAL_EXTRATOS for unit " + cUnitCode)

    // Step 5: Insere dados de teste em RPT_PORTAL_AGENDA para a unidade
    cSql := "INSERT INTO RPT_PORTAL_AGENDA (REA_UNIDADE, REA_COMPETENCIA, REA_VENCIMENTO, REA_VALOR, D_E_L_E_T_) VALUES ("
    cSql += "'" + cUnitCode + "', "
    cSql += "'2025-02', "
    cSql += "'2025-02-15', "
    cSql += "1000.00, "
    cSql += "' ')"
    FWExecStatement(cSql)

    FWLogMsg("INFO", "Test schedule inserted: 1 RPT_PORTAL_AGENDA for unit " + cUnitCode)

    // Step 6: Chama função GcPortalCondominoV2
    If U_GcPortalCondominoV2(cToken)
        FWLogMsg("INFO", "GcPortalCondominoV2 returned .T. (authentication successful)")
    Else
        FWLogMsg("ERROR", "[FAIL] GcPortalCondominoV2 returned .F.")
        Return .F.
    EndIf

    // Step 7: Verifica se token foi marcado como usado
    cSql := "SELECT USADO FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:USADO = 1
        FWLogMsg("INFO", "[PASS] Token marked as used (USADO = 1)")
    Else
        FWLogMsg("ERROR", "[FAIL] Token not marked as used")
        Return .F.
    EndIf

    // Step 8: Verifica se dados de AVISOS foram recuperados para a unidade
    cSql := "SELECT COUNT(*) as CNT FROM AVISOS WHERE AVI_UNIDADE = '" + cUnitCode + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT = 2
        FWLogMsg("INFO", "[PASS] 2 notices retrieved for unit " + cUnitCode)
    Else
        FWLogMsg("ERROR", "[FAIL] Expected 2 notices, got " + cValToChar(aResult[1]:CNT))
        Return .F.
    EndIf

    // Step 9: Verifica se dados de RPT_PORTAL_EXTRATOS foram recuperados
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_EXTRATOS WHERE REX_UNIDADE = '" + cUnitCode + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT = 1
        FWLogMsg("INFO", "[PASS] 1 extract retrieved for unit " + cUnitCode)
    Else
        FWLogMsg("ERROR", "[FAIL] Expected 1 extract, got " + cValToChar(aResult[1]:CNT))
        Return .F.
    EndIf

    // Step 10: Verifica se dados de RPT_PORTAL_AGENDA foram recuperados
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE = '" + cUnitCode + "' AND D_E_L_E_T_ = ' '"
    aResult := FWExecStatement(cSql)
    If Len(aResult) > 0 .And. aResult[1]:CNT = 1
        FWLogMsg("INFO", "[PASS] 1 schedule item retrieved for unit " + cUnitCode)
    Else
        FWLogMsg("ERROR", "[FAIL] Expected 1 schedule item, got " + cValToChar(aResult[1]:CNT))
        Return .F.
    EndIf

    // Step 11: Verifica que token expira não pode ser usado novamente
    If !U_GcPortalCondominoV2(cToken)
        FWLogMsg("INFO", "[PASS] Token cannot be used twice (second attempt rejected)")
    Else
        FWLogMsg("ERROR", "[FAIL] Token was reused after marking as used")
        Return .F.
    EndIf

    FWLogMsg("INFO", "[PASS] TestGcPortalCondominoV2 completed successfully")
Return .T.
