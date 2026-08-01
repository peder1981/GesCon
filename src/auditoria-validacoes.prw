// src/auditoria-validacoes.prw -- 6 detectores de anomalia (Task 5, Portal
// v3 + Auditoria Dashboard). Cada funcao consulta o banco em busca de um
// tipo de anomalia, grava no maximo 1 registro-resumo em ANOMALIA_LOG
// quando encontra alguma ocorrencia, e retorna .T. (anomalia encontrada)
// ou .F. (periodo limpo para aquele tipo de checagem).
//
// Nota de schema: o desenho original da task assumia LANCAMENTOS com
// LAN_TIPO IN ('D','C') e LAN_PERIODO, e uma FK direta LAN_COB_ID -> COB.
// O schema real (ver schema.sql) usa outro modelo de partida dupla: cada
// linha de LANCAMENTOS ja carrega LAN_CONTA_DEB + LAN_CONTA_CRED + um unico
// LAN_VALOR (debito e credito sempre iguais por construcao, e ha um CHECK
// LAN_CONTA_DEB <> LAN_CONTA_CRED), o periodo fica em LAN_EXERCICIO, e nao
// existe nenhuma coluna de LANCAMENTOS ou COB apontando uma pra outra --
// GcAuditoriaFecharPeriodo (src/auditoria.prw) ja usa um casamento
// heuristico por competencia+valor pra relacionar as duas tabelas, entao os
// detectores de orfao abaixo reusam a mesma heuristica. Os detalhes de cada
// adaptacao estao documentados no cabecalho Protheus.doc de cada funcao.
#include "totvs.ch"

/*{Protheus.doc}
Detecta desequilibrio contabil: para cada lancamento AUTOMATICO_RATEIO do
periodo, o valor do lancamento (LAN_VALOR) deve ser igual a soma dos valores
distribuidos em RATEIO_DETALHE (RAT_VALOR) para aquele lancamento. Um
lancamento cujo rateio nao fecha com o valor lancado e um desequilibrio
contabil real e detectavel neste schema (diferente do par LAN_TIPO 'D'/'C'
assumido no desenho original, que nao existe nesta tabela -- ver nota de
schema no topo do arquivo).
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio (ex: "2025-01")
@return Logical .T. se algum lancamento com rateio desbalanceado foi encontrado
/*/
User Function GcValidarDesequilibrioContabil(cPeriodo as character) as logical
  Local cQuery as character
  Local aResult as array
  Local nQtd as numeric := 0
  Local nDiferenca as numeric := 0
  Local cDescricao as character

  cQuery := "SELECT COUNT(*) as CNT, COALESCE(SUM(ABS(L.LAN_VALOR - IFNULL(R.SOMA, 0))), 0) as DIFF " + ;
            "FROM LANCAMENTOS L LEFT JOIN " + ;
            "(SELECT RAT_LANCAMENTO, SUM(RAT_VALOR) as SOMA FROM RATEIO_DETALHE WHERE D_E_L_E_T_ = ' ' GROUP BY RAT_LANCAMENTO) R " + ;
            "ON R.RAT_LANCAMENTO = L.LAN_ID " + ;
            "WHERE L.LAN_EXERCICIO = '" + GcSqlLit(cPeriodo) + "' AND L.LAN_TIPO = 'AUTOMATICO_RATEIO' AND L.D_E_L_E_T_ = ' ' " + ;
            "AND ABS(L.LAN_VALOR - IFNULL(R.SOMA, 0)) > 0.01"

  aResult := TCSqlQuery(cQuery)

  If Len(aResult) > 0
    nQtd := Val(aResult[1]:CNT)
    nDiferenca := Val(aResult[1]:DIFF)
  EndIf

  If nQtd > 0
    cDescricao := "Desequilibrio contabil: " + AllTrim(Str(nQtd, 10, 0)) + ;
      " lancamento(s) de rateio cuja soma em RATEIO_DETALHE nao fecha com LAN_VALOR, diferenca total=" + ;
      AllTrim(Str(nDiferenca, 15, 2))
    cQuery := "INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, " + ;
              "ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) VALUES (" + ;
              "'DESEQUILIBRIO_CONTABIL', '" + GcSqlLit(cPeriodo) + "', " + AllTrim(Str(nDiferenca, 15, 2)) + ", " + ;
              "'" + GcSqlLit(cDescricao) + "', " + ;
              "datetime('now'), 'ABERTO', ' ')"
    TCSqlExec(cQuery)
    Return .T.
  EndIf

