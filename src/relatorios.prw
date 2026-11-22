// src/relatorios.prw — relatórios de gestão (Plano 2, trazido pro Plano 1
// a pedido do usuário). Read-only por convenção: cada função recalcula um
// snapshot do zero (DELETE + INSERT) numa tabela RPT_* própria e abre um
// FWMBrowse sobre ela — mesmo padrão que GcFecharMes já usa pra Cobrança.
// FWMBrowse só abre tabela física por alias fixo (sem parâmetro de
// query), por isso o snapshot: não dá pra apontar direto pra uma
// consulta agregada/filtrada. Balancete Mensal é a exceção — é um
// resumo de poucos números, não uma lista, então usa MsgInfo em vez de
// browse.
//
// Cada relatório tabular vem em duas funções — GcXxxCalc() (só grava o
// snapshot, testável via `advplc run`) e GcXxx() (chama a Calc e abre o
// browse) — porque FWMBrowse:Activate() exige `advplc serve` e erroa em
// execução headless, mesmo padrão de GcCondominos/GcUnidades/etc, que
// também nunca são testadas via advplc run por esse motivo.
#include "totvs.ch"

/*/{Protheus.doc} GcAtualizarInadimplentes
    Promove pra status "atrasado" toda Cobrança "pendente" com
    vencimento já passado. Sem job agendado no AdvPP hoje — chamada
    explicitamente após o login (GesCon) e antes de recalcular o
    relatório de Inadimplência, então o status gravado em COB nunca
    fica velho por mais do que a duração de uma sessão.
    @type Function
    @author GesCon
    @since 2026-07-24
    @return nQtd, numeric, quantidade de Cobranças promovidas a atrasado
*/
User Function GcAtualizarInadimplentes()
    TCSqlExec("UPDATE COB SET COB_STATUS = 'atrasado' " + ;
        "WHERE COB_STATUS = 'pendente' AND COB_VENCTO < date('now') AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
    Local aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM COB WHERE COB_STATUS = 'atrasado' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
Return Val(aQtd[1]:QTD)

