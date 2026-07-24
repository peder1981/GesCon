// gescon.prw — ponto de entrada do GesCon. `advplc serve gescon.prw` sobe
// a UI web com um menu real (FWMenuSelect, AdvPP v1.23.0+) navegando
// entre todas as telas sem reiniciar o processo. Login único de
// administrador (GcLogin) gate na frente do menu — sem papéis/permissões.
#include "totvs.ch"
#include "src/db.prw"
#include "src/login.prw"
#include "src/unidades.prw"
#include "src/condominos.prw"
#include "src/despesas.prw"
#include "src/cobrancas.prw"
#include "src/fechamento.prw"
#include "src/malas.prw"
#include "src/relatorios.prw"

/*/{Protheus.doc} GesCon
    Ponto de entrada do GesCon — sobe com `advplc serve gescon.prw`,
    mostra um menu navegando entre todas as telas.
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GesCon()
    Local aMenu := {"Unidades", "Condôminos", "Despesas", "Cobranças", "Fechamento Mensal", "Mala Direta", "Relatórios", "Sair"}
    Local nOpcao
    Local cCompetencia
    Local nEnviados
    Local cDiaVenc
    Local nDiaVenc

    ConOut("GesCon — Sistema de Gestão Condominial")

    If !GcLogin()
        MsgStop("Acesso não autorizado.", "GesCon")
        Return
    EndIf

    // Atualiza status "atrasado" logo após o login — reflete no resto da
    // sessão (Cobranças, Mala Direta) sem precisar abrir o relatório de
    // Inadimplência antes.
    GcAtualizarInadimplentes()

    Do While .T.
        nOpcao := FWMenuSelect(aMenu, "GesCon — Sistema de Gestão Condominial")
        Do Case
            Case nOpcao == 1
                GcUnidades()
            Case nOpcao == 2
                GcCondominos()
            Case nOpcao == 3
                GcDespesas()
            Case nOpcao == 4
                GcCobrancas()
            Case nOpcao == 5
                cCompetencia := FWGetText("Fechar qual competência? (YYYY-MM)", "")
                If !Empty(cCompetencia)
                    cDiaVenc := FWGetText("Dia do vencimento no mês seguinte? (1-28)", "10")
                    nDiaVenc := Val(cDiaVenc)
                    If GcFecharMes(cCompetencia, nDiaVenc)
                        MsgInfo("Competência " + cCompetencia + " fechada com sucesso.", "Fechamento Mensal")
                    Else
                        MsgAlert("Não foi possível fechar " + cCompetencia + " — já fechada ou sem unidade cadastrada.", "Fechamento Mensal")
                    EndIf
                EndIf
            Case nOpcao == 6
                cCompetencia := FWGetText("Mala direta de qual competência? (YYYY-MM)", "")
                If !Empty(cCompetencia)
                    nEnviados := GcMalaDireta(cCompetencia)
                    MsgInfo(Str(nEnviados) + " e-mail(s) enviado(s).", "Mala Direta")
                EndIf
            Case nOpcao == 7
                GcMenuRelatorios()
            Otherwise
                Exit
        EndCase
    EndDo
Return

/*/{Protheus.doc} GcMenuRelatorios
    Submenu de relatórios — Balancete Mensal, Inadimplência, Extrato
    por Unidade, Despesas por Categoria.
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcMenuRelatorios()
    Local aMenu := {"Balancete Mensal", "Inadimplência", "Extrato por Unidade", "Despesas por Categoria", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Relatórios")
    Local cCompetencia
    Local cUnidade

    Do Case
        Case nOpcao == 1
            cCompetencia := FWGetText("Balancete de qual competência? (YYYY-MM)", "")
            If !Empty(cCompetencia)
                GcBalanceteMensal(cCompetencia)
            EndIf
        Case nOpcao == 2
            GcInadimplencia()
        Case nOpcao == 3
            cUnidade := FWGetText("Extrato de qual unidade?", "")
            If !Empty(cUnidade)
                GcExtratoUnidade(cUnidade)
            EndIf
        Case nOpcao == 4
            cCompetencia := FWGetText("Despesas por categoria de qual competência? (vazio = todas)", "")
            GcDespesasCategoria(cCompetencia)
    EndCase
Return
