// src/portal-v2.prw — Portal v2 snapshot generators (billing, notices, schedule)
#include "totvs.ch"
#include "contabil.prw"
#include "portal.prw"

/*/{Protheus.doc} GcPortalCondominoV2
    Gateway do portal do condomínio v2. Autenticação via token + acesso filtrado
    a avisos, extratos e agenda da unidade vinculada.
    Workflow:
    1. Autentica token via GcAuthPortalToken (reusa logic v1)
    2. Extrai UNI_CODIGO da resposta do token
    3. Consulta AVISOS filtrado por unidade
    4. Consulta RPT_PORTAL_EXTRATOS filtrado por unidade
    5. Consulta RPT_PORTAL_AGENDA filtrado por unidade
    6. Retorna .T. se autenticado com sucesso, .F. caso contrário
    @type User Function
    @author GesCon
    @since 2026-07-30
    @param cToken, character, token UUID 36 chars
    @return lOk, logical, .T. se autenticado e dados carregados, .F. caso contrário
    @example
        If U_GcPortalCondominoV2("550e8400-e29b-41d4-a716-446655440000")
            ConOut("Autenticado com sucesso, dados carregados")
        Else
            ConOut("Falha na autenticação")
        EndIf
*/
User Function GcPortalCondominoV2(cToken as character) as logical
    Local lAutenticado := .F. as logical
    Local cUnitCode := "" as character
    Local aAvisos := {} as array
    Local aExtratos := {} as array
    Local aAgenda := {} as array
    Local cSql := "" as character

    // Validação de parâmetro
    If Empty(cToken)
        FWLogMsg("ERROR", "GcPortalCondominoV2: Token é obrigatório")
        Return .F.
    EndIf

    // Autentica token (reusa lógica v1 - marca como usado, salva em globals)
    lAutenticado := GcAuthPortalToken(cToken)
    If !lAutenticado
        FWLogMsg("ERROR", "GcPortalCondominoV2: Token inválido, expirado ou já utilizado")
        Return .F.
    EndIf

    // Extrai código da unidade das variáveis globais populadas por GcAuthPortalToken
    cUnitCode := g_cUniPortal
    If Empty(cUnitCode)
        FWLogMsg("ERROR", "GcPortalCondominoV2: Código de unidade não encontrado após autenticação")
        Return .F.
    EndIf

    FWLogMsg("INFO", "GcPortalCondominoV2: Token autenticado para unidade " + cUnitCode)

    // Consulta AVISOS filtrado por unidade
    cSql := "SELECT COUNT(*) as CNT FROM AVISOS WHERE AVI_UNIDADE = '" + GcSqlLit(cUnitCode) + "' AND D_E_L_E_T_ = ' '"
    aAvisos := TCSqlQuery(cSql)
    If Len(aAvisos) > 0
        FWLogMsg("INFO", "GcPortalCondominoV2: " + cValToChar(aAvisos[1]:CNT) + " avisos encontrados para unidade " + cUnitCode)
    EndIf

    // Consulta RPT_PORTAL_EXTRATOS filtrado por unidade
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_EXTRATOS WHERE REX_UNIDADE = '" + GcSqlLit(cUnitCode) + "' AND D_E_L_E_T_ = ' '"
    aExtratos := TCSqlQuery(cSql)
    If Len(aExtratos) > 0
        FWLogMsg("INFO", "GcPortalCondominoV2: " + cValToChar(aExtratos[1]:CNT) + " extratos encontrados para unidade " + cUnitCode)
    EndIf

    // Consulta RPT_PORTAL_AGENDA filtrado por unidade
    cSql := "SELECT COUNT(*) as CNT FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE = '" + GcSqlLit(cUnitCode) + "' AND D_E_L_E_T_ = ' '"
    aAgenda := TCSqlQuery(cSql)
    If Len(aAgenda) > 0
        FWLogMsg("INFO", "GcPortalCondominoV2: " + cValToChar(aAgenda[1]:CNT) + " agendas encontradas para unidade " + cUnitCode)
    EndIf

    FWLogMsg("INFO", "GcPortalCondominoV2: Autenticação e carregamento de dados completado com sucesso")
