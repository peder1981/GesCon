// src/operacoes.prw — operações sem diálogo para a interface web: token do
// portal, configuração do boleto, abertura de exercício e gestão de
// usuários. Devolvem "" (ou o dado pedido) e o motivo da recusa em texto;
// quem mostra é a tela.
#include "totvs.ch"

/*/{Protheus.doc} GcEmitirToken
    Emite token de acesso ao portal para a unidade (condomínio da
    sessão), válido por 48 horas e de uso único.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cUnidade, character, unidade
    @return array, {cToken, cValidadeLocal, cMotivo}: token vazio se recusado
*/
User Function GcEmitirToken(cUnidade)
    Local cFil   := GcSqlLit(FWxFilial('GCT_TOKEN')) as character
    Local aUni   := {} as array
    Local aDatas := {} as array
    Local cToken := "" as character

    aUni := TCSqlQuery("SELECT UNI_CODIGO, IFNULL(UNI_CONDOMINO, '') AS UNI_CONDOMINO FROM UNI WHERE UNI_CODIGO = '" + ;
        GcSqlLit(AllTrim(cUnidade)) + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")
    If Len(aUni) == 0
        Return {"", "", "Unidade não encontrada."}
    EndIf
    If Empty(aUni[1]:UNI_CONDOMINO)
        Return {"", "", "A unidade não tem condômino vinculado."}
    EndIf
    cToken := GcGerarTokenId()
    If Empty(cToken)
        Return {"", "", "Não foi possível gerar um token seguro. Tente de novo."}
    EndIf
    aDatas := TCSqlQuery("SELECT datetime('now') AS CRIADO, datetime('now', '+2 days') AS VALIDADE, " + ;
        "strftime('%d/%m/%Y %H:%M', 'now', '+2 days', 'localtime') AS VALIDADE_LOCAL")
    If !TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, FILIAL) VALUES ('" + ;
            cToken + "', '" + GcSqlLit(GcUsuarioSessao()) + "', '" + GcSqlLit(aUni[1]:UNI_CONDOMINO) + "', '" + ;
            GcSqlLit(aUni[1]:UNI_CODIGO) + "', '" + aDatas[1]:CRIADO + "', '" + aDatas[1]:VALIDADE + "', 0, '" + cFil + "')")
        Return {"", "", "Não foi possível gravar o token: " + TCSqlError()}
    EndIf
Return {cToken, aDatas[1]:VALIDADE_LOCAL, ""}

/*/{Protheus.doc} GcRevogarTokenUnidade
    Revoga os tokens ainda válidos de uma unidade (condomínio da sessão).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cUnidade, character, unidade
    @return character, "" se revogou algum, ou o motivo
*/
User Function GcRevogarTokenUnidade(cUnidade)
    If Len(TCSqlQuery("UPDATE GCT_TOKEN SET D_E_L_E_T_ = '*' WHERE UNI_CODIGO = '" + GcSqlLit(AllTrim(cUnidade)) + "' " + ;
            "AND USADO = 0 AND VALIDO_ATE > datetime('now') AND D_E_L_E_T_ = ' ' " + ;
            "AND FILIAL = '" + GcSqlLit(FWxFilial('GCT_TOKEN')) + "' RETURNING TOKEN")) == 0
        Return "Nenhum token válido para esta unidade."
    EndIf
Return ""

