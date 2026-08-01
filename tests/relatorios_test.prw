// tests/relatorios_test.prw
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito.
// `advplc run` escolhe sozinho o ponto de entrada: a primeira User
// Function cuja linha seja >= a primeira linha de codigo do arquivo raiz
// (pkg/compiler/codegen.go). Como #include cola o texto incluido no lugar,
// includes no topo empurram as funcoes dos modulos para antes do runner
// deste arquivo -- e a suite inteira roda em silencio, executando algo
// como GcSqlLit no lugar dos testes. Com os includes no fim, o runner
// abaixo e sempre a primeira funcao do compilado. scripts/test.sh
// confere isso a cada execucao.

User Function RelatoriosTest()
    // Isola dados de teste
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'RPT01'")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2095-06'")

    // Cenário: uma unidade com 1 cobrança paga e 1 vencida/não paga
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG) VALUES " + ;
        "('RPT01', '2095-05', 500, '2095-05-10', 'pago', '2095-05-05')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES " + ;
        "('RPT01', '2095-06', 600, '2020-01-10', 'pendente')") // vencimento no passado -> inadimplente

    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET) VALUES " + ;
        "('Teste A', 'Manutenção', 300, '2095-06')")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET) VALUES " + ;
        "('Teste B', 'Manutenção', 200, '2095-06')")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET) VALUES " + ;
        "('Teste C', 'Limpeza', 100, '2095-06')")

    // Balancete de 2095-05: receita 500 (pago), despesa 0 -> saldo 500
    Local nSaldo := GcBalanceteMensal("2095-05")
    ConOut("saldo=" + Str(nSaldo))

    // Inadimplência: deve conter RPT01/2095-06, e o status real da
    // Cobrança deve ter sido promovido pra "atrasado" (não fica só no
    // relatório — GcInadimplenciaCalc chama GcAtualizarInadimplentes)
    GcInadimplenciaCalc()
    Local aInadim := TCSqlQuery("SELECT RIN_UNIDADE, RIN_VALOR FROM RPT_INADIM WHERE RIN_UNIDADE = 'RPT01'")
    ConOut("inadim_qtd=" + Str(Len(aInadim)))
    If Len(aInadim) > 0
        ConOut("inadim_valor=" + aInadim[1]:RIN_VALOR)
    EndIf

    Local aStatus := TCSqlQuery("SELECT COB_STATUS FROM COB WHERE COB_UNIDADE = 'RPT01' AND COB_COMPET = '2095-06'")
    ConOut("status_real=" + aStatus[1]:COB_STATUS)

    // Extrato da unidade RPT01: deve ter as 2 cobranças
    GcExtratoUnidadeCalc("RPT01")
    Local aExtrato := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_EXTRATO")
    ConOut("extrato_qtd=" + aExtrato[1]:QTD)

    // Despesas por categoria de 2095-06: Manutenção=500, Limpeza=100
    GcDespesasCategoriaCalc("2095-06")
    Local aCateg := TCSqlQuery("SELECT RDC_CATEG, RDC_TOTAL FROM RPT_DESCAT ORDER BY RDC_TOTAL DESC")
    Local i
    For i := 1 To Len(aCateg)
        ConOut("categ=" + aCateg[i]:RDC_CATEG + " total=" + aCateg[i]:RDC_TOTAL)
    Next

    // Teardown
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'RPT01'")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2095-06'")
    TCSqlExec("DELETE FROM RPT_INADIM")
    TCSqlExec("DELETE FROM RPT_EXTRATO")
    TCSqlExec("DELETE FROM RPT_DESCAT")
Return

#include "../src/db.prw"
#include "../src/relatorios.prw"
