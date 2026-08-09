// src/condominios-cadastro.prw — cadastro de condomínios (tabela COND).
// Browse CRUD puro — COND não tem coluna FILIAL (é ELA que define as
// filiais dos outros, não é filtrada por uma).
#include "totvs.ch"

/*/{Protheus.doc} GcCadastroCondominios
    Abre o cadastro de condomínios (browse CRUD sobre COND) -- só para
    SUPERADMIN.

    I4 (revisão final): COND não tem FILIAL (por design -- é ELA que
    define as filiais das outras tabelas), então o auto-filtro por linha
    do engine não se aplica aqui. Um FWMBrowse cru sobre COND, disponível
    pra qualquer síndico, deixava QUALQUER síndico Alterar/Excluir
    QUALQUER condomínio -- inclusive desativar o condomínio de outro
    síndico (COND_ATIVO=0, tranca o dono de fora) ou trocar o
    COND_FILIAL alheio (órfã as 22 tabelas daquele tenant). A spec só
    previa síndico CRIANDO condomínio, nunca editando/excluindo um que
    não é seu -- e este browse não distinguia Incluir de
    Alterar/Excluir. Restringe a tela inteira a SUPERADMIN.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcCadastroCondominios()
    Local oBrowse

    If GcPerfilDoLogin(cLoginAtual) != "SUPERADMIN"
        MsgAlert("Apenas o super admin pode gerenciar o cadastro de condomínios.", "Condomínios")
        Return
    EndIf

    oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("COND")
    oBrowse:SetDescription("Condomínios")
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcVincularCondominioAoCriador
    Vincula cLogin ao condomínio cFilial em USR_COND, se o vínculo ainda
    não existir. Chamada depois que um síndico cadastra um condomínio
    novo (GcCadastroCondominios não sabe "quem" criou a linha — é um
    FWMBrowse cru — então este passo roda como uma ação separada no
    menu, não automaticamente dentro do Incluir).
    @type Function
    @author GesCon
    @since 2026-08-08
    @param cLogin, character
    @param cFilial, character
*/
User Function GcVincularCondominioAoCriador(cLogin, cFilial)
    Local aJa := TCSqlQuery("SELECT R_E_C_N_O_ FROM USR_COND WHERE USR_LOGIN = '" + ;
        GcSqlLit(cLogin) + "' AND FILIAL = '" + GcSqlLit(cFilial) + "' AND D_E_L_E_T_ = ' '")
    If Len(aJa) == 0
        TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('" + ;
            GcSqlLit(cLogin) + "', '" + GcSqlLit(cFilial) + "')")
    EndIf
Return

/*/{Protheus.doc} GcMenuVincularCondominio
    Caminho de menu para GcVincularCondominioAoCriador — que por si só
    não tem UI (é uma função de apoio pura). Lista os condomínios ativos,
    deixa o usuário logado (cLoginAtual, Private declarado em GesCon())
    escolher um e vincula. Cobre o caso descrito na doc de
    GcCadastroCondominios: um síndico que acabou de cadastrar um
    condomínio novo pelo browse cru ainda precisa se vincular a ele
    manualmente.
    C2 (revisão final), defesa em profundidade: GcMenuUsuarios já esconde
    esta opção de quem não é SUPERADMIN, mas esta função confere de novo
    -- sem isto, qualquer síndico conseguia se autovincular (e ganhar
    acesso total de leitura/escrita, via "Trocar Condomínio") a
    QUALQUER condomínio ativo, inclusive de outro síndico.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcMenuVincularCondominio()
    Local aCond
    Local cLista := ""
    Local nJ
    Local cSel
    Local nIdx

    If GcPerfilDoLogin(cLoginAtual) != "SUPERADMIN"
        MsgAlert("Apenas o super admin pode se vincular livremente a qualquer condomínio.", "Vincular Condomínio")
        Return
    EndIf

    aCond := TCSqlQuery("SELECT COND_FILIAL, COND_NOME FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY COND_NOME")

    If Len(aCond) == 0
        MsgAlert("Nenhum condomínio cadastrado ainda.", "Vincular Condomínio")
        Return
    EndIf

    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:COND_NOME + Chr(10)
    Next nJ
    cLista += "\nVincular-se a qual condomínio?"

    cSel := FWGetText(cLista, "")
    nIdx := Val(AllTrim(cSel))

    If nIdx < 1 .Or. nIdx > Len(aCond)
        MsgAlert("Índice inválido.", "Vincular Condomínio")
        Return
    EndIf

    GcVincularCondominioAoCriador(cLoginAtual, aCond[nIdx]:COND_FILIAL)
    MsgInfo("Vinculado ao condomínio '" + AllTrim(aCond[nIdx]:COND_NOME) + "'.", "GesCon")
Return
