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
