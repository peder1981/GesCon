// tests/fechamento_test.prw
// NOTA: #include "../src/db.prw" abaixo parece redundante com o #include
// de fechamento.prw (que também inclui db.prw), mas NÃO é — o AdvPP
// resolve #include de forma relativa ao diretório do arquivo RAIZ
// compilado, não ao diretório de quem faz o include. O "db.prw" (sem
// caminho) dentro de src/fechamento.prw só resolve quando a raiz está em
// src/; daqui (tests/), precisa do caminho explícito. Removê-lo quebra
// `advplc run` com "unknown function: GcSqlLit" mesmo com `advplc check`
// passando limpo (check não pega isso).
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
User Function FechamentoTest()
    Local lOk

    // Isola a competência de teste pra não colidir com dados reais
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('T01','T02')")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO IN ('T01','T02')")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-01'")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-01'")

    // FILIAL explícito: sem ele a linha fica NULL e nunca bate com o
    // FWxFilial('UNI')/FWxFilial('DES') = '      ' que GcFecharMes usa
    // pra filtrar numa sessão sem RpcSetEnv -- achado ao adicionar os
    // asserts PASS/FAIL abaixo (o teste original só imprimia, nunca
    // verificava, então o bug ficou invisível).
    TCSqlExec("INSERT INTO UNI (FILIAL, UNI_CODIGO, UNI_FRACAO) VALUES ('      ', 'T01', 0.6)")
    TCSqlExec("INSERT INTO UNI (FILIAL, UNI_CODIGO, UNI_FRACAO) VALUES ('      ', 'T02', 0.4)")
    TCSqlExec("INSERT INTO DES (FILIAL, DES_DESCR, DES_VALOR, DES_COMPET) VALUES ('      ', 'Teste', 1000, '2099-01')")

    lOk := GcFecharMes("2099-01")
    ConOut("fechou=" + cValToChar(lOk))

    Local aCob := TCSqlQuery("SELECT COB_UNIDADE, COB_VALOR, COB_STATUS, COB_VENCTO FROM COB WHERE COB_COMPET = '2099-01' ORDER BY COB_UNIDADE")
    ConOut("qtd_cobrancas=" + Str(Len(aCob)))
    ConOut("t01_valor=" + aCob[1]:COB_VALOR)
    ConOut("t01_status=" + aCob[1]:COB_STATUS)
    ConOut("t02_valor=" + aCob[2]:COB_VALOR)
    ConOut("vencimento_padrao=" + aCob[1]:COB_VENCTO)

    // Fechar de novo deve ser bloqueado (trava contra duplicidade)
    Local lSegundaVez := GcFecharMes("2099-01")
    ConOut("segunda_vez=" + cValToChar(lSegundaVez))

    // Dia de vencimento configurável — competência separada, sem trava
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-02'")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-02'")
    TCSqlExec("INSERT INTO DES (FILIAL, DES_DESCR, DES_VALOR, DES_COMPET) VALUES ('      ', 'Teste2', 500, '2099-02')")
    GcFecharMes("2099-02", 20)
    Local aCob2 := TCSqlQuery("SELECT COB_VENCTO FROM COB WHERE COB_COMPET = '2099-02' LIMIT 1")
    ConOut("vencimento_dia_20=" + aCob2[1]:COB_VENCTO)

    // Ponte pra Contabilidade formal (Wilson Kraft, QA 2026-08-21): com um
    // exercício aberto pra competência, o fechamento também grava
    // LANCAMENTOS, e o Balancete passa a refletir o fechamento em lote.
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-03'")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-03'")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_EXERCICIO = '2099-03'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO = '2099-03'")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '1000', 'Caixa', 'ATIVO', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '3000', 'Receita Condominial', 'RECEITA', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '4000', 'Despesa Comum', 'DESPESA', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '5000', 'Contas a Receber', 'ATIVO', 1, ' ')")
    TCSqlExec("INSERT INTO EXERCICIO (FILIAL, EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) VALUES ('      ', '2099-03', '20990101', '20991231', 1, 0, ' ')")
    TCSqlExec("INSERT INTO DES (FILIAL, DES_DESCR, DES_VALOR, DES_COMPET) VALUES ('      ', 'Teste3', 1000, '2099-03')")

    Local lOk3 := GcFecharMes("2099-03")
    ConOut("fechou_com_exercicio=" + cValToChar(lOk3))

    Local aLanDespesa := TCSqlQuery("SELECT LAN_VALOR FROM LANCAMENTOS WHERE LAN_EXERCICIO = '2099-03' AND LAN_TIPO = 'AUTOMATICO_DESPESA' AND D_E_L_E_T_ = ' '")
    If Len(aLanDespesa) == 1 .And. Val(aLanDespesa[1]:LAN_VALOR) == 1000
        ConOut("PASS: lançamento de despesa gravado (4000/1000, valor=1000)")
    Else
        ConOut("FAIL: lançamento de despesa esperado (1 linha, valor=1000), achou " + cValToChar(Len(aLanDespesa)))
    EndIf

    Local aLanRateio := TCSqlQuery("SELECT LAN_VALOR FROM LANCAMENTOS WHERE LAN_EXERCICIO = '2099-03' AND LAN_TIPO = 'AUTOMATICO_RATEIO' AND D_E_L_E_T_ = ' ' ORDER BY LAN_VALOR DESC")
    If Len(aLanRateio) == 2 .And. Val(aLanRateio[1]:LAN_VALOR) == 600 .And. Val(aLanRateio[2]:LAN_VALOR) == 400
        ConOut("PASS: lançamentos de rateio gravados (5000/3000, 600 + 400)")
    Else
        ConOut("FAIL: lançamentos de rateio esperados (600 + 400), achou " + cValToChar(Len(aLanRateio)) + " linhas")
    EndIf

    Local nSaldo3 := GcGerarBalancetePeriodo("2099-03")
    If nSaldo3 == 0
        ConOut("PASS: Balancete do fechamento em lote fecha em zero (receita 1000 - despesa 1000)")
    Else
        ConOut("FAIL: Balancete esperado 0, achou " + cValToChar(nSaldo3))
    EndIf

    // Teardown — não deixa fixture no banco real compartilhado
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-01'")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-01'")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-02'")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-02'")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-03'")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-03'")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_EXERCICIO = '2099-03'")
    TCSqlExec("DELETE FROM RPT_BALANCETE WHERE RPT_EXERCICIO = '2099-03'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO = '2099-03'")
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('T01','T02')")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO IN ('T01','T02')")
Return

#include "../src/db.prw"
#include "../src/fechamento.prw"
#include "../src/contabil.prw"
