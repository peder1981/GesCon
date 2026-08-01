// src/plano-contas.prw — cadastros contábeis de apoio: plano de contas e
// tipos de repartição. Ambos são browse CRUD puro sobre o alias; o SX3 em
// schema.sql já descreve as colunas.
#include "totvs.ch"

/*/{Protheus.doc} GcPlanoContas
    Abre o cadastro do plano de contas (browse CRUD sobre PLANO_CONTAS).
    As contas aqui são o domínio de LAN_CONTA_DEB/LAN_CONTA_CRED: sem a
    conta cadastrada, o lançamento correspondente não passa na FK.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcPlanoContas()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("PLANO_CONTAS")
    oBrowse:SetDescription("Plano de Contas")
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcReparticao
    Abre o cadastro de tipos de repartição (browse CRUD sobre REPARTICAO).
    O tipo escolhido aqui é o que GcCalcularRateio usa para dividir a
    despesa entre as unidades.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcReparticao()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("REPARTICAO")
    oBrowse:SetDescription("Tipos de Repartição")
    oBrowse:Activate()
Return
