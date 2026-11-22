// tests/usuarios_test.prw -- usuários criados pela interface: cada um
// entra só com a própria senha, nenhum com a senha de outro; o identificador
// de token é único a cada chamada.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} UsuariosTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function UsuariosTest()
    Local nFalhas := 0 as numeric

    GcAdicionarColunasSeguranca()
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN IN ('sindico1', 'sindico2')")
    nFalhas += Confere("cria sindico1", GcCriarUsuarioBase("sindico1", "Primeira#Senha1", "SINDICO"), "")
    nFalhas += Confere("cria sindico2", GcCriarUsuarioBase("sindico2", "Segunda#Senha2", "SINDICO"), "")
    nFalhas += Confere("sindico1 com a propria senha", GcCredenciaisValidas("sindico1", "Primeira#Senha1"), .T.)
    nFalhas += Confere("sindico2 com a propria senha", GcCredenciaisValidas("sindico2", "Segunda#Senha2"), .T.)
    nFalhas += Confere("sindico1 com a senha do outro", GcCredenciaisValidas("sindico1", "Segunda#Senha2"), .F.)
    nFalhas += Confere("tokens diferentes", GcGerarTokenId() != GcGerarTokenId(), .T.)
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN IN ('sindico1', 'sindico2')")
    If nFalhas == 0
        ConOut("usuarios: todos os casos ok")
    Else
        ConOut("FALHA usuarios: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/usuarios.prw"