Return .T.

/*/{Protheus.doc} GcGerarPortalExtratos
    Gera snapshot de extratos (cobranças) para um período específico.
    Workflow:
    1. Valida competência (formato YYYY-MM)
    2. Inicia transação para consistência
    3. Deleta extratos antigos para a competência
    4. Consulta tabela COB para a competência (ativa + soft-delete válidas)
    5. Para cada cobrança, insere em RPT_PORTAL_EXTRATOS:
       - REX_COMPETENCIA = COB_COMPET
       - REX_UNIDADE = COB_UNIDADE
       - REX_VALOR = COB_VALOR
       - REX_VENCIMENTO = COB_VENCTO (convertendo YYYYMMDD para DATE)
       - REX_STATUS = 'PAGO' se COB_STATUS='PAGO'|'P', senão 'PENDENTE'
       - REX_DATA_PAGAMENTO = COB_DTPAG (convertendo YYYYMMDD para DATE se preenchido)
    6. Confirma transação ao sucesso, faz rollback se erro
    7. Retorna quantidade de registros inseridos, ou -1 se erro
    Nota: Usa padrão de snapshot (DELETE + INSERT 100%) conforme tabelas RPT_* existentes.
    @type User Function
    @author GesCon
    @since 2026-07-30
    @param cCompetencia, character, competência no formato YYYY-MM (ex: "2025-01")
    @return nCount, numeric, quantidade de registros inseridos (ou -1 se erro)
    @example
        nTotal := U_GcGerarPortalExtratos("2025-01")
        If nTotal >= 0
            FWLogMsg("INFO", "Snapshot gerado: " + cValToChar(nTotal) + " extratos")
        Else
            FWLogMsg("ERROR", "Erro ao gerar snapshot")
        EndIf
*/
User Function GcGerarPortalExtratos(cCompetencia as character) as numeric
    Local nCount := 0 as numeric
    Local cSql := "" as character
    Local aCobrancas := {} as array
    Local i := 0 as numeric
    Local cVencimento := "" as character
    Local cDataPagamento := "" as character
    Local cStatus := "" as character
    Local lTrans := .F. as logical

    // Validação de parâmetro
    If Empty(cCompetencia)
        FWLogMsg("ERROR", "Competência é obrigatória para GcGerarPortalExtratos")
        Return -1
    EndIf

    // Valida formato de competência (YYYY-MM)
    If Len(AllTrim(cCompetencia)) <> 7 .Or. SubStr(cCompetencia, 5, 1) <> "-"
        FWLogMsg("ERROR", "Formato de competência inválido: " + cCompetencia + " (esperado YYYY-MM)")
        Return -1
    EndIf

    // Inicia transação para consistência
    Begin Transaction
    lTrans := .T.

    Try
        // Passo 1: Delete dos extratos antigos para esta competência (snapshot pattern)
        cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + GcSqlLit(cCompetencia) + "'"
        FWExecStatement(cSql)
        FWLogMsg("INFO", "Old extracts cleared for competência: " + cCompetencia)

        // Passo 2: Consulta COB table para a competência (ativa + soft-delete valid)
        cSql := "SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG "
        cSql += "FROM COB "
        cSql += "WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "' "
        cSql += "AND D_E_L_E_T_ = ' '"
        aCobrancas := FWExecStatement(cSql)

        If Len(aCobrancas) = 0
            FWLogMsg("INFO", "No billing records found for competência: " + cCompetencia)
            Rollback()
            lTrans := .F.
            Return 0
        EndIf

        FWLogMsg("INFO", "Found " + cValToChar(Len(aCobrancas)) + " billing records for competência: " + cCompetencia)

        // Passo 3: Itera sobre cada cobrança e insere em RPT_PORTAL_EXTRATOS
        For i := 1 To Len(aCobrancas)
            // Valida vencimento (YYYYMMDD string -> converte para DATE)
            If Empty(aCobrancas[i]:COB_VENCTO)
                FWLogMsg("WARN", "Skipping record with empty vencimento for unit " + aCobrancas[i]:COB_UNIDADE)
                Loop
            EndIf

            // Converte vencimento de YYYYMMDD para DATE
            cVencimento := GcConverterDataString(aCobrancas[i]:COB_VENCTO)

            // Define status baseado em COB_STATUS: 'PAGO'|'P' -> 'PAGO', else -> 'PENDENTE'
            // Esta lógica mapeia o status de pagamento conforme definido na spec
            If aCobrancas[i]:COB_STATUS = "PAGO" .Or. aCobrancas[i]:COB_STATUS = "P"
                cStatus := "PAGO"
                // Se status é PAGO, converte data de pagamento se disponível
                If !Empty(aCobrancas[i]:COB_DTPAG)
                    cDataPagamento := GcConverterDataString(aCobrancas[i]:COB_DTPAG)
                Else
                    cDataPagamento := "NULL"
                EndIf
            Else
                cStatus := "PENDENTE"
                cDataPagamento := "NULL"
            EndIf

            // Monta SQL de inserção em RPT_PORTAL_EXTRATOS
            cSql := "INSERT INTO RPT_PORTAL_EXTRATOS ("
            cSql += "REX_COMPETENCIA, REX_UNIDADE, REX_VALOR, REX_VENCIMENTO, REX_STATUS, REX_DATA_PAGAMENTO, D_E_L_E_T_"
            cSql += ") VALUES ("
            cSql += "'" + GcSqlLit(cCompetencia) + "', "
            cSql += "'" + GcSqlLit(aCobrancas[i]:COB_UNIDADE) + "', "
            cSql += cValToChar(aCobrancas[i]:COB_VALOR) + ", "
            cSql += "'" + GcSqlLit(cVencimento) + "', "
            cSql += "'" + GcSqlLit(cStatus) + "', "
            If cDataPagamento = "NULL"
                cSql += "NULL"
            Else
                cSql += "'" + GcSqlLit(cDataPagamento) + "'"
            EndIf
            cSql += ", "
            cSql += "' '"
            cSql += ")"

            // Executa inserção com verificação de erro
            FWExecStatement(cSql)
            nCount := nCount + 1

            FWLogMsg("INFO", "Inserted extract: Unit=" + aCobrancas[i]:COB_UNIDADE + ", Value=" + cValToChar(aCobrancas[i]:COB_VALOR) + ", Status=" + cStatus)
        Next i

        // Commit da transação
        End Transaction
        lTrans := .F.
        FWLogMsg("INFO", "GcGerarPortalExtratos completed: " + cValToChar(nCount) + " records inserted")

    Catch oError
        FWLogMsg("ERROR", "GcGerarPortalExtratos failed: " + oError:Description)
        If lTrans
            Rollback()
        EndIf
        Return -1
    End Try

