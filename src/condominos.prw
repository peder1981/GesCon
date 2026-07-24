// src/condominos.prw — cadastro de condôminos. CRUD via FWMBrowse: a UI
// web (advplc serve) já dá Incluir/Alterar/Excluir sem código customizado
// (ver tests/mvc_browse_test.prw do AdvPP, mesmo padrão).
#include "totvs.ch"

/*/{Protheus.doc} GcCondominos
    Abre o cadastro de condôminos (browse CRUD sobre CON).
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcCondominos()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("CON")
    oBrowse:SetDescription("Condôminos")
    oBrowse:Activate()
Return
