// src/auditoria-menu.prw — telas do menu Auditoria. A regra de detecção
// mora em src/auditoria-validacoes.prw; aqui só há escolha de período,
// apresentação e as grades sobre ANOMALIA_LOG e ALERTA.
#include "totvs.ch"

/*/{Protheus.doc} GcMenuAuditoria
    Submenu de auditoria contábil.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcMenuAuditoria()
    Local aMenu := {"Auditar Período Completo", "Rodar Validador Individual", ;
        "Anomalias Detectadas", "Alertas", "Painel do Período", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Auditoria")
    Local oBrowse

    Do Case
        Case nOpcao == 1
            GcAuditarPeriodoUI()
        Case nOpcao == 2
            GcValidadorIndividualUI()
        Case nOpcao == 3
            oBrowse := FWMBrowse():New()
            oBrowse:SetAlias("ANOMALIA_LOG")
            oBrowse:SetDescription("Anomalias Detectadas")
            oBrowse:Activate()
        Case nOpcao == 4
            GcMenuAlertas()
        Case nOpcao == 5
            GcPainelAuditoria()
    EndCase
Return

/*/{Protheus.doc} GcPeriodoAuditoria
    Pergunta o período a auditar, propondo o exercício ativo como padrão.
    @type Function
    @author GesCon
    @since 2026-07-31
    @return cPeriodo, character, período no formato AAAA-MM, ou "" se cancelado
*/
User Function GcPeriodoAuditoria()
    Local cPadrao := GcExercicioAtivo()
    Local cPeriodo := ""

    If cPadrao == Nil
        cPadrao := ""
    EndIf

    cPeriodo := AllTrim(FWGetText("Auditar qual período? (AAAA-MM)", cPadrao))

    If Empty(cPeriodo)
        Return ""
    EndIf

    If Len(cPeriodo) != 7 .Or. SubStr(cPeriodo, 5, 1) != "-"
        MsgAlert("Período deve estar no formato AAAA-MM (ex: 2026-01).", "Auditoria")
        Return ""
    EndIf
Return cPeriodo