Return .F.

/*{Protheus.doc}
Detecta lancamentos orfaos: lancamentos AUTOMATICO_RATEIO do periodo sem
nenhuma cobranca (COB) correspondente. Nao ha FK entre LANCAMENTOS e COB
neste schema, entao o casamento e feito por competencia+valor, a mesma
heuristica ja usada por GcAuditoriaFecharPeriodo em src/auditoria.prw.
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio (ex: "2025-01")
@return Logical .T. se algum lancamento orfao foi encontrado
/*/
User Function GcValidarLancamentosOrfaos(cPeriodo as character) as logical
  Local cQuery as character
  Local aResult as array
  Local nQtd as numeric := 0
  Local cDescricao as character

  cQuery := "SELECT COUNT(*) as CNT FROM LANCAMENTOS L " + ;
            "WHERE L.LAN_EXERCICIO = '" + GcSqlLit(cPeriodo) + "' AND L.LAN_TIPO = 'AUTOMATICO_RATEIO' AND L.D_E_L_E_T_ = ' ' " + ;
            "AND NOT EXISTS (SELECT 1 FROM COB C WHERE C.COB_COMPET = L.LAN_EXERCICIO AND C.COB_VALOR = L.LAN_VALOR AND C.D_E_L_E_T_ = ' ')"

  aResult := TCSqlQuery(cQuery)

  If Len(aResult) > 0
    nQtd := Val(aResult[1]:CNT)
  EndIf

  If nQtd > 0
    cDescricao := "Lancamentos orfaos (sem cobranca correspondente): " + AllTrim(Str(nQtd, 10, 0))
    cQuery := "INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, " + ;
              "ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) VALUES (" + ;
              "'LAN_ORFAO', '" + GcSqlLit(cPeriodo) + "', " + AllTrim(Str(nQtd, 10, 0)) + ", " + ;
              "'" + GcSqlLit(cDescricao) + "', " + ;
              "datetime('now'), 'ABERTO', ' ')"
    TCSqlExec(cQuery)
    Return .T.
  EndIf

Return .F.

/*{Protheus.doc}
Detecta cobrancas orfas: cobrancas (COB) do periodo sem nenhum lancamento
AUTOMATICO_RATEIO correspondente. Espelho de GcValidarLancamentosOrfaos,
mesma heuristica de casamento por competencia+valor.
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/competencia (ex: "2025-01")
@return Logical .T. se alguma cobranca orfa foi encontrada
/*/
User Function GcValidarCobrancasOrfaos(cPeriodo as character) as logical
  Local cQuery as character
  Local aResult as array
  Local nQtd as numeric := 0
  Local cDescricao as character

  cQuery := "SELECT COUNT(*) as CNT FROM COB C " + ;
            "WHERE C.COB_COMPET = '" + GcSqlLit(cPeriodo) + "' AND C.D_E_L_E_T_ = ' ' " + ;
            "AND NOT EXISTS (SELECT 1 FROM LANCAMENTOS L WHERE L.LAN_EXERCICIO = C.COB_COMPET AND L.LAN_VALOR = C.COB_VALOR AND L.LAN_TIPO = 'AUTOMATICO_RATEIO' AND L.D_E_L_E_T_ = ' ')"

  aResult := TCSqlQuery(cQuery)

  If Len(aResult) > 0
    nQtd := Val(aResult[1]:CNT)
  EndIf

  If nQtd > 0
    cDescricao := "Cobrancas orfas (sem lancamento correspondente): " + AllTrim(Str(nQtd, 10, 0))
    cQuery := "INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, " + ;
              "ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) VALUES (" + ;
              "'COB_ORFAO', '" + GcSqlLit(cPeriodo) + "', " + AllTrim(Str(nQtd, 10, 0)) + ", " + ;
              "'" + GcSqlLit(cDescricao) + "', " + ;
              "datetime('now'), 'ABERTO', ' ')"
    TCSqlExec(cQuery)
    Return .T.
  EndIf

