// tests/consultas_test.prw -- consultas da interface nova: portal só vê a
// própria unidade e o próprio condomínio (sem tabela de rascunho
// compartilhada), datas e valores formatados; permissão por perfil;
// condomínios que cada login pode abrir.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} ConsultasTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function ConsultasTest()
    Local nFalhas := 0 as numeric
    Local aQ      := {} as array
    Local aC      := {} as array

    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('QA1', 'QA2')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('QA1', '2026-10', 1234.5, '2026-11-10', 'pendente', '010101')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('QA2', '2026-10', 999, '2026-11-10', 'pendente', '010101')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('QA1', '2026-10', 777, '2026-11-10', 'pendente', '020202')")

    RpcSetEnv("010101")
    aQ := GcQPortalCobrancas("QA1")
    nFalhas += Confere("portal: so a propria unidade e condominio", Len(aQ[2]), 1)
    nFalhas += Confere("portal: valor em reais", aQ[2][1][3], "1.234,50")
    nFalhas += Confere("portal: vencimento DD/MM/AAAA", aQ[2][1][4], "10/11/2026")
    nFalhas += Confere("portal: colunas", Len(aQ[1]), 6)
    nFalhas += Confere("portal: unidade com aspas nao vaza", Len(GcQPortalCobrancas("' OR '1'='1")[2]), 0)
    RpcSetEnv("020202")
    aQ := GcQPortalCobrancas("QA1")
    nFalhas += Confere("portal: outro condominio, outra cobranca", Len(aQ[2]) == 1 .And. aQ[2][1][3] == "777,00", .T.)

    nFalhas += Confere("data ISO", GcDataBr("2026-11-21 10:00:00"), "21/11/2026")
    nFalhas += Confere("data AAAAMMDD", GcDataBr("20261121"), "21/11/2026")
    nFalhas += Confere("data vazia", GcDataBr(""), "")

    // Permissões
    nFalhas += Confere("super cadastra condominio", GcPode("SUPERADMIN", "condominios"), .T.)
    nFalhas += Confere("sindico nao cadastra condominio", GcPode("SINDICO", "condominios"), .F.)
    nFalhas += Confere("sindico nao cria super", GcPode("SINDICO", "criar_super"), .F.)
    nFalhas += Confere("sindico fecha mes", GcPode("SINDICO", "fechamento"), .T.)
    nFalhas += Confere("perfil desconhecido nada", GcPode("", "unidades"), .F.)

    // Condomínios por login
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN IN ('qsuper', 'qsind')")
    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'qsind'")
    TCSqlExec("INSERT OR IGNORE INTO COND (COND_FILIAL, COND_NOME) VALUES ('020202', 'Condomínio Dois')")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('qsuper', '-', 'SUPERADMIN')")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('qsind', '-', 'SINDICO')")
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('qsind', '020202')")
    aC := GcCondominiosDoLogin("qsuper")
    nFalhas += Confere("super ve todos", Len(aC) >= 2, .T.)
    aC := GcCondominiosDoLogin("qsind")
    nFalhas += Confere("sindico ve so o seu", Len(aC) == 1 .And. aC[1][1] == "020202", .T.)

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN IN ('qsuper', 'qsind')")
    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'qsind'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL = '020202'")
    RpcSetEnv("010101")
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE IN ('QA1', 'QA2')")
    RpcSetEnv("      ")
    If nFalhas == 0
        ConOut("consultas: todos os casos ok")
    Else
        ConOut("FALHA consultas: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/seguranca.prw"
#include "../src/consultas.prw"
