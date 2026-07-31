// tests/auditoria_test.prw— Testes das tabelas de auditoria e anomalias
// Verifica criao e existncia das tabelas ANOMALIA_LOG, ALERTA e DASHBOARD_CACHE
#include "totvs.ch"
#include "../src/db.prw"
#include "../src/login.prw"
#include "../src/usuarios.prw"
#include "../src/auth-primitives.prw"

/*/{Protheus.doc} RunAuditoriaTests
    Driver de execucao: `advplc run tests/auditoria_test.prw` so executa a
    primeira User Function do arquivo (limitacao do advplc v2.0.3 - nao
    existe suporte a `arquivo::Funcao` nem descoberta automatica de todas
    as funcoes `Test*`), entao esta funcao roda em sequencia todas as
    suites deste arquivo e agrega o resultado. As 3 suites
    TestAuthValidateToken/TestAuthLoginRestEndpoint/TestAuthLogoutRestEndpoint
    (Task 2, endpoints REST) usam JsonObject():parse(), metodo nao
    implementado no advplc v2.0.3 - ficam de fora desta chamada em cadeia
    para nao abortar a execucao das demais suites (erro nao tratavel via
    Try/Catch por ser um erro de metodo desconhecido na VM).
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todas as suites chamadas passaram
*/
User Function RunAuditoriaTests()
    Local lOk as logical

    lOk := .T.
    If !TestAuditoriaTablesExist()
        lOk := .F.
    EndIf
    If !TestGcValidarToken()
        lOk := .F.
    EndIf
    If !TestGcValidarLoginPortal()
        lOk := .F.
    EndIf
    If !TestGcInvalidarToken()
        lOk := .F.
    EndIf

    If lOk
        ConOut("=== RunAuditoriaTests: TODAS AS SUITES PASSARAM ===")
    Else
        ConOut("=== RunAuditoriaTests: HA FALHAS, ver [FAIL] acima ===")
    EndIf
Return lOk

/*/{Protheus.doc} TestAuditoriaTablesExist
    Verifica que todas as 3 tabelas de auditoria existem no banco de dados.
    Consulta sqlite_master para confirmar a existncia de:
    - ANOMALIA_LOG
    - ALERTA
    - DASHBOARD_CACHE
    @type Function
    @author GesCon
    @since 2026-07-30
    @return lOk, logical, .T. se todas as tabelas existem, .F. caso contrrio
*/
User Function TestAuditoriaTablesExist()
    Local lOk := .T.
    Local aAnomalia := {}
    Local aAlerta := {}
    Local aDashboard := {}
    Local cMsg := ""

    // Verifica existncia de ANOMALIA_LOG
    aAnomalia := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ANOMALIA_LOG'")
    If Len(aAnomalia) == 0
        lOk := .F.
        cMsg += "ERRO: Tabela ANOMALIA_LOG no encontrada" + CRLF
    Else
        ConOut("OK: Tabela ANOMALIA_LOG existe")
    EndIf

    // Verifica existncia de ALERTA
    aAlerta := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ALERTA'")
    If Len(aAlerta) == 0
        lOk := .F.
        cMsg += "ERRO: Tabela ALERTA no encontrada" + CRLF
    Else
        ConOut("OK: Tabela ALERTA existe")
    EndIf

    // Verifica existncia de DASHBOARD_CACHE
    aDashboard := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='DASHBOARD_CACHE'")
    If Len(aDashboard) == 0
        lOk := .F.
        cMsg += "ERRO: Tabela DASHBOARD_CACHE no encontrada" + CRLF
    Else
        ConOut("OK: Tabela DASHBOARD_CACHE existe")
    EndIf

    // Log resultado
    If lOk
        ConOut("SUCESSO: Todas as 3 tabelas de auditoria foram criadas com sucesso")
    Else
        ConOut(cMsg)
    EndIf

Return lOk

/*/{Protheus.doc} TestAuthValidateToken
    Verifica que um token válido retorna {ok: true, perfil, unidades}
    via GcAuthValidateRestToken.
    @type Function
    @author Claude
    @since 2026-07-30
    @return lOk, logical, .T. se o teste passou
*/
User Function TestAuthValidateToken()
    Local cToken as character
    Local oResult as object
    Local lOk as logical

    cToken := "test-token-uuid"
    oResult := JsonObject():parse(GcAuthValidateRestToken(cToken))

    If oResult["ok"] <> .T.
        ConOut("[FAIL] TestAuthValidateToken: token validation failed")
        Return .F.
    EndIf

    lOk := .T.
    ConOut("[PASS] TestAuthValidateToken: token validado com sucesso")