Return .F.

/*{Protheus.doc}
Detecta rateio invalido: para cada lancamento AUTOMATICO_RATEIO do periodo
que tem detalhamento em RATEIO_DETALHE, a soma dos percentuais rateados
(RAT_PERCENTUAL) deve fechar em 100% (tolerancia 0.5 ponto percentual).
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio (ex: "2025-01")
@return Logical .T. se algum lancamento com rateio percentual invalido foi encontrado
/*/
User Function GcValidarRateioValido(cPeriodo as character) as logical
  Local cQuery as character
  Local aResult as array
  Local nQtd as numeric := 0
  Local cDescricao as character

  cQuery := "SELECT COUNT(*) as CNT FROM (" + ;
            "SELECT L.LAN_ID, SUM(COALESCE(R.RAT_PERCENTUAL, 0)) as SOMA " + ;
            "FROM LANCAMENTOS L JOIN RATEIO_DETALHE R ON R.RAT_LANCAMENTO = L.LAN_ID AND R.D_E_L_E_T_ = ' ' " + ;
            "WHERE L.LAN_EXERCICIO = '" + GcSqlLit(cPeriodo) + "' AND L.LAN_TIPO = 'AUTOMATICO_RATEIO' AND L.D_E_L_E_T_ = ' ' " + ;
            "GROUP BY L.LAN_ID " + ;
            "HAVING ABS(SOMA - 100) > 0.5" + ;
            ")"

  aResult := TCSqlQuery(cQuery)

  If Len(aResult) > 0
    nQtd := Val(aResult[1]:CNT)
  EndIf

  If nQtd > 0
    cDescricao := "Rateio invalido: " + AllTrim(Str(nQtd, 10, 0)) + " lancamento(s) cuja soma de RAT_PERCENTUAL nao fecha em 100%"
    cQuery := "INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, " + ;
              "ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) VALUES (" + ;
              "'RATEIO_INVALIDO', '" + GcSqlLit(cPeriodo) + "', " + AllTrim(Str(nQtd, 10, 0)) + ", " + ;
              "'" + GcSqlLit(cDescricao) + "', " + ;
              "datetime('now'), 'ABERTO', ' ')"
    TCSqlExec(cQuery)
    Return .T.
  EndIf

Return .F.

