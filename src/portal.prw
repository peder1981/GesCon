// src/portal.prw — autenticação do condômino via token + portal de leitura.
// O condômino cola o token recebido do admin, acessa apenas as cobranças
// da sua unidade em modo read-only.
#include "totvs.ch"

/*/{Protheus.doc} GcAuthPortalToken
    Autentica um token na tabela GCT_TOKEN.
    Verifica: TOKEN existente, D_E_L_E_T_=' ', VALIDO_ATE > agora, USADO=0.
    Se válido: marca USADO=1, busca uni_codigo pela tabela, retorna .T.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cToken, character, token UUID 36 chars
    @return lOk, logical
*/
User Function GcAuthPortalToken(cToken)
    Local aToken := {} as array
    Local aCond  := {} as array

    If ValType(cToken) != "C" .Or. Empty(cToken)
        Return .F.
    EndIf

    // Consome o token num único comando: o UPDATE só marca USADO = 1 se o
    // token ainda está válido e não usado, e devolve a linha consumida.
    // Antes era SELECT e depois UPDATE: dois acessos simultâneos passavam
    // com o mesmo token de uso único. TOKEN é PRIMARY KEY (globalmente
    // único) -- sem filtro de FILIAL de propósito: um token gerado antes da
    // migração multi-condomínio tem FILIAL=''/NULL.
    aToken := TCSqlQuery("UPDATE GCT_TOKEN SET USADO = 1 " + ;
        "WHERE TOKEN = '" + GcSqlLit(AllTrim(cToken)) + "' " + ;
        "AND D_E_L_E_T_ = ' ' " + ;
        "AND USADO = 0 " + ;
        "AND VALIDO_ATE > datetime('now') " + ;
        "RETURNING UNI_CODIGO, CON_CODIGO, FILIAL")
    If Len(aToken) == 0
        Return .F.
    EndIf
    aCond := TCSqlQuery("SELECT COND_NOME FROM COND WHERE COND_FILIAL = '" + GcSqlLit(aToken[1]:FILIAL) + "' AND D_E_L_E_T_ = ' '")

    // A sessão do portal NUNCA passa por GcSelecionarCondominio (esse é o
    // fluxo do admin, gescon.prw:72/126) -- então FWxFilial() aqui dentro
    // sempre devolveria o default vazio, não a filial de quem é dono do
    // token, e todo filtro FILIAL nas telas seguintes (GcPortalCalcCobrancas,
    // GcPortalCondominoV2) bateria contra a filial errada. É por isso que os
    // lookups de GCT_TOKEN acima e abaixo não filtram por FILIAL -- eles são
    // o jeito de DESCOBRIR a filial, não de já assumir uma. RpcSetEnv aqui é
    // o que estabelece o contexto pras telas seguintes usarem certo.
    // Token gerado antes desta migração tem FILIAL=''/NULL: RpcSetEnv
    // recusa (exige exatamente 6 caracteres) e devolve .F. sem alterar o
    // estado da sessão -- fica no default vazio, que é o comportamento
    // correto pra dado que também nunca teve FILIAL real.
    RpcSetEnv(aToken[1]:FILIAL)

    // Salva unidade e condômino no escopo da sessão
    g_cUniPortal := aToken[1]:UNI_CODIGO
    g_cConPortal := aToken[1]:CON_CODIGO
    g_cFilialAtiva := aToken[1]:FILIAL
    g_lAutoPortal := .T.
    // Fica vazio para tokens gerados antes da migração multi-condomínio
    // (FILIAL=''/NULL, sem COND correspondente).
    g_cCondNomePortal := ""
    If Len(aCond) > 0
        g_cCondNomePortal := aCond[1]:COND_NOME
    EndIf

    // Sem diálogo aqui: a função também serve à interface web, que avisa do jeito dela.
Return .T.