/*/{Protheus.doc} GcAuditarPeriodoUI
    Roda os seis validadores sobre um período e atualiza o painel.
    GcAuditarPeriodoCompleto devolve .T. quando ENCONTROU anomalia.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcAuditarPeriodoUI()
    Local cPeriodo := GcPeriodoAuditoria()
    Local lAchou   := .F.
    Local aTot     := {}

    If Empty(cPeriodo)
        Return
    EndIf

    lAchou := GcAuditarPeriodoCompleto(cPeriodo)

    If !lAchou
        MsgInfo("Período " + cPeriodo + " auditado: nenhuma anomalia encontrada.", "Auditoria")
        Return
    EndIf

    aTot := TCSqlQuery("SELECT COUNT(*) as CNT FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + ;
        GcSqlLit(cPeriodo) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('ANOMALIA_LOG')) + "'")

    MsgAlert("Período " + cPeriodo + " auditado: " + ;
        AllTrim(aTot[1]["CNT"]) + " anomalia(s) registrada(s)." + Chr(10) + ;
        "Veja em Auditoria > Anomalias Detectadas.", "Auditoria")
Return

/*/{Protheus.doc} GcValidadorIndividualUI
    Roda um dos seis validadores isoladamente, para investigar um tipo de
    anomalia sem reprocessar o período inteiro.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcValidadorIndividualUI()
    Local aMenu := {"Desequilíbrio contábil", "Lançamentos órfãos", "Cobranças órfãs", ;
        "Rateio inválido", "Timing de lançamentos", "Alteração em período fechado", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Validador Individual")
    Local cPeriodo := ""
    Local lAchou := .F.

    If nOpcao <= 0 .Or. nOpcao >= Len(aMenu)
        Return
    EndIf

    cPeriodo := GcPeriodoAuditoria()
    If Empty(cPeriodo)
        Return
    EndIf

    Do Case
        Case nOpcao == 1
            lAchou := GcValidarDesequilibrioContabil(cPeriodo)
        Case nOpcao == 2
            lAchou := GcValidarLancamentosOrfaos(cPeriodo)
        Case nOpcao == 3
            lAchou := GcValidarCobrancasOrfaos(cPeriodo)
        Case nOpcao == 4
            lAchou := GcValidarRateioValido(cPeriodo)
        Case nOpcao == 5
            lAchou := GcValidarTimingLancamentos(cPeriodo)
        Case nOpcao == 6
            lAchou := GcValidarAlteracoesEmPeriodoFechado(cPeriodo)
    EndCase

    If lAchou
        MsgAlert("Anomalia encontrada em " + cPeriodo + " e registrada no log.", "Validador")
    Else
        MsgInfo("Nada encontrado em " + cPeriodo + " para este validador.", "Validador")
    EndIf
Return

/*/{Protheus.doc} GcMenuAlertas
    Consulta os alertas e permite marcar um como visto.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcMenuAlertas()
    Local aMenu := {"Ver Todos os Alertas", "Marcar Alerta como Visto", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Alertas")
    Local oBrowse
    Local aAlt   := {}
    Local aItens := {}
    Local nI     := 0
    Local nEscolha := 0

    Do Case
        Case nOpcao == 1
            oBrowse := FWMBrowse():New()
            oBrowse:SetAlias("ALERTA")
            oBrowse:SetDescription("Alertas de Auditoria")
            oBrowse:Activate()
        Case nOpcao == 2
            aAlt := TCSqlQuery("SELECT ALT_ID, ALT_TIPO, ALT_MENSAGEM, ALT_CRIADO_EM " + ;
                "FROM ALERTA WHERE ALT_VISTO = 0 AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('ALERTA')) + "' ORDER BY ALT_CRIADO_EM DESC")

            If Len(aAlt) == 0
                MsgInfo("Nenhum alerta pendente.", "Alertas")
                Return
            EndIf

            For nI := 1 To Len(aAlt)
                AAdd(aItens, "[" + AllTrim(aAlt[nI]["ALT_TIPO"]) + "] " + ;
                    AllTrim(aAlt[nI]["ALT_MENSAGEM"]))
            Next nI
            AAdd(aItens, "Voltar")

            nEscolha := FWMenuSelect(aItens, "Marcar como visto")

            If nEscolha > 0 .And. nEscolha <= Len(aAlt)
                TCSqlExec("UPDATE ALERTA SET ALT_VISTO = 1, ALT_VISTO_EM = datetime('now') " + ;
                    "WHERE ALT_ID = " + AllTrim(aAlt[nEscolha]["ALT_ID"]) + " AND FILIAL = '" + GcSqlLit(FWxFilial('ALERTA')) + "'")
                MsgInfo("Alerta marcado como visto.", "Alertas")
            EndIf
    EndCase
Return

/*/{Protheus.doc} GcPainelAuditoria
    Mostra os contadores de DASHBOARD_CACHE para um período. O cache é
    gravado por GcAtualizarDashboardCache ao final de cada auditoria.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcPainelAuditoria()
    Local cPeriodo := GcPeriodoAuditoria()
    Local aDsh := {}
    Local cMsg := ""

    If Empty(cPeriodo)
        Return
    EndIf

    aDsh := TCSqlQuery("SELECT DSH_ANOMALIAS_TOTAL, DSH_DESEQUILIBRIO_COUNT, DSH_LAN_ORFAO_COUNT, " + ;
        "DSH_COB_ORFAO_COUNT, DSH_RATEIO_INVALID_COUNT, DSH_TIMING_COUNT, DSH_ATUALIZADO_EM " + ;
        "FROM DASHBOARD_CACHE WHERE DSH_PERIODO = '" + GcSqlLit(cPeriodo) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DASHBOARD_CACHE')) + "'")

    If Len(aDsh) == 0
        MsgAlert("Sem painel para " + cPeriodo + "." + Chr(10) + ;
            "Rode Auditoria > Auditar Período Completo primeiro.", "Painel de Auditoria")
        Return
    EndIf

    cMsg := "Período: " + cPeriodo + Chr(10) + Chr(10)
    cMsg += "Total de anomalias...: " + AllTrim(aDsh[1]["DSH_ANOMALIAS_TOTAL"]) + Chr(10)
    cMsg += "Desequilíbrio........: " + AllTrim(aDsh[1]["DSH_DESEQUILIBRIO_COUNT"]) + Chr(10)
    cMsg += "Lançamentos órfãos...: " + AllTrim(aDsh[1]["DSH_LAN_ORFAO_COUNT"]) + Chr(10)
    cMsg += "Cobranças órfãs......: " + AllTrim(aDsh[1]["DSH_COB_ORFAO_COUNT"]) + Chr(10)
    cMsg += "Rateio inválido......: " + AllTrim(aDsh[1]["DSH_RATEIO_INVALID_COUNT"]) + Chr(10)
    cMsg += "Timing...............: " + AllTrim(aDsh[1]["DSH_TIMING_COUNT"]) + Chr(10) + Chr(10)
    cMsg += "Atualizado em: " + AllTrim(aDsh[1]["DSH_ATUALIZADO_EM"])

    MsgInfo(cMsg, "Painel de Auditoria")
Return
