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
#include "db.prw"

/*/{Protheus.doc} GcBalanceteMensal
    Balancete de uma competência: receitas (Cobrança paga), despesas
    lançadas, saldo. Mostra via MsgInfo.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, competência "YYYY-MM"
    @return nSaldo, numeric, receitas - despesas
*/
User Function GcBalanceteMensal(cCompetencia)
    Local aReceitas := TCSqlQuery("SELECT COALESCE(SUM(COB_VALOR),0) AS TOTAL FROM COB WHERE COB_COMPET = '" + ;
        GcSqlLit(cCompetencia) + "' AND COB_STATUS = 'pago' AND D_E_L_E_T_ = ' '")
    Local nReceitas := Val(aReceitas[1]:TOTAL)

    Local aDespesas := TCSqlQuery("SELECT COALESCE(SUM(DES_VALOR),0) AS TOTAL FROM DES WHERE DES_COMPET = '" + ;
        GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' '")
    Local nDespesas := Val(aDespesas[1]:TOTAL)

    Local nSaldo := nReceitas - nDespesas

    MsgInfo("Competência: " + cCompetencia + Chr(10) + ;
        "Receitas (cobranças pagas): R$ " + cValToChar(nReceitas) + Chr(10) + ;
        "Despesas: R$ " + cValToChar(nDespesas) + Chr(10) + ;
        "Saldo: R$ " + cValToChar(nSaldo), "Balancete Mensal")
Return nSaldo

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
        "WHERE COB_STATUS = 'pendente' AND COB_VENCTO < date('now') AND D_E_L_E_T_ = ' '")
    Local aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM COB WHERE COB_STATUS = 'atrasado' AND D_E_L_E_T_ = ' '")
Return Val(aQtd[1]:QTD)

/*/{Protheus.doc} GcInadimplenciaCalc
    Recalcula RPT_INADIM do zero: unidades com Cobrança em status
    "atrasado" (chama GcAtualizarInadimplentes primeiro, pra garantir
    que o status reflete a data atual), valor e dias de atraso.
    @type Function
    @author GesCon
    @since 2026-07-24
    @return nQtd, numeric, quantidade de linhas geradas
*/
User Function GcInadimplenciaCalc()
    GcAtualizarInadimplentes()

    TCSqlExec("DELETE FROM RPT_INADIM")
    TCSqlExec("INSERT INTO RPT_INADIM (RIN_UNIDADE, RIN_COMPET, RIN_VALOR, RIN_VENCTO, RIN_ATRASO) " + ;
        "SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, " + ;
        "CAST(julianday('now') - julianday(COB_VENCTO) AS INTEGER) " + ;
        "FROM COB WHERE COB_STATUS = 'atrasado' AND D_E_L_E_T_ = ' ' " + ;
        "ORDER BY COB_VENCTO")
    Local aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_INADIM")
Return Val(aQtd[1]:QTD)

/*/{Protheus.doc} GcInadimplencia
    Abre a tela de inadimplência (chama GcInadimplenciaCalc + browse).
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcInadimplencia()
    GcInadimplenciaCalc()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("RPT_INADIM")
    oBrowse:SetDescription("Inadimplência")
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcExtratoUnidadeCalc
    Recalcula RPT_EXTRATO do zero: histórico de cobranças/pagamentos de
    uma unidade.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cUnidade, character, código da unidade (UNI_CODIGO)
    @return nQtd, numeric, quantidade de linhas geradas
*/
User Function GcExtratoUnidadeCalc(cUnidade)
    TCSqlExec("DELETE FROM RPT_EXTRATO")
    TCSqlExec("INSERT INTO RPT_EXTRATO (REX_COMPET, REX_VALOR, REX_VENCTO, REX_STATUS, REX_DTPAG) " + ;
        "SELECT COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_DTPAG " + ;
        "FROM COB WHERE COB_UNIDADE = '" + GcSqlLit(cUnidade) + "' AND D_E_L_E_T_ = ' ' " + ;
        "ORDER BY COB_COMPET")
    Local aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_EXTRATO")
Return Val(aQtd[1]:QTD)

/*/{Protheus.doc} GcExtratoUnidade
    Abre a tela de extrato de uma unidade (chama GcExtratoUnidadeCalc +
    browse).
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cUnidade, character, código da unidade (UNI_CODIGO)
*/
User Function GcExtratoUnidade(cUnidade)
    GcExtratoUnidadeCalc(cUnidade)
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("RPT_EXTRATO")
    oBrowse:SetDescription("Extrato — Unidade " + cUnidade)
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcDespesasCategoriaCalc
    Recalcula RPT_DESCAT do zero: soma de despesas agrupada por
    categoria, opcionalmente filtrada por competência.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, "YYYY-MM" ou "" para todas
    @return nQtd, numeric, quantidade de categorias geradas
*/
User Function GcDespesasCategoriaCalc(cCompetencia)
    Local cWhere := "D_E_L_E_T_ = ' '"
    If !Empty(cCompetencia)
        cWhere += " AND DES_COMPET = '" + GcSqlLit(cCompetencia) + "'"
    EndIf

    TCSqlExec("DELETE FROM RPT_DESCAT")
    TCSqlExec("INSERT INTO RPT_DESCAT (RDC_CATEG, RDC_TOTAL) " + ;
        "SELECT COALESCE(NULLIF(DES_CATEG,''),'(sem categoria)'), SUM(DES_VALOR) " + ;
        "FROM DES WHERE " + cWhere + " GROUP BY COALESCE(NULLIF(DES_CATEG,''),'(sem categoria)') " + ;
        "ORDER BY SUM(DES_VALOR) DESC")
    Local aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM RPT_DESCAT")
Return Val(aQtd[1]:QTD)

/*/{Protheus.doc} GcDespesasCategoria
    Abre a tela de despesas por categoria (chama
    GcDespesasCategoriaCalc + browse).
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, "YYYY-MM" ou "" para todas
*/
User Function GcDespesasCategoria(cCompetencia)
    GcDespesasCategoriaCalc(cCompetencia)

    Local cDescricao := "Despesas por Categoria"
    If !Empty(cCompetencia)
        cDescricao += " — " + cCompetencia
    EndIf

    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("RPT_DESCAT")
    oBrowse:SetDescription(cDescricao)
    oBrowse:Activate()
Return