/*{Protheus.doc}
Detecta anomalia de timing: lancamento cuja data (LAN_DATA) e posterior ao
vencimento (COB_VENCTO) da cobranca correspondente (casada por
competencia+valor, mesma heuristica dos demais detectores de orfao neste
arquivo). LAN_DATA e gravada como 'YYYYMMDD' (ver GcLancarManual em
src/contabil.prw, usa DtoS()) enquanto COB_VENCTO e gravada como
'YYYY-MM-DD' -- a comparacao normaliza LAN_DATA para o formato ISO via
substr() antes de comparar como texto.
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio (ex: "2025-01")
@return Logical .T. se algum lancamento posterior ao vencimento da cobranca foi encontrado
/*/
User Function GcValidarTimingLancamentos(cPeriodo as character) as logical
  Local cQuery as character
  Local aResult as array
  Local nQtd as numeric := 0
  Local cDescricao as character

  cQuery := "SELECT COUNT(*) as CNT FROM LANCAMENTOS L " + ;
            "JOIN COB C ON C.COB_COMPET = L.LAN_EXERCICIO AND C.COB_VALOR = L.LAN_VALOR AND C.D_E_L_E_T_ = ' ' " + ;
            "WHERE L.LAN_EXERCICIO = '" + GcSqlLit(cPeriodo) + "' AND L.D_E_L_E_T_ = ' ' " + ;
            "AND (substr(L.LAN_DATA, 1, 4) || '-' || substr(L.LAN_DATA, 5, 2) || '-' || substr(L.LAN_DATA, 7, 2)) > C.COB_VENCTO"

  aResult := TCSqlQuery(cQuery)

  If Len(aResult) > 0
    nQtd := Val(aResult[1]:CNT)
  EndIf

  If nQtd > 0
    cDescricao := "Timing anomalo: " + AllTrim(Str(nQtd, 10, 0)) + " lancamento(s) com data posterior ao vencimento da cobranca correspondente"
    cQuery := "INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, " + ;
              "ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) VALUES (" + ;
              "'TIMING_ANOMALIA', '" + GcSqlLit(cPeriodo) + "', " + AllTrim(Str(nQtd, 10, 0)) + ", " + ;
              "'" + GcSqlLit(cDescricao) + "', " + ;
              "datetime('now'), 'ABERTO', ' ')"
    TCSqlExec(cQuery)
    Return .T.
  EndIf

Return .F.

/*{Protheus.doc}
Detecta anomalia de usuario/alteracao em periodo fechado: lancamentos
soft-deletados (D_E_L_E_T_ <> ' ') cujo exercicio (LAN_EXERCICIO) esta
marcado como fechado (EXERCICIO.EXE_FECHADO = 1). Indica que alguem alterou
ou removeu um lancamento contabil depois do fechamento do periodo, o que
nao deveria ser possivel via fluxo normal (GcEditarLancamentoDescricao e
GcExcluirLancamento em src/contabil.prw bloqueiam periodo fechado) -- esta
checagem existe como rede de seguranca contra alteracao direta no banco.
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio (ex: "2025-01")
@return Logical .T. se alguma alteracao em periodo fechado foi encontrada
/*/
User Function GcValidarAlteracoesEmPeriodoFechado(cPeriodo as character) as logical
  Local cQuery as character
  Local aResult as array
  Local nQtd as numeric := 0
  Local cDescricao as character

  cQuery := "SELECT COUNT(*) as CNT FROM LANCAMENTOS L " + ;
            "JOIN EXERCICIO E ON E.EXE_CODIGO = L.LAN_EXERCICIO AND E.D_E_L_E_T_ = ' ' " + ;
            "WHERE L.LAN_EXERCICIO = '" + GcSqlLit(cPeriodo) + "' AND E.EXE_FECHADO = 1 AND L.D_E_L_E_T_ <> ' '"

  aResult := TCSqlQuery(cQuery)

  If Len(aResult) > 0
    nQtd := Val(aResult[1]:CNT)
  EndIf

  If nQtd > 0
    cDescricao := "Alteracao em periodo fechado: " + AllTrim(Str(nQtd, 10, 0)) + " lancamento(s) removido(s) apos o fechamento do exercicio"
    cQuery := "INSERT INTO ANOMALIA_LOG (ANL_TIPO, ANL_PERIODO, ANL_VALOR, ANL_DESCRICAO, " + ;
              "ANL_CRIADO_EM, ANL_STATUS, D_E_L_E_T_) VALUES (" + ;
              "'USUARIO_ANOMALIA', '" + GcSqlLit(cPeriodo) + "', " + AllTrim(Str(nQtd, 10, 0)) + ", " + ;
              "'" + GcSqlLit(cDescricao) + "', " + ;
              "datetime('now'), 'ABERTO', ' ')"
    TCSqlExec(cQuery)
    Return .T.
  EndIf

Return .F.

