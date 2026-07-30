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
