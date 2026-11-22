// tests/condominio_selecao_test.prw -- condomínios que cada login pode
// abrir (GcCondominiosDoLogin): super vê todos os ativos em ordem de nome;
// síndico só os vinculados e ativos; vínculo revogado some; sem vínculo,
// nenhum.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} CondominioSelecaoTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-08-08
*/
User Function CondominioSelecaoTest()
    Local nFalhas := 0 as numeric
    Local aC      := {} as array

    GcAdicionarColunasSeguranca()
    TCSqlExec("DELETE FROM COND")
    TCSqlExec("DELETE FROM USR")
    TCSqlExec("DELETE FROM USR_COND")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME) VALUES ('090011', 'Beta')")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME) VALUES ('090021', 'Alfa')")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090031', 'Inativo', 0)")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('super', '-', 'SUPERADMIN')")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('sind', '-', 'SINDICO')")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('semvinculo', '-', 'SINDICO')")
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('sind', '090011')")
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('sind', '090021')")
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('sind', '090031')")

    aC := GcCondominiosDoLogin("super")
    nFalhas += Confere("super: 2 ativos em ordem de nome", Len(aC) == 2 .And. aC[1][2] == "Alfa" .And. aC[2][2] == "Beta", .T.)
    aC := GcCondominiosDoLogin("sind")
    nFalhas += Confere("sindico: so vinculados e ativos", Len(aC) == 2 .And. aC[1][1] == "090021", .T.)
    TCSqlExec("UPDATE USR_COND SET D_E_L_E_T_ = '*' WHERE USR_LOGIN = 'sind' AND FILIAL = '090021'")
    aC := GcCondominiosDoLogin("sind")
    nFalhas += Confere("vinculo revogado some", Len(aC) == 1 .And. aC[1][1] == "090011", .T.)
    nFalhas += Confere("login em maiusculas acha os vinculos", Len(GcCondominiosDoLogin("SIND")), 1)
    nFalhas += Confere("sem vinculo, nenhum", Len(GcCondominiosDoLogin("semvinculo")), 0)
    nFalhas += Confere("login inexistente, nenhum", Len(GcCondominiosDoLogin("ninguem")), 0)

    TCSqlExec("DELETE FROM USR")
    TCSqlExec("DELETE FROM USR_COND")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL LIKE '0900%'")
    TCSqlExec("INSERT OR IGNORE INTO COND (COND_FILIAL, COND_NOME) VALUES ('010101', 'Condomínio 1')")
    If nFalhas == 0
        ConOut("condominio_selecao: todos os casos ok")
    Else
        ConOut("FALHA condominio_selecao: " + cValToChar(nFalhas) + " caso(s)")
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
