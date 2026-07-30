// src/contabil.prw — utilidades do sistema contábil em partida dupla
// Acesso a exercícios, períodos, validações de lançamentos
#include "totvs.ch"

/*/{Protheus.doc} GcSqlLit
    Escapa aspas simples e envolve com quotes — todo valor de texto interpolado
    numa query via TCSqlExec/TCSqlQuery precisa passar por aqui para evitar
    SQL injection e quebra de literais.
    @type Function
    @author GesCon
    @since 2026-07-30
    @param cValor, character, valor a escapar (aceita Nil)
    @return cRet, character, valor com aspas simples duplicadas e envolvido com quotes
    @example
        cSql := "INSERT INTO EXERCICIO (EXE_CODIGO, EXE_NOME) VALUES (" + GcSqlLit("2025-01") + ", " + GcSqlLit("João's Company") + ")"
*/
User Function GcSqlLit(cValor)
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
        aExercicio := TCSqlQuery("SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")

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
    cSql += GcSqlLit(DtoS(dData)) + ", "
    cSql += GcSqlLit(cContaDeb) + ", "
    cSql += GcSqlLit(cContaCred) + ", "
    cSql += cValToChar(nValor) + ", "
    cSql += GcSqlLit(cDescricao) + ", "
    cSql += GcSqlLit("MANUAL") + ", "
    cSql += GcSqlLit(cExercicio) + ", "
    cSql += "datetime('now'), "
    cSql += GcSqlLit("TEST_USER") + ", "
    cSql += GcSqlLit(" ") + ", "
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
    cSql := "UPDATE LANCAMENTOS SET LAN_DESCR = " + GcSqlLit(cDescricao) + ", LAN_DATA_HORA = datetime('now') WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '"

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