Return nCount

/*/{Protheus.doc} GcGerarPortalAgenda
    Gera snapshot de agenda (próximos vencimentos) para os próximos 12 meses.
    Workflow:
    1. Valida competência (formato YYYY-MM)
    2. Inicia transação para consistência
    3. Deleta agenda antiga (DELETE 100%, sem filtro de competência)
    4. Gera lista de próximas 12 competências (starting from cCompetencia)
    5. Para cada competência:
       - Consulta tabela COB para aquela competência (ativa + soft-delete válidas)
       - Para cada cobrança, insere em RPT_PORTAL_AGENDA:
         - REA_UNIDADE = COB_UNIDADE
         - REA_COMPETENCIA = COB_COMPET (a competência iterada)
         - REA_VENCIMENTO = COB_VENCTO (convertendo YYYYMMDD para DATE)
         - REA_VALOR = COB_VALOR
    6. Confirma transação ao sucesso, faz rollback se erro
    7. Retorna quantidade de registros inseridos, ou -1 se erro
    @type User Function
    @author GesCon
    @since 2026-07-30
    @param cCompetencia, character, competência inicial no formato YYYY-MM (ex: "2025-01")
    @return nCount, numeric, quantidade de registros inseridos (ou -1 se erro)
    @example
        nTotal := U_GcGerarPortalAgenda("2025-01")
        If nTotal >= 0
            FWLogMsg("INFO", "Agenda gerada: " + cValToChar(nTotal) + " vencimentos")
        Else
            FWLogMsg("ERROR", "Erro ao gerar agenda")
        EndIf
*/
User Function GcGerarPortalAgenda(cCompetencia as character) as numeric
    Local nCount := 0 as numeric
    Local cSql := "" as character
    Local aCobrancas := {} as array
    Local aMeses := {} as array
    Local i := 0 as numeric
    Local j := 0 as numeric
    Local cVencimento := "" as character
    Local cMesAtual := "" as character
    Local lTrans := .F. as logical

    // Validação de parâmetro
    If Empty(cCompetencia)
        FWLogMsg("ERROR", "Competência é obrigatória para GcGerarPortalAgenda")
        Return -1
    EndIf

    // Valida formato de competência (YYYY-MM)
    If Len(AllTrim(cCompetencia)) <> 7 .Or. SubStr(cCompetencia, 5, 1) <> "-"
        FWLogMsg("ERROR", "Formato de competência inválido: " + cCompetencia + " (esperado YYYY-MM)")
        Return -1
    EndIf

    // Inicia transação para consistência
    Begin Transaction
    lTrans := .T.

    Try
        // Passo 1: Delete da agenda antiga (snapshot pattern - delete 100%, sem filtro)
        cSql := "DELETE FROM RPT_PORTAL_AGENDA"
        FWExecStatement(cSql)
        FWLogMsg("INFO", "Old agenda cleared")

        // Passo 2: Gera lista de próximas 12 competências starting from cCompetencia
        aMeses := GcGerarProximos12Meses(cCompetencia)

        If Len(aMeses) = 0
            FWLogMsg("ERROR", "Failed to generate 12-month list from " + cCompetencia)
            Rollback()
            lTrans := .F.
            Return -1
        EndIf

        FWLogMsg("INFO", "Generated 12-month range starting from " + cCompetencia)

        // Passo 3: Itera sobre cada mês e consulta COB records
        For i := 1 To Len(aMeses)
            cMesAtual := aMeses[i]

            // Consulta COB table para este mês (ativa + soft-delete valid)
            cSql := "SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO "
            cSql += "FROM COB "
            cSql += "WHERE COB_COMPET = '" + GcSqlLit(cMesAtual) + "' "
            cSql += "AND D_E_L_E_T_ = ' '"
            aCobrancas := FWExecStatement(cSql)

            If Len(aCobrancas) = 0
                FWLogMsg("INFO", "No billing records found for competência: " + cMesAtual)
                Loop
            EndIf

            FWLogMsg("INFO", "Found " + cValToChar(Len(aCobrancas)) + " billing records for competência: " + cMesAtual)

            // Passo 4: Itera sobre cada cobrança e insere em RPT_PORTAL_AGENDA
            For j := 1 To Len(aCobrancas)
                // Valida vencimento (YYYYMMDD string -> converte para DATE)
                If Empty(aCobrancas[j]:COB_VENCTO)
                    FWLogMsg("WARN", "Skipping record with empty vencimento for unit " + aCobrancas[j]:COB_UNIDADE + ", competência " + cMesAtual)
                    Loop
                EndIf

                // Converte vencimento de YYYYMMDD para DATE
                cVencimento := GcConverterDataString(aCobrancas[j]:COB_VENCTO)

                // Monta SQL de inserção em RPT_PORTAL_AGENDA
                cSql := "INSERT INTO RPT_PORTAL_AGENDA ("
                cSql += "REA_UNIDADE, REA_COMPETENCIA, REA_VENCIMENTO, REA_VALOR, D_E_L_E_T_"
                cSql += ") VALUES ("
                cSql += "'" + GcSqlLit(aCobrancas[j]:COB_UNIDADE) + "', "
                cSql += "'" + GcSqlLit(cMesAtual) + "', "
                cSql += "'" + GcSqlLit(cVencimento) + "', "
                cSql += cValToChar(aCobrancas[j]:COB_VALOR) + ", "
                cSql += "' '"
                cSql += ")"

                // Executa inserção com verificação de erro
                FWExecStatement(cSql)
                nCount := nCount + 1

                FWLogMsg("INFO", "Inserted agenda: Unit=" + aCobrancas[j]:COB_UNIDADE + ", Competencia=" + cMesAtual + ", Value=" + cValToChar(aCobrancas[j]:COB_VALOR))
            Next j
        Next i

        // Commit da transação
        End Transaction
        lTrans := .F.
        FWLogMsg("INFO", "GcGerarPortalAgenda completed: " + cValToChar(nCount) + " records inserted")

    Catch oError
        FWLogMsg("ERROR", "GcGerarPortalAgenda failed: " + oError:Description)
        If lTrans
            Rollback()
        EndIf
        Return -1
    End Try