Return lOk

/*/{Protheus.doc} TestAuthLoginRestEndpoint
    Verifica que login com credenciais válidas retorna token via
    GcAuthLoginRestEndpoint.
    @type Function
    @author Claude
    @since 2026-07-30
    @return lOk, logical, .T. se o teste passou
*/
User Function TestAuthLoginRestEndpoint()
    Local oResult as object
    Local lOk as logical

    oResult := JsonObject():parse(GcAuthLoginRestEndpoint("admin", "admin123"))

    If oResult["ok"] <> .T. .Or. Empty(oResult["token"])
        ConOut("[FAIL] TestAuthLoginRestEndpoint: login failed or token empty")
        Return .F.
    EndIf

    lOk := .T.
    ConOut("[PASS] TestAuthLoginRestEndpoint: login efetuado, token recebido")
Return lOk

/*/{Protheus.doc} TestAuthLogoutRestEndpoint
    Verifica que logout invalida o token via GcAuthLogoutRestEndpoint.
    @type Function
    @author Claude
    @since 2026-07-30
    @return lOk, logical, .T. se o teste passou
*/
User Function TestAuthLogoutRestEndpoint()
    Local cToken as character
    Local oResult as object
    Local lOk as logical

    cToken := "test-token-uuid"
    oResult := JsonObject():parse(GcAuthLogoutRestEndpoint(cToken))

    If oResult["ok"] <> .T.
        ConOut("[FAIL] TestAuthLogoutRestEndpoint: logout failed")
        Return .F.
    EndIf

    lOk := .T.
    ConOut("[PASS] TestAuthLogoutRestEndpoint: logout efetuado com sucesso")
Return lOk

/*/{Protheus.doc} TestGcValidarToken
    Verifica GcValidarToken (Task 1.5): token valido/nao expirado/nao
    usado retorna ativo=.T., expirado=.F. e o perfil gravado em
    TOK_PERFIL; token inexistente e token vazio retornam ativo=.F.,
    expirado=.T. Cria e limpa dados de teste em GCT_TOKEN.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcValidarToken()
    Local cToken as character
    Local cValido as character
    Local oToken as object
    Local lOk as logical

    lOk := .T.
    cToken := "test15-tok-valido"
    cValido := DTOS(Date() + 2)
    cValido := SubStr(cValido, 1, 4) + "-" + SubStr(cValido, 5, 2) + "-" + SubStr(cValido, 7, 2) + " 23:59:59"

    // Setup: limpa resto de execucoes anteriores e insere token de teste
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, TOK_PERFIL) " + ;
        "VALUES ('" + cToken + "', 'admin', 'C15', 'U15', '2026-07-01 10:00:00', '" + cValido + "', 0, 'ADMIN')")

    // Caso 1: token valido
    oToken := GcValidarToken(cToken)
    If oToken:ativo <> .T. .Or. oToken:expirado <> .F. .Or. oToken:perfil <> "ADMIN"
        ConOut("[FAIL] TestGcValidarToken: token valido nao retornou ativo=.T./expirado=.F./perfil=ADMIN")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarToken: token valido OK (ativo, nao expirado, perfil ADMIN)")
    EndIf

    // Caso 2: token inexistente
    oToken := GcValidarToken("test15-tok-inexistente")
    If oToken:ativo <> .F. .Or. oToken:expirado <> .T.
        ConOut("[FAIL] TestGcValidarToken: token inexistente deveria retornar ativo=.F./expirado=.T.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarToken: token inexistente OK (ativo=.F., expirado=.T.)")
    EndIf

    // Caso 3: token vazio
    oToken := GcValidarToken("")
    If oToken:ativo <> .F. .Or. oToken:expirado <> .T.
        ConOut("[FAIL] TestGcValidarToken: token vazio deveria retornar ativo=.F./expirado=.T.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarToken: token vazio OK (ativo=.F., expirado=.T.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
Return lOk

/*/{Protheus.doc} TestGcValidarLoginPortal
    Verifica GcValidarLoginPortal (Task 1.5): credenciais validas
    retornam objeto com token/perfil/unidades_permitidas e gravam uma
    linha nova em GCT_TOKEN; credenciais invalidas retornam .Null. e nao
    gravam nada. Cria e limpa um usuario de teste em USR.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcValidarLoginPortal()
    Local cLogin as character
    Local cSenha as character
    Local oResult as object
    Local nTokensAntes as numeric
    Local nTokensDepois as numeric
    Local lOk as logical

    lOk := .T.
    cLogin := "test15user"
    cSenha := "test15senha"

    // Setup: limpa resto de execucoes anteriores e cria usuario de teste
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE USR_LOGIN = '" + cLogin + "'")
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = '" + cLogin + "'")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('" + cLogin + "', '" + FWHash(cSenha) + "', 'CONDOMINO')")

    // Caso 1: credenciais validas
    nTokensAntes := Len(TCSqlQuery("SELECT TOKEN FROM GCT_TOKEN WHERE USR_LOGIN = '" + cLogin + "' AND D_E_L_E_T_ = ' '"))
    oResult := GcValidarLoginPortal(cLogin, cSenha)
    nTokensDepois := Len(TCSqlQuery("SELECT TOKEN FROM GCT_TOKEN WHERE USR_LOGIN = '" + cLogin + "' AND D_E_L_E_T_ = ' '"))

    If oResult == .Null. .Or. Empty(oResult:token) .Or. oResult:perfil <> "CONDOMINO" .Or. nTokensDepois <> (nTokensAntes + 1)
        ConOut("[FAIL] TestGcValidarLoginPortal: login valido nao emitiu token/perfil corretos")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarLoginPortal: login valido OK (token emitido, perfil CONDOMINO)")
    EndIf

    // Caso 2: senha incorreta
    oResult := GcValidarLoginPortal(cLogin, "senha-errada")
    If oResult <> .Null.
        ConOut("[FAIL] TestGcValidarLoginPortal: senha incorreta deveria retornar .Null.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarLoginPortal: senha incorreta OK (.Null.)")
    EndIf

    // Caso 3: usuario inexistente
    oResult := GcValidarLoginPortal("test15-usuario-inexistente", "qualquer")
    If oResult <> .Null.
        ConOut("[FAIL] TestGcValidarLoginPortal: usuario inexistente deveria retornar .Null.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarLoginPortal: usuario inexistente OK (.Null.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE USR_LOGIN = '" + cLogin + "'")
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = '" + cLogin + "'")
Return lOk

