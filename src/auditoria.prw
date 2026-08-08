// src/auditoria.prw — auditoria e detecção de anomalias no sistema contábil
// Detecta inconsistências (lançamentos órfãos, desequilíbrio, cobranças órfãs)
// e registra em tabela AUDITORIA para rastreamento
#include "totvs.ch"

/*/{Protheus.doc} GcRegistrarAnomalia
    Registra uma anomalia detectada na auditoria.
    Insere um registro na tabela AUDITORIA com timestamp, tipo, descrição e severidade.
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cTipo, character, tipo de anomalia (DESEQUILIBRIO_CONTABIL, COB_ORFAO, LAN_ORFAO, OUTRO)
    @param cDescricao, character, descrição da anomalia (max 200 caracteres)
    @param cSeveridade, character, severidade (CRITICA, AVISO, INFO)
    @param cExercicio, character, código do exercício (opcional)
    @param nRecnoLan, numeric, número de registro do lançamento (opcional)
    @param nRecnoCob, numeric, número de registro da cobrança (opcional)
    @return lRet, logical, .T. se registrado com sucesso, .F. se validação falhou
    @example
        If GcRegistrarAnomalia("LAN_ORFAO", "Lançamento 12345 sem cobrança relacionada", "AVISO", "2025-01", 12345)
            ConOut("Anomalia registrada")
        EndIf
*/
User Function GcRegistrarAnomalia(cTipo, cDescricao, cSeveridade, cExercicio, nRecnoLan, nRecnoCob)
    Local lRet := .F.
    Local cSql := ""

    // Valores padrão para parâmetros opcionais
    If cExercicio == Nil
        cExercicio := ""
    EndIf
    If nRecnoLan == Nil
        nRecnoLan := 0
    EndIf
    If nRecnoCob == Nil
        nRecnoCob := 0
    EndIf

    // Validações básicas
    If Empty(cTipo) .Or. Empty(cDescricao) .Or. Empty(cSeveridade)
        ConOut("ERROR: Invalid parameters for anomaly registration")
        Return .F.
    EndIf

    // Valida tipo
    If cTipo <> "DESEQUILIBRIO_CONTABIL" .And. cTipo <> "COB_ORFAO" .And. cTipo <> "LAN_ORFAO" .And. cTipo <> "OUTRO"
        ConOut("ERROR: Invalid anomaly type: " + cTipo)
        Return .F.
    EndIf

    // Valida severidade
    If cSeveridade <> "CRITICA" .And. cSeveridade <> "AVISO" .And. cSeveridade <> "INFO"
        ConOut("ERROR: Invalid severity: " + cSeveridade)
        Return .F.
    EndIf

    // Monta SQL de inserção
    cSql := "INSERT INTO AUDITORIA ("
    cSql += "AUD_DATA_HORA, AUD_TIPO, AUD_DESCRICAO, AUD_SEVERIDADE, AUD_EXERCICIO, AUD_RECNO_LAN, AUD_RECNO_COB, D_E_L_E_T_, FILIAL"
    cSql += ") VALUES ("
    cSql += "datetime('now'), "
    cSql += GcSqlVal(cTipo) + ", "
    cSql += GcSqlVal(cDescricao) + ", "
    cSql += GcSqlVal(cSeveridade) + ", "
    cSql += GcSqlVal(cExercicio) + ", "
    cSql += cValToChar(nRecnoLan) + ", "
    cSql += cValToChar(nRecnoCob) + ", "
    cSql += GcSqlVal(" ") + ", "
    cSql += GcSqlVal(FWxFilial('AUDITORIA'))
    cSql += ")"

    // Executa inserção
    TCSqlExec(cSql)
    lRet := .T.
    ConOut("Anomaly registered: " + cTipo + " - " + cSeveridade)

Return lRet