/*{Protheus.doc}
Orquestrador: executa os 6 validadores de auditoria (Task 5) para o periodo
informado, em sequencia, e ao final atualiza o cache do dashboard
(DASHBOARD_CACHE) via GcAtualizarDashboardCache. Cada validador grava sua
propria linha de resumo em ANOMALIA_LOG quando encontra alguma ocorrencia
(ver cabecalhos individuais); esta funcao apenas agrega o resultado
logico (alguma anomalia encontrada em qualquer um dos 6 tipos) e garante
que o cache fique consistente com o estado mais recente de ANOMALIA_LOG.
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio (ex: "2025-01")
@return Logical .T. se algum dos 6 validadores encontrou alguma anomalia
/*/
User Function GcAuditarPeriodoCompleto(cPeriodo as character) as logical
  Local lAnomaliaEncontrada as logical := .F.

  If GcValidarDesequilibrioContabil(cPeriodo)
    lAnomaliaEncontrada := .T.
  EndIf

  If GcValidarLancamentosOrfaos(cPeriodo)
    lAnomaliaEncontrada := .T.
  EndIf

  If GcValidarCobrancasOrfaos(cPeriodo)
    lAnomaliaEncontrada := .T.
  EndIf

  If GcValidarRateioValido(cPeriodo)
    lAnomaliaEncontrada := .T.
  EndIf

  If GcValidarTimingLancamentos(cPeriodo)
    lAnomaliaEncontrada := .T.
  EndIf

  If GcValidarAlteracoesEmPeriodoFechado(cPeriodo)
    lAnomaliaEncontrada := .T.
  EndIf

  GcAtualizarDashboardCache(cPeriodo)

  // Desequilibrio contabil e o unico achado que nao pode esperar revisao:
  // debitos != creditos invalida o balancete inteiro do periodo. Vira
  // alerta CRITICO, visivel em Auditoria > Alertas.
  If GcValidarDesequilibrioContabil(cPeriodo)
    GcCriarAlertaCritico("CRITICO", "Desequilibrio contabil no periodo " + cPeriodo + ;
      ": a soma dos debitos difere da soma dos creditos.")
  EndIf

Return lAnomaliaEncontrada

/*{Protheus.doc}
Cria um alerta (ALERTA) para consumo do portal/dashboard. Tipos aceitos por
constraint de banco (ver schema.sql, CHECK ALT_TIPO): 'CRITICO', 'AVISO',
'INFO'. Os alertas gravados aqui sao lidos pelo menu Auditoria da GUI
(browse sobre ALERTA).
@type Function
@author Claude
@since 2026-07-31
@param cTipo Character tipo do alerta (CRITICO, AVISO, INFO)
@param cMsg Character mensagem do alerta
@return Logical .T. se o alerta foi criado, .F. se cTipo ou cMsg vierem vazios
/*/
User Function GcCriarAlertaCritico(cTipo as character, cMsg as character) as logical
  Local cQuery as character

  If Empty(cTipo) .Or. Empty(cMsg)
    Return .F.
  EndIf

  cQuery := "INSERT INTO ALERTA (ALT_TIPO, ALT_MENSAGEM, ALT_CRIADO_EM, ALT_VISTO, D_E_L_E_T_) " + ;
            "VALUES ('" + GcSqlLit(cTipo) + "', '" + GcSqlLit(cMsg) + "', datetime('now'), 0, ' ')"

  TCSqlExec(cQuery)

Return .T.

