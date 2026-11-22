// src/ui.prw — interface web do GesCon (PO-UI, `advplc serve gescon.prw`).
//
// Só monta tela e repassa: regras em src/seguranca.prw, src/cadastros.prw e
// nos módulos de negócio; dados de tabela e relatório em src/consultas.prw.
// Cada sessão do navegador é um programa próprio; o estado da sessão fica
// nas Private declaradas em GesCon() (gescon.prw).
#include "totvs.ch"

#define GC_INATIVIDADE 1800   // segundos sem ação até a sessão expirar

/*/{Protheus.doc} GcUI
    Abre a aplicação: tela de entrada (administração e portal do condômino).
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function GcUI()
    Local oApp := PoApp():New("GesCon") as object
    Local oPg  := Nil

    oPg := PoPage():New(oApp, "GesCon — Gestão Condominial")
    If !GcBootAdmin(GetEnv("GESCON_ADMIN_SENHA"))
        GcUIInstalacaoPendente(oPg)
    Else
        GcUIEntrada(oApp, oPg)
    EndIf
    // Expira a sessão por inatividade (verifica a cada minuto)
    oApp:SetTimer(60000, {|| GcUIExpira(oApp)})
    oApp:Activate()
Return

/*/{Protheus.doc} GcUIInstalacaoPendente
    Instalação sem usuários e sem senha inicial: explica o que fazer.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oPg, object, página
*/
Static Function GcUIInstalacaoPendente(oPg)
    Local oW := PoWidget():New(oPg, "Instalação pendente") as object

    oW:SetCols(8)
    PoInfo():New(oW, "Nenhum usuário cadastrado", "O responsável pelo servidor precisa definir a senha inicial do administrador " + ;
        "(GESCON_ADMIN_SENHA) e reiniciar o GesCon.")
    PoInfo():New(oW, "Depois", "Entre com o login admin e essa senha; o GesCon pede uma senha nova no primeiro acesso.")
Return

/*/{Protheus.doc} GcUIEntrada
    Tela de entrada em duas colunas: administração (login) e condômino (token).
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param oPg, object, página
*/
Static Function GcUIEntrada(oApp, oPg)
    Local oW    := PoWidget():New(oPg, "Administração") as object
    Local oUsu  := PoInput():New(oW, "Login") as object
    Local oSen  := PoPassword():New(oW, "Senha") as object
    Local oBtn  := PoButton():New(oW, "Entrar") as object
    Local oC    := PoWidget():New(oPg, "Sou condômino") as object
    Local oTok  := PoInput():New(oC, "Token de acesso (recebido da administração)") as object
    Local oBtnC := PoButton():New(oC, "Ver minhas cobranças") as object

    oW:SetCols(6)
    oBtn:Set("kind", "primary")
    oBtn:Set("icon", "an an-sign-in")
    oBtn:OnClick({|| GcUIEntra(oApp, GcStr(oUsu:GetValue()), GcStr(oSen:GetValue()))})
    oC:SetCols(6)
    PoInfo():New(oC, "", "Acesso de leitura às cobranças e avisos da sua unidade. O token vale uma vez e expira em 48 horas.")
    oBtnC:Set("icon", "an an-key")
    oBtnC:OnClick({|| GcUIPortal(oApp, GcStr(oTok:GetValue()))})
Return

/*/{Protheus.doc} GcUIEntra
    Confere login e senha e segue: troca obrigatória, condomínio, menu.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param cLogin, character, login digitado
    @param cSenha, character, senha digitada
*/
Static Function GcUIEntra(oApp, cLogin, cSenha)
    Local cReal := "" as character
    Local cRet  := "" as character

    GcUIToque()
    If Empty(cLogin) .Or. Empty(cSenha)
        oApp:Notify("Informe login e senha.", "warning")
        Return
    EndIf
    cRet := GcAutenticarCredencial(cLogin, cSenha, @cReal)
    Do Case
        Case cRet == "BLOQUEADO"
            oApp:Notify("Usuário bloqueado por excesso de tentativas. Tente de novo em 15 minutos.", "error")
        Case cRet == "INVALIDO"
            oApp:Notify("Login ou senha inválidos.", "error")
        Case cRet == "TROCA"
            GcUISenhaPg(oApp, cReal, .T.)
        Otherwise
            GcUICondominio(oApp, cReal)
    EndCase
Return

/*/{Protheus.doc} GcUISenhaPg
    Página de troca de senha: obrigatória (primeiro acesso) ou do menu.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param cLogin, character, login como gravado
    @param lObrigatoria, logical, .T. no primeiro acesso (segue para o condomínio)
    @return object, a página
*/
Static Function GcUISenhaPg(oApp, cLogin, lObrigatoria)
    Local cTit := "Minha senha" as character
    Local oPg  := Nil
    Local oReg := Nil
    Local oW   := Nil
    Local oAt  := Nil
    Local oS1  := Nil
    Local oS2  := Nil
    Local oBtn := Nil

    If lObrigatoria
        cTit := "Defina sua senha"
    EndIf
    oPg  := PoPage():New(oApp, cTit)
    oReg := PoWidget():New(oPg, "Regras da senha")
    oW   := PoWidget():New(oPg, "Nova senha de " + cLogin)
    oReg:SetCols(5)
    PoInfo():New(oReg, "Tamanho", "No mínimo 10 caracteres")
    PoInfo():New(oReg, "Composição", "Letra maiúscula, letra minúscula, número e caractere especial")
    PoInfo():New(oReg, "Evite", "O seu login dentro da senha")
    oW:SetCols(7)
    If !lObrigatoria
        oAt := PoPassword():New(oW, "Senha atual")
    EndIf
    oS1 := PoPassword():New(oW, "Nova senha")
    oS2 := PoPassword():New(oW, "Confirme a nova senha")
    oBtn := PoButton():New(oW, "Gravar senha")
    oBtn:Set("kind", "primary")
    oBtn:OnClick({|| GcUISenhaGrava(oApp, cLogin, lObrigatoria, oAt, GcStr(oS1:GetValue()), GcStr(oS2:GetValue()))})
    If lObrigatoria
        oApp:Navigate(oPg)
    EndIf
Return oPg

/*/{Protheus.doc} GcUISenhaGrava
    Grava a senha nova (política em GcDefinirSenha).
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUISenhaGrava(oApp, cLogin, lObrigatoria, oAt, cS1, cS2)
    Local cMot := "" as character

    GcUIToque()
    If oAt != Nil .And. !GcCredenciaisValidas(cLogin, GcStr(oAt:GetValue()))
        oApp:Notify("Senha atual inválida.", "error")
        Return
    EndIf
    If Empty(cS1) .Or. !(cS1 == cS2)
        oApp:Notify("A confirmação não confere com a senha nova.", "error")
        Return
    EndIf
    cMot := GcDefinirSenha(cLogin, cS1, .F.)
    If !Empty(cMot)
        oApp:Notify(cMot, "error")
        Return
    EndIf
    oApp:Notify("Senha gravada.", "success")
    If lObrigatoria
        GcUICondominio(oApp, cLogin)
    EndIf
Return

/*/{Protheus.doc} GcUICondominio
    Escolhe o condomínio: abre direto se houver um só.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param cLogin, character, login como gravado
