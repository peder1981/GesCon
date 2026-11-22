// tests/contabil_trilha_test.prw -- lançamento manual grava o login da
// sessão (trilha de auditoria), valor arredondado a 2 casas, e lançamento
// automático do Fechamento não pode ser editado nem excluído à mão.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} ContabilTrilhaTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function ContabilTrilhaTest()
    Local nFalhas := 0 as numeric
    Local aLan    := {} as array
    Local nRecAut := 0 as numeric
    Local nRecMan := 0 as numeric
    Private cLoginAtual := "sindico.ana"

    TCSqlExec("INSERT OR IGNORE INTO EXERCICIO (FILIAL, EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) VALUES ('      ', '2097-01', '20000101', '20991231', 1, 0, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '1000', 'Caixa', 'ATIVO', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '1100', 'Banco', 'ATIVO', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '3000', 'Receita Condominial', 'RECEITA', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '5000', 'Contas a Receber', 'ATIVO', 1, ' ')")

    // Lançamento manual: login da sessão e valor arredondado
    nFalhas += Confere("manual criado", GcCriarLancamentoManualDireto(Date(), "Trilha", "1100", "1000", 10.005), .T.)
    aLan := TCSqlQuery("SELECT R_E_C_N_O_, LAN_USUARIO, LAN_VALOR FROM LANCAMENTOS WHERE LAN_DESCR = 'Trilha' AND D_E_L_E_T_ = ' '")
    nFalhas += Confere("1 lancamento", Len(aLan), 1)
    nFalhas += Confere("usuario = login da sessao", aLan[1]:LAN_USUARIO, "sindico.ana")
    nFalhas += Confere("valor arredondado", Val(aLan[1]:LAN_VALOR), 10.01)
    nRecMan := Val(aLan[1]:R_E_C_N_O_)
    nFalhas += Confere("valor 0,004 vira 0 e e recusado", GcCriarLancamentoManualDireto(Date(), "Trilha zero", "1100", "1000", 0.004), .F.)

    // Lançamento automático (como o Fechamento grava): protegido
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_, FILIAL) " + ;
        "VALUES ('" + DToS(Date()) + "', '5000', '3000', 50, 'Rateio trilha', 'AUTOMATICO_RATEIO', '2097-01', datetime('now'), 'FECHAMENTO_MENSAL', ' ', " + ;
        "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS), '      ')")
    aLan := TCSqlQuery("SELECT R_E_C_N_O_ FROM LANCAMENTOS WHERE LAN_DESCR = 'Rateio trilha' AND D_E_L_E_T_ = ' '")
    nRecAut := Val(aLan[1]:R_E_C_N_O_)
    nFalhas += Confere("automatico: editar recusado", GcEditarLancamentoDescricao(nRecAut, "mexido"), .F.)
    nFalhas += Confere("automatico: excluir recusado", GcDeletarLancamento(nRecAut), .F.)
    aLan := TCSqlQuery("SELECT LAN_DESCR FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecAut) + " AND D_E_L_E_T_ = ' '")
    nFalhas += Confere("automatico intacto", Len(aLan) == 1 .And. aLan[1]:LAN_DESCR == "Rateio trilha", .T.)

    // Manual continua editável e excluível
    nFalhas += Confere("manual: editar", GcEditarLancamentoDescricao(nRecMan, "Trilha editada"), .T.)
    nFalhas += Confere("manual: excluir", GcDeletarLancamento(nRecMan), .T.)

    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_EXERCICIO = '2097-01' OR LAN_DESCR IN ('Trilha', 'Trilha editada')")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO = '2097-01'")

    If nFalhas == 0
        ConOut("contabil_trilha: todos os casos ok")
    Else
        ConOut("FALHA contabil_trilha: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/contabil.prw"
