// tests/fechamento_validacao_test.prw -- recusas do Fechamento Mensal
// (competência inválida, frações ideais fora de 100%), gravação das
// cobranças num único comando e índice único de cobrança.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} FechamentoValidacaoTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function FechamentoValidacaoTest()
    Local nFalhas := 0 as numeric
    Local aQtd    := {} as array

    // Competência
    nFalhas += Confere("2026-11 valida", GcCompetenciaValida("2026-11"), .T.)
    nFalhas += Confere("2026-13 invalida", GcCompetenciaValida("2026-13"), .F.)
    nFalhas += Confere("2026-00 invalida", GcCompetenciaValida("2026-00"), .F.)
    nFalhas += Confere("abc invalida", GcCompetenciaValida("abc"), .F.)
    nFalhas += Confere("2026/11 invalida", GcCompetenciaValida("2026/11"), .F.)
    nFalhas += Confere("26-11 invalida", GcCompetenciaValida("26-11"), .F.)
    nFalhas += Confere("2O26-11 (letra O) invalida", GcCompetenciaValida("2O26-11"), .F.)

    // Cenário isolado: só as unidades deste teste nesta filial
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '      '")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '      '")
    TCSqlExec("DELETE FROM DES WHERE FILIAL = '      '")
    TCSqlExec("INSERT INTO UNI (FILIAL, UNI_CODIGO, UNI_FRACAO) VALUES ('      ', 'V01', 0.3)")
    TCSqlExec("INSERT INTO UNI (FILIAL, UNI_CODIGO, UNI_FRACAO) VALUES ('      ', 'V02', 0.2)")
    TCSqlExec("INSERT INTO DES (FILIAL, DES_DESCR, DES_VALOR, DES_COMPET) VALUES ('      ', 'Teste', 1000, '2098-01')")

    nFalhas += Confere("fechar 'abc' recusado", GcFecharMes("abc"), .F.)
    aQtd := TCSqlQuery("SELECT COUNT(*) AS Q FROM COB WHERE FILIAL = '      '")
    nFalhas += Confere("nenhuma cobranca com competencia invalida", Val(aQtd[1]:Q), 0)

    // Frações somam 50%: recusado, nada gravado
    nFalhas += Confere("fracoes 50% recusado", GcFecharMes("2098-01"), .F.)
    aQtd := TCSqlQuery("SELECT COUNT(*) AS Q FROM COB WHERE FILIAL = '      '")
    nFalhas += Confere("nenhuma cobranca com fracoes 50%", Val(aQtd[1]:Q), 0)

    // Frações somam 120%: recusado
    TCSqlExec("INSERT INTO UNI (FILIAL, UNI_CODIGO, UNI_FRACAO) VALUES ('      ', 'V03', 0.7)")
    nFalhas += Confere("fracoes 120% recusado", GcFecharMes("2098-01"), .F.)

    // Falha no meio da gravação (gatilho recusa a cobrança de V02): nenhuma
    // cobrança gravada e o fechamento devolve .F. (AdvPP 4.8.6+: o erro de
    // SQL volta para o programa em vez de encerrá-lo).
    TCSqlExec("UPDATE UNI SET UNI_FRACAO = 0.5 WHERE FILIAL = '      ' AND UNI_CODIGO = 'V03'")
    TCSqlExec("CREATE TRIGGER TRG_TESTE_RECUSA BEFORE INSERT ON COB WHEN NEW.COB_UNIDADE = 'V02' " + ;
        "BEGIN SELECT RAISE(ABORT, 'recusa de teste'); END")
    nFalhas += Confere("falha no meio devolve .F.", GcFecharMes("2098-01"), .F.)
    aQtd := TCSqlQuery("SELECT COUNT(*) AS Q FROM COB WHERE FILIAL = '      '")
    nFalhas += Confere("falha no meio nao grava nenhuma", Val(aQtd[1]:Q), 0)
    TCSqlExec("DROP TRIGGER TRG_TESTE_RECUSA")

    // Frações em 100%: fecha, uma cobrança por unidade, soma = despesa
    TCSqlExec("UPDATE UNI SET UNI_FRACAO = 0.5 WHERE FILIAL = '      ' AND UNI_CODIGO = 'V03'")
    nFalhas += Confere("fracoes 100% fecha", GcFecharMes("2098-01"), .T.)
    aQtd := TCSqlQuery("SELECT COUNT(*) AS Q, SUM(COB_VALOR) AS S FROM COB WHERE FILIAL = '      ' AND COB_COMPET = '2098-01'")
    nFalhas += Confere("3 cobrancas", Val(aQtd[1]:Q), 3)
    nFalhas += Confere("soma = 1000", Round(Val(aQtd[1]:S), 2), 1000)

    // Índice único: criado em banco sem duplicatas
    nFalhas += Confere("indice unico criado", GcCriarIndiceUnicoCob(), .T.)
    aQtd := TCSqlQuery("SELECT COUNT(*) AS Q FROM sqlite_master WHERE type = 'index' AND name = 'UQ_COB_COMPET_UNIDADE'")
    nFalhas += Confere("indice existe", Val(aQtd[1]:Q), 1)

    // Com duplicata antiga: não cria (e não derruba o boot)
    TCSqlExec("DROP INDEX IF EXISTS UQ_COB_COMPET_UNIDADE")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) " + ;
        "VALUES ('V01', '2098-01', 1, '2098-02-10', 'pendente', '      ')")
    nFalhas += Confere("com duplicata nao cria", GcCriarIndiceUnicoCob(), .F.)

    TCSqlExec("DROP INDEX IF EXISTS UQ_COB_COMPET_UNIDADE")
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '      '")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '      '")
    TCSqlExec("DELETE FROM DES WHERE FILIAL = '      '")

    If nFalhas == 0
        ConOut("fechamento_validacao: todos os casos ok")
    Else
        ConOut("FALHA fechamento_validacao: " + cValToChar(nFalhas) + " caso(s)")
    EndIf
Return

/*/{Protheus.doc} Confere
    Compara obtido x esperado e imprime ok/FALHA.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param cNome, character, nome do caso
    @param xObtido, variant, valor obtido
    @param xEsperado, variant, valor esperado
    @return numeric, 0 se bateu, 1 se falhou
*/
Static Function Confere(cNome, xObtido, xEsperado)
    If ValType(xObtido) == ValType(xEsperado) .And. xObtido == xEsperado
        ConOut("ok    " + cNome)
        Return 0
    EndIf
    ConOut("FALHA " + cNome + ": obtido [" + cValToChar(xObtido) + "] esperado [" + cValToChar(xEsperado) + "]")
Return 1

#include "../src/db.prw"
#include "../src/fechamento.prw"
#include "../src/contabil.prw"
