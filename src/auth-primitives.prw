// src/auth-primitives.prw — Portal v2 auth primitives (Task 1.5, prerequisite
// for Task 2's REST auth endpoints in src/auditoria-rest.prw).
// Non-interactive equivalents of the interactive admin flows already in
// src/usuarios.prw (GcGerarToken/GcRevogarToken, UI-driven, single condomino
// picked from a list) and src/login.prw (GcCredenciaisValidas, admin-only
// login gate) — safe to call from a stateless REST handler: no
// MsgInfo/MsgStop/MsgYesNo, no globals.
#include "totvs.ch"

/*/{Protheus.doc} GcValidarToken
    Valida um token da tabela GCT_TOKEN sem nenhuma interação com o
    usuário. Perfil default 'CONDOMINO' quando TOK_PERFIL está vazio —
    cobre os tokens já emitidos pelo fluxo interativo GcGerarToken
    (src/usuarios.prw), anterior à coluna TOK_PERFIL, que sempre
    representam acesso de condômino a uma única unidade.
    @type User Function
    @author Claude
    @since 2026-07-31
    @param cToken, character, valor do token
    @return oToken, object, JsonObject {ativo, expirado, perfil, usuario, unidades_permitidas}
*/
User Function GcValidarToken(cToken as character) as object
    Local oToken as object
    Local aResult as array
    Local dValidoAte as date
    Local lExpirado as logical
    Local lUsado as logical
    Local cPerfil as character

    oToken := JsonObject():new()

    If Empty(cToken)
        oToken:ativo := .F.
        oToken:expirado := .T.
        Return oToken
    EndIf

    aResult := TCSqlQuery("SELECT TOK_PERFIL, USR_LOGIN, UNI_CODIGO, VALIDO_ATE, USADO " + ;
        "FROM GCT_TOKEN WHERE TOKEN = '" + GcSqlLit(cToken) + "' AND D_E_L_E_T_ = ' '")

    If Len(aResult) == 0
        oToken:ativo := .F.
        oToken:expirado := .T.
        Return oToken
    EndIf

    dValidoAte := GcIsoToDate(aResult[1]:VALIDO_ATE)
    lExpirado := (dValidoAte < Date())
    lUsado := (Val(aResult[1]:USADO) <> 0)

    cPerfil := aResult[1]:TOK_PERFIL
    If Empty(cPerfil)
        cPerfil := "CONDOMINO"
    EndIf

    oToken:ativo := !lUsado .And. !lExpirado
    oToken:expirado := lExpirado
    oToken:perfil := cPerfil
    oToken:usuario := aResult[1]:USR_LOGIN
    oToken:unidades_permitidas := {aResult[1]:UNI_CODIGO}
Return oToken

/*/{Protheus.doc} GcValidarLoginPortal
    Valida usuário/senha (reaproveita GcCredenciaisValidas de
    src/login.prw, que já compara a senha por hash via FWHash — nunca em
    texto puro) e, se válidas, emite um novo token em GCT_TOKEN com o
    perfil do usuário (USR_PERFIL, default 'ADMIN' se vazio) e validade
    de 30 dias. Sem interação com o usuário. Usado pelo endpoint REST
    POST /auth/login (src/auditoria-rest.prw::GcAuthLoginRestEndpoint).
    @type User Function
    @author Claude
    @since 2026-07-31
    @param cUsername, character, login (USR_LOGIN)
    @param cPassword, character, senha em texto puro (comparada por hash)
    @return oResult, object, JsonObject {token, perfil, unidades_permitidas} — ou .Null. se credenciais inválidas
*/
User Function GcValidarLoginPortal(cUsername as character, cPassword as character) as object
    Local aPerfil as array
    Local cToken as character
    Local cPerfil as character
    Local dValidade as date
    Local cCriadoIso as character
    Local cValidoIso as character
    Local oResult as object

    If Empty(cUsername) .Or. Empty(cPassword)
        Return .Null.
    EndIf

    If !GcCredenciaisValidas(cUsername, cPassword)
        Return .Null.
    EndIf

    aPerfil := TCSqlQuery("SELECT USR_PERFIL FROM USR WHERE USR_LOGIN = '" + GcSqlLit(cUsername) + ;
        "' AND D_E_L_E_T_ = ' '")

    cPerfil := "ADMIN"
    If Len(aPerfil) > 0 .And. !Empty(aPerfil[1]:USR_PERFIL)
        cPerfil := aPerfil[1]:USR_PERFIL
    EndIf

    // CON_CODIGO vazio: token de login admin não representa um condômino
    // específico. UNI_CODIGO '000': unidade sentinela usada como
    // "todas as unidades" — a mesma convenção já adotada pela spec do
    // Task 2 (unidades_permitidas := {"000"}).
    cToken := GcGerarTokenUnico()
    cCriadoIso := GcDataHoraIso(Date())
    dValidade := Date() + 30
    cValidoIso := GcDataHoraIso(dValidade)

    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, TOK_PERFIL) " + ;
        "VALUES ('" + GcSqlLit(cToken) + "', '" + GcSqlLit(cUsername) + "', '', '000', " + ;
        "'" + GcSqlLit(cCriadoIso) + "', '" + GcSqlLit(cValidoIso) + "', 0, '" + GcSqlLit(cPerfil) + "')")

    oResult := JsonObject():new()
    oResult:token := cToken
    oResult:perfil := cPerfil
    oResult:unidades_permitidas := {"000"}
