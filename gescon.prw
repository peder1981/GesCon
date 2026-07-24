// gescon.prw — ponto de entrada do GesCon. `advplc serve gescon.prw` sobe
// a UI web com um menu real (FWMenuSelect, AdvPP v1.23.0+) navegando
// entre todas as telas sem reiniciar o processo. Login fica pro Plano 2.
#include "totvs.ch"
#include "src/db.prw"
#include "src/unidades.prw"
#include "src/condominos.prw"
#include "src/despesas.prw"
#include "src/cobrancas.prw"
#include "src/fechamento.prw"
#include "src/malas.prw"

/*/{Protheus.doc} GesCon
    Ponto de entrada do GesCon — sobe com `advplc serve gescon.prw`,
    mostra um menu navegando entre todas as telas.
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GesCon()
    Local aMenu := {"Unidades", "Condôminos", "Despesas", "Cobranças", "Fechamento Mensal", "Mala Direta", "Sair"}
    Local nOpcao
    Local cCompetencia
    Local nEnviados

    ConOut("GesCon — Sistema de Gestão Condominial")

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
                    If GcFecharMes(cCompetencia)
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
            Otherwise
                Exit
        EndCase
    EndDo
Return
