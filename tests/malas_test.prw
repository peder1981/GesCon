// tests/malas_test.prw — exercita GcMalaDireta de ponta a ponta contra um
// servidor SMTP real (endereço/porta vêm de GESCON_SMTP_HOST/PORT do
// ambiente — sem servidor configurado, GcMalaDireta retorna 0 e não
// tenta enviar nada, então este teste sozinho não garante entrega real;
// ver README para como rodar com um servidor SMTP de teste).
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

User Function MalasTest()
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'MALATEST'")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO = 'MALATEST'")
    TCSqlExec("DELETE FROM CON WHERE CON_CODIGO = 'MALATEST'")

    // FILIAL estampado com 6 espaços: esta suite nunca chama RpcSetEnv,
    // entao a sessao roda com a filial default (ver FWxFilial), e
    // GcMalaDireta agora filtra COB/UNI/CON por essa mesma filial.
    TCSqlExec("INSERT INTO CON (CON_CODIGO, CON_NOME, CON_EMAIL, FILIAL) VALUES ('MALATEST', 'Fulano de Tal', 'fulano@teste.local', '      ')")
    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO, FILIAL) VALUES ('MALATEST', 0.1, 'MALATEST', '      ')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('MALATEST', '2097-03', 123.45, '2097-03-10', 'pendente', '      ')")

    Local nEnviados := GcMalaDireta("2097-03")
    ConOut("enviados=" + Str(nEnviados))

    // Teardown
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'MALATEST'")
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO = 'MALATEST'")
    TCSqlExec("DELETE FROM CON WHERE CON_CODIGO = 'MALATEST'")

    // Validação de e-mail (vai para o cabeçalho da mensagem)
    Local aCasos := {{"fulano@teste.com.br", .T.}, {"a@b.co", .T.}, {"", .F.}, {"semarroba.com", .F.}, ;
        {"dois@@x.com", .F.}, {"a@b@c.com", .F.}, {"a@semponto", .F.}, {"a@x..com", .F.}, {"a@x.com.", .F.}, ;
        {"a b@x.com", .F.}, {"a@x.com" + Chr(13) + Chr(10) + "Bcc: alvo@y.com", .F.}, {"a@x.com,b@y.com", .F.}, {"@x.com", .F.}}
    Local nC
    For nC := 1 To Len(aCasos)
        If GcEmailValido(aCasos[nC][1]) == aCasos[nC][2]
            ConOut("ok    email [" + StrTran(StrTran(aCasos[nC][1], Chr(13), "\r"), Chr(10), "\n") + "]")
        Else
            ConOut("FALHA email [" + aCasos[nC][1] + "] esperado " + cValToChar(aCasos[nC][2]))
        EndIf
    Next nC

    // Corpo: valor em reais e datas no formato brasileiro
    Local cCorpo := GcMalaCorpo("Fulano", "101", "2026-11", 1234.5, "2026-12-10", "pendente")
    If "R$ 1.234,50" $ cCorpo .And. "Vencimento: 10/12/2026" $ cCorpo .And. "competência 11/2026" $ cCorpo .And. "Situação: Pendente" $ cCorpo
        ConOut("ok    corpo formatado")
    Else
        ConOut("FALHA corpo formatado: " + cCorpo)
    EndIf
Return

#include "../src/db.prw"
#include "../src/malas.prw"
