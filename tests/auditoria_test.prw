// tests/auditoria_test.prw? Testes das tabelas de auditoria e anomalias
// Verifica criao e existncia das tabelas ANOMALIA_LOG, ALERTA e DASHBOARD_CACHE
#include "totvs.ch"
#include "../src/db.prw"
#include "../src/login.prw"
#include "../src/usuarios.prw"
#include "../src/auth-primitives.prw"
#include "../src/auditoria-validacoes.prw"

/*/{Protheus.doc} RunAuditoriaTests
    Driver de execucao: `advplc run tests/auditoria_test.prw` so executa a
    primeira User Function do arquivo (limitacao do advplc v2.0.3 - nao
    existe suporte a `arquivo::Funcao` nem descoberta automatica de todas
    as funcoes `Test*`), entao esta funcao roda em sequencia todas as
    suites deste arquivo e agrega o resultado.
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
    If !TestGcValidarDesequilibrioContabil()
        lOk := .F.
    EndIf
    If !TestGcValidarLancamentosOrfaos()
        lOk := .F.
    EndIf
    If !TestGcValidarCobrancasOrfaos()
        lOk := .F.
    EndIf
    If !TestGcValidarRateioValido()
        lOk := .F.
    EndIf
    If !TestGcValidarTimingLancamentos()
        lOk := .F.
    EndIf
    If !TestGcValidarAlteracoesEmPeriodoFechado()
        lOk := .F.
    EndIf
    If !TestGcAuditarPeriodoCompleto()
        lOk := .F.
    EndIf
    If !TestGcCriarAlertaCritico()
        lOk := .F.
    EndIf
    If !TestGcAtualizarDashboardCache()
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

User Function TestGcValidarDesequilibrioContabil()
    Local cPeriodo as character
    Local cPeriodoLimpo as character
    Local cDescr as character
    Local nLanId as numeric
    Local aLan as array
    Local aAnomalia as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9995-01"
    cPeriodoLimpo := "9995-91"
    cDescr := "test5-desequilibrio"

    // Setup
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM RATEIO_DETALHE WHERE RAT_LANCAMENTO IN (SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodo + "', '9995-01-01', '9995-01-31', 0, 0, ' ')")
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
        "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) VALUES (" + ;
        "'99950101', '4000', '1000', 100.00, '" + cDescr + "', 'AUTOMATICO_RATEIO', '" + cPeriodo + "', datetime('now'), 'TEST5', ' ')")

    aLan := TCSqlQuery("SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "' ORDER BY LAN_ID DESC LIMIT 1")
    nLanId := Val(aLan[1]:LAN_ID)

    // RATEIO_DETALHE soma apenas 80.00, mas LAN_VALOR = 100.00 -> desequilibrio
    TCSqlExec("INSERT INTO RATEIO_DETALHE (RAT_LANCAMENTO, RAT_UNIDADE, RAT_VALOR, RAT_PERCENTUAL, D_E_L_E_T_) " + ;
        "VALUES (" + AllTrim(Str(nLanId, 10, 0)) + ", '101', 80.00, 80.00, ' ')")

    // Caso 1: periodo com lancamento desbalanceado
    If !GcValidarDesequilibrioContabil(cPeriodo)
        ConOut("[FAIL] TestGcValidarDesequilibrioContabil: deveria retornar .T. para lancamento desbalanceado")
        lOk := .F.
    Else
        aAnomalia := TCSqlQuery("SELECT ANL_ID FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "' AND ANL_TIPO = 'DESEQUILIBRIO_CONTABIL' AND D_E_L_E_T_ = ' '")
        If Len(aAnomalia) == 0
            ConOut("[FAIL] TestGcValidarDesequilibrioContabil: retornou .T. mas nao gravou em ANOMALIA_LOG")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcValidarDesequilibrioContabil: desequilibrio detectado e gravado em ANOMALIA_LOG")
        EndIf
    EndIf

    // Caso 2: periodo limpo (sem lancamentos)
    If GcValidarDesequilibrioContabil(cPeriodoLimpo)
        ConOut("[FAIL] TestGcValidarDesequilibrioContabil: periodo limpo deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarDesequilibrioContabil: periodo limpo OK (.F.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM RATEIO_DETALHE WHERE RAT_LANCAMENTO IN (SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
Return lOk

/*/{Protheus.doc} TestGcValidarLancamentosOrfaos
    Verifica GcValidarLancamentosOrfaos (Task 5): um lancamento
    AUTOMATICO_RATEIO sem cobranca (COB) correspondente por
    competencia+valor deve ser detectado (retorna .T., grava 1 linha em
    ANOMALIA_LOG com ANL_TIPO = LAN_ORFAO); periodo sem lancamentos orfaos
    retorna .F. Cria e limpa dados de teste em LANCAMENTOS.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcValidarLancamentosOrfaos()
    Local cPeriodo as character
    Local cPeriodoLimpo as character
    Local cDescr as character
    Local aAnomalia as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9995-02"
    cPeriodoLimpo := "9995-92"
    cDescr := "test5-lanorfao"

    // Setup
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO = '" + cPeriodo + "'")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodo + "', '9995-02-01', '9995-02-28', 0, 0, ' ')")
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
        "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) VALUES (" + ;
        "'99950201', '4000', '1000', 50.00, '" + cDescr + "', 'AUTOMATICO_RATEIO', '" + cPeriodo + "', datetime('now'), 'TEST5', ' ')")

    // Caso 1: lancamento sem cobranca correspondente (50.00 em '9995-02', nenhuma COB casa)
    If !GcValidarLancamentosOrfaos(cPeriodo)
        ConOut("[FAIL] TestGcValidarLancamentosOrfaos: deveria retornar .T. para lancamento orfao")
        lOk := .F.
    Else
        aAnomalia := TCSqlQuery("SELECT ANL_ID FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "' AND ANL_TIPO = 'LAN_ORFAO' AND D_E_L_E_T_ = ' '")
        If Len(aAnomalia) == 0
            ConOut("[FAIL] TestGcValidarLancamentosOrfaos: retornou .T. mas nao gravou em ANOMALIA_LOG")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcValidarLancamentosOrfaos: lancamento orfao detectado e gravado em ANOMALIA_LOG")
        EndIf
    EndIf

    // Caso 2: periodo limpo (sem lancamentos)
    If GcValidarLancamentosOrfaos(cPeriodoLimpo)
        ConOut("[FAIL] TestGcValidarLancamentosOrfaos: periodo limpo deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarLancamentosOrfaos: periodo limpo OK (.F.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO = '" + cPeriodo + "'")
Return lOk

/*/{Protheus.doc} TestGcValidarCobrancasOrfaos
    Verifica GcValidarCobrancasOrfaos (Task 5): uma cobranca (COB) sem
    lancamento AUTOMATICO_RATEIO correspondente por competencia+valor deve
    ser detectada (retorna .T., grava 1 linha em ANOMALIA_LOG com ANL_TIPO
    = COB_ORFAO); periodo sem cobrancas orfas retorna .F. Cria e limpa
    dados de teste em COB.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcValidarCobrancasOrfaos()
    Local cPeriodo as character
    Local cPeriodoLimpo as character
    Local aAnomalia as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9995-03"
    cPeriodoLimpo := "9995-93"

    // Setup
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "') AND COB_UNIDADE = 'TEST5'")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) " + ;
        "VALUES ('TEST5', '" + cPeriodo + "', 60.00, '" + cPeriodo + "-10', 'pendente', ' ')")

    // Caso 1: cobranca sem lancamento correspondente
    If !GcValidarCobrancasOrfaos(cPeriodo)
        ConOut("[FAIL] TestGcValidarCobrancasOrfaos: deveria retornar .T. para cobranca orfa")
        lOk := .F.
    Else
        aAnomalia := TCSqlQuery("SELECT ANL_ID FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "' AND ANL_TIPO = 'COB_ORFAO' AND D_E_L_E_T_ = ' '")
        If Len(aAnomalia) == 0
            ConOut("[FAIL] TestGcValidarCobrancasOrfaos: retornou .T. mas nao gravou em ANOMALIA_LOG")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcValidarCobrancasOrfaos: cobranca orfa detectada e gravada em ANOMALIA_LOG")
        EndIf
    EndIf

    // Caso 2: periodo limpo (sem cobrancas)
    If GcValidarCobrancasOrfaos(cPeriodoLimpo)
        ConOut("[FAIL] TestGcValidarCobrancasOrfaos: periodo limpo deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarCobrancasOrfaos: periodo limpo OK (.F.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "') AND COB_UNIDADE = 'TEST5'")
Return lOk

/*/{Protheus.doc} TestGcValidarRateioValido
    Verifica GcValidarRateioValido (Task 5): um lancamento AUTOMATICO_RATEIO
    cuja soma de RAT_PERCENTUAL em RATEIO_DETALHE nao fecha em 100% deve
    ser detectado (retorna .T., grava 1 linha em ANOMALIA_LOG com ANL_TIPO
    = RATEIO_INVALIDO); um lancamento cujo rateio fecha em 100% nao e
    sinalizado (.F.). Cria e limpa dados de teste em LANCAMENTOS e
    RATEIO_DETALHE.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcValidarRateioValido()
    Local cPeriodo as character
    Local cPeriodoLimpo as character
    Local cDescr as character
    Local cDescrLimpo as character
    Local nLanId as numeric
    Local aLan as array
    Local aAnomalia as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9995-04"
    cPeriodoLimpo := "9995-94"
    cDescr := "test5-rateiopct"
    cDescrLimpo := "test5-rateiopct-ok"

    // Setup
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM RATEIO_DETALHE WHERE RAT_LANCAMENTO IN (SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR IN ('" + cDescr + "', '" + cDescrLimpo + "'))")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR IN ('" + cDescr + "', '" + cDescrLimpo + "')")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodo + "', '9995-04-01', '9995-04-30', 0, 0, ' ')")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodoLimpo + "', '9995-94-01', '9995-94-30', 0, 0, ' ')")

    // Caso 1: rateio percentual desbalanceado (soma 80%, nao 100%)
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
        "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) VALUES (" + ;
        "'99950401', '4000', '1000', 100.00, '" + cDescr + "', 'AUTOMATICO_RATEIO', '" + cPeriodo + "', datetime('now'), 'TEST5', ' ')")
    aLan := TCSqlQuery("SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "' ORDER BY LAN_ID DESC LIMIT 1")
    nLanId := Val(aLan[1]:LAN_ID)
    TCSqlExec("INSERT INTO RATEIO_DETALHE (RAT_LANCAMENTO, RAT_UNIDADE, RAT_VALOR, RAT_PERCENTUAL, D_E_L_E_T_) " + ;
        "VALUES (" + AllTrim(Str(nLanId, 10, 0)) + ", '101', 40.00, 40.00, ' ')")
    TCSqlExec("INSERT INTO RATEIO_DETALHE (RAT_LANCAMENTO, RAT_UNIDADE, RAT_VALOR, RAT_PERCENTUAL, D_E_L_E_T_) " + ;
        "VALUES (" + AllTrim(Str(nLanId, 10, 0)) + ", '102', 40.00, 40.00, ' ')")

    If !GcValidarRateioValido(cPeriodo)
        ConOut("[FAIL] TestGcValidarRateioValido: deveria retornar .T. para rateio percentual invalido")
        lOk := .F.
    Else
        aAnomalia := TCSqlQuery("SELECT ANL_ID FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "' AND ANL_TIPO = 'RATEIO_INVALIDO' AND D_E_L_E_T_ = ' '")
        If Len(aAnomalia) == 0
            ConOut("[FAIL] TestGcValidarRateioValido: retornou .T. mas nao gravou em ANOMALIA_LOG")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcValidarRateioValido: rateio invalido detectado e gravado em ANOMALIA_LOG")
        EndIf
    EndIf

    // Caso 2: rateio percentual valido (soma 100%) nao deve ser sinalizado
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
        "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) VALUES (" + ;
        "'99950401', '4000', '1000', 100.00, '" + cDescrLimpo + "', 'AUTOMATICO_RATEIO', '" + cPeriodoLimpo + "', datetime('now'), 'TEST5', ' ')")
    aLan := TCSqlQuery("SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescrLimpo + "' ORDER BY LAN_ID DESC LIMIT 1")
    nLanId := Val(aLan[1]:LAN_ID)
    TCSqlExec("INSERT INTO RATEIO_DETALHE (RAT_LANCAMENTO, RAT_UNIDADE, RAT_VALOR, RAT_PERCENTUAL, D_E_L_E_T_) " + ;
        "VALUES (" + AllTrim(Str(nLanId, 10, 0)) + ", '101', 50.00, 50.00, ' ')")
    TCSqlExec("INSERT INTO RATEIO_DETALHE (RAT_LANCAMENTO, RAT_UNIDADE, RAT_VALOR, RAT_PERCENTUAL, D_E_L_E_T_) " + ;
        "VALUES (" + AllTrim(Str(nLanId, 10, 0)) + ", '102', 50.00, 50.00, ' ')")

    If GcValidarRateioValido(cPeriodoLimpo)
        ConOut("[FAIL] TestGcValidarRateioValido: rateio valido (100%) nao deveria ser sinalizado")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarRateioValido: rateio valido OK (.F.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM RATEIO_DETALHE WHERE RAT_LANCAMENTO IN (SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR IN ('" + cDescr + "', '" + cDescrLimpo + "'))")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR IN ('" + cDescr + "', '" + cDescrLimpo + "')")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
Return lOk

/*/{Protheus.doc} TestGcValidarTimingLancamentos
    Verifica GcValidarTimingLancamentos (Task 5): um lancamento cuja
    LAN_DATA e posterior ao COB_VENCTO da cobranca correspondente (casada
    por competencia+valor) deve ser detectado (retorna .T., grava 1 linha
    em ANOMALIA_LOG com ANL_TIPO = TIMING_ANOMALIA); periodo sem anomalia
    de timing retorna .F. Cria e limpa dados de teste em COB e LANCAMENTOS.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcValidarTimingLancamentos()
    Local cPeriodo as character
    Local cPeriodoLimpo as character
    Local cDescr as character
    Local aAnomalia as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9995-05"
    cPeriodoLimpo := "9995-95"
    cDescr := "test5-timing"

    // Setup
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "') AND COB_UNIDADE = 'TEST5'")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO = '" + cPeriodo + "'")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodo + "', '9995-05-01', '9995-05-31', 0, 0, ' ')")

    // Vencimento em 9995-05-10, lancamento em 9995-05-15 (posterior -> anomalia)
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, D_E_L_E_T_) " + ;
        "VALUES ('TEST5', '" + cPeriodo + "', 70.00, '" + cPeriodo + "-10', 'pendente', ' ')")
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
        "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) VALUES (" + ;
        "'99950515', '4000', '1000', 70.00, '" + cDescr + "', 'AUTOMATICO_RATEIO', '" + cPeriodo + "', datetime('now'), 'TEST5', ' ')")

    // Caso 1: lancamento posterior ao vencimento da cobranca
    If !GcValidarTimingLancamentos(cPeriodo)
        ConOut("[FAIL] TestGcValidarTimingLancamentos: deveria retornar .T. para lancamento posterior ao vencimento")
        lOk := .F.
    Else
        aAnomalia := TCSqlQuery("SELECT ANL_ID FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "' AND ANL_TIPO = 'TIMING_ANOMALIA' AND D_E_L_E_T_ = ' '")
        If Len(aAnomalia) == 0
            ConOut("[FAIL] TestGcValidarTimingLancamentos: retornou .T. mas nao gravou em ANOMALIA_LOG")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcValidarTimingLancamentos: timing anomalo detectado e gravado em ANOMALIA_LOG")
        EndIf
    EndIf

    // Caso 2: periodo limpo (sem cobrancas/lancamentos)
    If GcValidarTimingLancamentos(cPeriodoLimpo)
        ConOut("[FAIL] TestGcValidarTimingLancamentos: periodo limpo deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarTimingLancamentos: periodo limpo OK (.F.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "') AND COB_UNIDADE = 'TEST5'")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO = '" + cPeriodo + "'")
Return lOk

/*/{Protheus.doc} TestGcValidarAlteracoesEmPeriodoFechado
    Verifica GcValidarAlteracoesEmPeriodoFechado (Task 5): um lancamento
    soft-deletado (D_E_L_E_T_ <> ' ') cujo exercicio esta fechado
    (EXE_FECHADO = 1) deve ser detectado (retorna .T., grava 1 linha em
    ANOMALIA_LOG com ANL_TIPO = USUARIO_ANOMALIA); um periodo fechado sem
    lancamentos removidos retorna .F. Cria e limpa dados de teste em
    EXERCICIO e LANCAMENTOS.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcValidarAlteracoesEmPeriodoFechado()
    Local cPeriodo as character
    Local cPeriodoLimpo as character
    Local cDescr as character
    Local aAnomalia as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9995-06"
    cPeriodoLimpo := "9995-96"
    cDescr := "test5-fechado"

    // Setup
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodo + "', '9995-06-01', '9995-06-30', 0, 1, ' ')")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodoLimpo + "', '9995-96-01', '9995-96-28', 0, 1, ' ')")

    // Lancamento soft-deletado em periodo fechado
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
        "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) VALUES (" + ;
        "'99950601', '4000', '1000', 90.00, '" + cDescr + "', 'MANUAL', '" + cPeriodo + "', datetime('now'), 'TEST5', '*')")

    // Caso 1: lancamento removido apos fechamento do periodo
    If !GcValidarAlteracoesEmPeriodoFechado(cPeriodo)
        ConOut("[FAIL] TestGcValidarAlteracoesEmPeriodoFechado: deveria retornar .T. para alteracao em periodo fechado")
        lOk := .F.
    Else
        aAnomalia := TCSqlQuery("SELECT ANL_ID FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "' AND ANL_TIPO = 'USUARIO_ANOMALIA' AND D_E_L_E_T_ = ' '")
        If Len(aAnomalia) == 0
            ConOut("[FAIL] TestGcValidarAlteracoesEmPeriodoFechado: retornou .T. mas nao gravou em ANOMALIA_LOG")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcValidarAlteracoesEmPeriodoFechado: alteracao em periodo fechado detectada e gravada em ANOMALIA_LOG")
        EndIf
    EndIf

    // Caso 2: periodo fechado sem lancamentos removidos
    If GcValidarAlteracoesEmPeriodoFechado(cPeriodoLimpo)
        ConOut("[FAIL] TestGcValidarAlteracoesEmPeriodoFechado: periodo fechado sem remocoes deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcValidarAlteracoesEmPeriodoFechado: periodo limpo OK (.F.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
Return lOk

/*/{Protheus.doc} TestGcAuditarPeriodoCompleto
    Verifica GcAuditarPeriodoCompleto (Task 6): roda os 6 validadores em
    sequencia para um periodo com um lancamento AUTOMATICO_RATEIO
    desbalanceado (rateio nao fecha com LAN_VALOR) e espera .T. (alguma
    anomalia encontrada), com pelo menos 1 linha gravada em ANOMALIA_LOG
    (DESEQUILIBRIO_CONTABIL) e o cache do dashboard (DASHBOARD_CACHE)
    atualizado refletindo essa contagem; um periodo totalmente limpo
    retorna .F. e ainda assim grava/atualiza um DASHBOARD_CACHE zerado.
    Cria e limpa dados de teste em EXERCICIO, LANCAMENTOS, RATEIO_DETALHE,
    ANOMALIA_LOG e DASHBOARD_CACHE.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcAuditarPeriodoCompleto()
    Local cPeriodo as character
    Local cPeriodoLimpo as character
    Local cDescr as character
    Local nLanId as numeric
    Local aLan as array
    Local aCache as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9994-01"
    cPeriodoLimpo := "9994-91"
    cDescr := "test6-auditarcompleto"

    // Setup
    TCSqlExec("DELETE FROM DASHBOARD_CACHE WHERE DSH_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM RATEIO_DETALHE WHERE RAT_LANCAMENTO IN (SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodo + "', '9994-01-01', '9994-01-31', 0, 0, ' ')")
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + cPeriodoLimpo + "', '9994-91-01', '9994-91-28', 0, 0, ' ')")
    TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
        "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) VALUES (" + ;
        "'99940101', '4000', '1000', 100.00, '" + cDescr + "', 'AUTOMATICO_RATEIO', '" + cPeriodo + "', datetime('now'), 'TEST6', ' ')")
    aLan := TCSqlQuery("SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "' ORDER BY LAN_ID DESC LIMIT 1")
    nLanId := Val(aLan[1]:LAN_ID)
    // RATEIO_DETALHE soma apenas 80.00, mas LAN_VALOR = 100.00 -> desequilibrio
    TCSqlExec("INSERT INTO RATEIO_DETALHE (RAT_LANCAMENTO, RAT_UNIDADE, RAT_VALOR, RAT_PERCENTUAL, D_E_L_E_T_) " + ;
        "VALUES (" + AllTrim(Str(nLanId, 10, 0)) + ", '101', 80.00, 80.00, ' ')")

    // Caso 1: periodo com anomalia -> .T., ANOMALIA_LOG gravado, DASHBOARD_CACHE atualizado
    If !GcAuditarPeriodoCompleto(cPeriodo)
        ConOut("[FAIL] TestGcAuditarPeriodoCompleto: periodo com lancamento desbalanceado deveria retornar .T.")
        lOk := .F.
    Else
        aCache := TCSqlQuery("SELECT DSH_ANOMALIAS_TOTAL, DSH_DESEQUILIBRIO_COUNT FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodo + "' AND D_E_L_E_T_ = ' '")
        If Len(aCache) == 0
            ConOut("[FAIL] TestGcAuditarPeriodoCompleto: nao gravou DASHBOARD_CACHE para o periodo")
            lOk := .F.
        ElseIf Val(aCache[1]:DSH_ANOMALIAS_TOTAL) < 1 .Or. Val(aCache[1]:DSH_DESEQUILIBRIO_COUNT) < 1
            ConOut("[FAIL] TestGcAuditarPeriodoCompleto: DASHBOARD_CACHE nao refletiu a anomalia detectada")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcAuditarPeriodoCompleto: anomalia detectada e DASHBOARD_CACHE atualizado corretamente")
        EndIf
    EndIf

    // Caso 2: periodo totalmente limpo -> .F., mas ainda assim atualiza DASHBOARD_CACHE (zerado)
    If GcAuditarPeriodoCompleto(cPeriodoLimpo)
        ConOut("[FAIL] TestGcAuditarPeriodoCompleto: periodo limpo deveria retornar .F.")
        lOk := .F.
    Else
        aCache := TCSqlQuery("SELECT DSH_ANOMALIAS_TOTAL FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodoLimpo + "' AND D_E_L_E_T_ = ' '")
        If Len(aCache) == 0 .Or. Val(aCache[1]:DSH_ANOMALIAS_TOTAL) <> 0
            ConOut("[FAIL] TestGcAuditarPeriodoCompleto: periodo limpo deveria gravar DASHBOARD_CACHE zerado")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcAuditarPeriodoCompleto: periodo limpo OK (.F., DASHBOARD_CACHE zerado)")
        EndIf
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM DASHBOARD_CACHE WHERE DSH_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
    TCSqlExec("DELETE FROM RATEIO_DETALHE WHERE RAT_LANCAMENTO IN (SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_DESCR = '" + cDescr + "'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('" + cPeriodo + "', '" + cPeriodoLimpo + "')")
Return lOk

/*/{Protheus.doc} TestGcCriarAlertaCritico
    Verifica GcCriarAlertaCritico (Task 6): tipo e mensagem validos gravam
    uma linha ativa em ALERTA (ALT_VISTO = 0) e retornam .T.; tipo vazio ou
    mensagem vazia retornam .F. sem gravar nada. Cria e limpa dados de
    teste em ALERTA.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcCriarAlertaCritico()
    Local cMsg as character
    Local aAlerta as array
    Local lOk as logical

    lOk := .T.
    cMsg := "test6-alerta-critico"

    // Setup
    TCSqlExec("DELETE FROM ALERTA WHERE ALT_MENSAGEM = '" + cMsg + "'")

    // Caso 1: tipo e mensagem validos
    If !GcCriarAlertaCritico("CRITICO", cMsg)
        ConOut("[FAIL] TestGcCriarAlertaCritico: alerta valido deveria retornar .T.")
        lOk := .F.
    Else
        aAlerta := TCSqlQuery("SELECT ALT_TIPO, ALT_VISTO FROM ALERTA WHERE ALT_MENSAGEM = '" + cMsg + "' AND D_E_L_E_T_ = ' '")
        If Len(aAlerta) == 0 .Or. AllTrim(aAlerta[1]:ALT_TIPO) <> "CRITICO" .Or. Val(aAlerta[1]:ALT_VISTO) <> 0
            ConOut("[FAIL] TestGcCriarAlertaCritico: alerta nao foi gravado corretamente em ALERTA")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcCriarAlertaCritico: alerta gravado corretamente (tipo CRITICO, nao visto)")
        EndIf
    EndIf

    // Caso 2: tipo vazio
    If GcCriarAlertaCritico("", cMsg)
        ConOut("[FAIL] TestGcCriarAlertaCritico: tipo vazio deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcCriarAlertaCritico: tipo vazio OK (.F.)")
    EndIf

    // Caso 3: mensagem vazia
    If GcCriarAlertaCritico("CRITICO", "")
        ConOut("[FAIL] TestGcCriarAlertaCritico: mensagem vazia deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("[PASS] TestGcCriarAlertaCritico: mensagem vazia OK (.F.)")
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM ALERTA WHERE ALT_MENSAGEM = '" + cMsg + "'")
Return lOk

/*/{Protheus.doc} TestGcAtualizarDashboardCache
    Verifica GcAtualizarDashboardCache (Task 6): dado um periodo com
    linhas ativas em ANOMALIA_LOG de varios tipos, grava/atualiza uma
    unica linha em DASHBOARD_CACHE com os contadores corretos por tipo e
    o total somado; rodar a funcao 2 vezes seguidas para o mesmo periodo
    nao duplica a linha (substitui a anterior via delete+insert). Cria e
    limpa dados de teste em ANOMALIA_LOG e DASHBOARD_CACHE.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return lOk, logical, .T. se todos os casos passaram
*/
User Function TestGcAtualizarDashboardCache()
    Local cPeriodo as character
    Local aCache as array
    Local lOk as logical

    lOk := .T.
    cPeriodo := "9994-02"

    // Setup
    TCSqlExec("DELETE FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodo + "'")
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "'")
    TCSqlExec("INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) " + ;
        "VALUES ('DESEQUILIBRIO_CONTABIL', '" + cPeriodo + "', 10.00, 'test6-cache-1', datetime('now'), 'ABERTO', ' ')")
    TCSqlExec("INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) " + ;
        "VALUES ('LAN_ORFAO', '" + cPeriodo + "', 1.00, 'test6-cache-2', datetime('now'), 'ABERTO', ' ')")
    TCSqlExec("INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) " + ;
        "VALUES ('LAN_ORFAO', '" + cPeriodo + "', 1.00, 'test6-cache-3', datetime('now'), 'ABERTO', ' ')")

    // Caso 1: primeira atualizacao grava contadores corretos (1 desequilibrio, 2 lan_orfao, total 3)
    If !GcAtualizarDashboardCache(cPeriodo)
        ConOut("[FAIL] TestGcAtualizarDashboardCache: deveria retornar .T.")
        lOk := .F.
    Else
        aCache := TCSqlQuery("SELECT DSH_ANOMALIAS_TOTAL, DSH_DESEQUILIBRIO_COUNT, DSH_LAN_ORFAO_COUNT FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodo + "' AND D_E_L_E_T_ = ' '")
        If Len(aCache) <> 1
            ConOut("[FAIL] TestGcAtualizarDashboardCache: esperava exatamente 1 linha em DASHBOARD_CACHE, achou " + AllTrim(Str(Len(aCache), 5, 0)))
            lOk := .F.
        ElseIf Val(aCache[1]:DSH_ANOMALIAS_TOTAL) <> 3 .Or. Val(aCache[1]:DSH_DESEQUILIBRIO_COUNT) <> 1 .Or. Val(aCache[1]:DSH_LAN_ORFAO_COUNT) <> 2
            ConOut("[FAIL] TestGcAtualizarDashboardCache: contadores incorretos (total=" + AllTrim(Str(Val(aCache[1]:DSH_ANOMALIAS_TOTAL), 10, 0)) + ;
                ", desequilibrio=" + AllTrim(Str(Val(aCache[1]:DSH_DESEQUILIBRIO_COUNT), 10, 0)) + ;
                ", lan_orfao=" + AllTrim(Str(Val(aCache[1]:DSH_LAN_ORFAO_COUNT), 10, 0)) + ")")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcAtualizarDashboardCache: contadores corretos (total=3, desequilibrio=1, lan_orfao=2)")
        EndIf
    EndIf

    // Caso 2: segunda chamada para o mesmo periodo nao duplica a linha (delete+insert)
    If !GcAtualizarDashboardCache(cPeriodo)
        ConOut("[FAIL] TestGcAtualizarDashboardCache: segunda chamada deveria retornar .T.")
        lOk := .F.
    Else
        aCache := TCSqlQuery("SELECT DSH_ID FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodo + "' AND D_E_L_E_T_ = ' '")
        If Len(aCache) <> 1
            ConOut("[FAIL] TestGcAtualizarDashboardCache: segunda chamada duplicou a linha em DASHBOARD_CACHE (" + AllTrim(Str(Len(aCache), 5, 0)) + " linhas)")
            lOk := .F.
        Else
            ConOut("[PASS] TestGcAtualizarDashboardCache: segunda chamada nao duplicou a linha (delete+insert OK)")
        EndIf
    EndIf

    // Teardown
    TCSqlExec("DELETE FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + cPeriodo + "'")
    TCSqlExec("DELETE FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + cPeriodo + "'")
Return lOk
