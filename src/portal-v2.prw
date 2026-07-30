// src/portal-v2.prw — Portal v2 snapshot generators (billing, notices, schedule)
#include "totvs.ch"
#include "contabil.prw"

/*/{Protheus.doc} GcGerarPortalExtratos
    Gera snapshot de extratos (cobranças) para um período específico.
    Workflow:
    1. Deleta extratos antigos para a competência
    2. Consulta tabela COB para a competência (ativa + soft-delete válidas)
    3. Para cada cobrança, insere em RPT_PORTAL_EXTRATOS:
       - REX_COMPETENCIA = COB_COMPET
       - REX_UNIDADE = COB_UNIDADE
       - REX_VALOR = COB_VALOR
       - REX_VENCIMENTO = COB_VENCTO (convertendo YYYYMMDD para DATE)
       - REX_STATUS = 'PAGO' se COB_DTPAG preenchido, senão 'PENDENTE'
       - REX_DATA_PAGAMENTO = COB_DTPAG (convertendo YYYYMMDD para DATE se preenchido)
    4. Retorna quantidade de registros inseridos
    Nota: Usa padrão de snapshot (DELETE + INSERT 100%) conforme tabelas RPT_* existentes.
    @type User Function
    @author GesCon
    @since 2026-07-30
    @param cCompetencia, character, competência no formato YYYY-MM (ex: "2025-01")
    @return nCount, numeric, quantidade de registros inseridos em RPT_PORTAL_EXTRATOS
    @example
        nTotal := U_GcGerarPortalExtratos("2025-01")
        If nTotal > 0
            ConOut("Snapshot gerado: " + cValToChar(nTotal) + " extratos")
        EndIf
*/
User Function GcGerarPortalExtratos(cCompetencia as character) as numeric
    Local nCount := 0 as numeric
    Local cSql := "" as character
    Local aExtratos := {} as array
    Local aCobrancas := {} as array
    Local i := 0 as numeric
    Local cVencimento := "" as character
    Local cDataPagamento := "" as character
    Local cStatus := "" as character

    // Validação de parâmetro
    If Empty(cCompetencia)
        ConOut("ERROR: Competência é obrigatória para GcGerarPortalExtratos")
        Return 0
    EndIf

    // Passo 1: Delete dos extratos antigos para esta competência (snapshot pattern)
    cSql := "DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_COMPETENCIA = " + GcSqlLit(cCompetencia)
    TCSqlExec(cSql)
    ConOut("Old extracts cleared for competência: " + cCompetencia)

    // Passo 2: Consulta COB table para a competência (ativa + soft-delete valid)
    cSql := "SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG "
    cSql += "FROM COB "
    cSql += "WHERE COB_COMPET = " + GcSqlLit(cCompetencia) + " "
    cSql += "AND D_E_L_E_T_ = ' '"
    aCobrancas := TCSqlQuery(cSql)

    If Len(aCobrancas) = 0
        ConOut("No billing records found for competência: " + cCompetencia)
        Return 0
    EndIf

    ConOut("Found " + cValToChar(Len(aCobrancas)) + " billing records for competência: " + cCompetencia)

    // Passo 3: Itera sobre cada cobrança e insere em RPT_PORTAL_EXTRATOS
    For i := 1 To Len(aCobrancas)
        // Valida vencimento (YYYYMMDD string -> converte para DATE)
        If Empty(aCobrancas[i]:COB_VENCTO)
            ConOut("WARNING: Skipping record with empty vencimento for unit " + aCobrancas[i]:COB_UNIDADE)
            Loop
        EndIf

        // Converte vencimento de YYYYMMDD para DATE
        cVencimento := GcConverterDataString(aCobrancas[i]:COB_VENCTO)

        // Define status: se COB_DTPAG está preenchido, status é PAGO, senão PENDENTE
        If !Empty(aCobrancas[i]:COB_DTPAG)
            cStatus := "PAGO"
            cDataPagamento := GcConverterDataString(aCobrancas[i]:COB_DTPAG)
        Else
            cStatus := "PENDENTE"
            cDataPagamento := "NULL"
        EndIf

        // Monta SQL de inserção em RPT_PORTAL_EXTRATOS
        cSql := "INSERT INTO RPT_PORTAL_EXTRATOS ("
        cSql += "REX_COMPETENCIA, REX_UNIDADE, REX_VALOR, REX_VENCIMENTO, REX_STATUS, REX_DATA_PAGAMENTO, D_E_L_E_T_"
        cSql += ") VALUES ("
        cSql += GcSqlLit(aCobrancas[i]:COB_COMPET) + ", "
        cSql += GcSqlLit(aCobrancas[i]:COB_UNIDADE) + ", "
        cSql += cValToChar(aCobrancas[i]:COB_VALOR) + ", "
        cSql += GcSqlLit(cVencimento) + ", "
        cSql += GcSqlLit(cStatus) + ", "
        If cDataPagamento = "NULL"
            cSql += "NULL"
        Else
            cSql += GcSqlLit(cDataPagamento)
        EndIf
        cSql += ", "
        cSql += GcSqlLit(" ")
        cSql += ")"

        // Executa inserção
        TCSqlExec(cSql)
        nCount := nCount + 1

        ConOut("Inserted extract: Unit=" + aCobrancas[i]:COB_UNIDADE + ", Value=" + cValToChar(aCobrancas[i]:COB_VALOR) + ", Status=" + cStatus)
    Next i

    ConOut("GcGerarPortalExtratos completed: " + cValToChar(nCount) + " records inserted")
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
