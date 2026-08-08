// src/login.prw — gate de autenticação (spec original, operação nº5 do
// v1, nunca implementada até agora). Login único de administrador, sem
// papéis/permissões. Sem tela dedicada de cadastro de usuário na v1: se
// a tabela USR estiver vazia, o primeiro acesso cria o administrador.
// Senha mascarada via 3º arg bIsPassword=.T. de FWGetText (AdvPP v1.24.0+).
// Senha nunca é gravada em texto puro — sempre via FWHash
// (SHA-256, AdvPP v1.23.5+).
#include "totvs.ch"

/*/{Protheus.doc} GcLogin
    Gate de autenticação. Se não houver nenhum usuário cadastrado,
    cria o administrador no primeiro acesso (GcCriarAdmin). Caso
    contrário, pede login/senha (até 3 tentativas).
    @type Function
    @author GesCon
    @since 2026-07-24
    @return lOk, logical, .T. se autenticado
*/
User Function GcLogin()
    Local aUsr := TCSqlQuery("SELECT COUNT(*) AS QTD FROM USR WHERE D_E_L_E_T_ = ' '")
    Local nQtd := Val(aUsr[1]:QTD)
    Local nTentativas
    Local lOk

    If nQtd == 0
        Return GcCriarAdmin()
    EndIf

    nTentativas := 0
    lOk := .F.
    Do While nTentativas < 3 .And. !lOk
        lOk := GcAutenticar()
        nTentativas++
    EndDo
Return lOk

/*/{Protheus.doc} GcCriarAdmin
    Cria o administrador único no primeiro acesso (tabela USR vazia).
    @type Function
    @author GesCon
    @since 2026-07-24
    @return lOk, logical, .T. se criou (e autenticou) com sucesso
*/
User Function GcCriarAdmin()
    Local cLogin := FWGetText("Nenhum administrador cadastrado. Escolha um login:", "admin")
    If Empty(cLogin)
        Return .F.
    EndIf

    Local cSenha := FWGetText("Escolha uma senha para " + cLogin + ":", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('" + ;
        GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', 'SUPERADMIN')")
    MsgInfo("Administrador " + cLogin + " criado. Login efetuado.", "GesCon")
    cLoginAtual := cLogin
Return .T.

/*/{Protheus.doc} GcAutenticar
    Pede login/senha e confere contra a tabela USR (senha em hash).
    @type Function
    @author GesCon
    @since 2026-07-24
    @return lOk, logical, .T. se as credenciais batem
*/
User Function GcAutenticar()
    Local cLogin := FWGetText("Login:", "")
    If Empty(cLogin)
        Return .F.
    EndIf

    Local cSenha := FWGetText("Senha:", "", .T.)

    If !GcCredenciaisValidas(cLogin, cSenha)
        MsgStop("Login ou senha inválidos.", "GesCon")
        Return .F.
    EndIf

    cLoginAtual := cLogin
Return .T.

/*/{Protheus.doc} GcCredenciaisValidas
    Confere um login/senha contra a tabela USR (senha em hash) sem
    pedir nada nem mostrar diálogo — usado por GcAutenticar e
    GcTrocarSenha.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cLogin, character
    @param cSenha, character, senha em texto puro (comparada por hash)
    @return lOk, logical, .T. se login+senha batem com um usuário ativo
*/
User Function GcCredenciaisValidas(cLogin, cSenha)
    Local aConfere := TCSqlQuery("SELECT USR_LOGIN FROM USR WHERE USR_LOGIN = '" + GcSqlLit(cLogin) + ;
        "' AND USR_SENHA = '" + GcSqlLit(FWHash(cSenha)) + "' AND D_E_L_E_T_ = ' '")
Return Len(aConfere) > 0

/*/{Protheus.doc} GcTrocarSenha
    Troca a senha de um usuário: pede login, senha atual (confere) e
    a senha nova duas vezes (confirmação).
    @type Function
    @author GesCon
    @since 2026-07-24
    @return lOk, logical, .T. se a senha foi trocada
*/
User Function GcTrocarSenha()
    Local cLogin := FWGetText("Login:", "")
    If Empty(cLogin)
        Return .F.
    EndIf

    Local cSenhaAtual := FWGetText("Senha atual:", "", .T.)
    If !GcCredenciaisValidas(cLogin, cSenhaAtual)
        MsgStop("Login ou senha atual inválidos.", "Trocar Senha")
        Return .F.
    EndIf

    Local cSenhaNova := FWGetText("Nova senha:", "", .T.)
    If Empty(cSenhaNova)
        Return .F.
    EndIf

    Local cConfirma := FWGetText("Confirme a nova senha:", "", .T.)
    If cSenhaNova != cConfirma
        MsgStop("A confirmação não bate com a nova senha.", "Trocar Senha")
        Return .F.
    EndIf

    TCSqlExec("UPDATE USR SET USR_SENHA = '" + GcSqlLit(FWHash(cSenhaNova)) + ;
        "' WHERE USR_LOGIN = '" + GcSqlLit(cLogin) + "' AND D_E_L_E_T_ = ' '")
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
    cLista += "\nSelecione o número do condomínio:"

    cSel := FWGetText(cLista, "")
    nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aCond)
        MsgStop("Índice inválido.", "GesCon")
        Return .F.
    EndIf

    RpcSetEnv(aCond[nIdx]:COND_FILIAL)
    g_cFilialAtiva := aCond[nIdx]:COND_FILIAL
Return .T.
