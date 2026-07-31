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