*/
Static Function GcUICondominio(oApp, cLogin)
    Local aCond := GcCondominiosDoLogin(cLogin) as array
    Local aOps  := {} as array
    Local oPg   := Nil
    Local oW    := Nil
    Local oSel  := Nil
    Local oBtn  := Nil
    Local nI    := 0 as numeric

    If Len(aCond) == 0
        oApp:Notify("Nenhum condomínio vinculado a este usuário. Fale com a administração.", "error")
        Return
    EndIf
    If Len(aCond) == 1
        GcUIAbre(oApp, cLogin, aCond[1][1], aCond[1][2], 1)
        Return
    EndIf
    For nI := 1 To Len(aCond)
        aAdd(aOps, {aCond[nI][2], aCond[nI][1]})
    Next nI
    oPg := PoPage():New(oApp, "Escolha o condomínio")
    oW := PoWidget():New(oPg, "Condomínio")
    oW:SetCols(6)
    oSel := PoSelect():New(oW, "Condomínio", aOps, aCond[1][1])
    oBtn := PoButton():New(oW, "Abrir")
    oBtn:Set("kind", "primary")
    oBtn:OnClick({|| GcUIAbreSel(oApp, cLogin, aCond, GcStr(oSel:GetValue()))})
    oApp:Navigate(oPg)
Return

/*/{Protheus.doc} GcUIAbreSel
    Abre o condomínio escolhido, conferindo que ele está na lista do login.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIAbreSel(oApp, cLogin, aCond, cFil)
    Local nP := aScan(aCond, {|x| x[1] == cFil}) as numeric

    If nP == 0
        oApp:Notify("Escolha um condomínio da lista.", "warning")
        Return
    EndIf
    GcUIAbre(oApp, cLogin, aCond[nP][1], aCond[nP][2], Len(aCond))
Return

/*/{Protheus.doc} GcUIAbre
    Sessão aberta: fixa condomínio e perfil e monta o menu com as páginas
    que o perfil pode ver.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param cLogin, character, login como gravado
    @param cFil, character, filial (condomínio)
    @param cNome, character, nome do condomínio
    @param nConds, numeric, quantos condomínios o login pode abrir
*/
Static Function GcUIAbre(oApp, cLogin, cFil, cNome, nConds)
    Local oMenu := Nil
    Local oIni  := Nil
    Local oPg   := Nil
    Local aPags := {} as array
    Local nI    := 0 as numeric

    If !RpcSetEnv(cFil)
        oApp:Notify("Condomínio indisponível.", "error")
        Return
    EndIf
    cLoginAtual    := cLogin
    cGcPerfil      := GcPerfilDoLogin(cLogin)
    g_cFilialAtiva := cFil
    cGcCondNome    := cNome
    GcAtualizarInadimplentes()

    oMenu := PoMenu():New(oApp)
    oIni := GcUIInicio(oApp)
    GcUIMenuItem(oApp, oMenu, "Início", "an an-house", oIni)
    aPags := GcUIPaginas()
    For nI := 1 To Len(aPags)
        If GcPode(cGcPerfil, aPags[nI][3])
            oPg := Eval(aPags[nI][4], oApp)
            GcUIMenuItem(oApp, oMenu, aPags[nI][1], aPags[nI][2], oPg)
        EndIf
    Next nI
    GcUIMenuItem(oApp, oMenu, "Minha senha", "an an-key", GcUISenhaPg(oApp, cLogin, .F.))
    If nConds > 1
        oMenu:AddItem("Trocar condomínio", "an an-buildings", {|| GcUIToque(), GcUICondominio(oApp, cLogin)})
    EndIf
    oMenu:AddItem("Sair", "an an-sign-out", {|| oApp:Close()})
    oApp:Notify("Bem-vindo, " + cLogin + " — " + cNome + ".", "success")
    oApp:Navigate(oIni)
Return

/*/{Protheus.doc} GcUIPaginas
    Páginas do menu, na ordem: {rótulo, ícone, ação (GcPode), bloco que
    monta a página}. Cada fase da etapa 3 acrescenta as suas aqui.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @return array, páginas
*/
Static Function GcUIPaginas()
Return { ;
    {"Unidades", "an an-buildings", "unidades", {|o| GcUIPgUnidades(o)}}, ;
    {"Condôminos", "an an-users", "condominos", {|o| GcUIPgCondominos(o)}}, ;
    {"Despesas", "an an-receipt", "despesas", {|o| GcUIPgDespesas(o)}}, ;
    {"Fechamento", "an an-calendar-check", "fechamento", {|o| GcUIPgFechamento(o)}}, ;
    {"Cobranças", "an an-money", "cobrancas", {|o| GcUIPgCobrancas(o)}}, ;
    {"Comunicação", "an an-megaphone", "comunicacao", {|o| GcUIPgComunicacao(o)}}, ;
    {"Relatórios", "an an-chart-bar", "relatorios", {|o| GcUIPgRelatorios(o)}}, ;
    {"Contabilidade", "an an-calculator", "contabilidade", {|o| GcUIPgContabil(o)}}, ;
    {"Auditoria", "an an-shield-check", "auditoria", {|o| GcUIPgAuditoria(o)}}, ;
    {"Usuários", "an an-user-gear", "usuarios", {|o| GcUIPgUsuarios(o)}}, ;
    {"Condomínios", "an an-city", "condominios", {|o| GcUIPgCondominios(o)}} }

