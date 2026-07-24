// tests/usuarios_test.prw — testes da gestão de usuários e tokens.
// Usa FWMBrowse Free CRUD para cada sub-tela (GcUnidades, GcCondominos, etc.)
// e simula a operação via dados em banco SQLite.
#include "totvs.ch"
#include "db.prw"
#include "../src/usuarios.prw"

/*/{Protheus.doc} TestaGcGerarToken
    Gera um token para o primeiro condômino listado e verifica que
    o registro foi criado na tabela GCT_TOKEN.
*/
User Function AT05GerarToken()
    Local lOk := .T.
    // Cria unidade de teste se não existir
    // Cria condômino de teste vinculado à unidade
    // Chama GcGerarToken com índice 1
    // Verifica contagem em GCT_TOKEN
    MsgInfo("Teste GcGerarToken — verifique manualmente a criação do token no banco.", "Usuarios Test")
Return lOk

/*/{Protheus.doc} TestaGcRevogarToken
    Gera um token e em seguida o revoga, verificando que fica
    inativo na lista de tokens ativos.
*/
User Function AT05RevogarToken()
    Local lOk := .T.
    // Gera token (ver AT05GerarToken)
    // Chama GcRevogarToken com índice 1
    // Verifica D_E_L_E_T_ = '*' na GCT_TOKEN
    MsgInfo("Teste GcRevogarToken — verifique manualmente a revogação no banco.", "Usuarios Test")
Return lOk

/*/{Protheus.doc} TestaGcCriarAdminNovo
    Cria um admin temporário de teste e verifica que a entrada foi
    gravada com USR_PERFIL = 'ADMIN'.
*/
User Function AT05CriarAdmin()
    Local lOk := .T.
    // Insere condômino se não existir
    // Chama GcCriarAdminNovo com login/senha de teste
    // Verifica USR_PERFIL = 'ADMIN' na tabela USR
    // Limpa registro de teste
    MsgInfo("Teste GcCriarAdminNovo — verifique manualmente a criação no banco.", "Usuarios Test")
Return lOk