Return nCount

/*/{Protheus.doc} GcGerarProximos12Meses
    Gera array com os próximos 12 meses a partir de uma competência inicial.
    Formato de entrada: YYYY-MM (ex: "2025-01")
    Formato de saída: array com 12 elementos no formato YYYY-MM
    @type Static Function
    @author GesCon
    @since 2026-07-30
    @param cCompetencia, character, competência inicial (ex: "2025-01")
    @return aMeses, array, array com 12 elementos (meses consecutivos)
    @example
        aMeses := GcGerarProximos12Meses("2025-01")
        // retorna {"2025-01", "2025-02", ..., "2025-12"}
*/
Static Function GcGerarProximos12Meses(cCompetencia as character) as array
    Local aMeses := {} as array
    Local cAno := "" as character
    Local nMes := 0 as numeric
    Local i := 0 as numeric
    Local cNovoAno := "" as character
    Local nNovoMes := 0 as numeric

    // Extrai ano e mês
    cAno := SubStr(cCompetencia, 1, 4)
    nMes := Val(SubStr(cCompetencia, 6, 2))

    // Valida entrada
    If nMes < 1 .Or. nMes > 12
        Return {}
    EndIf

    // Gera 12 meses
    For i := 1 To 12
        // Calcula novo mês e ano
        nNovoMes := nMes + (i - 1)
        cNovoAno := cAno

        // Ajusta para anos seguintes se necessário
        While nNovoMes > 12
            nNovoMes := nNovoMes - 12
            cNovoAno := cValToChar(Val(cNovoAno) + 1)
        End While

        // Formata e adiciona ao array
        AAdd(aMeses, cNovoAno + "-" + PadL(cValToChar(nNovoMes), 2, "0"))
    Next i