/*/{Protheus.doc} GcUIPgFechamento
    Fechamento mensal: rateio das despesas da competência pelas frações.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgFechamento(oApp)
    Local oPg   := PoPage():New(oApp, "Fechamento mensal") as object
    Local oF    := PoWidget():New(oPg, "Fechar competência") as object
    Local cComp := Left(DToS(Date()), 4) + "-" + SubStr(DToS(Date()), 5, 2) as character
    Local oComp := PoInput():New(oF, "Competência (AAAA-MM)") as object
    Local oDia  := PoInput():New(oF, "Dia do vencimento no mês seguinte (1 a 28)") as object
    Local oB    := Nil
    Local oWT   := PoWidget():New(oPg, "Competências fechadas") as object
    Local oTab  := PoTable():New(oWT) as object

    oF:SetCols(4)
    oWT:SetCols(8)
    oComp:SetValue(cComp)
    oDia:SetValue("10")
    oB := PoButton():New(oF, "Fechar competência", {|| GcUIFecha(oApp, oTab, GcStr(oComp:GetValue()), GcNum(oDia:GetValue()))})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-calendar-check")
    PoInfo():New(oF, "", "Rateia as despesas da competência pelas frações ideais e gera uma cobrança por unidade. " + ;
        "Recusa se as frações não somarem 100%. Com exercício contábil aberto, também contabiliza.")
    GcUIRegistra(oPg, {|| GcUITabela(oTab, GcQCompetencias())})
Return oPg

Static Function GcUIFecha(oApp, oTab, cComp, nDia)
    GcUIToque()
    If GcFecharMes(cComp, nDia)
        oApp:Notify("Competência " + cComp + " fechada.", "success")
    EndIf
    GcUITabela(oTab, GcQCompetencias())
Return

/*/{Protheus.doc} GcUIPgCobrancas
    Cobranças: filtro por situação, registro de pagamento, boleto e dados
    bancários do boleto.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgCobrancas(oApp)
    Local oPg   := PoPage():New(oApp, "Cobranças") as object
    Local oWT   := PoWidget():New(oPg, "Cobranças") as object
    Local oFil  := PoSelect():New(oWT, "Situação", {{"Todas", ""}, {"Em aberto", "pendente"}, {"Atrasadas", "atrasado"}, {"Pagas", "pago"}}, "") as object
    Local oTab  := PoTable():New(oWT) as object
    Local oA    := PoWidget():New(oPg, "Cobrança selecionada") as object
    Local oData := PoInput():New(oA, "Data do pagamento (DD/MM/AAAA)") as object
    Local aSel  := {0} as array
    Local oB    := Nil
    Local oLin  := Nil
    Local oBar  := Nil
    Local oCfg  := PoWidget():New(oPg, "Dados bancários do boleto") as object
    Local aCfg  := TCSqlQuery("SELECT CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA FROM CFG_BOLETO " + ;
        "WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('CFG_BOLETO')) + "'") as array
    Local oBco  := PoSelect():New(oCfg, "Banco", {{"Itaú (341)", "341"}, {"Bradesco (237)", "237"}}, "341") as object
    Local oAg   := PoInput():New(oCfg, "Agência") as object
    Local oCc   := PoInput():New(oCfg, "Conta corrente") as object
    Local oCart := PoInput():New(oCfg, "Carteira") as object
    Local oConv := PoInput():New(oCfg, "Código do beneficiário / convênio") as object

    // Tabela em largura total; abaixo, a cobrança selecionada e os dados
    // bancários lado a lado.
    oWT:SetCols(12)
    oA:SetCols(6)
    oCfg:SetCols(6)
    oFil:OnChange({|o, x| GcUIToque(), GcUITabela(oTab, GcQCobrancas(GcStr(x)))})
    oTab:OnSelect({|o, aLin| aSel[1] := GcNum(aLin[1])})
    oData:SetValue(DToC(Date()))
    oB := PoButton():New(oA, "Registrar pagamento", {|| GcUIPaga(oApp, oTab, oFil, aSel[1], GcStr(oData:GetValue()))})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-check")
    oB := PoButton():New(oA, "Boleto")
    oB:Set("icon", "an an-barcode")
    oLin := PoInfo():New(oA, "Linha digitável", "selecione uma cobrança e clique em Boleto")
    oBar := PoInfo():New(oA, "Código de barras", "")
    oB:OnClick({|| GcUIBoleto(oApp, oLin, oBar, aSel[1], "")})
    If Len(aCfg) > 0
        oBco:SetValue(AllTrim(aCfg[1]:CFG_BANCO))
        oAg:SetValue(AllTrim(aCfg[1]:CFG_AGENCIA))
        oCc:SetValue(AllTrim(aCfg[1]:CFG_CONTA))
        oCart:SetValue(AllTrim(aCfg[1]:CFG_CARTEIRA))
        oConv:SetValue(AllTrim(aCfg[1]:CFG_COBRT))
    EndIf
    oB := PoButton():New(oCfg, "Gravar dados bancários", {|| GcUIMsg(oApp, GcSalvarCfgBoleto(GcStr(oBco:GetValue()), ;
        GcStr(oAg:GetValue()), GcStr(oCc:GetValue()), GcStr(oConv:GetValue()), GcStr(oCart:GetValue())), "Dados bancários gravados.")})
    oB:Set("kind", "secondary")
    GcUIRegistra(oPg, {|| GcUITabela(oTab, GcQCobrancas(GcStr(oFil:GetValue())))})
Return oPg

Static Function GcUIPaga(oApp, oTab, oFil, nRecno, cData)
    Local dPag := GcDataDigitada(cData) as date

    GcUIToque()
    If nRecno <= 0
        oApp:Notify("Selecione uma cobrança na tabela.", "warning")
        Return
    EndIf
    If Empty(dPag) .Or. dPag > Date()
        oApp:Notify("Data inválida: use DD/MM/AAAA, uma data que exista e que não seja futura.", "error")
        Return
    EndIf
    If !GcRegistrarPagamento(nRecno, dPag)
        oApp:Notify("Pagamento não registrado: a cobrança já está paga ou não existe.", "error")
        Return
    EndIf
    oApp:Notify("Pagamento registrado.", "success")
    GcUITabela(oTab, GcQCobrancas(GcStr(oFil:GetValue())))
Return

/*/{Protheus.doc} GcUIMsg
    Mostra o resultado de uma operação: motivo da recusa ou a mensagem de
    sucesso.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return logical, .T. se deu certo
*/
User Function GcUIMsg(oApp, cMot, cOk)
    GcUIToque()
    If !Empty(cMot)
        oApp:Notify(cMot, "error")
        Return .F.
    EndIf
    oApp:Notify(cOk, "success")
Return .T.

/*/{Protheus.doc} GcUIPgComunicacao
    Mala direta, avisos do condomínio e tokens do portal do condômino.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgComunicacao(oApp)
    Local oPg   := PoPage():New(oApp, "Comunicação") as object
    Local oTabs := PoTabs():New(oPg) as object
    Local oT1   := PoTab():New(oTabs, "Avisos") as object
    Local oT2   := PoTab():New(oTabs, "Portal do condômino") as object
    Local oT3   := PoTab():New(oTabs, "Mala direta") as object
    Local oAvT  := PoTable():New(oT1) as object
    Local oTit  := PoInput():New(oT1, "Título") as object
    Local oCor  := PoTextarea():New(oT1, "Texto do aviso") as object
    Local aAv   := {0} as array
    Local oUni  := PoInput():New(oT2, "Unidade") as object
    Local oTkT  := Nil
    Local oRes  := PoWidget():New(oT2, "Token emitido") as object
    Local oComp := PoInput():New(oT3, "Competência (AAAA-MM)") as object
    Local oB    := Nil

    oAvT:OnSelect({|o, aLin| aAv[1] := GcNum(aLin[1])})
    oB := PoButton():New(oT1, "Publicar aviso", {|| GcUIAviso(oApp, oAvT, GcStr(oTit:GetValue()), GcStr(oCor:GetValue()))})
    oB:Set("kind", "primary")
    oB := PoButton():New(oT1, "Arquivar o selecionado", {|| GcUIArquiva(oApp, oAvT, aAv[1])})
    oB:Set("kind", "secondary")

    oRes:SetCols(12)
    PoInfo():New(oRes, "", "O token vale uma vez e expira em 48 horas. Entregue ao condômino por um canal seguro.")
    oB := PoButton():New(oT2, "Emitir token", {|| GcUIToken(oApp, oRes, oTkT, GcStr(oUni:GetValue()))})
    oB:Set("kind", "primary")
    oB := PoButton():New(oT2, "Revogar tokens da unidade", {|| GcUIMsg(oApp, GcRevogarTokenUnidade(GcStr(oUni:GetValue())), "Tokens revogados."), ;
        GcUITabela(oTkT, GcQTokens())})
    oB:Set("kind", "secondary")
    oTkT := PoTable():New(PoWidget():New(oT2, "Tokens válidos"))

    oComp:SetValue(Left(DToS(Date()), 4) + "-" + SubStr(DToS(Date()), 5, 2))
    PoInfo():New(oT3, "", "Envia por e-mail a cobrança da competência a cada condômino com e-mail cadastrado e cobrança em aberto. " + ;
        "O servidor precisa do SMTP configurado (GESCON_SMTP_HOST).")
    oB := PoButton():New(oT3, "Enviar", {|| GcUIToque(), oApp:Notify(cValToChar(GcMalaDireta(GcStr(oComp:GetValue()))) + " e-mail(s) enviado(s).", "info")})
    oB:Set("kind", "primary")
    GcUIRegistra(oPg, {|| GcUITabela(oAvT, GcQAvisos()), GcUITabela(oTkT, GcQTokens())})
Return oPg

Static Function GcUIAviso(oApp, oAvT, cTit, cCorpo)
    GcUIToque()
    If Empty(cTit) .Or. Empty(cCorpo)
        oApp:Notify("Informe título e texto.", "warning")
        Return
    EndIf
    If !GcCriarAviso(cTit, cCorpo)
        oApp:Notify("Não foi possível publicar o aviso.", "error")
        Return
    EndIf
    oApp:Notify("Aviso publicado.", "success")
    GcUITabela(oAvT, GcQAvisos())
Return

Static Function GcUIArquiva(oApp, oAvT, nId)
    GcUIToque()
    If nId <= 0 .Or. !GcArquivarAviso(nId)
        oApp:Notify("Selecione um aviso publicado.", "warning")
        Return
    EndIf
    oApp:Notify("Aviso arquivado.", "success")
    GcUITabela(oAvT, GcQAvisos())
Return

Static Function GcUIToken(oApp, oRes, oTkT, cUni)
    Local aT := GcEmitirToken(cUni) as array

    GcUIToque()
    If Empty(aT[1])
        oApp:Notify(aT[3], "error")
        Return
    EndIf
    PoInfo():New(oRes, "Unidade " + cUni + " — válido até " + aT[2], aT[1])
    oApp:Notify("Token emitido.", "success")
    GcUITabela(oTkT, GcQTokens())
Return

/*/{Protheus.doc} GcUIPgUsuarios
    Usuários: super vê todos e cria super ou síndico; síndico vê e cria
    síndicos do condomínio. Redefinir senha (troca obrigatória) e
    desbloquear.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgUsuarios(oApp)
    Local oPg   := PoPage():New(oApp, "Usuários") as object
    Local oWT   := PoWidget():New(oPg, "Usuários") as object
    Local oTab  := PoTable():New(oWT) as object
    Local oF    := PoWidget():New(oPg, "Usuário") as object
    Local aPerf := {{"Síndico", "SINDICO"}} as array
    Local oLog  := Nil
    Local oSen  := Nil
    Local oPerf := Nil
    Local oB    := Nil

    If GcPode(cGcPerfil, "criar_super")
        aAdd(aPerf, {"Super administrador", "SUPERADMIN"})
    EndIf
    oWT:SetCols(8)
    oF:SetCols(4)
    oLog  := PoInput():New(oF, "Login")
    oSen  := PoPassword():New(oF, "Senha inicial / provisória")
    oPerf := PoSelect():New(oF, "Perfil", aPerf, "SINDICO")
    oTab:OnSelect({|o, aLin| GcUIToque(), oLog:SetValue(GcStr(aLin[1]))})
    oB := PoButton():New(oF, "Criar usuário", {|| GcUIMsg(oApp, GcCriarUsuarioCondominio(GcStr(oLog:GetValue()), GcStr(oSen:GetValue()), ;
        GcStr(oPerf:GetValue())), "Usuário criado. A senha será trocada no primeiro acesso."), GcUITabela(oTab, GcQUsuarios())})
    oB:Set("kind", "primary")
    oB := PoButton():New(oF, "Redefinir senha", {|| GcUIMsg(oApp, GcRedefinirSenha(GcStr(oLog:GetValue()), GcStr(oSen:GetValue())), ;
        "Senha provisória definida; o usuário troca no próximo acesso."), GcUITabela(oTab, GcQUsuarios())})
    oB:Set("kind", "secondary")
    oB := PoButton():New(oF, "Desbloquear", {|| GcUIMsg(oApp, GcDesbloquearUsuario(GcStr(oLog:GetValue())), "Usuário desbloqueado."), ;
        GcUITabela(oTab, GcQUsuarios())})
    oB:Set("kind", "tertiary")
    PoInfo():New(oF, "", "Síndico criado aqui fica vinculado a este condomínio. Senha: no mínimo 10 caracteres, com maiúscula, " + ;
        "minúscula, número e caractere especial, sem o login.")
    GcUIRegistra(oPg, {|| GcUITabela(oTab, GcQUsuarios())})
Return oPg

/*/{Protheus.doc} GcUIPgCondominos
    Cadastro de condôminos.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgCondominos(oApp)
Return GcUICadastro(oApp, "Condôminos", {|| GcQCondominos()}, ;
    {{"Código", "C", 1}, {"Nome", "C", 2}, {"CPF ou CNPJ", "C", 3}, {"E-mail (mala direta)", "C", 4}, {"Telefone", "C", 5}}, ;
    {|a| GcSalvarCondomino(a[1], a[2], a[3], a[4], a[5])}, {|a| GcExcluirCondomino(a[1])}, ;
    "CPF e CNPJ são conferidos pelo dígito, inclusive o CNPJ com letras (a partir de julho de 2026).")

/*/{Protheus.doc} GcUIPgUnidades
    Cadastro de unidades.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgUnidades(oApp)
Return GcUICadastro(oApp, "Unidades", {|| GcQUnidades()}, ;
    {{"Unidade", "C", 1}, {"Bloco", "C", 2}, {"Fração ideal (0 a 1; 2,5% = 0,025)", "N", 3}, {"Código do condômino", "C", 5}}, ;
    {|a| GcSalvarUnidade(a[1], a[2], a[3], a[4])}, {|a| GcExcluirUnidade(a[1])}, ;
    "A soma das frações das unidades precisa dar 100% para o Fechamento ratear as despesas.")

/*/{Protheus.doc} GcUIPgDespesas
    Lançamento de despesas da competência.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgDespesas(oApp)
    Local cHoje := Left(DToS(Date()), 4) + "-" + SubStr(DToS(Date()), 5, 2) as character
Return GcUICadastro(oApp, "Despesas", {|| GcQDespesas()}, ;
    {{"", "K", 1}, {"Competência (AAAA-MM)", "C", 2, cHoje}, {"Descrição", "C", 3}, {"Categoria", "C", 4}, {"Valor (R$)", "N", 5}}, ;
    {|a| GcSalvarDespesa(Val(a[1]), a[3], a[4], a[5], a[2])}, {|a| GcExcluirDespesa(Val(a[1]))}, ;
    "Competência fechada não recebe nem muda despesa. A categoria define a conta contábil (Contabilidade).")

/*/{Protheus.doc} GcUIPgCondominios
    Cadastro de condomínios (só super administrador).
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgCondominios(oApp)
Return GcUICadastro(oApp, "Condomínios", {|| GcQCondominios()}, ;
    {{"", "K", 1}, {"Nome", "C", 2}, {"CNPJ", "C", 3}, {"Endereço", "C", 4}}, ;
    {|a| GcSalvarCondominio(a[1], a[2], a[3], a[4])}, Nil, ;
    "Condomínio novo recebe o próximo código. Para um síndico enxergá-lo, vincule-o em Usuários.")

/*/{Protheus.doc} GcUICadastro
    Página de cadastro: tabela (8 colunas da grade) e formulário (4). A
    linha clicada preenche o formulário; Gravar inclui ou altera; Excluir
    pede confirmação; Novo limpa. Campo: {rótulo, "C" | "N" | "K" (chave
    oculta) | {opções}, coluna da tabela que o preenche, padrão}.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param cTitulo, character, título
    @param bQ, codeblock, consulta {colunas, linhas}
    @param aCampos, array, campos
    @param bSalvar, codeblock, recebe os valores, devolve "" ou o motivo
    @param bExcluir, codeblock, (opcional) idem, para excluir
    @param cAjuda, character, texto de ajuda
    @return object, a página
*/
Static Function GcUICadastro(oApp, cTitulo, bQ, aCampos, bSalvar, bExcluir, cAjuda)
    Local oPg    := PoPage():New(oApp, cTitulo) as object
    Local oWT    := PoWidget():New(oPg, cTitulo) as object
    Local oTab   := PoTable():New(oWT) as object
    Local oF     := PoWidget():New(oPg, "Dados") as object
    Local aObj   := {} as array
    Local aChave := {""} as array
    Local oB     := Nil
    Local nI     := 0 as numeric

    oWT:SetCols(8)
    oF:SetCols(4)
    For nI := 1 To Len(aCampos)
        aAdd(aObj, GcUICampo(oF, aCampos[nI]))
    Next nI
    oB := PoButton():New(oF, "Gravar", {|| GcUICadGrava(oApp, oTab, bQ, aCampos, aObj, aChave, bSalvar)})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-floppy-disk")
    If bExcluir != Nil
        oB := PoButton():New(oF, "Excluir", {|| GcUICadExclui(oApp, oTab, bQ, aCampos, aObj, aChave, bExcluir)})
        oB:Set("kind", "secondary")
        oB:Set("icon", "an an-trash")
    EndIf
    oB := PoButton():New(oF, "Novo", {|| GcUICadLimpa(aCampos, aObj, aChave)})
    oB:Set("kind", "tertiary")
    If !Empty(cAjuda)
        PoInfo():New(oF, "", cAjuda)
    EndIf
    oTab:OnSelect({|o, aLin| GcUICadPreenche(aLin, aCampos, aObj, aChave)})
    GcUIRegistra(oPg, {|| GcUITabela(oTab, Eval(bQ))})
Return oPg

/*/{Protheus.doc} GcUICampo
    Cria o componente de um campo (Nil para chave oculta).
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUICampo(oPai, aC)
    Local oC := Nil

    If ValType(aC[2]) == "A"
        oC := PoSelect():New(oPai, aC[1], aC[2], "")
    ElseIf aC[2] == "K"
        Return Nil
    Else
        // Número também em campo de texto: o campo numérico do navegador não
        // aceita vírgula nem casas além do passo (fração 0,025, R$ 1.234,56).
        oC := PoInput():New(oPai, aC[1])
    EndIf
    If Len(aC) >= 4 .And. !Empty(aC[4])
        oC:SetValue(aC[4])
    EndIf
Return oC

/*/{Protheus.doc} GcUICadValores
    Valores do formulário na ordem dos campos (chave, texto ou número).
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUICadValores(aCampos, aObj, aChave)
    Local aV := {} as array
    Local nI := 0 as numeric

    For nI := 1 To Len(aCampos)
        If aCampos[nI][2] == "K"
            aAdd(aV, aChave[1])
        ElseIf aCampos[nI][2] == "N"
            aAdd(aV, GcNum(aObj[nI]:GetValue()))
        Else
            aAdd(aV, GcStr(aObj[nI]:GetValue()))
        EndIf
    Next nI
Return aV

Static Function GcUICadGrava(oApp, oTab, bQ, aCampos, aObj, aChave, bSalvar)
    Local cMot := "" as character

    GcUIToque()
    cMot := Eval(bSalvar, GcUICadValores(aCampos, aObj, aChave))
    If !Empty(cMot)
        oApp:Notify(cMot, "error")
        Return
    EndIf
    oApp:Notify("Gravado.", "success")
    GcUITabela(oTab, Eval(bQ))
Return

Static Function GcUICadExclui(oApp, oTab, bQ, aCampos, aObj, aChave, bExcluir)
    GcUIToque()
    oApp:Confirm("Excluir o registro selecionado?", {|| GcUICadExcluiOk(oApp, oTab, bQ, aCampos, aObj, aChave, bExcluir)}, Nil, "Excluir")
Return

Static Function GcUICadExcluiOk(oApp, oTab, bQ, aCampos, aObj, aChave, bExcluir)
    Local cMot := Eval(bExcluir, GcUICadValores(aCampos, aObj, aChave)) as character

    If !Empty(cMot)
        oApp:Notify(cMot, "error")
        Return
    EndIf
    oApp:Notify("Excluído.", "success")
    GcUICadLimpa(aCampos, aObj, aChave)
    GcUITabela(oTab, Eval(bQ))
Return

Static Function GcUICadLimpa(aCampos, aObj, aChave)
    Local nI := 0 as numeric

    aChave[1] := ""
    For nI := 1 To Len(aCampos)
        If aObj[nI] != Nil
            If Len(aCampos[nI]) >= 4
                aObj[nI]:SetValue(aCampos[nI][4])
            Else
                aObj[nI]:SetValue("")
            EndIf
        EndIf
    Next nI
Return

Static Function GcUICadPreenche(aLin, aCampos, aObj, aChave)
    Local nI := 0 as numeric
    Local nC := 0 as numeric

    GcUIToque()
    If ValType(aLin) != "A"
        Return
    EndIf
    For nI := 1 To Len(aCampos)
        nC := aCampos[nI][3]
        If nC > 0 .And. nC <= Len(aLin)
            If aCampos[nI][2] == "K"
                aChave[1] := GcStr(aLin[nC])
            Else
                aObj[nI]:SetValue(GcStr(aLin[nC]))
            EndIf
        EndIf
    Next nI
Return

/*/{Protheus.doc} GcNum
    Número de componente ou de célula ("1.234,56", "0.5", 12) como numérico.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param xVal, variant, valor
    @return numeric, número
*/
User Function GcNum(xVal)
    Local c := "" as character

    If ValType(xVal) == "N"
        Return xVal
    EndIf
    c := GcStr(xVal)
    If "," $ c
        c := StrTran(StrTran(c, ".", ""), ",", ".")
    EndIf
Return Val(c)

/*/{Protheus.doc} GcUIMenuItem
    Item de menu que leva à página e recarrega as tabelas dela (dado
    fresco a cada visita). Função própria para o bloco capturar a página
    certa, não a variável do laço.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIMenuItem(oApp, oMenu, cRot, cIcone, oPg)
    oMenu:AddItem(cRot, cIcone, {|| GcUIToque(), GcUIRecarrega(oPg), oApp:Navigate(oPg)})
Return

/*/{Protheus.doc} GcUIRecarrega
    Roda os blocos de recarga registrados para a página (GcUIRegistra).
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oPg, object, página
*/
Static Function GcUIRecarrega(oPg)
    Local nI := 0 as numeric

    For nI := 1 To Len(aGcRecarga)
        If aGcRecarga[nI][1] == oPg
            Eval(aGcRecarga[nI][2])
        EndIf
    Next nI
Return

/*/{Protheus.doc} GcUIRegistra
    Registra um bloco que recarrega dados da página e já o executa.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param oPg, object, página
    @param bRecarga, codeblock, bloco
*/
User Function GcUIRegistra(oPg, bRecarga)
    aAdd(aGcRecarga, {oPg, bRecarga})
    Eval(bRecarga)
Return

/*/{Protheus.doc} GcUIInicio
    Página inicial: indicadores do condomínio e despesas por categoria da
    competência atual.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @return object, a página
*/
Static Function GcUIInicio(oApp)
    Local oPg   := PoPage():New(oApp, "Início — " + cGcCondNome) as object
    Local aW    := {} as array
    Local oCh   := Nil
    Local oWc   := Nil
    Local cPf   := "síndico" as character
    Local nI    := 0 as numeric
    Local aTit  := {"Unidades", "Frações ideais", "A receber", "Em atraso", "Despesas do mês"} as array

    If cGcPerfil == "SUPERADMIN"
        cPf := "super administrador"
    EndIf
    // Cartões de 4 colunas (3 por linha) e o gráfico em largura total.
    For nI := 1 To Len(aTit)
        oWc := PoWidget():New(oPg, aTit[nI])
        oWc:SetCols(4)
        aAdd(aW, PoInfo():New(oWc, "", ""))
    Next nI
    oWc := PoWidget():New(oPg, "Sessão")
    oWc:SetCols(4)
    PoInfo():New(oWc, cLoginAtual, cPf)
    oWc := PoWidget():New(oPg, "Despesas do mês por categoria")
    oWc:SetCols(12)
    oCh := PoChart():New(oWc, "Despesas (R$)", "bar")
    GcUIRegistra(oPg, {|| GcUIIndicadores(aW, oCh)})
Return oPg

Static Function GcUIIndicadores(aW, oCh)
    Local aI   := GcIndicadores() as array
    Local aQ   := GcQDespesasCategoria(Left(DToS(Date()), 4) + "-" + SubStr(DToS(Date()), 5, 2)) as array
    Local aCat := {} as array
    Local aVal := {} as array
    Local cFr  := "" as character
    Local nI   := 0 as numeric

    aW[1]:SetValue(cValToChar(aI[1]))
    cFr := AllTrim(Transform(aI[2], "@E 999.9999")) + "%"
    If Abs(aI[2] - 100) > 0.1
        cFr += " — precisa somar 100%"
    EndIf
    aW[2]:SetValue(cFr)
    aW[3]:SetValue("R$ " + AllTrim(Transform(aI[3], "@E 999,999,999.99")))
    aW[4]:SetValue("R$ " + AllTrim(Transform(aI[4], "@E 999,999,999.99")) + " (" + cValToChar(aI[5]) + " cobrança(s))")
    aW[5]:SetValue("R$ " + AllTrim(Transform(aI[6], "@E 999,999,999.99")))
    For nI := 1 To Len(aQ[2])
        aAdd(aCat, aQ[2][nI][1])
        aAdd(aVal, GcNum(aQ[2][nI][3]))
    Next nI
    oCh:SetCategories(aCat)
    oCh:SetSeries({{"Despesas", aVal}})
Return

/*/{Protheus.doc} GcUIPgRelatorios
    Relatórios: inadimplência, extrato da unidade, despesas por categoria e
    resultado do mês (consultas diretas, sem tabela de rascunho).
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgRelatorios(oApp)
    Local oPg   := PoPage():New(oApp, "Relatórios") as object
    Local oTabs := PoTabs():New(oPg) as object
    Local oT1   := PoTab():New(oTabs, "Inadimplência") as object
    Local oT2   := PoTab():New(oTabs, "Extrato da unidade") as object
    Local oT3   := PoTab():New(oTabs, "Despesas por categoria") as object
    Local oT4   := PoTab():New(oTabs, "Resultado do mês") as object
    Local cComp := Left(DToS(Date()), 4) + "-" + SubStr(DToS(Date()), 5, 2) as character
    Local oIn   := PoTable():New(oT1) as object
    Local oUni  := PoInput():New(oT2, "Unidade") as object
    Local oEx   := Nil
    Local oDc   := PoInput():New(oT3, "Competência (AAAA-MM; vazio = todas)") as object
    Local oDt   := Nil
    Local oRc   := PoInput():New(oT4, "Competência (AAAA-MM)") as object
    Local aRes  := {} as array
    Local oB    := Nil

    oB := PoButton():New(oT2, "Ver extrato", {|| GcUIToque(), GcUITabela(oEx, GcQPortalCobrancas(GcStr(oUni:GetValue())))})
    oB:Set("kind", "primary")
    oEx := PoTable():New(oT2)
    oDc:SetValue(cComp)
    oB := PoButton():New(oT3, "Atualizar", {|| GcUIToque(), GcUITabela(oDt, GcQDespesasCategoria(GcStr(oDc:GetValue())))})
    oB:Set("kind", "primary")
    oDt := PoTable():New(oT3)
    oRc:SetValue(cComp)
    oB := PoButton():New(oT4, "Calcular", {|| GcUIResultado(aRes, GcStr(oRc:GetValue()))})
    oB:Set("kind", "primary")
    aAdd(aRes, PoInfo():New(oT4, "Recebido (cobranças pagas)", ""))
    aAdd(aRes, PoInfo():New(oT4, "Despesas", ""))
    aAdd(aRes, PoInfo():New(oT4, "Saldo", ""))
    aAdd(aRes, PoInfo():New(oT4, "Ainda em aberto", ""))
    GcUIRegistra(oPg, {|| GcUITabela(oIn, GcQInadimplencia()), GcUITabela(oDt, GcQDespesasCategoria(GcStr(oDc:GetValue()))), ;
        GcUIResultado(aRes, GcStr(oRc:GetValue()))})
Return oPg

Static Function GcUIResultado(aRes, cComp)
    Local aR := GcResultadoMensal(cComp) as array
    Local nI := 0 as numeric

    GcUIToque()
    For nI := 1 To 4
        aRes[nI]:SetValue("R$ " + AllTrim(Transform(aR[nI], "@E 999,999,999.99")))
    Next nI
Return

/*/{Protheus.doc} GcUIPgContabil
    Contabilidade: lançamentos do exercício ativo, plano de contas,
    exercícios (abrir, validar, fechar) e balancete por conta.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgContabil(oApp)
    Local oPg   := PoPage():New(oApp, "Contabilidade") as object
    Local oTabs := PoTabs():New(oPg) as object
    Local oT1   := PoTab():New(oTabs, "Lançamentos") as object
    Local oT2   := PoTab():New(oTabs, "Plano de contas") as object
    Local oT3   := PoTab():New(oTabs, "Exercícios") as object
    Local oT4   := PoTab():New(oTabs, "Balancete") as object
    Local oLan  := PoTable():New(oT1) as object
    Local aSel  := {0} as array
    Local oData := PoInput():New(oT1, "Data (DD/MM/AAAA)") as object
    Local oHist := PoInput():New(oT1, "Histórico") as object
    Local oDeb  := PoInput():New(oT1, "Conta debitada (código)") as object
    Local oCred := PoInput():New(oT1, "Conta creditada (código)") as object
    Local oVal  := PoInput():New(oT1, "Valor (R$)") as object
    Local oPla  := PoTable():New(oT2) as object
    Local oCod  := PoInput():New(oT2, "Código") as object
    Local oNom  := PoInput():New(oT2, "Nome") as object
    Local oTip  := PoSelect():New(oT2, "Tipo", {{"Ativo", "ATIVO"}, {"Passivo", "PASSIVO"}, {"Receita", "RECEITA"}, {"Despesa", "DESPESA"}}, "DESPESA") as object
    Local oExe  := PoTable():New(oT3) as object
    Local oEc   := PoInput():New(oT3, "Código (AAAA-MM)") as object
    Local oEi   := PoInput():New(oT3, "Início (AAAAMMDD)") as object
    Local oEf   := PoInput():New(oT3, "Fim (AAAAMMDD)") as object
    Local oBal  := PoTable():New(oT4) as object
    Local oB    := Nil
    Local oPlaL := Nil
    Local bRec  := Nil

    // Contas por código (campo de texto): o AdvPP 4.8.6 não troca as opções
    // de um PoSelect depois de montado, e o plano muda na outra aba.
    bRec := {|| GcUITabela(oLan, GcQLancamentos(GcExercicioAtivo())), GcUITabela(oPla, GcQPlanoContas()), ;
        GcUITabela(oExe, GcQExercicios()), GcUITabela(oBal, GcQBalancete(GcExercicioAtivo())), GcUITabela(oPlaL, GcQPlanoContas())}
    oLan:OnSelect({|o, aLin| GcUIToque(), aSel[1] := GcNum(aLin[1]), oHist:SetValue(GcStr(aLin[6]))})
    oData:SetValue(DToC(Date()))
    oB := PoButton():New(oT1, "Lançar", {|| GcUIMsg(oApp, GcLancamentoManual(GcDataDigitada(GcStr(oData:GetValue())), GcStr(oHist:GetValue()), ;
        GcStr(oDeb:GetValue()), GcStr(oCred:GetValue()), GcNum(oVal:GetValue())), "Lançamento gravado."), Eval(bRec)})
    oB:Set("kind", "primary")
    oB := PoButton():New(oT1, "Alterar histórico do selecionado", {|| GcUILanOk(oApp, GcEditarLancamentoDescricao(aSel[1], GcStr(oHist:GetValue())), ;
        "Histórico alterado."), Eval(bRec)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(oT1, "Excluir o selecionado", {|| oApp:Confirm("Excluir o lançamento selecionado?", ;
        {|| GcUILanOk(oApp, GcDeletarLancamento(aSel[1]), "Lançamento excluído."), Eval(bRec)}, Nil, "Excluir")})
    oB:Set("kind", "tertiary")
    PoInfo():New(oT1, "", "Só lançamentos manuais mudam; os do Fechamento (despesa e rateio) ficam como gravados.")
    oPlaL := PoTable():New(PoWidget():New(oT1, "Contas do plano"))

    oPla:OnSelect({|o, aLin| GcUIToque(), oCod:SetValue(GcStr(aLin[1])), oNom:SetValue(GcStr(aLin[2])), oTip:SetValue(GcStr(aLin[3]))})
    oB := PoButton():New(oT2, "Gravar conta", {|| GcUIMsg(oApp, GcSalvarConta(GcStr(oCod:GetValue()), GcStr(oNom:GetValue()), ;
        GcStr(oTip:GetValue())), "Conta gravada."), Eval(bRec)})
    oB:Set("kind", "primary")

    oB := PoButton():New(oT3, "Abrir exercício", {|| GcUIMsg(oApp, GcAbrirExercicioDados(GcStr(oEc:GetValue()), GcStr(oEi:GetValue()), ;
        GcStr(oEf:GetValue())), "Exercício aberto e definido como ativo."), Eval(bRec)})
    oB:Set("kind", "primary")
    oB := PoButton():New(oT3, "Validar integridade do ativo", {|| GcUIValida(oApp)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(oT3, "Fechar o exercício ativo", {|| oApp:Confirm("Fechar o exercício ativo? Depois de fechado não aceita mais lançamentos.", ;
        {|| GcUILanOk(oApp, GcFecharPeriodo(GcExercicioAtivo()), "Exercício fechado."), Eval(bRec)}, Nil, "Fechar exercício")})
    oB:Set("kind", "tertiary")
    GcUIRegistra(oPg, bRec)
Return oPg

Static Function GcUILanOk(oApp, lOk, cMsg)
    GcUIToque()
    If lOk
        oApp:Notify(cMsg, "success")
    Else
        oApp:Notify("Operação recusada: selecione um lançamento manual de exercício aberto (ou confira o exercício ativo).", "error")
    EndIf
Return

Static Function GcUIValida(oApp)
    Local cExe := GcExercicioAtivo() as character

    GcUIToque()
    If Empty(cExe)
        oApp:Notify("Nenhum exercício ativo.", "warning")
    ElseIf GcValidarIntegridade(cExe)
        oApp:Notify("Exercício " + cExe + " em equilíbrio: débitos = créditos.", "success")
    Else
        oApp:Notify("Exercício " + cExe + " com desequilíbrio contábil: veja a Auditoria.", "error")
    EndIf
Return

/*/{Protheus.doc} GcUIPgAuditoria
    Auditoria do exercício ativo: roda os validadores e lista anomalias e
    alertas.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUIPgAuditoria(oApp)
    Local oPg  := PoPage():New(oApp, "Auditoria") as object
    Local oW   := PoWidget():New(oPg, "Exercício ativo") as object
    Local oAn  := PoTable():New(PoWidget():New(oPg, "Anomalias")) as object
    Local oAl  := PoTable():New(PoWidget():New(oPg, "Alertas")) as object
    Local oB   := Nil

    oW:SetCols(12)
    oB := PoButton():New(oW, "Auditar agora", {|| GcUIAudita(oApp, oAn, oAl)})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-shield-check")
    oB := PoButton():New(oW, "Conferir fechamento do período", {|| GcUIAuditaFech(oApp)})
    oB:Set("kind", "secondary")
    PoInfo():New(oW, "", "Auditar: equilíbrio contábil, lançamentos e cobranças sem par, rateio, datas fora do período e alterações " + ;
        "em período fechado. Conferir fechamento: anomalias críticas que impedem fechar o exercício ativo.")
    GcUIRegistra(oPg, {|| GcUITabela(oAn, GcQAnomalias()), GcUITabela(oAl, GcQAlertas())})
Return oPg

Static Function GcUIAuditaFech(oApp)
    Local cExe := GcExercicioAtivo() as character
    Local nAn  := 0 as numeric

    GcUIToque()
    If Empty(cExe)
        oApp:Notify("Nenhum exercício ativo.", "warning")
        Return
    EndIf
    nAn := GcAuditoriaFecharPeriodo(cExe)
    If nAn == 0
        oApp:Notify("Exercício " + cExe + " sem anomalias críticas: pode ser fechado.", "success")
    Else
        oApp:Notify("Exercício " + cExe + ": " + cValToChar(nAn) + " anomalia(s) crítica(s) antes de fechar.", "error")
    EndIf
Return

Static Function GcUIAudita(oApp, oAn, oAl)
    Local cExe := GcExercicioAtivo() as character

    GcUIToque()
    If Empty(cExe)
        oApp:Notify("Nenhum exercício ativo para auditar.", "warning")
        Return
    EndIf
    If GcAuditarPeriodoCompleto(cExe)
        oApp:Notify("Auditoria de " + cExe + " sem anomalias.", "success")
    Else
        oApp:Notify("Auditoria de " + cExe + " encontrou anomalias.", "warning")
    EndIf
    GcUITabela(oAn, GcQAnomalias())
    GcUITabela(oAl, GcQAlertas())
Return

/*/{Protheus.doc} GcUIPortal
    Portal do condômino: token de uso único, depois só leitura das
    cobranças e avisos da unidade (consultas diretas, sem tabela de
    rascunho compartilhada).
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param cToken, character, token digitado
*/
Static Function GcUIPortal(oApp, cToken)
    Local oPg  := Nil
    Local oTab := Nil
    Local oAv  := Nil
    Local oB   := Nil
    Local oSt  := Nil
    Local aSel := {0} as array
    Local cTit := "" as character
    Local oLin := Nil
    Local oBar := Nil

    GcUIToque()
    If Empty(cToken) .Or. !GcAuthPortalToken(cToken)
        oApp:Notify("Token inválido, expirado ou já utilizado.", "error")
        Return
    EndIf
    cTit := "Minhas cobranças — unidade " + g_cUniPortal
    If !Empty(g_cCondNomePortal)
        cTit += " — " + g_cCondNomePortal
    EndIf
    oPg := PoPage():New(oApp, cTit)
    oPg:AddAction("Sair", {|| oApp:Close()})
    oTab := PoTable():New(oPg)
    GcUITabela(oTab, GcQPortalCobrancas(g_cUniPortal))
    oTab:OnSelect({|o, aLin| aSel[1] := Val(GcStr(aLin[1]))})
    oSt := PoWidget():New(oPg, "Boleto")
    oSt:SetCols(12)
    oB := PoButton():New(oSt, "Boleto da cobrança selecionada")
    oB:Set("icon", "an an-barcode")
    oLin := PoInfo():New(oSt, "Linha digitável", "selecione uma cobrança em aberto e clique no botão")
    oBar := PoInfo():New(oSt, "Código de barras", "")
    oB:OnClick({|| GcUIBoleto(oApp, oLin, oBar, aSel[1], g_cUniPortal)})
    oAv := PoTable():New(PoWidget():New(oPg, "Avisos do condomínio"))
    GcUITabela(oAv, GcQAvisosAtivos())
    oApp:Notify("Bem-vindo, condômino da unidade " + g_cUniPortal + ".", "success")
    oApp:Navigate(oPg)
Return

/*/{Protheus.doc} GcUIBoleto
    Mostra linha digitável e código de barras da cobrança escolhida nos
    dois PoInfo da página (substitui o boleto anterior).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param oLinha, object, PoInfo da linha digitável
    @param oBarra, object, PoInfo do código de barras
    @param nRecno, numeric, cobrança
    @param cUnidade, character, (opcional) unidade obrigatória (portal)
*/
User Function GcUIBoleto(oApp, oLinha, oBarra, nRecno, cUnidade)
    Local aB := {} as array

    GcUIToque()
    If nRecno <= 0
        oApp:Notify("Selecione uma cobrança na tabela.", "warning")
        Return
    EndIf
    aB := GcBoletoDados(nRecno, cUnidade)
    If !aB[1]
        oApp:Notify(aB[2], "warning")
        Return
    EndIf
    oLinha:Set("label", "Linha digitável — competência " + aB[7] + ", vencimento " + DToC(aB[5]) + ", R$ " + ;
        AllTrim(Transform(aB[6], "@E 999,999,999.99")))
    oLinha:SetValue(aB[3])
    oBarra:SetValue(aB[4])
Return

/*/{Protheus.doc} GcUITabela
    Preenche uma PoTable com o resultado de uma consulta {colunas, linhas}.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function GcUITabela(oTab, aQ)
    oTab:SetColumns(aQ[1])
    oTab:SetItems(aQ[2])
Return

/*/{Protheus.doc} GcUIToque
    Marca atividade na sessão (base da expiração por inatividade).
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function GcUIToque()
    nGcUltimaAcao := GcAgora()
Return

/*/{Protheus.doc} GcUIExpira
    Sessão sem ação há mais de 30 minutos: encerra (a página volta à
    entrada ao recarregar).
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
*/
Static Function GcUIExpira(oApp)
    If GcAgora() - nGcUltimaAcao > GC_INATIVIDADE
        oApp:Notify("Sessão encerrada por inatividade. Recarregue a página para entrar de novo.", "warning")
        oApp:Close()
    EndIf
Return

/*/{Protheus.doc} GcAgora
    Segundos corridos (data + hora), sem voltar a zero à meia-noite.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return numeric, segundos
*/
User Function GcAgora()
Return (Date() - SToD("20000101")) * 86400 + Seconds()

/*/{Protheus.doc} GcStr
    Valor de componente como texto aparado.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param xVal, variant, valor
    @return character, texto
*/
User Function GcStr(xVal)
    If ValType(xVal) == "C"
        Return AllTrim(xVal)
    EndIf
Return AllTrim(cValToChar(xVal))
