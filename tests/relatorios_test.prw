// tests/relatorios_test.prw -- relatórios por consulta direta (antes
// gravavam tabelas de rascunho compartilhadas): inadimplência com dias de
// atraso e status atualizado, extrato da unidade, despesas por categoria e
// resultado do mês, todos limitados ao condomínio da sessão.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} RelatoriosTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function RelatoriosTest()
    Local nFalhas := 0 as numeric
    Local aQ      := {} as array

    RpcSetEnv("010101")
    TCSqlExec("DELETE FROM COB WHERE FILIAL IN ('010101', '020202')")
    TCSqlExec("DELETE FROM DES WHERE FILIAL IN ('010101', '020202')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('R1', '2099-01', 100, date('now', '-10 days'), 'pendente', '010101')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('R2', '2099-01', 200, date('now', '+10 days'), 'pendente', '010101')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG, FILIAL) VALUES ('R1', '2098-12', 150, '2099-01-10', 'pago', '2099-01-09', '010101')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('R1', '2099-01', 999, date('now', '-10 days'), 'pendente', '020202')")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET, FILIAL) VALUES ('Água', 'AGUA', 80, '2099-01', '010101')")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET, FILIAL) VALUES ('Água 2', 'AGUA', 20, '2099-01', '010101')")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET, FILIAL) VALUES ('Luz', '', 50, '2099-01', '010101')")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET, FILIAL) VALUES ('Outro', 'AGUA', 5000, '2099-01', '020202')")

    aQ := GcQInadimplencia()
    nFalhas += Confere("inadimplencia: so a vencida deste condominio", Len(aQ[2]), 1)
    nFalhas += Confere("inadimplencia: dias de atraso", aQ[2][1][6], "10")
    nFalhas += Confere("status atualizado para atrasado", TCSqlQuery("SELECT COB_STATUS FROM COB WHERE COB_UNIDADE = 'R1' AND COB_COMPET = '2099-01' AND FILIAL = '010101'")[1]:COB_STATUS, "atrasado")
    nFalhas += Confere("a vencer continua pendente", TCSqlQuery("SELECT COB_STATUS FROM COB WHERE COB_UNIDADE = 'R2' AND FILIAL = '010101'")[1]:COB_STATUS, "pendente")
    nFalhas += Confere("extrato da unidade R1", Len(GcQPortalCobrancas("R1")[2]), 2)
    aQ := GcQDespesasCategoria("2099-01")
    nFalhas += Confere("despesas: 2 categorias", Len(aQ[2]), 2)
    nFalhas += Confere("despesas: AGUA somada e primeiro", aQ[2][1][1] == "AGUA" .And. aQ[2][1][3] == "100,00", .T.)
    nFalhas += Confere("despesas: sem categoria", aQ[2][2][1], "(sem categoria)")
    aQ := GcResultadoMensal("2099-01")
    nFalhas += Confere("resultado do mes", aQ[1] == 0 .And. aQ[2] == 150 .And. aQ[3] == -150 .And. aQ[4] == 300, .T.)

    TCSqlExec("DELETE FROM COB WHERE FILIAL IN ('010101', '020202')")
    TCSqlExec("DELETE FROM DES WHERE FILIAL IN ('010101', '020202')")
    RpcSetEnv("      ")
    If nFalhas == 0
        ConOut("relatorios: todos os casos ok")
    Else
        ConOut("FALHA relatorios: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/relatorios.prw"
#include "../src/consultas.prw"
