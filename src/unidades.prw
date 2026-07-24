// src/unidades.prw — cadastro de unidades. UNI_CONDOMINO guarda o código
// do condômino responsável como texto livre, sem combo/lookup vinculado
// (decisão registrada na spec, seção "Decisões explícitas registradas").
#include "totvs.ch"

/*/{Protheus.doc} GcUnidades
    Abre o cadastro de unidades (browse CRUD sobre UNI).
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcUnidades()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("UNI")
    oBrowse:SetDescription("Unidades")
    oBrowse:Activate()
Return
