// src/condominos.prw — cadastro de condôminos. CRUD via FWMBrowse: a UI
// web (advplc serve) já dá Incluir/Alterar/Excluir sem código customizado
// (ver tests/mvc_browse_test.prw do AdvPP, mesmo padrão).
#include "totvs.ch"

User Function GcCondominos()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("CON")
    oBrowse:SetDescription("Condôminos")
    oBrowse:Activate()
Return
