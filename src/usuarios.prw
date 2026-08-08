// src/usuarios.prw — gestão de usuários e tokens temporários do GesCon.
// Menu "Usuários" com: Gerar Token, Revogar Token, Criar Usuário,
// Vincular-me a Condomínio, Voltar.
#include "totvs.ch"

/*/{Protheus.doc} GcMenuUsuarios
    Menu de gestão de usuários. Abre submenu com opções: gerar token,
    revogar token, criar usuário, vincular-me a condomínio, voltar.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcMenuUsuarios()
    Local aMenu := {"Gerar Token", "Revogar Token", "Criar Usuário", "Vincular-me a Condomínio", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Usuários")

    Do Case
        Case nOpcao == 1
            GcGerarToken()
        Case nOpcao == 2
            GcRevogarToken()
        Case nOpcao == 3
            GcCriarUsuario()
        Case nOpcao == 4
            GcMenuVincularCondominio()
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
    Local aTipo := {"Super Admin", "Síndico"}
    Local nTipo := FWMenuSelect(aTipo, "Tipo de usuário")

    Do Case
        Case nTipo == 1
            GcCriarAdminNovo("SUPERADMIN")
        Case nTipo == 2
            GcCriarSindicoNovo()
    EndCase
Return

/*/{Protheus.doc} GcCriarAdminNovo
    Cria novo administrador com login e senha, no perfil recebido em
    cPerfil ('SUPERADMIN' ou 'ADMIN'). Sem parâmetro (chamada legada,
    zero args), assume 'SUPERADMIN' — preserva o comportamento de
    qualquer chamador anterior a esta função ganhar o parâmetro.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cPerfil, character, perfil do novo usuário (default 'SUPERADMIN')
    @return lSucesso, logical, .T. se criado com sucesso
*/
User Function GcCriarAdminNovo(cPerfil)
    Local cLogin := FWGetText("Login do novo admin:", "admin2")
    If Empty(cLogin)
        Return .F.
    EndIf

    Local cSenha := FWGetText("Senha:", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf

    If Empty(cPerfil)
        cPerfil := "SUPERADMIN"
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) " + ;
        "VALUES ('" + GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', '" + GcSqlLit(cPerfil) + "')")
    MsgInfo("Administrador '" + cLogin + "' criado.", "GesCon")
Return .T.

/*/{Protheus.doc} GcParseIndicesSindico
    Faz o parsing puro de uma lista de índices separados por vírgula
    (ex: "1,3,5") — extraído de GcCriarSindicoNovo pra ficar testável
    sem depender de FWGetText. Ignora tokens vazios/inválidos e qualquer
    índice fora de [1, nMax] (ex: "1,x,99" com nMax=3 devolve só {1}).
    @type Function
    @author GesCon
    @since 2026-08-08
    @param cSel, character, lista de índices separados por vírgula
    @param nMax, numeric, maior índice válido (Len(aCond) do chamador)
    @return aIdx, array, índices válidos (1-based), sem duplicar a ordem de entrada
*/
User Function GcParseIndicesSindico(cSel, nMax)
    Local aTok := StrTokArr(cSel, ",")
    Local aIdx := {}
    Local i
    Local nIdx

    For i := 1 To Len(aTok)
        nIdx := Val(AllTrim(aTok[i]))
        If nIdx >= 1 .And. nIdx <= nMax
            AAdd(aIdx, nIdx)
        EndIf
    Next i
Return aIdx

/*/{Protheus.doc} GcCriarSindicoNovo
    Cria um síndico (USR_PERFIL='SINDICO') e vincula a 1+ condomínios
    escolhidos de uma lista (índices separados por vírgula, ex: "1,3").
    @type Function
    @author GesCon
    @since 2026-08-08
    @return lOk, logical
*/
User Function GcCriarSindicoNovo()
    Local cLogin := FWGetText("Login do novo síndico:", "")
    Local cSenha
    Local aCond
    Local cLista := ""
    Local nJ
    Local cSel
    Local aIdx
    Local i

    If Empty(cLogin)
        Return .F.
    EndIf

    cSenha := FWGetText("Senha:", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf

    aCond := TCSqlQuery("SELECT COND_FILIAL, COND_NOME FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY COND_NOME")
    If Len(aCond) == 0
        MsgAlert("Nenhum condomínio cadastrado ainda.", "Criar Síndico")
        Return .F.
    EndIf

    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:COND_NOME + Chr(10)
    Next nJ
    cLista += "\nNúmeros dos condomínios (separados por vírgula, ex: 1,3):"

    cSel := FWGetText(cLista, "")
    If Empty(cSel)
        Return .F.
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('" + ;
        GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', 'SINDICO')")

    aIdx := GcParseIndicesSindico(cSel, Len(aCond))
    For i := 1 To Len(aIdx)
        TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('" + ;
            GcSqlLit(cLogin) + "', '" + GcSqlLit(aCond[aIdx[i]]:COND_FILIAL) + "')")
    Next i

    MsgInfo("Síndico '" + cLogin + "' criado e vinculado.", "GesCon")
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
