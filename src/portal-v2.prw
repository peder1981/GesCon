// src/portal-v2.prw — Portal v2 snapshot generators (billing, notices, schedule)
#include "totvs.ch"
#include "contabil.prw"

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
        cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = '" + cCompetencia + "'"
        FWExecStatement(cSql)
        FWLogMsg("INFO", "Old extracts cleared for competência: " + cCompetencia)

        // Passo 2: Consulta COB table para a competência (ativa + soft-delete valid)
        cSql := "SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG "
        cSql += "FROM COB "
        cSql += "WHERE COB_COMPET = '" + cCompetencia + "' "
        cSql += "AND D_E_L_E_T_ = ' '"
        aCobrancas := FWExecStatement(cSql)

        If Len(aCobrancas) = 0
            FWLogMsg("INFO", "No billing records found for competência: " + cCompetencia)
            End Transaction
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
            cSql += "'" + cCompetencia + "', "
            cSql += "'" + aCobrancas[i]:COB_UNIDADE + "', "
            cSql += cValToChar(aCobrancas[i]:COB_VALOR) + ", "
            cSql += "'" + cVencimento + "', "
            cSql += "'" + cStatus + "', "
            If cDataPagamento = "NULL"
                cSql += "NULL"
            Else
                cSql += "'" + cDataPagamento + "'"
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

/*/{Protheus.doc} GcConverterDataString
    Converte string de data YYYYMMDD para formato DATE do SQLite.
    Retorna string no formato que SQLite aceita para DATE (YYYY-MM-DD).
    @type Static Function
    @author GesCon
    @since 2026-07-30
    @param cDataStr, character, data em formato YYYYMMDD (ex: "20250215")
    @return cRet, character, data formatada para SQLite (ex: "2025-02-15")
    @example
        cData := GcConverterDataString("20250215")  // retorna "2025-02-15"
*/
Static Function GcConverterDataString(cDataStr as character) as character
    Local cRet := "" as character

    If Empty(cDataStr) .Or. Len(AllTrim(cDataStr)) <> 8
        Return ""
    EndIf

    cRet := SubStr(cDataStr, 1, 4) + "-" + SubStr(cDataStr, 5, 2) + "-" + SubStr(cDataStr, 7, 2)

Return cRet
