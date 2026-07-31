// src/auditoria-rest.prw — REST API auth endpoints (Portal v3 + Auditoria Dashboard)
// Reutiliza sistema de tokens do Portal v2 (GcValidarToken, GcValidarLoginPortal,
// GcInvalidarToken) para autenticação stateless via REST.
#include "totvs.ch"

/*{Protheus.doc}
Validate token for REST API
@type Function
@author Claude
@since 2026-07-30
@param cToken Character auth token
@return Character JSON {ok, perfil, unidades}
/*/
User Function GcAuthValidateRestToken(cToken as character) as character
  Local oToken as object
  Local oResult as object

  oToken := GcValidarToken(cToken)
  oResult := JsonObject():new()

  If oToken <> .Null. .And. oToken:ativo .And. !oToken:expirado
    oResult["ok"] := .T.
    oResult["perfil"] := oToken:perfil
    oResult["unidades"] := oToken:unidades_permitidas
  Else
    oResult["ok"] := .F.
    oResult["erro"] := "Token inválido ou expirado"
  EndIf

Return oResult:toJson()

/*{Protheus.doc}
REST endpoint: GET /auditoria/anomalias?periodo=2025-01&tipo=DESEQUILIBRIO
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character period (YYYY-MM)
@param cTipo Character anomaly type (optional, empty = all)
@return Character JSON array of anomalias
/*/
User Function GcAuditoriaAnomaliaRestEndpoint(cPeriodo as character, cTipo as character) as character
  Local cQuery as character
  Local aAnomalias as array := {}
  Local oResult as object

  cQuery := "SELECT ANL_ID, ANL_TIPO, ANL_PERIODO, ANL_UNIDADE, ANL_VALOR, ANL_DESCRICAO, " + ;
            "ANL_CRIADO_EM, ANL_STATUS FROM ANOMALIA_LOG " + ;
            "WHERE ANL_PERIODO = '" + GcSqlLit(cPeriodo) + "' AND D_E_L_E_T_ = ' '"

  If !Empty(cTipo)
    cQuery += " AND ANL_TIPO = '" + GcSqlLit(cTipo) + "'"
  EndIf

  cQuery += " ORDER BY ANL_CRIADO_EM DESC"

  aAnomalias := TCSqlQuery(cQuery)

  Local i as numeric
  Local cReturn as character

  cReturn := "["
  For i := 1 To Len(aAnomalias)
    oResult := JsonObject():new()
    oResult["id"] := Val(aAnomalias[i]:ANL_ID)
    oResult["tipo"] := aAnomalias[i]:ANL_TIPO
    oResult["periodo"] := aAnomalias[i]:ANL_PERIODO
    oResult["unidade"] := aAnomalias[i]:ANL_UNIDADE
    oResult["valor"] := Val(aAnomalias[i]:ANL_VALOR)
    oResult["descricao"] := aAnomalias[i]:ANL_DESCRICAO
    oResult["criado_em"] := aAnomalias[i]:ANL_CRIADO_EM
    oResult["status"] := aAnomalias[i]:ANL_STATUS
    If i > 1
      cReturn += ","
    EndIf
    cReturn += oResult:toJson()
  Next
  cReturn += "]"

Return cReturn

