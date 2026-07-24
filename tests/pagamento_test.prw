#include "totvs.ch"
#include "../src/cobrancas.prw"

User Function PagamentoTest()
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'PAGTEST'")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_STATUS) VALUES ('PAGTEST', '2099-02', 500, 'pendente')")

    Local aCob := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = 'PAGTEST'")
    Local nRecno := Val(aCob[1]:R_E_C_N_O_)

    Local lOk := GcRegistrarPagamento(nRecno, CToD("15/02/2099"))
    ConOut("registrou=" + cValToChar(lOk))

    Local aConfere := TCSqlQuery("SELECT COB_STATUS, COB_DTPAG FROM COB WHERE R_E_C_N_O_ = " + Str(nRecno))
    ConOut("status=" + aConfere[1]:COB_STATUS)
    ConOut("dtpag=" + aConfere[1]:COB_DTPAG)

    // Teardown — não deixa fixture no banco real compartilhado
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'PAGTEST'")
Return
