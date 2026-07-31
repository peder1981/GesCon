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
Escapa valor de texto para embutir com seguranca dentro de uma string JSON
construida manualmente (barra invertida, aspas duplas e quebras de linha).
Usado pelos endpoints /portal/* porque JsonObject():toJson() neste advplc
(v2.0.3) so serializa pares chave/valor escalares de um unico objeto - nao
ha suporte a array (":fromArray" nao existe, erro "unknown method FROMARRAY
on JsonObject") nem a objetos aninhados, entao arrays JSON precisam ser
montados como string.
@type Static Function
@author Claude
@since 2026-07-31
@param cValor Character valor a escapar (aceita Nil)
@return Character valor escapado, seguro para uso entre aspas duplas em JSON
/*/
Static Function GcJsonEscape(cValor as character) as character
  Local cRet as character

  cRet := cValor
  If cRet == Nil
    cRet := ""
  EndIf

  cRet := StrTran(cRet, "\", "\\")
  cRet := StrTran(cRet, '"', '\"')
  cRet := StrTran(cRet, Chr(13), "")
  cRet := StrTran(cRet, Chr(10), "\n")

Return cRet

/*{Protheus.doc}
REST endpoint: GET /portal/extratos?unidade=T01
Consulta o snapshot RPT_PORTAL_EXTRATOS (gerado por GcGerarPortalExtratos)
filtrado pela unidade informada. JSON montado manualmente (ver GcJsonEscape)
porque JsonObject():toJson() neste advplc nao serializa arrays.
@type Function
@author Claude
@since 2026-07-31
@param cUnidade Character codigo da unidade
@return Character JSON array de extratos, ordenado por competencia DESC
/*/
User Function GcPortalExtratosRestEndpoint(cUnidade as character) as character
  Local cQuery as character
  Local aExtratos as array
  Local cJson as character
  Local i as numeric

  cQuery := "SELECT REX_ID, REX_COMPETENCIA, REX_VALOR, REX_VENCIMENTO, REX_STATUS " + ;
            "FROM RPT_PORTAL_EXTRATOS WHERE REX_UNIDADE = '" + GcSqlLit(cUnidade) + "' AND D_E_L_E_T_ = ' ' " + ;
            "ORDER BY REX_COMPETENCIA DESC"

  aExtratos := TCSqlQuery(cQuery)

  cJson := "["
  For i := 1 To Len(aExtratos)
    If i > 1
      cJson += ", "
    EndIf
    cJson += "{"
    cJson += '"id": ' + AllTrim(aExtratos[i]:REX_ID) + ", "
    cJson += '"competencia": "' + GcJsonEscape(aExtratos[i]:REX_COMPETENCIA) + '", '
    cJson += '"valor": ' + AllTrim(aExtratos[i]:REX_VALOR) + ", "
    cJson += '"vencimento": "' + GcJsonEscape(aExtratos[i]:REX_VENCIMENTO) + '", '
    cJson += '"status": "' + GcJsonEscape(aExtratos[i]:REX_STATUS) + '"'
    cJson += "}"
  Next i
  cJson += "]"

Return cJson

/*{Protheus.doc}
REST endpoint: GET /portal/agenda?unidade=T01
Consulta o snapshot RPT_PORTAL_AGENDA (gerado por GcGerarPortalAgenda,
proximos 12 meses de vencimentos) filtrado pela unidade informada. JSON
montado manualmente (ver GcJsonEscape) porque JsonObject():toJson() neste
advplc nao serializa arrays.
@type Function
@author Claude
@since 2026-07-31
@param cUnidade Character codigo da unidade
@return Character JSON array de vencimentos futuros, ordenado por competencia ASC
/*/
User Function GcPortalAgendaRestEndpoint(cUnidade as character) as character
  Local cQuery as character
  Local aAgenda as array
  Local cJson as character
  Local i as numeric

  cQuery := "SELECT REA_ID, REA_COMPETENCIA, REA_VENCIMENTO, REA_VALOR " + ;
            "FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE = '" + GcSqlLit(cUnidade) + "' AND D_E_L_E_T_ = ' ' " + ;
            "ORDER BY REA_COMPETENCIA ASC"

  aAgenda := TCSqlQuery(cQuery)

  cJson := "["
  For i := 1 To Len(aAgenda)
    If i > 1
      cJson += ", "
    EndIf
    cJson += "{"
    cJson += '"id": ' + AllTrim(aAgenda[i]:REA_ID) + ", "
    cJson += '"competencia": "' + GcJsonEscape(aAgenda[i]:REA_COMPETENCIA) + '", '
    cJson += '"vencimento": "' + GcJsonEscape(aAgenda[i]:REA_VENCIMENTO) + '", '
    cJson += '"valor": ' + AllTrim(aAgenda[i]:REA_VALOR)
    cJson += "}"
  Next i
  cJson += "]"

Return cJson

/*{Protheus.doc}
REST endpoint: GET /portal/avisos
Consulta o mural de avisos (tabela AVISOS) filtrando apenas os ativos
(AVI_ATIVO = 1), limitado aos 10 mais recentes. JSON montado manualmente
(ver GcJsonEscape) porque JsonObject():toJson() neste advplc nao serializa
arrays. Nota: a coluna real de data de criacao em AVISOS e AVI_DATA_CRIACAO
(nao AVI_CRIADO_EM) - ver schema.sql; a chave JSON de saida continua
"criado_em" por clareza da API.
@type Function
@author Claude
@since 2026-07-31
@return Character JSON array dos avisos ativos, mais recentes primeiro
/*/
User Function GcPortalAvisosRestEndpoint() as character
  Local cQuery as character
  Local aAvisos as array
  Local cJson as character
  Local i as numeric

  cQuery := "SELECT AVI_ID, AVI_TITULO, AVI_CORPO, AVI_DATA_CRIACAO FROM AVISOS " + ;
            "WHERE AVI_ATIVO = 1 AND D_E_L_E_T_ = ' ' " + ;
            "ORDER BY AVI_DATA_CRIACAO DESC LIMIT 10"

  aAvisos := TCSqlQuery(cQuery)

  cJson := "["
  For i := 1 To Len(aAvisos)
    If i > 1
      cJson += ", "
    EndIf
    cJson += "{"
    cJson += '"id": ' + AllTrim(aAvisos[i]:AVI_ID) + ", "
    cJson += '"titulo": "' + GcJsonEscape(aAvisos[i]:AVI_TITULO) + '", '
    cJson += '"corpo": "' + GcJsonEscape(aAvisos[i]:AVI_CORPO) + '", '
    cJson += '"criado_em": "' + GcJsonEscape(aAvisos[i]:AVI_DATA_CRIACAO) + '"'
    cJson += "}"
  Next i
  cJson += "]"

Return cJson

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
