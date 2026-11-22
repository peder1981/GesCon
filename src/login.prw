// src/login.prw — telas de login, troca de senha e escolha do condomínio.
// Senha mascarada via 3º arg bIsPassword=.T. de FWGetText. Hash, política,
// bloqueio e primeiro acesso em src/seguranca.prw.
#include "totvs.ch"

/*/{Protheus.doc} GcLogin
    Gate de autenticação. Sem usuários, o administrador só é criado com a
    senha de GESCON_ADMIN_SENHA (ver GcBootAdmin, src/seguranca.prw);
    ninguém cria administrador pela tela. Até 3 tentativas por sessão --
    o bloqueio de verdade (5 erros, 15 minutos) é por usuário, no banco.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return logical, .T. se autenticado
*/
User Function GcLogin()
    Local nTentativas := 0 as numeric
    Local lOk         := .F. as logical

    If !GcBootAdmin(GetEnv("GESCON_ADMIN_SENHA"))
        MsgStop("Nenhum usuário cadastrado. O responsável pelo servidor precisa definir a senha inicial " + ;
            "(GESCON_ADMIN_SENHA) e reiniciar o GesCon.", "GesCon")
        Return .F.
    EndIf
    Do While nTentativas < 3 .And. !lOk
        lOk := GcAutenticar()
        nTentativas++
    EndDo
Return lOk

/*/{Protheus.doc} GcAutenticar
    Pede login/senha e confere (GcAutenticarCredencial). Com troca
    obrigatória pendente, só entra depois de trocar.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return logical, .T. se autenticado
*/
User Function GcAutenticar()
    Local cLogin := "" as character
    Local cSenha := "" as character
    Local cReal  := "" as character
    Local cRet   := "" as character

    cLogin := FWGetText("Login:", "")
    If Empty(cLogin)
        Return .F.
    EndIf
    cSenha := FWGetText("Senha:", "", .T.)
    cRet := GcAutenticarCredencial(cLogin, cSenha, @cReal)
    Do Case
        Case cRet == "BLOQUEADO"
            MsgStop("Usuário bloqueado por excesso de tentativas. Tente de novo em 15 minutos.", "GesCon")
            Return .F.
        Case cRet == "INVALIDO"
            MsgStop("Login ou senha inválidos.", "GesCon")
            Return .F.
        Case cRet == "TROCA"
            If !GcTrocaObrigatoria(cReal)
                Return .F.
            EndIf
    EndCase
    cLoginAtual := cReal
Return .T.

/*/{Protheus.doc} GcTrocaObrigatoria
    Primeiro acesso ou senha redefinida: pede a senha nova duas vezes e só
    libera com ela gravada.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login já conferido
    @return logical, .T. se trocou
*/
User Function GcTrocaObrigatoria(cLogin)
    Local cNova := "" as character
    Local cConf := "" as character
    Local cMot  := "" as character

    cNova := FWGetText("Primeiro acesso: defina uma senha nova (mínimo 10 caracteres, com maiúscula, minúscula, número e caractere especial):", "", .T.)
    If Empty(cNova)
        Return .F.
    EndIf
    cConf := FWGetText("Confirme a senha nova:", "", .T.)
    If cNova != cConf
        MsgStop("A confirmação não bate com a senha nova.", "GesCon")
        Return .F.
    EndIf
    cMot := GcDefinirSenha(cLogin, cNova, .F.)
    If !Empty(cMot)
        MsgStop(cMot, "GesCon")
        Return .F.
    EndIf
    MsgInfo("Senha definida.", "GesCon")
Return .T.

