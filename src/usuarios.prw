// src/usuarios.prw � gest�o de usu�rios e tokens tempor�rios do GesCon.
// Menu "Usu�rios" com: Gerar Token, Revogar Token, Criar Usu�rio, Voltar.
#include "totvs.ch"

/*/{Protheus.doc} GcMenuUsuarios
    Menu de gest�o de usu�rios. Abre submenu com op��es: gerar token,
    revogar token, criar usu�rio, voltar.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcMenuUsuarios()
    Local aMenu := {"Gerar Token", "Revogar Token", "Criar Usu�rio", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Usu�rios")

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
    Gera token tempor�rio para um cond�mino acessar o portal.
    Lista cond�minos (JOIN CON-UNI), admin seleciona, sistema gera
    token + validade +48h e grava em GCT_TOKEN.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @obs Token � v�lido por 48 horas a partir da gera��o
*/
User Function GcGerarToken()
    Local aCond := TCSqlQuery("SELECT CON_CODIGO, CON_NOME, UNI_CODIGO, CON_EMAIL " + ;
        "FROM CON " + ;
        "INNER JOIN UNI ON UNI.UNI_CONDOMINO = CON.CON_CODIGO " + ;
        "WHERE CON.D_E_L_E_T_ = ' ' " + ;
        "ORDER BY CON_NOME")

    If Len(aCond) == 0
        MsgStop("Nenhum cond�mino cadastrado.", "Gerar Token")
        Return
    EndIf

    // Mostra lista numerada
    Local cLista := ""
    Local nJ
    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:CON_NOME + " (Uni: " + aCond[nJ]:UNI_CODIGO + ")" + Chr(10)
    Next
    cLista += "\nSelecione o n�mero:"

    Local cSel := FWGetText(cLista, "")
    Local nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aCond)
        MsgStop("�ndice inv�lido.", "Gerar Token")
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
        "Cond�mino: " + cConCod + " - " + aCond[nIdx]:CON_NOME + Chr(10) + ;
        "Unidade: " + cUniCod + Chr(10) + ;
        "V�lido at�: " + cValidadeIso, "GesCon � Token Gerado")
Return

/*/{Protheus.doc} GcRevogarToken
    Revoga token ativo. Lista tokens v�lidos (n�o expirados, n�o usados).
    Admin seleciona e faz DELETE l�gico na GCT_TOKEN.
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
    cLista += "\nSelecione o n�mero para revogar:"

    Local cSel := FWGetText(cLista, "")
    Local nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aTokens)
        MsgStop("�ndice inv�lido.", "Revogar Token")
        Return
    EndIf

    // DELETE l�gico
    Local cTokenSelecionado := aTokens[nIdx]:TOKEN
    TCSqlExec("UPDATE GCT_TOKEN SET D_E_L_E_T_ = '*' WHERE TOKEN = '" + GcSqlLit(cTokenSelecionado) + "' AND D_E_L_E_T_ = ' '")

    MsgInfo("Token revogado: " + Left(cTokenSelecionado, 8) + "...", "GesCon")
Return

/*/{Protheus.doc} GcCriarUsuario
    Cria novo usu�rio: Admin (login/senha).
    Cond�minos acessam via token tempor�rio (n�o possuem login direto).
    @type User Function
    @author GesCon
    @since 2026-07-24
    @obs Acesso de cond�minos � exclusivamente via token � perfil CONDOMINO ser� implementado no Plano 3
*/
User Function GcCriarUsuario()
    Local aTipo := {"Admin"}
    Local nTipo := FWMenuSelect(aTipo, "Tipo de usu�rio")

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

/*/{Protheus.doc} GcDateToIso
    Converte data Protheus para formato ISO 8601 (YYYY-MM-DD).
    Usa DtoS (YYYYMMDD) com inser��o de h�fens.
    @type Static Function
    @author GesCon
    @since 2026-07-24
    @param dData, date, Data a converter
    @return cIso, character, Data em formato YYYY-MM-DD
*/
Static Function GcDateToIso(dData)
    Local cDtos := DtoS(dData)
Return SubStr(cDtos, 1, 4) + "-" + SubStr(cDtos, 5, 2) + "-" + SubStr(cDtos, 7, 2)

/*/{Protheus.doc} GcGerarTokenId
    Gera identificador �nico de 36 chars (formato UUID-like) para tokens.
    Usa timestamp + random em AdvPL puro (n�o h� gen uuid nativo do AdvPP v1).
    @type User Function
    @author GesCon
    @since 2026-07-24
    @return cTokenId, character, 36 chars no formato xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
*/
User Function GcGerarTokenId()
    Local cSeed := DTOC(Date()) + Time() + Str(Random(999999999), 9)
    Local cHash := FWHash(cSeed)
    // Usa os primeiros 32 chars hex + formata��o UUID-like = 36
    Local cToken := Left(cHash, 8) + "-" + SubStr(cHash, 9, 4) + "-" + SubStr(cHash, 13, 4) + "-" + SubStr(cHash, 17, 4) + "-" + SubStr(cHash, 21, 12)
Return cToken