/*{Protheus.doc}
REST endpoint: GET /auditoria/dashboards?periodo=2025-01
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character period (YYYY-MM)
@return Character JSON dashboard object with counts and summary
/*/
User Function GcAuditoriaDashboardRestEndpoint(cPeriodo as character) as character
  Local cQuery as character
  Local aDash as array := {}
  Local oResult as object

  // Query dashboard cache
  cQuery := "SELECT DSH_ANOMALIAS_TOTAL, DSH_DESEQUILIBRIO_COUNT, DSH_LAN_ORFAO_COUNT, " + ;
            "DSH_COB_ORFAO_COUNT, DSH_RATEIO_INVALID_COUNT, DSH_TIMING_COUNT, DSH_USUARIO_COUNT, " + ;
            "DSH_JSON FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + GcSqlLit(cPeriodo) + "' " + ;
            "AND D_E_L_E_T_ = ' ' ORDER BY DSH_ATUALIZADO_EM DESC LIMIT 1"

  aDash := TCSqlQuery(cQuery)

  oResult := JsonObject():new()

  If Len(aDash) > 0
    oResult["total"] := Val(aDash[1]:DSH_ANOMALIAS_TOTAL)
    oResult["desequilibrio"] := Val(aDash[1]:DSH_DESEQUILIBRIO_COUNT)
    oResult["lancamento_orfao"] := Val(aDash[1]:DSH_LAN_ORFAO_COUNT)
    oResult["cobranca_orfao"] := Val(aDash[1]:DSH_COB_ORFAO_COUNT)
    oResult["rateio_invalido"] := Val(aDash[1]:DSH_RATEIO_INVALID_COUNT)
    oResult["timing_anomalia"] := Val(aDash[1]:DSH_TIMING_COUNT)
    oResult["usuario_anomalia"] := Val(aDash[1]:DSH_USUARIO_COUNT)
  Else
    oResult["total"] := 0
    oResult["desequilibrio"] := 0
    oResult["lancamento_orfao"] := 0
    oResult["cobranca_orfao"] := 0
    oResult["rateio_invalido"] := 0
    oResult["timing_anomalia"] := 0
    oResult["usuario_anomalia"] := 0
  EndIf

Return oResult:toJson()

/*{Protheus.doc}
REST endpoint: GET /auditoria/alertas (unread alerts)
@type Function
@author Claude
@since 2026-07-31
@return Character JSON array of unread alerts
/*/
User Function GcAuditoriaAlertasRestEndpoint() as character
  Local cQuery as character
  Local aAlertas as array := {}
  Local oResult as object

  cQuery := "SELECT ALT_ID, ALT_TIPO, ALT_MENSAGEM, ALT_CRIADO_EM FROM ALERTA " + ;
            "WHERE ALT_VISTO = 0 AND D_E_L_E_T_ = ' ' " + ;
            "ORDER BY ALT_CRIADO_EM DESC LIMIT 20"

  aAlertas := TCSqlQuery(cQuery)

  Local i as numeric
  Local cReturn as character

  cReturn := "["
  For i := 1 To Len(aAlertas)
    oResult := JsonObject():new()
    oResult["id"] := Val(aAlertas[i]:ALT_ID)
    oResult["tipo"] := aAlertas[i]:ALT_TIPO
    oResult["mensagem"] := aAlertas[i]:ALT_MENSAGEM
    oResult["criado_em"] := aAlertas[i]:ALT_CRIADO_EM
    If i > 1
      cReturn += ","
    EndIf
    cReturn += oResult:toJson()
  Next
  cReturn += "]"

Return cReturn

/*{Protheus.doc}
REST endpoint: POST /auth/login
@type Function
@author Claude
@since 2026-07-30
@param cUsername Character username
@param cPassword Character password
@return Character JSON {token, perfil, unidades}
/*/
User Function GcAuthLoginRestEndpoint(cUsername as character, cPassword as character) as character
  Local oToken as object
  Local oResult as object

  oToken := GcValidarLoginPortal(cUsername, cPassword)
  oResult := JsonObject():new()

  If oToken <> .Null.
    oResult["ok"] := .T.
    oResult["token"] := oToken:token
    oResult["perfil"] := oToken:perfil
    oResult["unidades"] := oToken:unidades_permitidas
  Else
    oResult["ok"] := .F.
    oResult["erro"] := "Credenciais inválidas"
  EndIf

Return oResult:toJson()

/*{Protheus.doc}
REST endpoint: POST /auth/logout
@type Function
@author Claude
@since 2026-07-30
@param cToken Character auth token
@return Character JSON {ok}
/*/
User Function GcAuthLogoutRestEndpoint(cToken as character) as character
  Local oResult as object

  oResult := JsonObject():new()

  // Call v2 logout (invalidates token)
  If GcInvalidarToken(cToken)
    oResult["ok"] := .T.
  Else
    oResult["ok"] := .F.
    oResult["erro"] := "Falha ao fazer logout"
  EndIf

Return oResult:toJson()