/*/{Protheus.doc} GcSalvarCfgBoleto
    Grava os dados bancários do boleto do condomínio da sessão (uma
    configuração por condomínio), conferindo o layout do banco.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cBanco, character, "341" (Itaú) ou "237" (Bradesco)
    @param cAgencia, character, agência
    @param cConta, character, conta corrente
    @param cConvenio, character, código do beneficiário/convênio (impresso)
    @param cCarteira, character, carteira
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarCfgBoleto(cBanco, cAgencia, cConta, cConvenio, cCarteira)
    Local cFil := GcSqlLit(FWxFilial('CFG_BOLETO')) as character

    cBanco := AllTrim(cBanco)
    If cBanco != "341" .And. cBanco != "237"
        Return "Banco não suportado: use 341 (Itaú) ou 237 (Bradesco)."
    EndIf
    If Empty(GcBoletoCampoLivre(cBanco, cAgencia, cConta, cCarteira, "1"))
        Return "Agência, conta ou carteira fora do layout do banco. Itaú: agência até 4 dígitos, conta até 5, carteira até 3 " + ;
            "(107, 122, 142, 143, 196 e 198 não suportadas). Bradesco: agência até 4, conta até 7, carteira até 2."
    EndIf
    TCSqlExec("DELETE FROM CFG_BOLETO WHERE FILIAL = '" + cFil + "'")
    If !TCSqlExec("INSERT INTO CFG_BOLETO (CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA, FILIAL) VALUES ('" + ;
            cBanco + "', '" + GcSqlLit(AllTrim(cAgencia)) + "', '" + GcSqlLit(AllTrim(cConta)) + "', '" + ;
            GcSqlLit(AllTrim(cConvenio)) + "', '" + GcSqlLit(AllTrim(cCarteira)) + "', '" + cFil + "')")
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcAbrirExercicioDados
    Abre um exercício contábil (e o torna o ativo; um ativo por vez).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cCodigo, character, AAAA-MM
    @param cInicio, character, início AAAAMMDD
    @param cFim, character, fim AAAAMMDD
    @return character, "" se abriu, ou o motivo
*/
User Function GcAbrirExercicioDados(cCodigo, cInicio, cFim)
    Local cFil := GcSqlLit(FWxFilial('EXERCICIO')) as character
    Local dIni := GcBoletoDataVenc(cInicio) as date
    Local dFim := GcBoletoDataVenc(cFim) as date

    cCodigo := AllTrim(cCodigo)
    If !GcCompetenciaValida(cCodigo)
        Return "Código do exercício inválido: use AAAA-MM."
    EndIf
    If Empty(dIni) .Or. Empty(dFim) .Or. dFim < dIni
        Return "Início e fim precisam ser datas válidas (AAAAMMDD) e o fim não pode vir antes do início."
    EndIf
    If Len(TCSqlQuery("SELECT 1 FROM EXERCICIO WHERE EXE_CODIGO = '" + cCodigo + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + cFil + "'")) > 0
        Return "O exercício " + cCodigo + " já existe."
    EndIf
    TCSqlExec("UPDATE EXERCICIO SET EXE_ATIVO = 0 WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + cFil + "'")
    If !TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_, FILIAL) VALUES ('" + ;
            cCodigo + "', '" + DToS(dIni) + "', '" + DToS(dFim) + "', 1, 0, ' ', '" + cFil + "')")
        Return "Não foi possível abrir: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcCriarUsuarioCondominio
    Cria um usuário e o vincula ao condomínio da sessão. Super cria super ou
    síndico; síndico cria só síndico.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login
    @param cSenha, character, senha inicial (troca no primeiro acesso)
    @param cPerfil, character, "SUPERADMIN" ou "SINDICO"
    @return character, "" se criou, ou o motivo
*/
User Function GcCriarUsuarioCondominio(cLogin, cSenha, cPerfil)
    Local cMot := "" as character

    If cPerfil == "SUPERADMIN" .And. !GcPode(GcPerfilDoLogin(GcUsuarioSessao()), "criar_super")
        Return "Só um super administrador cria outro super administrador."
    EndIf
    cMot := GcCriarUsuarioBase(cLogin, cSenha, cPerfil)
    If !Empty(cMot)
        Return cMot
    EndIf
    If cPerfil == "SINDICO"
        TCSqlExec("INSERT OR IGNORE INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('" + GcSqlLit(GcLoginNormal(cLogin)) + "', '" + ;
            GcSqlLit(FWxFilial('COB')) + "')")
    EndIf
Return ""

/*/{Protheus.doc} GcUsuarioGerenciavel
    .T. se o usuário da sessão pode mexer na conta cLogin: super mexe em
    qualquer uma (menos a própria, que tem tela própria); síndico só em
    síndico vinculado ao condomínio da sessão.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcUsuarioGerenciavel(cLogin)
    Local cL  := GcLoginNormal(cLogin) as character
    Local cEu := GcPerfilDoLogin(GcUsuarioSessao()) as character

    If Empty(cL) .Or. cL == GcLoginNormal(GcUsuarioSessao())
        Return .F.
    EndIf
    If cEu == "SUPERADMIN"
        Return Len(TCSqlQuery("SELECT 1 FROM USR WHERE lower(USR_LOGIN) = '" + GcSqlLit(cL) + "' AND D_E_L_E_T_ = ' '")) == 1
    EndIf
Return cEu == "SINDICO" .And. Len(TCSqlQuery("SELECT 1 FROM USR U INNER JOIN USR_COND UC ON lower(UC.USR_LOGIN) = lower(U.USR_LOGIN) " + ;
    "AND UC.D_E_L_E_T_ = ' ' WHERE lower(U.USR_LOGIN) = '" + GcSqlLit(cL) + "' AND U.USR_PERFIL = 'SINDICO' AND U.D_E_L_E_T_ = ' ' " + ;
    "AND UC.FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")) > 0

/*/{Protheus.doc} GcRedefinirSenha
    Define uma senha provisória para outro usuário (troca obrigatória no
    próximo acesso) e desbloqueia a conta.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login do usuário
    @param cSenha, character, senha provisória
    @return character, "" se redefiniu, ou o motivo
