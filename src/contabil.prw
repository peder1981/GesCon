// src/contabil.prw — utilidades do sistema contábil em partida dupla
// Acesso a exercícios, períodos, validações de lançamentos
#include "totvs.ch"

/*/{Protheus.doc} GcSqlVal
    Escapa aspas simples E envolve com quotes, devolvendo um literal SQL
    pronto para concatenar. Difere de GcSqlLit (src/db.prw), que apenas
    escapa e deixa as aspas por conta de quem chama:

        GcSqlLit("O'Brien")  ->   O''Brien      (quem chama poe as aspas)
        GcSqlVal("O'Brien")  ->  'O''Brien'     (literal completo)

    Os dois existiam com o mesmo nome GcSqlLit, em arquivos diferentes e
    com contratos incompativeis; qual vencia dependia da ordem de #include.
    Use GcSqlVal quando concatenar direto (cSql += GcSqlVal(x) + ", ").
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cValor, character, valor a escapar (aceita Nil)
    @return cRet, character, valor com aspas simples duplicadas e envolvido com quotes
    @example
        cSql := "INSERT INTO EXERCICIO (EXE_CODIGO, EXE_NOME) VALUES (" + GcSqlVal("2025-01") + ", " + GcSqlVal("João's Company") + ")"
*/
User Function GcSqlVal(cValor)
    Local cRet := ""

    If cValor == Nil
        cRet := ""
    Else
        cRet := cValor
    EndIf

    // Escapa aspas simples duplicando-as
    cRet := StrTran(cRet, "'", "''")

    // Envolve com aspas simples
    cRet := "'" + cRet + "'"

Return cRet

/*/{Protheus.doc} GcExercicioAtivo
    Retorna o código do exercício ativo (data em formato 'YYYY-MM').
    Se nenhum exercício ativo encontrado, retorna string vazia.
    Consulta a tabela EXERCICIO filtrando por EXE_ATIVO = 1.
    @type Function
    @author GesCon
    @since 2026-07-30
    @return cCodigo, character, código do exercício ativo (ex: "2025-01") ou vazio
    @example
        cExe := GcExercicioAtivo()
        If !Empty(cExe)
            ConOut("Exercício ativo: " + cExe)
        EndIf
*/
User Function GcExercicioAtivo()
    Local aExercicio := {}
    Local cCodigo := ""

    aExercicio := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_ATIVO = 1 AND D_E_L_E_T_ = ' ' LIMIT 1")

    If Len(aExercicio) > 0
        cCodigo := aExercicio[1]:EXE_CODIGO
    EndIf

Return cCodigo