/*/{Protheus.doc} GcAuditoriaFecharPeriodo
    Executa auditoria completa antes do fechamento do período.
    Detecta e registra anomalias:
    1. DESEQUILIBRIO_CONTABIL: débitos != créditos (tolerância 0.01)
    2. LAN_ORFAO: lançamentos sem relacionamento com cobrança
    3. COB_ORFAO: cobranças sem lançamento relacionado
    Workflow:
    1. Valida integridade (débitos == créditos)
    2. Busca lançamentos órfãos (LAN_ID sem entrada em RATEIO_DETALHE ou cobrança)
    3. Busca cobranças órfãs (COB sem lançamento relacionado)
    4. Registra cada anomalia encontrada em AUDITORIA
    5. Retorna contagem de anomalias críticas encontradas
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cExercicio, character, código do exercício (ex: "2025-01")
    @return nAnomalias, numeric, quantidade de anomalias críticas detectadas (0 = tudo OK)
    @example
        nCriticas := GcAuditoriaFecharPeriodo("2025-01")
        If nCriticas = 0
            ConOut("Auditoria OK — período pode ser fechado")
        Else
            ConOut("ERRO: " + cValToChar(nCriticas) + " anomalias críticas detectadas")
        EndIf
*/
User Function GcAuditoriaFecharPeriodo(cExercicio)
    Local nAnomalias := 0
    Local lValido := .F.
    Local aLanOrfaos := {}
    Local aCobOrfaos := {}
    Local nI := 0
    Local cDescricao := ""
    Local nRecnoLan := 0
    Local nRecnoCob := 0

    If Empty(cExercicio)
        ConOut("ERROR: Exercise code is required")
        Return 0
    EndIf

    ConOut("Starting audit for period: " + cExercicio)

    // 1. Valida integridade (débitos == créditos)
    lValido := GcValidarIntegridade(cExercicio)
    If !lValido
        cDescricao := "Desequilibrio contabil detectado no exercicio " + cExercicio + " — débitos != créditos"
        GcRegistrarAnomalia("DESEQUILIBRIO_CONTABIL", cDescricao, "CRITICA", cExercicio)
        nAnomalias := nAnomalias + 1
        ConOut("CRITICAL: " + cDescricao)
    EndIf

    // 2. Busca lançamentos órfãos (AUTOMATICO_RATEIO sem cobrança correspondente)
    // Lançamento de rateio deveriam ter uma cobrança relacionada em COB
    aLanOrfaos := TCSqlQuery("SELECT L.LAN_ID, L.R_E_C_N_O_, L.LAN_DESCR, L.LAN_VALOR FROM LANCAMENTOS L " +
        "WHERE L.LAN_EXERCICIO = " + GcSqlVal(cExercicio) + " AND L.LAN_TIPO = 'AUTOMATICO_RATEIO' AND L.D_E_L_E_T_ = ' ' AND L.FILIAL = " + GcSqlVal(FWxFilial('LANCAMENTOS')) + " " +
        "AND NOT EXISTS (SELECT 1 FROM COB WHERE COB_COMPET = " + GcSqlVal(cExercicio) + " AND COB_VALOR = L.LAN_VALOR AND D_E_L_E_T_ = ' ' AND FILIAL = " + GcSqlVal(FWxFilial('COB')) + ")")

    For nI := 1 To Len(aLanOrfaos)
        nRecnoLan := aLanOrfaos[nI]:R_E_C_N_O_
        cDescricao := "Orphan entry: LAN_ID=" + cValToChar(aLanOrfaos[nI]:LAN_ID) + ", desc=" + aLanOrfaos[nI]:LAN_DESCR + ", valor=" + cValToChar(aLanOrfaos[nI]:LAN_VALOR)
        GcRegistrarAnomalia("LAN_ORFAO", cDescricao, "AVISO", cExercicio, nRecnoLan)
        nAnomalias := nAnomalias + 1
        ConOut("WARNING: " + cDescricao)
    Next nI

    // 3. Busca cobranças órfãs (COB sem lançamento contábil relacionado)
    aCobOrfaos := TCSqlQuery("SELECT C.R_E_C_N_O_, C.COB_UNIDADE, C.COB_COMPET, C.COB_VALOR FROM COB C " +
        "WHERE C.COB_COMPET = " + GcSqlVal(cExercicio) + " AND C.D_E_L_E_T_ = ' ' AND C.FILIAL = " + GcSqlVal(FWxFilial('COB')) + " " +
        "AND NOT EXISTS (SELECT 1 FROM LANCAMENTOS WHERE LAN_EXERCICIO = C.COB_COMPET AND LAN_VALOR = C.COB_VALOR AND D_E_L_E_T_ = ' ' AND FILIAL = " + GcSqlVal(FWxFilial('LANCAMENTOS')) + ")")

    For nI := 1 To Len(aCobOrfaos)
        nRecnoCob := aCobOrfaos[nI]:R_E_C_N_O_
        cDescricao := "Orphan charge: COB_UNIDADE=" + aCobOrfaos[nI]:COB_UNIDADE + ", valor=" + cValToChar(aCobOrfaos[nI]:COB_VALOR)
        GcRegistrarAnomalia("COB_ORFAO", cDescricao, "AVISO", cExercicio, , nRecnoCob)
        nAnomalias := nAnomalias + 1
        ConOut("WARNING: " + cDescricao)
    Next nI

    ConOut("Audit complete: " + cValToChar(nAnomalias) + " anomalies detected (including " + cValToChar(nI) + " orphan charges)")

Return nAnomalias
