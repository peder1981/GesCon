// tests/pagamento_test.prw -- Registrar Pagamento: grava status/data,
// recusa data vazia ou futura, cobrança inexistente, de outro condomínio
// ou já paga, e só devolve .T. quando a cobrança mudou de fato.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} PagamentoTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function PagamentoTest()
    Local nFalhas  := 0 as numeric
    Local aCob     := {} as array
    Local nRecno   := 0 as numeric
    Local nOutra   := 0 as numeric
    Local aConfere := {} as array

    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('PAGTEST', 'PAGOUTRA')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_STATUS, FILIAL) VALUES ('PAGTEST', '2026-02', 500, 'pendente', '      ')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_STATUS, FILIAL) VALUES ('PAGOUTRA', '2026-02', 500, 'pendente', '020202')")
    aCob := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = 'PAGTEST'")
    nRecno := Val(aCob[1]:R_E_C_N_O_)
    aCob := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = 'PAGOUTRA'")
    nOutra := Val(aCob[1]:R_E_C_N_O_)

    nFalhas += Confere("data futura recusada", GcRegistrarPagamento(nRecno, Date() + 1), .F.)
    nFalhas += Confere("data vazia recusada", GcRegistrarPagamento(nRecno, CToD("")), .F.)
    nFalhas += Confere("cobranca inexistente", GcRegistrarPagamento(999999, SToD("20260215")), .F.)
    nFalhas += Confere("cobranca de outro condominio", GcRegistrarPagamento(nOutra, SToD("20260215")), .F.)
    nFalhas += Confere("registra pagamento", GcRegistrarPagamento(nRecno, SToD("20260215")), .T.)
    aConfere := TCSqlQuery("SELECT COB_STATUS, COB_DTPAG FROM COB WHERE R_E_C_N_O_ = " + cValToChar(nRecno))
    nFalhas += Confere("status pago", aConfere[1]:COB_STATUS, "pago")
    nFalhas += Confere("data gravada", aConfere[1]:COB_DTPAG, "2026-02-15")
    nFalhas += Confere("ja paga recusada", GcRegistrarPagamento(nRecno, SToD("20260220")), .F.)
    aConfere := TCSqlQuery("SELECT COB_DTPAG FROM COB WHERE R_E_C_N_O_ = " + cValToChar(nRecno))
    nFalhas += Confere("data original mantida", aConfere[1]:COB_DTPAG, "2026-02-15")
    aConfere := TCSqlQuery("SELECT COB_STATUS FROM COB WHERE R_E_C_N_O_ = " + cValToChar(nOutra))
    nFalhas += Confere("outra continua pendente", aConfere[1]:COB_STATUS, "pendente")

    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('PAGTEST', 'PAGOUTRA')")
    If nFalhas == 0
        ConOut("pagamento: todos os casos ok")
    Else
        ConOut("FALHA pagamento: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/cobrancas.prw"
