// tests/auditoria_test.prw? Testes das tabelas de auditoria e anomalias
// Verifica criao e existncia das tabelas ANOMALIA_LOG, ALERTA e DASHBOARD_CACHE
#include "totvs.ch"
#include "../src/db.prw"
#include "../src/login.prw"
#include "../src/usuarios.prw"
#include "../src/auth-primitives.prw"
#include "../src/auditoria-rest.prw"

/*/{Protheus.doc} RunAuditoriaTests
    Driver de execucao: `advplc run tests/auditoria_test.prw` so executa a
    primeira User Function do arquivo (limitacao do advplc v2.0.3 - nao
    existe suporte a `arquivo::Funcao` nem descoberta automatica de todas
    as funcoes `Test*`), entao esta funcao roda em sequencia todas as
    suites deste arquivo e agrega o resultado. As 3 suites
    TestAuthValidateToken/TestAuthLoginRestEndpoint/TestAuthLogoutRestEndpoint
    (Task 2, endpoints REST) verificam o JSON de retorno via operador `$`
    (contains) em vez de JsonObject():parse(), que nao esta implementado
    no advplc v2.0.3 (erro "unknown method PARSE on JsonObject", nao
    tratavel via Try/Catch por ser erro de metodo desconhecido na VM).
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
    If !TestAuthValidateToken()
        lOk := .F.
    EndIf
    If !TestAuthLoginRestEndpoint()
        lOk := .F.
    EndIf
    If !TestAuthLogoutRestEndpoint()
        lOk := .F.
    EndIf
    If !TestAuditoriaAnomaliaRestEndpoint()
        lOk := .F.
    EndIf
    If !TestAuditoriaDashboardRestEndpoint()
        lOk := .F.
    EndIf
    If !TestAuditoriaAlertasRestEndpoint()
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
    Verifica que um token valido retorna {ok: true, perfil, unidades} via
    GcAuthValidateRestToken, e que um token inexistente retorna
    {ok: false}. Checa o JSON de retorno via operador `$` (contains) pois
    JsonObject():parse() nao esta implementado no advplc v2.0.3. Cria e
    limpa um token de teste em GCT_TOKEN.
    @type Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se o teste passou
*/
User Function TestAuthValidateToken()
    Local cToken as character
    Local cValido as character
    Local cJson as character
    Local lOk as logical

    lOk := .T.
    cToken := "test2-tok-validate"
    cValido := DTOS(Date() + 2)
    cValido := SubStr(cValido, 1, 4) + "-" + SubStr(cValido, 5, 2) + "-" + SubStr(cValido, 7, 2) + " 23:59:59"

    // Setup
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, TOK_PERFIL) " + ;
        "VALUES ('" + cToken + "', 'admin', 'C15', 'U15', '2026-07-01 10:00:00', '" + cValido + "', 0, 'ADMIN')")

    // Caso 1: token valido
    cJson := GcAuthValidateRestToken(cToken)
    If !('"ok": true' $ cJson) .Or. !('"perfil": "ADMIN"' $ cJson)
        ConOut("[FAIL] TestAuthValidateToken: token valido nao retornou ok=true/perfil=ADMIN. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuthValidateToken: token valido OK (ok=true, perfil=ADMIN)")
    EndIf

    // Caso 2: token inexistente
    cJson := GcAuthValidateRestToken("test2-tok-inexistente")
    If !('"ok": false' $ cJson)
        ConOut("[FAIL] TestAuthValidateToken: token inexistente deveria retornar ok=false. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuthValidateToken: token inexistente OK (ok=false)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
Return lOk

/*/{Protheus.doc} TestAuthLoginRestEndpoint
    Verifica que login com credenciais validas retorna token via
    GcAuthLoginRestEndpoint, e que credenciais invalidas retornam
    ok=false. Checa o JSON de retorno via operador `$` (contains) pois
    JsonObject():parse() nao esta implementado no advplc v2.0.3. Cria e
    limpa um usuario de teste em USR.
    @type Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se o teste passou
*/
User Function TestAuthLoginRestEndpoint()
    Local cLogin as character
    Local cSenha as character
    Local cJson as character
    Local lOk as logical

    lOk := .T.
    cLogin := "test2user"
    cSenha := "test2senha"

    // Setup
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE USR_LOGIN = '" + cLogin + "'")
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = '" + cLogin + "'")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('" + cLogin + "', '" + FWHash(cSenha) + "', 'CONDOMINO')")

    // Caso 1: credenciais validas
    cJson := GcAuthLoginRestEndpoint(cLogin, cSenha)
    If !('"ok": true' $ cJson) .Or. !('"perfil": "CONDOMINO"' $ cJson) .Or. !('"token": "' $ cJson)
        ConOut("[FAIL] TestAuthLoginRestEndpoint: login valido nao retornou ok=true/token/perfil. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuthLoginRestEndpoint: login valido OK (ok=true, token recebido, perfil CONDOMINO)")
    EndIf

    // Caso 2: credenciais invalidas
    cJson := GcAuthLoginRestEndpoint(cLogin, "senha-errada")
    If !('"ok": false' $ cJson)
        ConOut("[FAIL] TestAuthLoginRestEndpoint: credenciais invalidas deveriam retornar ok=false. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuthLoginRestEndpoint: credenciais invalidas OK (ok=false)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE USR_LOGIN = '" + cLogin + "'")
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = '" + cLogin + "'")
Return lOk

