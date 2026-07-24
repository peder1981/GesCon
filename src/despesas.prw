// src/despesas.prw — lançamento de despesas. Mesmo padrão de browse das
// telas anteriores; DES_VALOR <= 0 fica pra validação no Fechamento
// Mensal (Task 10), não bloqueado aqui — FWMBrowse não expõe validação de
// campo customizada na v1 desta integração.
#include "totvs.ch"

User Function GcDespesas()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("DES")
    oBrowse:SetDescription("Despesas")
    oBrowse:Activate()
Return