/*/{Protheus.doc} GcTrocarSenha
    Troca a senha do usuário logado: confere a atual e pede a nova duas
    vezes. Antes pedia o login e deixava trocar a senha de qualquer
    usuário de quem se soubesse a senha atual.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return logical, .T. se a senha foi trocada
*/
User Function GcTrocarSenha()
    Local cAtual := "" as character
    Local cNova  := "" as character
    Local cConf  := "" as character
    Local cMot   := "" as character

    If Type("cLoginAtual") != "C" .Or. Empty(cLoginAtual)
        Return .F.
    EndIf
    cAtual := FWGetText("Senha atual:", "", .T.)
    If !GcCredenciaisValidas(cLoginAtual, cAtual)
        MsgStop("Senha atual inválida.", "Trocar Senha")
        Return .F.
    EndIf
    cNova := FWGetText("Nova senha (mínimo 10 caracteres, com maiúscula, minúscula, número e caractere especial):", "", .T.)
    If Empty(cNova)
        Return .F.
    EndIf
    cConf := FWGetText("Confirme a nova senha:", "", .T.)
    If cNova != cConf
        MsgStop("A confirmação não bate com a nova senha.", "Trocar Senha")
        Return .F.
    EndIf
    cMot := GcDefinirSenha(cLoginAtual, cNova, .F.)
    If !Empty(cMot)
        MsgStop(cMot, "Trocar Senha")
        Return .F.
    EndIf
    MsgInfo("Senha alterada com sucesso.", "Trocar Senha")
Return .T.

/*/{Protheus.doc} GcSelecionarCondominio
    Lista os condomínios disponíveis para o login corrente (todos, se
    SUPERADMIN; só os vinculados via USR_COND, se SINDICO), e grava a
    escolha como filial ativa da sessão (RpcSetEnv + Private
    g_cFilialAtiva). Se houver exatamente 1 disponível, seleciona sozinho
    sem mostrar tela. Se houver 0, bloqueia.
    @type Function
    @author GesCon
    @since 2026-08-08
    @param cLogin, character, login já autenticado
    @return lOk, logical, .T. se uma filial foi selecionada
*/
User Function GcSelecionarCondominio(cLogin)
    Local aPerfil := TCSqlQuery("SELECT USR_PERFIL FROM USR WHERE USR_LOGIN = '" + ;
        GcSqlLit(cLogin) + "' AND D_E_L_E_T_ = ' '")
    Local cPerfil := ""
    Local aCond := {}
    Local cLista := ""
    Local nJ
    Local cSel
    Local nIdx

    If Len(aPerfil) > 0
        cPerfil := aPerfil[1]:USR_PERFIL
    EndIf

    If cPerfil == "SUPERADMIN"
        aCond := TCSqlQuery("SELECT COND_FILIAL, COND_NOME FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY COND_NOME")
    Else
        aCond := TCSqlQuery("SELECT C.COND_FILIAL, C.COND_NOME FROM COND C " + ;
            "INNER JOIN USR_COND UC ON UC.FILIAL = C.COND_FILIAL AND UC.D_E_L_E_T_ = ' ' " + ;
            "WHERE UC.USR_LOGIN = '" + GcSqlLit(cLogin) + "' AND C.COND_ATIVO = 1 AND C.D_E_L_E_T_ = ' ' " + ;
            "ORDER BY C.COND_NOME")
    EndIf

    If Len(aCond) == 0
        MsgStop("Nenhum condomínio vinculado a este usuário. Fale com o administrador.", "GesCon")
        Return .F.
    EndIf

    If Len(aCond) == 1
        RpcSetEnv(aCond[1]:COND_FILIAL)
        g_cFilialAtiva := aCond[1]:COND_FILIAL
        Return .T.
    EndIf

    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:COND_NOME + Chr(10)
    Next nJ
    cLista += Chr(10) + "Selecione o número do condomínio:"

    cSel := FWGetText(cLista, "")
    nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aCond)
        MsgStop("Índice inválido.", "GesCon")
        Return .F.
    EndIf

    RpcSetEnv(aCond[nIdx]:COND_FILIAL)
    g_cFilialAtiva := aCond[nIdx]:COND_FILIAL
Return .T.