/*/{Protheus.doc} TestAuthLogoutRestEndpoint
    Verifica que logout invalida o token via GcAuthLogoutRestEndpoint
    (ok=true e token some das consultas ativas), e que revogar de novo o
    mesmo token retorna ok=false. Checa o JSON de retorno via operador
    `$` (contains) pois JsonObject():parse() nao esta implementado no
    advplc v2.0.3. Cria e limpa um token de teste em GCT_TOKEN.
    @type Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se o teste passou
*/
User Function TestAuthLogoutRestEndpoint()
    Local cToken as character
    Local cJson as character
    Local lOk as logical
    Local aAtivo as array

    lOk := .T.
    cToken := "test2-tok-logout"

    // Setup
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, TOK_PERFIL) " + ;
        "VALUES ('" + cToken + "', 'admin', 'C15', 'U15', '2026-07-01 10:00:00', '2099-01-01 00:00:00', 0, 'ADMIN')")

    // Caso 1: logout de token existente
    cJson := GcAuthLogoutRestEndpoint(cToken)
    If !('"ok": true' $ cJson)
        ConOut("[FAIL] TestAuthLogoutRestEndpoint: logout deveria retornar ok=true. JSON=" + cJson)
        lOk := .F.
    Else
        aAtivo := TCSqlQuery("SELECT TOKEN FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "' AND D_E_L_E_T_ = ' '")
        If Len(aAtivo) <> 0
            ConOut("[FAIL] TestAuthLogoutRestEndpoint: token revogado ainda aparece como ativo")
            lOk := .F.
        Else
            ConOut("[PASS] TestAuthLogoutRestEndpoint: logout efetuado com sucesso (ok=true, token revogado)")
        EndIf
    EndIf

    // Caso 2: logout de token ja revogado
    cJson := GcAuthLogoutRestEndpoint(cToken)
    If !('"ok": false' $ cJson)
        ConOut("[FAIL] TestAuthLogoutRestEndpoint: segundo logout deveria retornar ok=false. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuthLogoutRestEndpoint: segundo logout OK (ok=false, ja estava revogado)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM GCT_TOKEN WHERE TOKEN = '" + cToken + "'")
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

/*/{Protheus.doc} TestAuditoriaAnomaliaRestEndpoint
    Verifica GcAuditoriaAnomaliaRestEndpoint (Task 4): consulta por
    periodo retorna todas as anomalias daquele periodo (varios tipos);
    consulta por periodo + tipo filtra apenas o tipo pedido; periodo sem
    anomalias retorna array vazio "[]". Checa o JSON de retorno via
    operador `$` (contains) pois JsonObject():parse() nao esta
    implementado no advplc v2.0.3. Cria e limpa dados de teste em
    ANOMALIA_LOG.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestAuditoriaAnomaliaRestEndpoint()
    Local cPeriodo as character
    Local cJson as character
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9999-01"

    // Setup
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "'")
    TCSqlExec("INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_UNIDADE, ANL_VALOR, ANL_DESCRICAO, ANL_CRIADO_EM, ANL_STATUS) " + ;
        "VALUES ('DESEQUILIBRIO', '" + cPeriodo + "', 'T99', 123.45, 'teste desequilibrio', '2026-07-31 10:00:00', 'ABERTO')")
    TCSqlExec("INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_UNIDADE, ANL_VALOR, ANL_DESCRICAO, ANL_CRIADO_EM, ANL_STATUS) " + ;
        "VALUES ('LAN_ORFAO', '" + cPeriodo + "', 'T98', 67.89, 'teste lancamento orfao', '2026-07-31 11:00:00', 'ABERTO')")

    // Caso 1: sem filtro de tipo, retorna as 2 anomalias do periodo
    cJson := GcAuditoriaAnomaliaRestEndpoint(cPeriodo, "")
    If !('"tipo": "DESEQUILIBRIO"' $ cJson) .Or. !('"tipo": "LAN_ORFAO"' $ cJson)
        ConOut("[FAIL] TestAuditoriaAnomaliaRestEndpoint: sem filtro deveria retornar as 2 anomalias. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuditoriaAnomaliaRestEndpoint: sem filtro OK (2 anomalias do periodo)")
    EndIf

    // Caso 2: com filtro de tipo, retorna apenas o tipo pedido
    cJson := GcAuditoriaAnomaliaRestEndpoint(cPeriodo, "DESEQUILIBRIO")
    If !('"tipo": "DESEQUILIBRIO"' $ cJson) .Or. ('"tipo": "LAN_ORFAO"' $ cJson)
        ConOut("[FAIL] TestAuditoriaAnomaliaRestEndpoint: filtro por tipo nao isolou DESEQUILIBRIO. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuditoriaAnomaliaRestEndpoint: filtro por tipo OK (apenas DESEQUILIBRIO)")
    EndIf

    // Caso 3: periodo sem anomalias retorna array vazio
    cJson := GcAuditoriaAnomaliaRestEndpoint("9999-02", "")
    If AllTrim(cJson) <> "[]"
        ConOut("[FAIL] TestAuditoriaAnomaliaRestEndpoint: periodo sem dados deveria retornar []. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuditoriaAnomaliaRestEndpoint: periodo sem dados OK ([])")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "'")
Return lOk

/*/{Protheus.doc} TestAuditoriaDashboardRestEndpoint
    Verifica GcAuditoriaDashboardRestEndpoint (Task 4): periodo com
    registro em DASHBOARD_CACHE retorna os contadores gravados; periodo
    sem cache retorna todos os contadores zerados. Checa o JSON de
    retorno via operador `$` (contains) pois JsonObject():parse() nao
    esta implementado no advplc v2.0.3. Cria e limpa dados de teste em
    DASHBOARD_CACHE.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestAuditoriaDashboardRestEndpoint()
    Local cPeriodo as character
    Local cJson as character
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9999-03"

    // Setup
    TCSqlExec("DELETE FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodo + "'")
    TCSqlExec("INSERT INTO DASHBOARD_CACHE (DSH_DATA, DSH_PERIODO, DSH_ANOMALIAS_TOTAL, DSH_DESEQUILIBRIO_COUNT, " + ;
        "DSH_LAN_ORFAO_COUNT, DSH_COB_ORFAO_COUNT, DSH_RATEIO_INVALID_COUNT, DSH_TIMING_COUNT, DSH_USUARIO_COUNT, " + ;
        "DSH_JSON, DSH_ATUALIZADO_EM) VALUES ('2026-07-31', '" + cPeriodo + "', 6, 2, 1, 1, 1, 1, 0, '{}', '2026-07-31 12:00:00')")

    // Caso 1: periodo com cache retorna contadores gravados
    cJson := GcAuditoriaDashboardRestEndpoint(cPeriodo)
    If !('"total": 6' $ cJson) .Or. !('"desequilibrio": 2' $ cJson) .Or. !('"lancamento_orfao": 1' $ cJson)
        ConOut("[FAIL] TestAuditoriaDashboardRestEndpoint: cache existente nao retornou contadores corretos. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuditoriaDashboardRestEndpoint: cache existente OK (contadores corretos)")
    EndIf

    // Caso 2: periodo sem cache retorna tudo zerado
    cJson := GcAuditoriaDashboardRestEndpoint("9999-04")
    If !('"total": 0' $ cJson) .Or. !('"desequilibrio": 0' $ cJson)
        ConOut("[FAIL] TestAuditoriaDashboardRestEndpoint: periodo sem cache deveria retornar zeros. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuditoriaDashboardRestEndpoint: periodo sem cache OK (zeros)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodo + "'")
Return lOk

/*/{Protheus.doc} TestAuditoriaAlertasRestEndpoint
    Verifica GcAuditoriaAlertasRestEndpoint (Task 4): retorna alertas com
    ALT_VISTO = 0 (nao lidos), e nao retorna alertas com ALT_VISTO = 1
    (ja vistos). Checa o JSON de retorno via operador `$` (contains) pois
    JsonObject():parse() nao esta implementado no advplc v2.0.3. Cria e
    limpa dados de teste em ALERTA.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestAuditoriaAlertasRestEndpoint()
    Local cJson as character
    Local lOk as logical
    Local cMsgNaoLido as character
    Local cMsgLido as character

    lOk := .T.
    cMsgNaoLido := "teste alerta nao lido 9999"
    cMsgLido := "teste alerta ja lido 9999"

    // Setup
    TCSqlExec("DELETE FROM ALERTA WHERE ALT_MENSAGEM = '" + cMsgNaoLido + "' OR ALT_MENSAGEM = '" + cMsgLido + "'")
    TCSqlExec("INSERT INTO ALERTA (ALT_TIPO, ALT_MENSAGEM, ALT_CRIADO_EM, ALT_VISTO) " + ;
        "VALUES ('CRITICO', '" + cMsgNaoLido + "', '2026-07-31 13:00:00', 0)")
    TCSqlExec("INSERT INTO ALERTA (ALT_TIPO, ALT_MENSAGEM, ALT_CRIADO_EM, ALT_VISTO) " + ;
        "VALUES ('CRITICO', '" + cMsgLido + "', '2026-07-31 13:30:00', 1)")

    cJson := GcAuditoriaAlertasRestEndpoint()

    If !(cMsgNaoLido $ cJson)
        ConOut("[FAIL] TestAuditoriaAlertasRestEndpoint: alerta nao lido deveria aparecer no retorno. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuditoriaAlertasRestEndpoint: alerta nao lido presente no retorno")
    EndIf

    If cMsgLido $ cJson
        ConOut("[FAIL] TestAuditoriaAlertasRestEndpoint: alerta ja lido nao deveria aparecer no retorno. JSON=" + cJson)
        lOk := .F.
    Else
        ConOut("[PASS] TestAuditoriaAlertasRestEndpoint: alerta ja lido corretamente ausente do retorno")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ALERTA WHERE ALT_MENSAGEM = '" + cMsgNaoLido + "' OR ALT_MENSAGEM = '" + cMsgLido + "'")
Return lOk