*/
User Function GcRedefinirSenha(cLogin, cSenha)
    If !GcUsuarioGerenciavel(cLogin)
        Return "Você não pode redefinir a senha deste usuário."
    EndIf
Return GcDefinirSenha(cLogin, cSenha, .T.)

/*/{Protheus.doc} GcDesbloquearUsuario
    Tira o bloqueio por tentativas e zera os erros.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login
    @return character, "" se desbloqueou, ou o motivo
*/
User Function GcDesbloquearUsuario(cLogin)
    If !GcUsuarioGerenciavel(cLogin)
        Return "Você não pode desbloquear este usuário."
    EndIf
    TCSqlExec("UPDATE USR SET USR_FALHAS = 0, USR_BLOQ_ATE = '' WHERE lower(USR_LOGIN) = '" + GcSqlLit(GcLoginNormal(cLogin)) + "' AND D_E_L_E_T_ = ' '")
Return ""

/*/{Protheus.doc} GcSalvarConta
    Inclui ou altera (pelo código) uma conta do plano de contas.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cCodigo, character, código numérico (até 10 dígitos)
    @param cNome, character, nome
    @param cTipo, character, ATIVO, PASSIVO, RECEITA ou DESPESA
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarConta(cCodigo, cNome, cTipo)
    Local cFil := GcSqlLit(FWxFilial('PLANO_CONTAS')) as character
    Local cCod := AllTrim(cCodigo) as character
    Local nI   := 0 as numeric
    Local cSql := "" as character

    If Empty(cCod) .Or. Len(cCod) > 10
        Return "Código da conta: de 1 a 10 dígitos."
    EndIf
    For nI := 1 To Len(cCod)
        If !(SubStr(cCod, nI, 1) $ "0123456789")
            Return "Código da conta: só dígitos."
        EndIf
    Next nI
    If Empty(AllTrim(cNome))
        Return "Informe o nome da conta."
    EndIf
    If !(cTipo $ "|ATIVO|PASSIVO|RECEITA|DESPESA|") .Or. Empty(cTipo)
        Return "Tipo inválido: ATIVO, PASSIVO, RECEITA ou DESPESA."
    EndIf
    If Len(TCSqlQuery("SELECT 1 FROM PLANO_CONTAS WHERE PLA_CODIGO = '" + cCod + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")) > 0
        cSql := "UPDATE PLANO_CONTAS SET PLA_NOME = '" + GcSqlLit(AllTrim(cNome)) + "', PLA_TIPO = '" + cTipo + "' " + ;
            "WHERE PLA_CODIGO = '" + cCod + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '"
    Else
        cSql := "INSERT INTO PLANO_CONTAS (PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_, FILIAL) VALUES ('" + ;
            cCod + "', '" + GcSqlLit(AllTrim(cNome)) + "', '" + cTipo + "', 1, ' ', '" + cFil + "')"
    EndIf
    If !TCSqlExec(cSql)
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcLancamentoManual
    Lançamento manual em partida dobrada, com o motivo da recusa (a função
    de base, GcCriarLancamentoManualDireto, só registra no log).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param dData, date, data do lançamento
    @param cDescr, character, histórico
    @param cDeb, character, conta debitada
    @param cCred, character, conta creditada
    @param nValor, numeric, valor
    @return character, "" se lançou, ou o motivo
*/
User Function GcLancamentoManual(dData, cDescr, cDeb, cCred, nValor)
    Local cExe := GcExercicioAtivo() as character

    If Empty(cExe)
        Return "Nenhum exercício ativo: abra um em Contabilidade > Exercícios."
    EndIf
    If GcPeriodoFechado(cExe)
        Return "O exercício " + cExe + " está fechado."
    EndIf
    If Empty(dData) .Or. !GcDataNoExercicio(DToS(dData), cExe)
        Return "A data precisa estar dentro do exercício " + cExe + "."
    EndIf
    If !GcContaExiste(cDeb) .Or. !GcContaExiste(cCred)
        Return "Conta de débito ou de crédito inexistente ou inativa no plano de contas."
    EndIf
    If AllTrim(cDeb) == AllTrim(cCred)
        Return "Débito e crédito precisam ser contas diferentes."
    EndIf
    If ValType(nValor) != "N" .Or. Round(nValor, 2) <= 0
        Return "O valor deve ser maior que zero."
    EndIf
    If Empty(AllTrim(cDescr))
        Return "Informe o histórico."
    EndIf
    If !GcCriarLancamentoManualDireto(dData, AllTrim(cDescr), AllTrim(cDeb), AllTrim(cCred), nValor)
        Return "Não foi possível lançar: " + TCSqlError()
    EndIf
Return ""