Return aMeses

Static Function GcConverterDataString(cDataStr as character) as character
    Local cRet := "" as character

    If Empty(cDataStr) .Or. Len(AllTrim(cDataStr)) <> 8
        Return ""
    EndIf

    cRet := SubStr(cDataStr, 1, 4) + "-" + SubStr(cDataStr, 5, 2) + "-" + SubStr(cDataStr, 7, 2)

Return cRet

/*/{Protheus.doc} GcCriarAviso
    Cria um novo aviso no mural (tabela AVISOS).
    Workflow:
    1. Valida parâmetros de entrada (cTitulo e cCorpo obrigatórios)
    2. Inicia transação para consistência
    3. Insere novo registro em AVISOS com:
       - AVI_TITULO = cTitulo (sanitizado)
       - AVI_CORPO = cCorpo (sanitizado)
       - AVI_DATA_CRIACAO = datetime('now') (preenchido automaticamente no DB)
       - AVI_ATIVO = 1 (ativo por padrão)
       - D_E_L_E_T_ = ' ' (soft-delete válido)
    4. Confirma transação ao sucesso, faz rollback se erro
    5. Retorna .T. se sucesso, .F. se erro
    @type User Function
    @author GesCon
    @since 2026-07-30
    @param cTitulo, character, título do aviso (obrigatório)
    @param cCorpo, character, corpo/conteúdo do aviso (obrigatório)
    @return lSucesso, logical, .T. se aviso criado com sucesso, .F. se erro
    @example
        If U_GcCriarAviso("Manutenção Programada", "A manutenção ocorrerá no dia 15.")
            FWLogMsg("INFO", "Aviso criado com sucesso")
        Else
            FWLogMsg("ERROR", "Erro ao criar aviso")
        EndIf
*/
User Function GcCriarAviso(cTitulo as character, cCorpo as character) as logical
    Local cSql := "" as character
    Local lTrans := .F. as logical

    // Validação de parâmetros
    If Empty(cTitulo)
        FWLogMsg("ERROR", "Título é obrigatório para GcCriarAviso")
        Return .F.
    EndIf

    If Empty(cCorpo)
        FWLogMsg("ERROR", "Corpo é obrigatório para GcCriarAviso")
        Return .F.
    EndIf

    // Inicia transação para consistência
    Begin Transaction
    lTrans := .T.

    Try
        // Monta SQL de inserção em AVISOS
        cSql := "INSERT INTO AVISOS ("
        cSql += "AVI_TITULO, AVI_CORPO, AVI_ATIVO, D_E_L_E_T_"
        cSql += ") VALUES ("
        cSql += "'" + GcSqlLit(cTitulo) + "', "
        cSql += "'" + GcSqlLit(cCorpo) + "', "
        cSql += "1, "
        cSql += "' '"
        cSql += ")"

        // Executa inserção com verificação de erro
        FWExecStatement(cSql)

        // Commit da transação
        End Transaction
        lTrans := .F.
        FWLogMsg("INFO", "GcCriarAviso completed: Título=" + cTitulo)

    Catch oError
        FWLogMsg("ERROR", "GcCriarAviso failed: " + oError:Description)
        If lTrans
            Rollback()
        EndIf
        Return .F.
    End Try