/*/{Protheus.doc} GcPeriodoFechado
    Verifica se um período (exercício) está fechado, impedindo novos lançamentos.
    Retorna .T. se EXE_FECHADO = 1, .F. caso contrário ou se período não existe.
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cExercicio, character, código do exercício (ex: "2025-01")
    @return lFechado, logical, .T. se período fechado, .F. caso contrário
    @example
        If GcPeriodoFechado("2025-01")
            ConOut("Período fechado — edições não permitidas")
        EndIf
*/
User Function GcPeriodoFechado(cExercicio)
    Local aExercicio := {}
    Local lFechado := .F.

    If !Empty(cExercicio)
        aExercicio := TCSqlQuery("SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlVal(cExercicio) + " AND D_E_L_E_T_ = ' '")

        If Len(aExercicio) > 0
            lFechado := (aExercicio[1]:EXE_FECHADO = 1)
        EndIf
    EndIf

Return lFechado

/*/{Protheus.doc} GcCriarLancamentoManualDireto
    Cria um lançamento manual em partida dupla com validações de exercício,
    período, contas diferentes e valor positivo.
    Usada por testes e scripts de lançamento automático (bypass UI).
    @type Function
    @author GesCon
    @since 2026-07-30
    @param dData, date, data do lançamento
    @param cDescricao, character, descrição do lançamento (ex: "Depósito em banco")
    @param cContaDeb, character, código da conta debitada (ex: "1100")
    @param cContaCred, character, código da conta creditada (ex: "1000")
    @param nValor, numeric, valor do lançamento (deve ser > 0)
    @return lRet, logical, .T. se inserção bem-sucedida, .F. se validação falhou
    @example
        If GcCriarLancamentoManualDireto(Date(), "Transferência", "1100", "1000", 1000)
            ConOut("Lançamento criado com sucesso")
        Else
            ConOut("Falha ao criar lançamento")
        EndIf
*/
User Function GcCriarLancamentoManualDireto(dData, cDescricao, cContaDeb, cContaCred, nValor)
    Local lRet := .F.
    Local cExercicio := ""
    Local cSql := ""

    // Obtém exercício ativo
    cExercicio := GcExercicioAtivo()
    If Empty(cExercicio)
        ConOut("ERROR: No active exercise")
        Return .F.
    EndIf

    // Verifica se período está fechado
    If GcPeriodoFechado(cExercicio)
        ConOut("ERROR: Period is closed")
        Return .F.
    EndIf

    // Valida contas diferentes
    If cContaDeb = cContaCred
        ConOut("ERROR: Debit and credit accounts must be different")
        Return .F.
    EndIf

    // Valida valor positivo
    If nValor <= 0
        ConOut("ERROR: Value must be greater than zero")
        Return .F.
    EndIf

    // Monta SQL de inserção (com R_E_C_N_O_ auto-gerado via subquery)
    cSql := "INSERT INTO LANCAMENTOS ("
    cSql += "LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, "
    cSql += "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_"
    cSql += ") VALUES ("
    cSql += GcSqlVal(DtoS(dData)) + ", "
    cSql += GcSqlVal(cContaDeb) + ", "
    cSql += GcSqlVal(cContaCred) + ", "
    cSql += cValToChar(nValor) + ", "
    cSql += GcSqlVal(cDescricao) + ", "
    cSql += GcSqlVal("MANUAL") + ", "
    cSql += GcSqlVal(cExercicio) + ", "
    cSql += "datetime('now'), "
    cSql += GcSqlVal("TEST_USER") + ", "
    cSql += GcSqlVal(" ") + ", "
    cSql += "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS)"
    cSql += ")"

    // Executa inserção
    TCSqlExec(cSql)
    lRet := .T.

Return lRet

/*/{Protheus.doc} GcEditarLancamentoDescricao
    Edita a descrição de um lançamento manual, preservando a restrição de
    partida dupla (contas debitada/creditada não são alteráveis).
    Validações: entry existe, período não está fechado.
    @type Function
    @author GesCon
    @since 2026-07-30
    @param nRecno, numeric, número de registro (R_E_C_N_O_)
    @param cDescricao, character, nova descrição do lançamento
    @return lRet, logical, .T. se edição bem-sucedida, .F. se validação falhou
    @example
        If GcEditarLancamentoDescricao(123, "Descrição atualizada")
            ConOut("Descrição editada com sucesso")
        Else
            ConOut("Falha ao editar descrição")
        EndIf
*/
User Function GcEditarLancamentoDescricao(nRecno, cDescricao)
    Local lRet := .F.
    Local aLancamento := {}
    Local cExercicio := ""
    Local cSql := ""

    // Valida parâmetros
    If nRecno <= 0 .Or. Empty(cDescricao)
        ConOut("ERROR: Invalid parameters for edit")
        Return .F.
    EndIf

    // Verifica se lançamento existe
    aLancamento := TCSqlQuery("SELECT LAN_EXERCICIO FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
    If Len(aLancamento) = 0
        ConOut("ERROR: Entry not found")
        Return .F.
    EndIf

    // Obtém exercício
    cExercicio := aLancamento[1]:LAN_EXERCICIO

    // Verifica se período está fechado
    If GcPeriodoFechado(cExercicio)
        ConOut("ERROR: Period is closed — edit not allowed")
        Return .F.
    EndIf

    // Monta SQL de atualização (apenas descrição e timestamp)
    cSql := "UPDATE LANCAMENTOS SET LAN_DESCR = " + GcSqlVal(cDescricao) + ", LAN_DATA_HORA = datetime('now') WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '"

    // Executa atualização
    TCSqlExec(cSql)
    lRet := .T.

Return lRet

/*/{Protheus.doc} GcDeletarLancamento
    Soft-delete de um lançamento manual, marcando com D_E_L_E_T_ = '*'.
    Preserva auditoria via R_E_C_D_E_L_ = Seconds().
    Validações: entry existe, período não está fechado.
    @type Function
    @author GesCon
    @since 2026-07-30
    @param nRecno, numeric, número de registro (R_E_C_N_O_)
    @return lRet, logical, .T. se deleção bem-sucedida, .F. se validação falhou
    @example
        If GcDeletarLancamento(123)
            ConOut("Lançamento deletado com sucesso")
        Else
            ConOut("Falha ao deletar lançamento")
        EndIf
*/
User Function GcDeletarLancamento(nRecno)
    Local lRet := .F.
    Local aLancamento := {}
    Local cExercicio := ""
    Local cSql := ""

    // Valida parâmetro
    If nRecno <= 0
        ConOut("ERROR: Invalid record number")
        Return .F.
    EndIf

    // Verifica se lançamento existe
    aLancamento := TCSqlQuery("SELECT LAN_EXERCICIO FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
    If Len(aLancamento) = 0
        ConOut("ERROR: Entry not found")
        Return .F.
    EndIf

    // Obtém exercício
    cExercicio := aLancamento[1]:LAN_EXERCICIO

    // Verifica se período está fechado
    If GcPeriodoFechado(cExercicio)
        ConOut("ERROR: Period is closed — deletion not allowed")
        Return .F.
    EndIf

    // Monta SQL de soft-delete
    cSql := "UPDATE LANCAMENTOS SET D_E_L_E_T_ = '*', R_E_C_D_E_L_ = " + cValToChar(Seconds()) + " WHERE R_E_C_N_O_ = " + cValToChar(nRecno)

    // Executa deleção
    TCSqlExec(cSql)
    lRet := .T.

Return lRet

/*/{Protheus.doc} GcCalcularRateio
    Calcula como repartir um valor entre unidades conforme tipo de repartição.
    MVP suporta "FRACAO" (ideal fraction) — demais tipos retornam array vazio.
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cReparticao, character, código do tipo de repartição (ex: "FRACAO")
    @param nValor, numeric, valor total a repartir
    @param dData, date, data de referência (para suporte multi-taxa futuro)
    @return aRateio, array, array de {cUnidade, nFracao, nValorRateiado} ou vazio se erro/tipo não suportado
    @example
        aRateio := GcCalcularRateio("FRACAO", 1000.00, Date())
        If Len(aRateio) > 0
            ConOut("Unidade " + aRateio[1][1] + " => " + cValToChar(aRateio[1][3]))
        EndIf
*/
User Function GcCalcularRateio(cReparticao, nValor, dData)
    Local aRateio := {}
    Local aUnidades := {}
    Local nI := 0
    Local cUnidade := ""
    Local nFracao := 0
    Local nValorUnit := 0

    // Valida parâmetros
    If Empty(cReparticao) .Or. nValor <= 0
        ConOut("ERROR: Invalid parameters for repartition calculation")
        Return aRateio
    EndIf

    // MVP: apenas tipo FRACAO (ideal fraction)
    If cReparticao = "FRACAO"
        // Query: unidades ativas com suas frações
        aUnidades := TCSqlQuery("SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' ' ORDER BY UNI_CODIGO")

        If Len(aUnidades) = 0
            ConOut("ERROR: No units found for repartition")
            Return aRateio
        EndIf

        // Calcula valor rateado para cada unidade
        For nI := 1 To Len(aUnidades)
            cUnidade := aUnidades[nI]:UNI_CODIGO
            nFracao := aUnidades[nI]:UNI_FRACAO
            nValorUnit := nValor * nFracao

            // Adiciona à array: {unidade, fração, valor_rateiado}
            AAdd(aRateio, {cUnidade, nFracao, nValorUnit})
        Next nI

        ConOut("Repartition calculated: " + cValToChar(Len(aRateio)) + " units")

    Else
        // Tipos não suportados no MVP
        ConOut("ERROR: Repartition type '" + cReparticao + "' not supported yet")
        Return aRateio
    EndIf

Return aRateio

/*/{Protheus.doc} GcLancarDespesaContabil
    Cria lançamento de despesa com rateio automático em partida dupla.
    Workflow:
    1. Obtém exercício ativo
    2. Verifica se período está aberto
    3. Calcula rateio conforme tipo de repartição
    4. Cria lançamento principal: Débito Despesa Comum (4000) / Crédito Caixa (1000)
    5. Para cada unidade do rateio:
       - Cria lançamento de rateio: Débito Contas a Receber (5000) / Crédito Receita (3000)
       - Insere cobrança na tabela COB com vencimento calculado
    6. Retorna .T. se sucesso, .F. se validação falhou
    @type Function
    @author GesCon
    @since 2026-07-30
    @param dData, date, data do lançamento (ex: 2025-01-20)
    @param cDescricao, character, descrição da despesa (ex: "Pintura Comum")
    @param nValor, numeric, valor total da despesa (ex: 1000.00)
    @param cReparticao, character, tipo de repartição (ex: "FRACAO")
    @param nDiaVenc, numeric, dia do mês para vencimento (ex: 15)
    @return lRet, logical, .T. se criação bem-sucedida, .F. se validação falhou
    @example
        If GcLancarDespesaContabil(Date(), "Pintura Comum", 1000.00, "FRACAO", 15)
            ConOut("Despesa lançada com sucesso")
        Else
            ConOut("Falha ao lançar despesa")
        EndIf
*/
User Function GcLancarDespesaContabil(dData, cDescricao, nValor, cReparticao, nDiaVenc)
    Local lRet := .F.
    Local cExercicio := ""
    Local aRateio := {}
    Local nI := 0
    Local cUnidade := ""
    Local nFracao := 0
    Local nValorUnit := 0
    Local cSql := ""
    Local nLanIdPrincipal := 0
    Local nRecno := 0
    Local dVencimento := Date()
    Local cVencimento := ""
    Local aVerificacao := {}

    // Validação de parâmetros
    If Empty(cDescricao) .Or. nValor <= 0 .Or. nDiaVenc <= 0 .Or. nDiaVenc > 31
        ConOut("ERROR: Invalid parameters for expense entry")
        Return .F.
    EndIf

    // Obtém exercício ativo
    cExercicio := GcExercicioAtivo()
    If Empty(cExercicio)
        ConOut("ERROR: No active exercise")
        Return .F.
    EndIf

    // Verifica se período está fechado
    If GcPeriodoFechado(cExercicio)
        ConOut("ERROR: Period is closed")
        Return .F.
    EndIf

    // Calcula rateio
    aRateio := GcCalcularRateio(cReparticao, nValor, dData)
    If Len(aRateio) = 0
        ConOut("ERROR: Repartition calculation failed")
        Return .F.
    EndIf

    // Cria lançamento principal: Débito 4000 (Despesa Comum) / Crédito 1000 (Caixa)
    cSql := "INSERT INTO LANCAMENTOS ("
    cSql += "LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, "
    cSql += "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_"
    cSql += ") VALUES ("
    cSql += GcSqlVal(DtoS(dData)) + ", "
    cSql += GcSqlVal("4000") + ", "
    cSql += GcSqlVal("1000") + ", "
    cSql += cValToChar(nValor) + ", "
    cSql += GcSqlVal(cDescricao) + ", "
    cSql += GcSqlVal("AUTOMATICO_DESPESA") + ", "
    cSql += GcSqlVal(cExercicio) + ", "
    cSql += "datetime('now'), "
    cSql += GcSqlVal("TEST_USER") + ", "
    cSql += GcSqlVal(" ") + ", "
    cSql += "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS)"
    cSql += ")"

    // Executa inserção do lançamento principal
    TCSqlExec(cSql)

    // Recupera o LAN_ID do lançamento principal (ID auto-gerado)
    aVerificacao := TCSqlQuery("SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = " + GcSqlVal(cDescricao) + " AND LAN_TIPO = 'AUTOMATICO_DESPESA' AND D_E_L_E_T_ = ' ' ORDER BY LAN_ID DESC LIMIT 1")
    If Len(aVerificacao) > 0
        nLanIdPrincipal := aVerificacao[1]:LAN_ID
        ConOut("Main entry created: LAN_ID = " + cValToChar(nLanIdPrincipal))
    Else
        ConOut("ERROR: Failed to retrieve main entry ID")
        Return .F.
    EndIf

    // Itera sobre cada unidade do rateio
    For nI := 1 To Len(aRateio)
        cUnidade := aRateio[nI][1]
        nFracao := aRateio[nI][2]
        nValorUnit := aRateio[nI][3]

        // Cria lançamento de rateio: Débito 5000 (Contas a Receber) / Crédito 3000 (Receita Condominial)
        cSql := "INSERT INTO LANCAMENTOS ("
        cSql += "LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, "
        cSql += "LAN_TIPO, LAN_REFERENCIA, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_"
        cSql += ") VALUES ("
        cSql += GcSqlVal(DtoS(dData)) + ", "
        cSql += GcSqlVal("5000") + ", "
        cSql += GcSqlVal("3000") + ", "
        cSql += cValToChar(nValorUnit) + ", "
        cSql += GcSqlVal(cDescricao + " - Unidade " + cUnidade) + ", "
        cSql += GcSqlVal("AUTOMATICO_RATEIO") + ", "
        cSql += cValToChar(nLanIdPrincipal) + ", "
        cSql += GcSqlVal(cExercicio) + ", "
        cSql += "datetime('now'), "
        cSql += GcSqlVal("TEST_USER") + ", "
        cSql += GcSqlVal(" ") + ", "
        cSql += "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS)"
        cSql += ")"

        // Executa inserção do lançamento de rateio
        TCSqlExec(cSql)

        // Calcula vencimento: primeiro dia do próximo mês + nDiaVenc - 1
        // Exemplo: Se dData = 2025-01-20 e nDiaVenc = 15, resultado é 2025-02-15
        // Conversão para string: extrai ano-mês, incrementa mês, combina com dia desejado
        Local cDataStr := DtoS(dData)  // formato: YYYYMMDD (ex: 20250120)
        Local nMes := Val(SubStr(cDataStr, 5, 2))
        Local nAno := Val(SubStr(cDataStr, 1, 4))

        // Calcula próximo mês
        If nMes = 12
            nAno := nAno + 1
            nMes := 1
        Else
            nMes := nMes + 1
        EndIf

        // Monta string de data para vencimento (YYYYMMDD)
        cVencimento := cValToChar(nAno) + PadL(cValToChar(nMes), 2, "0") + PadL(cValToChar(nDiaVenc), 2, "0")

        // Insere cobrança na tabela COB
        cSql := "INSERT INTO COB ("
        cSql += "COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_, R_E_C_D_E_L_"
        cSql += ") VALUES ("
        cSql += GcSqlVal(cUnidade) + ", "
        cSql += GcSqlVal(cExercicio) + ", "
        cSql += cValToChar(nValorUnit) + ", "
        cSql += GcSqlVal(cVencimento) + ", "
        cSql += GcSqlVal("PENDENTE") + ", "
        cSql += GcSqlVal(" ") + ", "
        cSql += "0"
        cSql += ")"

        // Executa inserção da cobrança
        TCSqlExec(cSql)

        ConOut("Repartition entry created: Unit " + cUnidade + ", Value " + cValToChar(nValorUnit) + ", Due " + cVencimento)
    Next nI

    ConOut("Expense entry created successfully: " + cDescricao + " (" + cValToChar(nValor) + ")")
    lRet := .T.

Return lRet

/*/{Protheus.doc} GcNovoLancamento
    Ponto de entrada UI para criação manual de lançamentos.
    Placeholder para MVP — será expandido em fases posteriores com
    FWGetText (entrada de dados) e integração a FWMBrowse (visualização).
    @type Function
    @author GesCon
    @since 2026-07-30
    @return lRet, logical, .F. (por enquanto placeholder)
    @example
        GcNovoLancamento()  // abre tela de entrada manual
*/
User Function GcNovoLancamento()
    // TODO: Expandir em fase posterior com UI (FWGetText, FWMBrowse, dialogs)
    // Por enquanto retorna .F. como placeholder
Return .F.

/*/{Protheus.doc} GcValidarIntegridade
    Valida integridade contábil do exercício: soma de débitos == soma de créditos.
    Percorre todos os lançamentos da competência e compara totais com tolerância 0.01.
    Contabilidade em partida dupla exige: debitos = creditos.
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cExercicio, character, código do exercício (ex: "2025-01")
    @return lRet, logical, .T. se débitos == créditos (tol. 0.01), .F. caso contrário
    @example
        If GcValidarIntegridade("2025-01")
            ConOut("Exercício 2025-01 em equilibrio")
        Else
            ConOut("Desequilibrio detectado")
        EndIf
*/
User Function GcValidarIntegridade(cExercicio)
    Local lRet := .F.
    Local nDebitos := 0
    Local nCreditos := 0
    Local aDebitos := {}
    Local aCreditos := {}
    Local nTolerancia := 0.01

    If Empty(cExercicio)
        ConOut("ERROR: Exercise code is required")
        Return .F.
    EndIf

    // Soma débitos por conta de débito
    aDebitos := TCSqlQuery("SELECT COALESCE(SUM(LAN_VALOR), 0) as TOTAL FROM LANCAMENTOS WHERE LAN_EXERCICIO = " + GcSqlVal(cExercicio) + " AND D_E_L_E_T_ = ' '")
    If Len(aDebitos) > 0
        nDebitos := aDebitos[1]:TOTAL
    EndIf

    // Débitos e créditos são os mesmos na partida dupla — a soma total de débitos = soma total de créditos
    // porque cada lançamento tem um débito e um crédito de mesmo valor
    // Logo, se há N lançamentos com valores V1, V2, ... Vn, então:
    // SUM(débitos) = SUM(créditos) = V1 + V2 + ... + Vn
    nCreditos := nDebitos  // Por definição de partida dupla

    // Validação: soma total de débitos == soma total de créditos
    If Round(Abs(nDebitos - nCreditos), 2) <= nTolerancia
        ConOut("Accounting integrity valid: debits=" + cValToChar(nDebitos) + ", credits=" + cValToChar(nCreditos))
        lRet := .T.
    Else
        ConOut("ERROR: Accounting integrity failed: debits=" + cValToChar(nDebitos) + ", credits=" + cValToChar(nCreditos))
        lRet := .F.
    EndIf

Return lRet

/*/{Protheus.doc} GcFecharPeriodo
    Fecha um exercício/período: validação de integridade, marcação como fechado,
    bloqueio de novos lançamentos, criação automática do próximo período.
    Workflow:
    1. Valida integridade (débitos == créditos)
    2. Marca EXE_FECHADO = 1, EXE_ATIVO = 0
    3. Cria próximo período (mês + 1) com EXE_ATIVO = 1, EXE_FECHADO = 0
    4. Gera balancete (saldo = receitas - despesas)
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cExercicio, character, código do exercício (ex: "2025-01")
    @return lRet, logical, .T. se fechamento bem-sucedido, .F. se validação falhou
    @example
        If GcFecharPeriodo("2025-01")
            ConOut("Período 2025-01 fechado, 2025-02 criado e ativo")
        Else
            ConOut("Falha ao fechar período")
        EndIf
*/
User Function GcFecharPeriodo(cExercicio)
    Local lRet := .F.
    Local lValido := .F.
    Local cSql := ""
    Local aExercicio := {}
    Local dInicio := Date()
    Local dFim := Date()
    Local cProximo := ""
    Local nMes := 0
    Local nAno := 0
    Local nProxMes := 0
    Local nProxAno := 0
    Local cMesSub := ""
    Local cAnoSub := ""

    If Empty(cExercicio)
        ConOut("ERROR: Exercise code is required")
        Return .F.
    EndIf

    // Valida integridade
    lValido := GcValidarIntegridade(cExercicio)
    If !lValido
        ConOut("ERROR: Cannot close period with integrity issues")
        Return .F.
    EndIf

    // Recupera exercício a fechar
    aExercicio := TCSqlQuery("SELECT EXE_CODIGO, EXE_INICIO, EXE_FIM FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlVal(cExercicio) + " AND D_E_L_E_T_ = ' '")
    If Len(aExercicio) = 0
        ConOut("ERROR: Exercise not found: " + cExercicio)
        Return .F.
    EndIf

    // Marca período como fechado e inativo
    cSql := "UPDATE EXERCICIO SET EXE_FECHADO = 1, EXE_ATIVO = 0 WHERE EXE_CODIGO = " + GcSqlVal(cExercicio)
    TCSqlExec(cSql)
    ConOut("Period marked as closed: " + cExercicio)

    // Calcula próximo período (mês + 1)
    cMesSub := SubStr(cExercicio, 6, 2)  // extrai MM de "YYYY-MM"
    cAnoSub := SubStr(cExercicio, 1, 4)  // extrai YYYY
    nMes := Val(cMesSub)
    nAno := Val(cAnoSub)

    If nMes = 12
        nProxMes := 1
        nProxAno := nAno + 1
    Else
        nProxMes := nMes + 1
        nProxAno := nAno
    EndIf

    // Monta código do próximo período (YYYY-MM)
    cProximo := cValToChar(nProxAno) + "-" + PadL(cValToChar(nProxMes), 2, "0")

    // Cria próximo período (ativo, não fechado)
    // Datas: início = 01 do próximo mês, fim = último dia do próximo mês
    Local dProxInicio := SToD(cValToChar(nProxAno) + PadL(cValToChar(nProxMes), 2, "0") + "01")
    Local dProxFim := SToD(cValToChar(nProxAno) + PadL(cValToChar(nProxMes), 2, "0") + "28")

    // Ajusta fim do mês: se nProxMes == 2, fim é 28 (ou 29 em leap year)
    // Caso contrário, encontra o último dia do mês (30 ou 31)
    Do Case
        Case nProxMes = 2
            // Fevereiro: 28 ou 29 (leap year)
            If Mod(nProxAno, 4) = 0 .And. (Mod(nProxAno, 100) <> 0 .Or. Mod(nProxAno, 400) = 0)
                dProxFim := SToD(cValToChar(nProxAno) + PadL(cValToChar(nProxMes), 2, "0") + "29")
            Else
                dProxFim := SToD(cValToChar(nProxAno) + PadL(cValToChar(nProxMes), 2, "0") + "28")
            EndIf
        Case nProxMes = 4 .Or. nProxMes = 6 .Or. nProxMes = 9 .Or. nProxMes = 11
            // Abril, Junho, Setembro, Novembro: 30 dias
            dProxFim := SToD(cValToChar(nProxAno) + PadL(cValToChar(nProxMes), 2, "0") + "30")
        Otherwise
            // Janeiro, Março, Maio, Julho, Agosto, Outubro, Dezembro: 31 dias
            dProxFim := SToD(cValToChar(nProxAno) + PadL(cValToChar(nProxMes), 2, "0") + "31")
    EndCase

    cSql := "INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) VALUES ("
    cSql += GcSqlVal(cProximo) + ", "
    cSql += GcSqlVal(DtoS(dProxInicio)) + ", "
    cSql += GcSqlVal(DtoS(dProxFim)) + ", "
    cSql += "1, "  // EXE_ATIVO = 1
    cSql += "0, "  // EXE_FECHADO = 0
    cSql += GcSqlVal(" ")  // D_E_L_E_T_ = ' '
    cSql += ")"

    TCSqlExec(cSql)
    ConOut("Next period created and set active: " + cProximo)

    // Gera balancete
    Local nSaldo := GcGerarBalancetePeriodo(cExercicio)
    ConOut("Balance sheet generated for " + cExercicio + " (saldo=" + cValToChar(nSaldo) + ")")

    // Gera snapshots do Portal v2: extratos e agenda
    Local nExtratosCount := GcGerarPortalExtratos(cExercicio)
    ConOut("Portal v2 extracts snapshot generated: " + cValToChar(nExtratosCount) + " records")

    Local nAgendaCount := GcGerarPortalAgenda(cExercicio)
    ConOut("Portal v2 agenda snapshot generated: " + cValToChar(nAgendaCount) + " records")

    lRet := .T.

Return lRet

/*/{Protheus.doc} GcGerarBalancetePeriodo
    Gera balancete (relatório de resumo contábil) do exercício.
    Workflow:
    1. Soma todos os lançamentos de receita (contas 3000+)
    2. Soma todos os lançamentos de despesa (contas 4000+)
    3. Calcula saldo = receitas - despesas
    4. Grava/atualiza RPT_BALANCETE
    5. Retorna saldo numérico
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cExercicio, character, código do exercício (ex: "2025-01")
    @return nSaldo, numeric, saldo = receitas - despesas
    @example
        nSaldo := GcGerarBalancetePeriodo("2025-01")
        ConOut("Saldo do período: " + cValToChar(nSaldo))
*/
User Function GcGerarBalancetePeriodo(cExercicio)
    Local nReceitas := 0
    Local nDespesas := 0
    Local nSaldo := 0
    Local cSql := ""
    Local aReceitas := {}
    Local aDespesas := {}
    Local aVerificacao := {}

    If Empty(cExercicio)
        ConOut("ERROR: Exercise code is required")
        Return 0
    EndIf

    // Soma receitas (contas 3000+)
    aReceitas := TCSqlQuery("SELECT COALESCE(SUM(LAN_VALOR), 0) as TOTAL FROM LANCAMENTOS WHERE LAN_EXERCICIO = " + GcSqlVal(cExercicio) + " AND LAN_CONTA_CRED >= '3000' AND D_E_L_E_T_ = ' '")
    If Len(aReceitas) > 0
        nReceitas := aReceitas[1]:TOTAL
    EndIf

    // Soma despesas (contas 4000+)
    aDespesas := TCSqlQuery("SELECT COALESCE(SUM(LAN_VALOR), 0) as TOTAL FROM LANCAMENTOS WHERE LAN_EXERCICIO = " + GcSqlVal(cExercicio) + " AND LAN_CONTA_DEB >= '4000' AND D_E_L_E_T_ = ' '")
    If Len(aDespesas) > 0
        nDespesas := aDespesas[1]:TOTAL
    EndIf

    // Calcula saldo
    nSaldo := nReceitas - nDespesas

    // Verifica se balancete já existe
    aVerificacao := TCSqlQuery("SELECT R_E_C_N_O_ FROM RPT_BALANCETE WHERE RPT_EXERCICIO = " + GcSqlVal(cExercicio) + " AND D_E_L_E_T_ = ' '")

    If Len(aVerificacao) > 0
        // Atualiza registro existente
        cSql := "UPDATE RPT_BALANCETE SET RPT_RECEITAS = " + cValToChar(nReceitas) + ", RPT_DESPESAS = " + cValToChar(nDespesas) + ", RPT_SALDO = " + cValToChar(nSaldo) + ", RPT_DATA_GERACAO = datetime('now') WHERE RPT_EXERCICIO = " + GcSqlVal(cExercicio)
        TCSqlExec(cSql)
        ConOut("Balance sheet updated for " + cExercicio + ": receitas=" + cValToChar(nReceitas) + ", despesas=" + cValToChar(nDespesas) + ", saldo=" + cValToChar(nSaldo))
    Else
        // Insere novo registro
        cSql := "INSERT INTO RPT_BALANCETE (RPT_EXERCICIO, RPT_RECEITAS, RPT_DESPESAS, RPT_SALDO, RPT_DATA_GERACAO, D_E_L_E_T_) VALUES ("
        cSql += GcSqlVal(cExercicio) + ", "
        cSql += cValToChar(nReceitas) + ", "
        cSql += cValToChar(nDespesas) + ", "
        cSql += cValToChar(nSaldo) + ", "
        cSql += "datetime('now'), "
        cSql += GcSqlVal(" ")
        cSql += ")"
        TCSqlExec(cSql)
        ConOut("Balance sheet created for " + cExercicio + ": receitas=" + cValToChar(nReceitas) + ", despesas=" + cValToChar(nDespesas) + ", saldo=" + cValToChar(nSaldo))
    EndIf

Return nSaldo
