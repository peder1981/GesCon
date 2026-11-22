// src/usuarios.prw — gestão de usuários e tokens temporários do GesCon.
// Menu "Usuários" com: Gerar Token, Revogar Token, Criar Usuário,
// Vincular-me a Condomínio, Voltar.
#include "totvs.ch"

/*/{Protheus.doc} GcMenuUsuarios
    Menu de gestão de usuários. Abre submenu com opções: gerar token,
    revogar token, criar usuário, vincular-me a condomínio (só
    SUPERADMIN), voltar.

    C2 (revisão final): "Vincular-me a Condomínio" ficava disponível pra
    QUALQUER perfil logado e não checava nada além de "o condomínio está
    ativo" -- um síndico conseguia se autovincular a qualquer condomínio
    (inclusive de outro síndico) e, com "Trocar Condomínio", ganhar acesso
    total de leitura/escrita a dados de um tenant que não é seu. Some do
    menu pra quem não é SUPERADMIN; GcMenuVincularCondominio também
    confere de novo (defesa em profundidade, ver seu próprio comentário).
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcMenuUsuarios()
    Local lSuperAdmin := (GcPerfilDoLogin(cLoginAtual) == "SUPERADMIN")
    Local aMenu := {"Gerar Token", "Revogar Token", "Criar Usuário"}
    Local nOpcao

    If lSuperAdmin
        AAdd(aMenu, "Vincular-me a Condomínio")
    EndIf
    AAdd(aMenu, "Voltar")

    nOpcao := FWMenuSelect(aMenu, "Usuários")

    Do Case
        Case nOpcao == 1
            GcGerarToken()
        Case nOpcao == 2
            GcRevogarToken()
        Case nOpcao == 3
            GcCriarUsuario()
        Case nOpcao == 4 .And. lSuperAdmin
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
        "INNER JOIN UNI ON UNI.UNI_CONDOMINO = CON.CON_CODIGO AND UNI.FILIAL = '" + GcSqlLit(FWxFilial('UNI')) + "' " + ;
        "WHERE CON.D_E_L_E_T_ = ' ' AND CON.FILIAL = '" + GcSqlLit(FWxFilial('CON')) + "' " + ;
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
    // Chr(10), não "\n" -- AdvPL/AdvPP não interpreta "\n" como escape de
    // quebra de linha (achado do Wilson Kraft, QA 2026-08-22).
    cLista += Chr(10) + "Selecione o número:"

    Local cSel := FWGetText(cLista, "")
    Local nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aCond)
        MsgStop("Índice inválido.", "Gerar Token")
        Return
    EndIf

    Local cConCod := aCond[nIdx]:CON_CODIGO
    Local cUniCod := aCond[nIdx]:UNI_CODIGO

    // Token aleatório criptográfico (ver GcGerarTokenId)
    Local cToken := GcGerarTokenId()
    If Empty(cToken)
        MsgStop("Não foi possível gerar um token seguro. Tente de novo.", "Gerar Token")
        Return
    EndIf

    // Validade +48h em ISO (YYYY-MM-DD HH:MM:SS), para comparar direto com
    // datetime('now') do SQLite.
    //
    // A conta de dias fica com o SQLite de proposito: no AdvPP, `Date() + 2`
    // perde o tipo data e DtoS() devolve string vazia, o que gravava
    // VALIDO_ATE = "-- 10:23:45" e fazia TODO token nascer invalido -- o
    // portal do condomino nunca autenticava.
    //
    // O que é GRAVADO fica em UTC (datetime('now')), que é o que o portal
    // compara; o que é MOSTRADO ao admin vai em hora local (VALIDADE_LOCAL)
    // -- exibir o UTC dava "válido até" 3h à frente no Brasil (ponto em
    // aberto do Wilson Kraft, QA v1.2.0).
    Local aDatas := TCSqlQuery("SELECT datetime('now') as CRIADO, datetime('now', '+2 days') as VALIDADE, datetime('now', '+2 days', 'localtime') as VALIDADE_LOCAL")
    Local cCriadoIso   := aDatas[1]:CRIADO
    Local cValidadeIso := aDatas[1]:VALIDADE
    Local cValidadeLocal := aDatas[1]:VALIDADE_LOCAL
    // Emissor = login de quem está na sessão (Private cLoginAtual de
    // GesCon()). Antes um Local com GetEnv("USER") encobria a variável e
    // gravava o usuário do sistema operacional do servidor.
    Local cEmissor     := ""
    If Type("cLoginAtual") == "C"
        cEmissor := cLoginAtual
    EndIf

    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, FILIAL) " + ;
        "VALUES ('" + GcSqlLit(cToken) + "', '" + GcSqlLit(cEmissor) + "', '" + GcSqlLit(cConCod) + "', " + ;
        "'" + GcSqlLit(cUniCod) + "', '" + GcSqlLit(cCriadoIso) + "', '" + GcSqlLit(cValidadeIso) + "', 0, '" + GcSqlLit(FWxFilial('GCT_TOKEN')) + "')")

    // Mostra token ao admin
    MsgInfo("Token gerado:" + Chr(10) + ;
        "Token: " + cToken + Chr(10) + ;
        "Condômino: " + cConCod + " - " + aCond[nIdx]:CON_NOME + Chr(10) + ;
        "Unidade: " + cUniCod + Chr(10) + ;
        "Válido até: " + cValidadeLocal, "GesCon — Token Gerado")
Return

/*/{Protheus.doc} GcRevogarToken
    Revoga token ativo. Lista tokens válidos (não expirados, não usados).
    Admin seleciona e faz DELETE lógico na GCT_TOKEN.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcRevogarToken()
    Local aTokens := TCSqlQuery("SELECT TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, datetime(VALIDO_ATE, 'localtime') AS VALIDO_ATE " + ;
        "FROM GCT_TOKEN " + ;
        "WHERE D_E_L_E_T_ = ' ' " + ;
        "AND USADO = 0 " + ;
        "AND VALIDO_ATE > datetime('now') " + ;
        "AND FILIAL = '" + GcSqlLit(FWxFilial('GCT_TOKEN')) + "' " + ;
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
    cLista += Chr(10) + "Selecione o número para revogar:"

    Local cSel := FWGetText(cLista, "")
    Local nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aTokens)
        MsgStop("Índice inválido.", "Revogar Token")
        Return
    EndIf

    // DELETE lógico
    Local cTokenSelecionado := aTokens[nIdx]:TOKEN
    TCSqlExec("UPDATE GCT_TOKEN SET D_E_L_E_T_ = '*' WHERE TOKEN = '" + GcSqlLit(cTokenSelecionado) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('GCT_TOKEN')) + "'")

    MsgInfo("Token revogado: " + Left(cTokenSelecionado, 8) + "...", "GesCon")
