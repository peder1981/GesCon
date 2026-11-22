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
    {"Condomínios", "an an-city", "condominios", {|o| GcUIPgCondominios(o)}} }

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
    Página inicial (indicadores na fase 3d).
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @return object, a página
*/
Static Function GcUIInicio(oApp)
    Local oPg := PoPage():New(oApp, "Início") as object
    Local oW  := PoWidget():New(oPg, cGcCondNome) as object
    Local cPf := "síndico" as character

    If cGcPerfil == "SUPERADMIN"
        cPf := "super administrador"
    EndIf
    oW:SetCols(12)
    PoInfo():New(oW, "Usuário", cLoginAtual + " (" + cPf + ")")
Return oPg

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
    oB:OnClick({|| GcUIBoleto(oApp, oSt, aSel[1], g_cUniPortal)})
    oAv := PoTable():New(PoWidget():New(oPg, "Avisos do condomínio"))
    GcUITabela(oAv, GcQAvisosAtivos())
    oApp:Notify("Bem-vindo, condômino da unidade " + g_cUniPortal + ".", "success")
    oApp:Navigate(oPg)
Return

/*/{Protheus.doc} GcUIBoleto
    Mostra linha digitável e código de barras da cobrança escolhida.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param oApp, object, aplicação
    @param oW, object, widget onde mostrar
    @param nRecno, numeric, cobrança
    @param cUnidade, character, (opcional) unidade obrigatória (portal)
*/
User Function GcUIBoleto(oApp, oW, nRecno, cUnidade)
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
    PoInfo():New(oW, "Competência " + aB[7] + " — vencimento " + DToC(aB[5]) + " — R$ " + ;
        AllTrim(Transform(aB[6], "@E 999,999,999.99")), aB[3])
    PoInfo():New(oW, "Código de barras", aB[4])
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
