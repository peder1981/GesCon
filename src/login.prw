// src/login.prw — gate de autenticação (spec original, operação nº5 do
// v1, nunca implementada até agora). Login único de administrador, sem
// papéis/permissões. Sem tela dedicada de cadastro de usuário na v1: se
// a tabela USR estiver vazia, o primeiro acesso cria o administrador.
// Limitação conhecida: FWGetText não tem campo de senha mascarado (não
// existe essa capacidade no AdvPP hoje) — a senha fica visível ao
// digitar. Senha nunca é gravada em texto puro — sempre via FWHash
// (SHA-256, AdvPP v1.23.5+).
#include "totvs.ch"
#include "db.prw"

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

    Local cSenha := FWGetText("Escolha uma senha para " + cLogin + " (sem campo mascarado na v1 — fica visível ao digitar):", "")
    If Empty(cSenha)
        Return .F.
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA) VALUES ('" + ;
        GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "')")
    MsgInfo("Administrador " + cLogin + " criado. Login efetuado.", "GesCon")
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

    Local cSenha := FWGetText("Senha (sem campo mascarado na v1 — fica visível ao digitar):", "")

    Local aConfere := TCSqlQuery("SELECT USR_LOGIN FROM USR WHERE USR_LOGIN = '" + GcSqlLit(cLogin) + ;
        "' AND USR_SENHA = '" + GcSqlLit(FWHash(cSenha)) + "' AND D_E_L_E_T_ = ' '")
    If Len(aConfere) == 0
        MsgStop("Login ou senha inválidos.", "GesCon")
        Return .F.
    EndIf
Return .T.
