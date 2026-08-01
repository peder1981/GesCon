// src/usuarios.prw — gestão de usuários e tokens temporários do GesCon.
// Menu "Usuários" com: Gerar Token, Revogar Token, Criar Usuário, Voltar.
#include "totvs.ch"

/*/{Protheus.doc} GcMenuUsuarios
    Menu de gestão de usuários. Abre submenu com opções: gerar token,
    revogar token, criar usuário, voltar.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcMenuUsuarios()
    Local aMenu := {"Gerar Token", "Revogar Token", "Criar Usuário", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Usuários")

    Do Case
        Case nOpcao == 1
            GcGerarToken()
        Case nOpcao == 2
            GcRevogarToken()
        Case nOpcao == 3
            GcCriarUsuario()
    EndCase
Return

/*/{Protheus.doc} GcGerarToken
    Gera token temporário para um condômino acessar o portal.
    Lista condôminos (JOIN CON-UNI), admin seleciona, sistema gera
    token + validade +48h e grava em GCT_TOKEN.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @obs Token — válido por 48 horas a partir da geração
*/
User Function GcGerarToken()
    Local aCond := TCSqlQuery("SELECT CON_CODIGO, CON_NOME, UNI_CODIGO, CON_EMAIL " + ;
        "FROM CON " + ;
        "INNER JOIN UNI ON UNI.UNI_CONDOMINO = CON.CON_CODIGO " + ;
        "WHERE CON.D_E_L_E_T_ = ' ' " + ;
        "ORDER BY CON_NOME")

    If Len(aCond) == 0
        MsgStop("Nenhum condômino cadastrado.", "Gerar Token")
        Return
    EndIf

    // Mostra lista numerada
    Local cLista := ""
    Local nJ
    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:CON_NOME + " (Uni: " + aCond[nJ]:UNI_CODIGO + ")" + Chr(10)
    Next
    cLista += "\nSelecione o número:"

    Local cSel := FWGetText(cLista, "")
    Local nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aCond)
        MsgStop("Índice inválido.", "Gerar Token")
        Return
    EndIf

    Local cConCod := aCond[nIdx]:CON_CODIGO
    Local cUniCod := aCond[nIdx]:UNI_CODIGO

    // Gera token (UUID36 simplificado)
    Local cToken := GcGerarTokenId()

    // Validade +48h em ISO (YYYY-MM-DD HH:MM:SS), para comparar direto com
    // datetime('now') do SQLite.
    //
    // A conta de dias fica com o SQLite de proposito: no AdvPP, `Date() + 2`
    // perde o tipo data e DtoS() devolve string vazia, o que gravava
    // VALIDO_ATE = "-- 10:23:45" e fazia TODO token nascer invalido -- o
    // portal do condomino nunca autenticava.
    Local aDatas := TCSqlQuery("SELECT datetime('now') as CRIADO, datetime('now', '+2 days') as VALIDADE")
    Local cCriadoIso   := aDatas[1]:CRIADO
    Local cValidadeIso := aDatas[1]:VALIDADE
    Local cLoginAtual  := GetEnv("USER")

    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO) " + ;
        "VALUES ('" + GcSqlLit(cToken) + "', '" + GcSqlLit(cLoginAtual) + "', '" + GcSqlLit(cConCod) + "', " + ;
        "'" + GcSqlLit(cUniCod) + "', '" + GcSqlLit(cCriadoIso) + "', '" + GcSqlLit(cValidadeIso) + "', 0)")

    // Mostra token ao admin
    MsgInfo("Token gerado:" + Chr(10) + ;
        "Token: " + cToken + Chr(10) + ;
        "Condômino: " + cConCod + " - " + aCond[nIdx]:CON_NOME + Chr(10) + ;
        "Unidade: " + cUniCod + Chr(10) + ;
        "Válido até: " + cValidadeIso, "GesCon — Token Gerado")
Return

/*/{Protheus.doc} GcRevogarToken
    Revoga token ativo. Lista tokens válidos (não expirados, não usados).
    Admin seleciona e faz DELETE lógico na GCT_TOKEN.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcRevogarToken()
    Local aTokens := TCSqlQuery("SELECT TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, VALIDO_ATE " + ;
        "FROM GCT_TOKEN " + ;
        "WHERE D_E_L_E_T_ = ' ' " + ;
        "AND USADO = 0 " + ;
        "AND VALIDO_ATE > datetime('now') " + ;
        "ORDER BY CRIPTADO DESC")

    If Len(aTokens) == 0
        MsgStop("Nenhum token ativo encontrado.", "Revogar Token")
        Return
    EndIf

    Local cLista := ""
    Local nJ
    For nJ := 1 To Len(aTokens)
        cLista += Str(nJ, 3) + ". " + Left(aTokens[nJ]:TOKEN, 8) + "... Uni:" + aTokens[nJ]:UNI_CODIGO + ;
            " Con:" + aTokens[nJ]:CON_CODIGO + " Val:" + aTokens[nJ]:VALIDO_ATE + Chr(10)
    Next
    cLista += "\nSelecione o número para revogar:"

    Local cSel := FWGetText(cLista, "")
    Local nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aTokens)
        MsgStop("Índice inválido.", "Revogar Token")
        Return
    EndIf

    // DELETE lógico
    Local cTokenSelecionado := aTokens[nIdx]:TOKEN
    TCSqlExec("UPDATE GCT_TOKEN SET D_E_L_E_T_ = '*' WHERE TOKEN = '" + GcSqlLit(cTokenSelecionado) + "' AND D_E_L_E_T_ = ' '")

    MsgInfo("Token revogado: " + Left(cTokenSelecionado, 8) + "...", "GesCon")
Return

/*/{Protheus.doc} GcCriarUsuario
    Cria novo usuário: Admin (login/senha).
    Condôminos acessam via token temporário (não possuem login direto).
    @type User Function
    @author GesCon
    @since 2026-07-24
    @obs Acesso de condôminos — exclusivamente via token — perfil CONDOMINO será implementado no Plano 3
*/
User Function GcCriarUsuario()
    Local aTipo := {"Admin"}
    Local nTipo := FWMenuSelect(aTipo, "Tipo de usuário")

    Do Case
        Case nTipo == 1
            GcCriarAdminNovo()
    EndCase
Return

/*/{Protheus.doc} GcCriarAdminNovo
    Cria novo administrador com login e senha.
    USR_PERFIL = 'ADMIN'.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return lSucesso, logical, .T. se criado com sucesso
*/
User Function GcCriarAdminNovo()
    Local cLogin := FWGetText("Login do novo admin:", "admin2")
    If Empty(cLogin)
        Return .F.
    EndIf

    Local cSenha := FWGetText("Senha:", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) " + ;
        "VALUES ('" + GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', 'ADMIN')")
    MsgInfo("Administrador '" + cLogin + "' criado.", "GesCon")
Return .T.

/*/{Protheus.doc} GcGerarTokenId
    Gera identificador único de 36 chars (formato UUID-like) para tokens.
    Usa timestamp + random em AdvPL puro (não há gen uuid nativo do AdvPP v1).
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return cTokenId, character, 36 chars no formato xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
*/
User Function GcGerarTokenId()
    Local cSeed := DTOC(Date()) + Time() + Str(Random(999999999), 9)
    Local cHash := FWHash(cSeed)
    // Usa os primeiros 32 chars hex + formatação UUID-like = 36
    Local cToken := Left(cHash, 8) + "-" + SubStr(cHash, 9, 4) + "-" + SubStr(cHash, 13, 4) + "-" + SubStr(cHash, 17, 4) + "-" + SubStr(cHash, 21, 12)
Return cToken
