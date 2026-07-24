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
#include "../src/db.prw"
#include "../src/fechamento.prw"
User Function FechamentoTest()
    Local lOk

    // Isola a competência de teste pra não colidir com dados reais
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO IN ('T01','T02')")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-01'")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-01'")

    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO) VALUES ('T01', 0.6)")
    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO) VALUES ('T02', 0.4)")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_VALOR, DES_COMPET) VALUES ('Teste', 1000, '2099-01')")

    lOk := GcFecharMes("2099-01")
    ConOut("fechou=" + cValToChar(lOk))

    Local aCob := TCSqlQuery("SELECT COB_UNIDADE, COB_VALOR, COB_STATUS FROM COB WHERE COB_COMPET = '2099-01' ORDER BY COB_UNIDADE")
    ConOut("qtd_cobrancas=" + Str(Len(aCob)))
    ConOut("t01_valor=" + aCob[1]:COB_VALOR)
    ConOut("t01_status=" + aCob[1]:COB_STATUS)
    ConOut("t02_valor=" + aCob[2]:COB_VALOR)

    // Fechar de novo deve ser bloqueado (trava contra duplicidade)
    Local lSegundaVez := GcFecharMes("2099-01")
    ConOut("segunda_vez=" + cValToChar(lSegundaVez))
Return