/*{Protheus.doc}
Atualiza o snapshot diario de contadores de anomalia em DASHBOARD_CACHE
para o periodo informado, contando (COUNT) as linhas ativas de
ANOMALIA_LOG por ANL_TIPO. Substitui (delete + insert) qualquer cache
previamente gravado para a mesma DSH_PERIODO nesta chamada, ja que
DASHBOARD_CACHE tem indice unico em (DSH_DATA, DSH_PERIODO, D_E_L_E_T_) --
rodar esta funcao mais de uma vez no mesmo dia para o mesmo periodo nao
gera violacao de unicidade nem duplica linhas. DSH_USUARIO_COUNT conta o
tipo 'USUARIO_ANOMALIA' gravado por GcValidarAlteracoesEmPeriodoFechado.
@type Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio (ex: "2025-01")
@return Logical .T. (sempre; a funcao nao tem caminho de falha logica)
/*/
User Function GcAtualizarDashboardCache(cPeriodo as character) as logical
  Local cQuery as character
  Local nTotal as numeric := 0
  Local nDesequilibrio as numeric := 0
  Local nLanOrfao as numeric := 0
  Local nCobOrfao as numeric := 0
  Local nRateio as numeric := 0
  Local nTiming as numeric := 0
  Local nUsuario as numeric := 0

  nDesequilibrio := GcContarAnomaliasPorTipo(cPeriodo, "DESEQUILIBRIO_CONTABIL")
  nLanOrfao      := GcContarAnomaliasPorTipo(cPeriodo, "LAN_ORFAO")
  nCobOrfao      := GcContarAnomaliasPorTipo(cPeriodo, "COB_ORFAO")
  nRateio        := GcContarAnomaliasPorTipo(cPeriodo, "RATEIO_INVALIDO")
  nTiming        := GcContarAnomaliasPorTipo(cPeriodo, "TIMING_ANOMALIA")
  nUsuario       := GcContarAnomaliasPorTipo(cPeriodo, "USUARIO_ANOMALIA")

  nTotal := nDesequilibrio + nLanOrfao + nCobOrfao + nRateio + nTiming + nUsuario

  cQuery := "DELETE FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + GcSqlLit(cPeriodo) + "'"
  TCSqlExec(cQuery)

  cQuery := "INSERT INTO DASHBOARD_CACHE (DSH_DATA, DSH_PERIODO, DSH_ANOMALIAS_TOTAL, " + ;
            "DSH_DESEQUILIBRIO_COUNT, DSH_LAN_ORFAO_COUNT, DSH_COB_ORFAO_COUNT, " + ;
            "DSH_RATEIO_INVALID_COUNT, DSH_TIMING_COUNT, DSH_USUARIO_COUNT, DSH_ATUALIZADO_EM, D_E_L_E_T_) " + ;
            "VALUES (date('now'), '" + GcSqlLit(cPeriodo) + "', " + AllTrim(Str(nTotal, 10, 0)) + ", " + ;
            AllTrim(Str(nDesequilibrio, 10, 0)) + ", " + AllTrim(Str(nLanOrfao, 10, 0)) + ", " + ;
            AllTrim(Str(nCobOrfao, 10, 0)) + ", " + AllTrim(Str(nRateio, 10, 0)) + ", " + ;
            AllTrim(Str(nTiming, 10, 0)) + ", " + AllTrim(Str(nUsuario, 10, 0)) + ", " + ;
            "datetime('now'), ' ')"

  TCSqlExec(cQuery)

Return .T.

/*{Protheus.doc}
Auxiliar interna de GcAtualizarDashboardCache: conta as linhas ativas
(D_E_L_E_T_ = ' ') de ANOMALIA_LOG para um periodo e tipo especificos.
Extraida para evitar repetir a mesma query 6 vezes com apenas o literal de
tipo mudando.
@type Static Function
@author Claude
@since 2026-07-31
@param cPeriodo Character periodo/exercicio
@param cTipo Character valor de ANL_TIPO a contar
@return Numeric quantidade de linhas encontradas
/*/
Static Function GcContarAnomaliasPorTipo(cPeriodo as character, cTipo as character) as numeric
  Local cQuery as character
  Local aResult as array

  cQuery := "SELECT COUNT(*) as CNT FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + GcSqlLit(cPeriodo) + ;
            "' AND ANL_TIPO = '" + GcSqlLit(cTipo) + "' AND D_E_L_E_T_ = ' '"

  aResult := TCSqlQuery(cQuery)

  If Len(aResult) > 0
    Return Val(aResult[1]:CNT)
  EndIf

Return 0