Return

/*/{Protheus.doc} GcCriarUsuario
    Cria novo usuário: Admin (login/senha) ou Síndico.
    Condôminos acessam via token temporário (não possuem login direto).

    I5 (revisão final): a opção "Super Admin" ficava escolhível por
    QUALQUER usuário logado -- um síndico conseguia criar outro super
    admin (escalação de privilégio direta). Some da lista pra quem não é
    SUPERADMIN; GcCriarAdminNovo também confere de novo (defesa em
    profundidade, ver seu próprio comentário).
    @type User Function
    @author GesCon
    @since 2026-07-24
    @obs Acesso de condôminos — exclusivamente via token — perfil CONDOMINO será implementado no Plano 3
*/
User Function GcCriarUsuario()
    Local lSuperAdmin := (GcPerfilDoLogin(cLoginAtual) == "SUPERADMIN")
    Local aTipo := {}
    Local nTipo

    If lSuperAdmin
        AAdd(aTipo, "Super Admin")
    EndIf
    AAdd(aTipo, "Síndico")

    nTipo := FWMenuSelect(aTipo, "Tipo de usuário")

    If lSuperAdmin
        Do Case
            Case nTipo == 1
                GcCriarAdminNovo("SUPERADMIN")
            Case nTipo == 2
                GcCriarSindicoNovo()
        EndCase
    Else
        Do Case
            Case nTipo == 1
                GcCriarSindicoNovo()
        EndCase
    EndIf
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
    Local cLogin := "" as character
    Local cSenha := "" as character
    Local cMot   := "" as character

    If Empty(cPerfil) .Or. cPerfil == "ADMIN"
        cPerfil := "SUPERADMIN"
    EndIf
    If cPerfil == "SUPERADMIN" .And. GcPerfilDoLogin(GcUsuarioSessao()) != "SUPERADMIN"
        MsgAlert("Apenas um super admin pode criar outro super admin.", "Criar Usuário")
        Return .F.
    EndIf
    cLogin := FWGetText("Login do novo admin (3 a 30 letras minúsculas, números, ponto, hífen ou sublinhado):", "")
    If Empty(cLogin)
        Return .F.
    EndIf
    cSenha := FWGetText("Senha inicial (ele troca no primeiro acesso):", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf
    cMot := GcCriarUsuarioBase(cLogin, cSenha, cPerfil)
    If !Empty(cMot)
        MsgStop(cMot, "Criar Usuário")
        Return .F.
    EndIf
    MsgInfo("Administrador '" + GcLoginNormal(cLogin) + "' criado. A senha será trocada no primeiro acesso.", "GesCon")
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
    Local cLogin := "" as character
    Local cSenha := "" as character
    Local cMot   := "" as character
    Local cEu    := GcUsuarioSessao() as character
    Local aCond  := {} as array
    Local cLista := "" as character
    Local cSel   := "" as character
    Local aIdx   := {} as array
    Local nJ     := 0 as numeric
    Local i      := 0 as numeric

    // Síndico só vincula o usuário novo aos condomínios dele; antes a lista
    // trazia todos, e um síndico dava a si mesmo (por outro login) acesso a
    // condomínios de outros clientes.
    If GcPerfilDoLogin(cEu) == "SUPERADMIN"
        aCond := TCSqlQuery("SELECT COND_FILIAL, COND_NOME FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY COND_NOME")
    Else
        aCond := TCSqlQuery("SELECT C.COND_FILIAL, C.COND_NOME FROM COND C " + ;
            "INNER JOIN USR_COND UC ON UC.FILIAL = C.COND_FILIAL AND UC.D_E_L_E_T_ = ' ' " + ;
            "WHERE lower(UC.USR_LOGIN) = '" + GcSqlLit(GcLoginNormal(cEu)) + "' AND C.COND_ATIVO = 1 AND C.D_E_L_E_T_ = ' ' " + ;
            "ORDER BY C.COND_NOME")
    EndIf
    If Len(aCond) == 0
        MsgAlert("Nenhum condomínio disponível para vincular.", "Criar Síndico")
        Return .F.
    EndIf
    cLogin := FWGetText("Login do novo síndico (3 a 30 letras minúsculas, números, ponto, hífen ou sublinhado):", "")
    If Empty(cLogin)
        Return .F.
    EndIf
    cSenha := FWGetText("Senha inicial (ele troca no primeiro acesso):", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf
    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:COND_NOME + Chr(10)
    Next nJ
    cLista += Chr(10) + "Números dos condomínios (separados por vírgula, ex: 1,3):"
    cSel := FWGetText(cLista, "")
    aIdx := GcParseIndicesSindico(cSel, Len(aCond))
    If Len(aIdx) == 0
        MsgAlert("Escolha ao menos um condomínio.", "Criar Síndico")
        Return .F.
    EndIf
    cMot := GcCriarUsuarioBase(cLogin, cSenha, "SINDICO")
    If !Empty(cMot)
        MsgStop(cMot, "Criar Síndico")
        Return .F.
    EndIf
    For i := 1 To Len(aIdx)
        TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('" + ;
            GcSqlLit(GcLoginNormal(cLogin)) + "', '" + GcSqlLit(aCond[aIdx[i]]:COND_FILIAL) + "')")
    Next i
    MsgInfo("Síndico '" + GcLoginNormal(cLogin) + "' criado e vinculado. A senha será trocada no primeiro acesso.", "GesCon")
Return .T.

/*/{Protheus.doc} GcGerarTokenId
    Gera o token de acesso do condômino: dois UUID v4 do runtime
    (UUIDRandom, gerador aleatório criptográfico) sem hífens = 64
    caracteres hexadecimais, 244 bits aleatórios. Antes era data + hora +
    Random() passados por SHA-256: previsível por quem soubesse a hora da
    emissão.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return character, token de 64 hex, ou "" se o runtime não gerou UUID
*/
User Function GcGerarTokenId()
    Local cU1 := StrTran(UUIDRandom(), "-", "") as character
    Local cU2 := StrTran(UUIDRandom(), "-", "") as character

    If Len(cU1) != 32 .Or. Len(cU2) != 32 .Or. cU1 == cU2
        Return ""
    EndIf
Return Lower(cU1 + cU2)