/*/{Protheus.doc} TestGcInvalidarToken
    Verifica GcInvalidarToken (Task 1.5): revoga (soft-delete) um token
    existente e retorna .T.; retorna .F. para token vazio, token
    inexistente e para uma segunda tentativa de revogar o mesmo token
    (ja revogado). Cria e limpa dados de teste em GCT_TOKEN.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcInvalidarToken()
    Local cToken as character
    Local lOk as logical
    Local aAtivo as array

    lOk := .T.
    cToken := "test15-tok-revogar"

    // Setup
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, TOK_PERFIL) " + ;
        "VALUES ('" + cToken + "', 'admin', 'C15', 'U15', '2026-07-01 10:00:00', '2099-01-01 00:00:00', 0, 'ADMIN')")

    // Caso 1: token vazio
    If GcInvalidarToken("") <> .F.
        ConOut("[FAIL] TestGcInvalidarToken: token vazio deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcInvalidarToken: token vazio OK (.F.)")
    EndIf

    // Caso 2: token inexistente
    If GcInvalidarToken("test15-tok-nao-existe") <> .F.
        ConOut("[FAIL] TestGcInvalidarToken: token inexistente deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcInvalidarToken: token inexistente OK (.F.)")
    EndIf

    // Caso 3: revoga token existente
    If GcInvalidarToken(cToken) <> .T.
        ConOut("[FAIL] TestGcInvalidarToken: revogacao do token existente deveria retornar .T.")
        lOk := .F.
    Else
        aAtivo := TCSqlQuery("SELECT TOKEN FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "' AND D_E_L_E_T_ = ' '")
        If Len(aAtivo) <> 0
            ConOut("[FAIL] TestGcInvalidarToken: token revogado ainda aparece como ativo (D_E_L_E_T_=' ')")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcInvalidarToken: revogacao OK (retornou .T., token some da consulta ativa)")
        EndIf
    EndIf

    // Caso 4: revogar de novo o mesmo token (ja revogado) deve retornar .F.
    If GcInvalidarToken(cToken) <> .F.
        ConOut("[FAIL] TestGcInvalidarToken: revogar token ja revogado deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcInvalidarToken: segunda revogacao OK (.F., ja estava revogado)")
    EndIf

    // Teardown (hard delete, ignora D_E_L_E_T_)
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
Return lOk