Return oResult

/*/{Protheus.doc} GcInvalidarToken
    Revoga um token (soft-delete D_E_L_E_T_='*'), versão não-interativa
    de GcRevogarToken (src/usuarios.prw, que lista tokens e pede
    confirmação ao admin). Usado pelo endpoint REST POST /auth/logout
    (src/auditoria-rest.prw::GcAuthLogoutRestEndpoint).
    @type User Function
    @author Claude
    @since 2026-07-31
    @param cToken, character, valor do token
    @return lOk, logical, .T. se revogado, .F. se o token não existe (ou já estava revogado/expirado logicamente)
*/
User Function GcInvalidarToken(cToken as character) as logical
    Local aResult as array

    If Empty(cToken)
        Return .F.
    EndIf

    aResult := TCSqlQuery("SELECT TOKEN FROM GCT_TOKEN WHERE TOKEN = '" + GcSqlLit(cToken) + ;
        "' AND D_E_L_E_T_ = ' '")

    If Len(aResult) == 0
        Return .F.
    EndIf

    TCSqlExec("UPDATE GCT_TOKEN SET D_E_L_E_T_ = '*', R_E_C_D_E_L_ = " + cValToChar(Seconds()) + ;
        " WHERE TOKEN = '" + GcSqlLit(cToken) + "' AND D_E_L_E_T_ = ' '")
Return .T.

/*/{Protheus.doc} GcGerarTokenUnico
    Gera um token único. Thin wrapper sobre GcGerarTokenId
    (src/usuarios.prw) — mesma geração timestamp+random+FWHash já usada
    por GcGerarToken, exposta aqui com o nome pedido pelo Task 1.5 para
    quem só depende do primitivo de autenticação e não quer acoplar em
    src/usuarios.prw diretamente.
    @type User Function
    @author Claude
    @since 2026-07-31
    @return cToken, character, token único de 36 chars (formato UUID-like)
*/
User Function GcGerarTokenUnico() as character
Return GcGerarTokenId()

/*/{Protheus.doc} GcIsoToDate
    Converte string ISO 8601 ("YYYY-MM-DD" ou "YYYY-MM-DD HH:MM:SS",
    formato gravado em VALIDO_ATE/CRIPTADO) para Date. Contraparte de
    GcDateToIso (src/usuarios.prw, Static/file-private, por isso
    reimplementada aqui).
    @type Static Function
    @author Claude
    @since 2026-07-31
    @param cIso, character, data em formato ISO (ao menos os 10 primeiros chars YYYY-MM-DD)
    @return dData, date
*/
Static Function GcIsoToDate(cIso as character) as date
    Local cAno := SubStr(cIso, 1, 4)
    Local cMes := SubStr(cIso, 6, 2)
    Local cDia := SubStr(cIso, 9, 2)
Return SToD(cAno + cMes + cDia)

/*/{Protheus.doc} GcDataHoraIso
    Converte Date para string ISO 8601 com a hora atual do sistema
    ("YYYY-MM-DD HH:MM:SS") — mesmo formato usado por GcGerarToken
    (src/usuarios.prw) para CRIPTADO/VALIDO_ATE, o que garante que a
    comparação lexicográfica de string continua válida.
    @type Static Function
    @author Claude
    @since 2026-07-31
    @param dData, date
    @return cIso, character
*/
Static Function GcDataHoraIso(dData as date) as character
    Local cDtos := DtoS(dData)
Return SubStr(cDtos, 1, 4) + "-" + SubStr(cDtos, 5, 2) + "-" + SubStr(cDtos, 7, 2) + " " + Left(Time(), 8)