Return .T.

/*/{Protheus.doc} GcArquivarAviso
    Arquiva um aviso (marca como inativo) na tabela AVISOS.
    Workflow:
    1. Valida parâmetro de entrada (nAvisoId obrigatório)
    2. Inicia transação para consistência
    3. Verifica se o aviso existe (AVI_ID = nAvisoId, D_E_L_E_T_ = ' ')
    4. Se não existe, retorna .F. (aviso não encontrado)
    5. Se existe, atualiza AVI_ATIVO = 0 para o registro
    6. Confirma transação ao sucesso, faz rollback se erro
    7. Retorna .T. se sucesso, .F. se erro
    @type User Function
    @author GesCon
    @since 2026-07-30
    @param nAvisoId, numeric, ID do aviso a arquivar (obrigatório)
    @return lSucesso, logical, .T. se aviso arquivado com sucesso, .F. se erro ou não encontrado
    @example
        If U_GcArquivarAviso(5)
            FWLogMsg("INFO", "Aviso 5 arquivado com sucesso")
        Else
            FWLogMsg("ERROR", "Aviso 5 não encontrado ou erro ao arquivar")
        EndIf
*/
User Function GcArquivarAviso(nAvisoId as numeric) as logical
    Local cSql := "" as character
    Local aResult := {} as array
    Local lTrans := .F. as logical

    // Validação de parâmetro
    If nAvisoId <= 0
        FWLogMsg("ERROR", "ID do aviso inválido para GcArquivarAviso: " + cValToChar(nAvisoId))
        Return .F.
    EndIf

    // Inicia transação para consistência
    Begin Transaction
    lTrans := .T.

    Try
        // Passo 1: Verifica se o aviso existe
        cSql := "SELECT AVI_ID FROM AVISOS WHERE AVI_ID = " + cValToChar(nAvisoId) + " AND D_E_L_E_T_ = ' '"
        aResult := FWExecStatement(cSql)

        If Len(aResult) = 0
            FWLogMsg("WARN", "Aviso não encontrado: AVI_ID=" + cValToChar(nAvisoId))
            Rollback()
            lTrans := .F.
            Return .F.
        EndIf

        // Passo 2: Atualiza AVI_ATIVO = 0
        cSql := "UPDATE AVISOS SET AVI_ATIVO = 0 WHERE AVI_ID = " + cValToChar(nAvisoId) + " AND D_E_L_E_T_ = ' '"
        FWExecStatement(cSql)

        // Commit da transação
        End Transaction
        lTrans := .F.
        FWLogMsg("INFO", "GcArquivarAviso completed: AVI_ID=" + cValToChar(nAvisoId))

    Catch oError
        FWLogMsg("ERROR", "GcArquivarAviso failed: " + oError:Description)
        If lTrans
            Rollback()
        EndIf
        Return .F.
    End Try

Return .T.
