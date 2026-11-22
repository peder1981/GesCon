// tests/login_test.prw — fluxo de login da tela (src/login.prw). Em
// execução headless o FWGetText devolve sempre o valor padrão (""), então
// aqui se testa o que não depende de digitação: sem usuários e sem
// GESCON_ADMIN_SENHA, ninguém vira administrador pela tela (antes o
// primeiro visitante criava o super administrador com a senha que
// quisesse); com usuários, login vazio não entra. Hash, política e
// bloqueio: tests/seguranca_test.prw.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} LoginTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function LoginTest()
    Local nFalhas := 0 as numeric
    Private cLoginAtual := ""

    GcAdicionarColunasSeguranca()
    TCSqlExec("DELETE FROM USR")
    If !Empty(GetEnv("GESCON_ADMIN_SENHA"))
        ConOut("FALHA ambiente: GESCON_ADMIN_SENHA definida no ambiente do teste")
        Return
    EndIf

    nFalhas += Confere("sem usuarios e sem senha inicial: nao entra", GcLogin(), .F.)
    nFalhas += Confere("nenhum usuario criado pela tela", Len(TCSqlQuery("SELECT 1 FROM USR")), 0)
    nFalhas += Confere("sessao sem login", cLoginAtual, "")

    GcCriarUsuarioBase("admin", "Inicial#2026x", "SUPERADMIN")
    nFalhas += Confere("com usuario, login vazio nao entra", GcLogin(), .F.)
    nFalhas += Confere("sessao continua sem login", cLoginAtual, "")
    nFalhas += Confere("trocar senha sem sessao recusado", GcTrocarSenha(), .F.)

    TCSqlExec("DELETE FROM USR")
    If nFalhas == 0
        ConOut("login: todos os casos ok")
    Else
        ConOut("FALHA login: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/login.prw"
