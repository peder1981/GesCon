// tests/malas_test.prw — exercita GcMalaDireta de ponta a ponta contra um
// servidor SMTP real (endereço/porta vêm de GESCON_SMTP_HOST/PORT do
// ambiente — sem servidor configurado, GcMalaDireta retorna 0 e não
// tenta enviar nada, então este teste sozinho não garante entrega real;
// ver README para como rodar com um servidor SMTP de teste).
#include "totvs.ch"
#include "../src/db.prw"
#include "../src/malas.prw"

User Function MalasTest()
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'MALATEST'")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO = 'MALATEST'")
    TCSqlExec("DELETE FROM CON WHERE CON_CODIGO = 'MALATEST'")

    TCSqlExec("INSERT INTO CON (CON_CODIGO, CON_NOME, CON_EMAIL) VALUES ('MALATEST', 'Fulano de Tal', 'fulano@teste.local')")
    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO) VALUES ('MALATEST', 0.1, 'MALATEST')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('MALATEST', '2097-03', 123.45, '2097-03-10', 'pendente')")

    Local nEnviados := GcMalaDireta("2097-03")
    ConOut("enviados=" + Str(nEnviados))

    // Teardown
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'MALATEST'")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO = 'MALATEST'")
    TCSqlExec("DELETE FROM CON WHERE CON_CODIGO = 'MALATEST'")
Return
