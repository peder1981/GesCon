// src/unidades.prw — cadastro de unidades. UNI_CONDOMINO guarda o código
// do condômino responsável como texto livre, sem combo/lookup vinculado
// (decisão registrada na spec, seção "Decisões explícitas registradas").
#include "totvs.ch"

User Function GcUnidades()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("UNI")
    oBrowse:SetDescription("Unidades")
    oBrowse:Activate()
Return
