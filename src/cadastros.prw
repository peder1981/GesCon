// src/cadastros.prw — gravação validada dos cadastros (condômino, unidade,
// despesa, condomínio), no condomínio (filial) da sessão. Cada função
// devolve "" se gravou, ou o motivo da recusa (a tela mostra o motivo).
// Antes a grade genérica (FWMBrowse) gravava qualquer coisa e só os
// gatilhos do banco seguravam algo.
#include "totvs.ch"

/*/{Protheus.doc} GcDocumentoNormal
    CPF/CNPJ só com letras e dígitos, letras em maiúsculas.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cDoc, character, documento digitado
    @return character, documento normalizado
*/
User Function GcDocumentoNormal(cDoc)
    Local cRet := "" as character
    Local cC   := "" as character
    Local nI   := 0 as numeric

    If ValType(cDoc) != "C"
        Return ""
    EndIf
    For nI := 1 To Len(cDoc)
        cC := Upper(SubStr(cDoc, nI, 1))
        If cC $ "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            cRet += cC
        EndIf
    Next nI
Return cRet

/*/{Protheus.doc} GcDocumentoValido
    CPF (11 dígitos) ou CNPJ (14 posições) com dígitos verificadores.
    CNPJ alfanumérico (Receita Federal, a partir de julho de 2026): as 12
    primeiras posições aceitam 0-9 e A-Z, os 2 dígitos verificadores são
    numéricos, e cada caractere vale o código ASCII menos 48 no módulo 11
    (pesos 2 a 9 da direita para a esquerda; resto 0 ou 1 dá 0). CNPJ
    numérico segue a mesma conta. Exemplo oficial (Serpro): 12.ABC.345/01DE-35.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cDoc, character, documento (com ou sem pontuação)
    @return logical, .T. se válido
*/
User Function GcDocumentoValido(cDoc)
    Local cD := GcDocumentoNormal(cDoc) as character
    Local nI := 0 as numeric

    If Len(cD) == 11
        For nI := 1 To 11
            If !(SubStr(cD, nI, 1) $ "0123456789")
                Return .F.
            EndIf
        Next nI
        If cD == Replicate(Left(cD, 1), 11)
            Return .F.
        EndIf
        Return GcDvMod11(Left(cD, 9), 10, .F.) == SubStr(cD, 10, 1) .And. GcDvMod11(Left(cD, 10), 11, .F.) == SubStr(cD, 11, 1)
    EndIf
    If Len(cD) == 14
        If !(SubStr(cD, 13, 1) $ "0123456789") .Or. !(SubStr(cD, 14, 1) $ "0123456789")
            Return .F.
        EndIf
        If cD == Replicate(Left(cD, 1), 14)
            Return .F.
        EndIf
        Return GcDvMod11(Left(cD, 12), 9, .T.) == SubStr(cD, 13, 1) .And. GcDvMod11(Left(cD, 13), 9, .T.) == SubStr(cD, 14, 1)
    EndIf
Return .F.

/*/{Protheus.doc} GcDvMod11
    Dígito módulo 11 com valor = ASCII - 48 por caractere.
    CPF: pesos crescentes da direita a partir de 2 até nPesoMax (10 ou 11),
    sem recomeçar. CNPJ: pesos 2 a 9 recomeçando (lRecomeca).
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @return character, dígito "0"-"9"
*/
Static Function GcDvMod11(cBase, nPesoMax, lRecomeca)
    Local nSoma := 0 as numeric
    Local nPeso := 2 as numeric
    Local nRest := 0 as numeric
    Local nI    := 0 as numeric

    For nI := Len(cBase) To 1 Step -1
        nSoma += (Asc(SubStr(cBase, nI, 1)) - 48) * nPeso
        nPeso++
        If lRecomeca .And. nPeso > nPesoMax
            nPeso := 2
        EndIf
    Next nI
    nRest := Mod(nSoma, 11)
    If nRest < 2
        Return "0"
    EndIf
Return cValToChar(11 - nRest)

/*/{Protheus.doc} GcCodigoValido
    Código de cadastro: 1 a 10 letras, dígitos, hífen ou barra, sem espaço.
    @type Static Function
    @author GesCon
    @since 2026-11-21
*/
Static Function GcCodigoValido(cCod)
    Local nI := 0 as numeric

    If ValType(cCod) != "C" .Or. Empty(cCod) .Or. Len(cCod) > 10
        Return .F.
    EndIf
    For nI := 1 To Len(cCod)
        If !(Upper(SubStr(cCod, nI, 1)) $ "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-/")
            Return .F.
        EndIf
    Next nI
Return .T.

/*/{Protheus.doc} GcSalvarCondomino
    Inclui ou altera (pelo código) um condômino do condomínio da sessão.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cCodigo, character, código
    @param cNome, character, nome
    @param cCpf, character, CPF ou CNPJ (opcional)
    @param cEmail, character, e-mail (opcional; a mala direta usa)
    @param cTel, character, telefone (opcional)
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarCondomino(cCodigo, cNome, cCpf, cEmail, cTel)
    Local cFil := GcSqlLit(FWxFilial('CON')) as character
    Local cCod := AllTrim(cCodigo) as character
    Local cDoc := GcDocumentoNormal(cCpf) as character
    Local cSql := "" as character

    If !GcCodigoValido(cCod)
        Return "Código inválido: até 10 letras, números, hífen ou barra."
    EndIf
    If Empty(AllTrim(cNome))
        Return "Informe o nome."
    EndIf
    If !Empty(cDoc) .And. !GcDocumentoValido(cDoc)
        Return "CPF/CNPJ inválido."
    EndIf
    If !Empty(AllTrim(cEmail)) .And. !GcEmailValido(cEmail)
        Return "E-mail inválido."
    EndIf
    If Len(TCSqlQuery("SELECT 1 FROM CON WHERE CON_CODIGO = '" + GcSqlLit(cCod) + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")) > 0
        cSql := "UPDATE CON SET CON_NOME = '" + GcSqlLit(AllTrim(cNome)) + "', CON_CPF = '" + cDoc + "', " + ;
            "CON_EMAIL = '" + GcSqlLit(AllTrim(cEmail)) + "', CON_TEL = '" + GcSqlLit(AllTrim(cTel)) + "' " + ;
            "WHERE CON_CODIGO = '" + GcSqlLit(cCod) + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '"
    Else
        cSql := "INSERT INTO CON (CON_CODIGO, CON_NOME, CON_CPF, CON_EMAIL, CON_TEL, FILIAL) VALUES ('" + ;
            GcSqlLit(cCod) + "', '" + GcSqlLit(AllTrim(cNome)) + "', '" + cDoc + "', '" + ;
            GcSqlLit(AllTrim(cEmail)) + "', '" + GcSqlLit(AllTrim(cTel)) + "', '" + cFil + "')"
    EndIf
    If !TCSqlExec(cSql)
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcExcluirCondomino
    Exclui (lógico) um condômino que não esteja vinculado a unidade.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cCodigo, character, código
    @return character, "" se excluiu, ou o motivo
*/
User Function GcExcluirCondomino(cCodigo)
    Local cFil := GcSqlLit(FWxFilial('CON')) as character
    Local cCod := GcSqlLit(AllTrim(cCodigo)) as character

    If Len(TCSqlQuery("SELECT 1 FROM UNI WHERE UNI_CONDOMINO = '" + cCod + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")) > 0
        Return "O condômino está vinculado a uma unidade: troque o vínculo antes."
    EndIf
    If Len(TCSqlQuery("UPDATE CON SET D_E_L_E_T_ = '*', R_E_C_D_E_L_ = R_E_C_N_O_ WHERE CON_CODIGO = '" + cCod + ;
            "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' ' RETURNING R_E_C_N_O_")) == 0
        Return "Condômino não encontrado."
    EndIf
Return ""

/*/{Protheus.doc} GcSalvarUnidade
    Inclui ou altera (pelo código) uma unidade do condomínio da sessão.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cCodigo, character, código (ex.: 101)
    @param cBloco, character, bloco (opcional)
    @param nFracao, numeric, fração ideal (0 < f <= 1)
    @param cCondomino, character, código do condômino (opcional)
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarUnidade(cCodigo, cBloco, nFracao, cCondomino)
    Local cFil := GcSqlLit(FWxFilial('UNI')) as character
    Local cCod := AllTrim(cCodigo) as character
    Local cCon := AllTrim(cCondomino) as character
    Local cSql := "" as character

    If !GcCodigoValido(cCod)
        Return "Código inválido: até 10 letras, números, hífen ou barra."
    EndIf
    If ValType(nFracao) != "N" .Or. nFracao <= 0 .Or. nFracao > 1
        Return "Fração ideal deve ser maior que 0 e no máximo 1 (ex.: 0,025 para 2,5%)."
    EndIf
    If !Empty(cCon) .And. Len(TCSqlQuery("SELECT 1 FROM CON WHERE CON_CODIGO = '" + GcSqlLit(cCon) + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")) == 0
        Return "Condômino " + cCon + " não cadastrado."
    EndIf
    If Len(TCSqlQuery("SELECT 1 FROM UNI WHERE UNI_CODIGO = '" + GcSqlLit(cCod) + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")) > 0
        cSql := "UPDATE UNI SET UNI_BLOCO = '" + GcSqlLit(AllTrim(cBloco)) + "', UNI_FRACAO = " + cValToChar(nFracao) + ", " + ;
            "UNI_CONDOMINO = '" + GcSqlLit(cCon) + "' WHERE UNI_CODIGO = '" + GcSqlLit(cCod) + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '"
    Else
        cSql := "INSERT INTO UNI (UNI_CODIGO, UNI_BLOCO, UNI_FRACAO, UNI_CONDOMINO, FILIAL) VALUES ('" + ;
            GcSqlLit(cCod) + "', '" + GcSqlLit(AllTrim(cBloco)) + "', " + cValToChar(nFracao) + ", '" + GcSqlLit(cCon) + "', '" + cFil + "')"
    EndIf
    If !TCSqlExec(cSql)
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcExcluirUnidade
    Exclui (lógico) uma unidade sem cobranças (cobrança é histórico).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cCodigo, character, código
    @return character, "" se excluiu, ou o motivo
*/
User Function GcExcluirUnidade(cCodigo)
    Local cFil := GcSqlLit(FWxFilial('UNI')) as character
    Local cCod := GcSqlLit(AllTrim(cCodigo)) as character

    If Len(TCSqlQuery("SELECT 1 FROM COB WHERE COB_UNIDADE = '" + cCod + "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")) > 0
        Return "A unidade tem cobranças (histórico): não pode ser excluída."
    EndIf
    If Len(TCSqlQuery("UPDATE UNI SET D_E_L_E_T_ = '*', R_E_C_D_E_L_ = R_E_C_N_O_ WHERE UNI_CODIGO = '" + cCod + ;
            "' AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' ' RETURNING R_E_C_N_O_")) == 0
        Return "Unidade não encontrada."
    EndIf
Return ""

/*/{Protheus.doc} GcCompetenciaFechada
    .T. se a competência já tem cobranças no condomínio da sessão.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cCompetencia, character, AAAA-MM
    @return logical
*/
User Function GcCompetenciaFechada(cCompetencia)
Return Len(TCSqlQuery("SELECT 1 FROM COB WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND FILIAL = '" + ;
    GcSqlLit(FWxFilial('COB')) + "' AND D_E_L_E_T_ = ' ' LIMIT 1")) > 0

/*/{Protheus.doc} GcSalvarDespesa
    Inclui (nRecno 0) ou altera uma despesa. Competência já fechada não
    recebe nem muda despesa (as cobranças já foram rateadas).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param nRecno, numeric, 0 para incluir
    @param cDescr, character, descrição
    @param cCateg, character, categoria (define a conta contábil)
    @param nValor, numeric, valor
    @param cCompet, character, AAAA-MM
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarDespesa(nRecno, cDescr, cCateg, nValor, cCompet)
    Local cFil := GcSqlLit(FWxFilial('DES')) as character
    Local aAnt := {} as array
    Local cSql := "" as character

    If Empty(AllTrim(cDescr))
        Return "Informe a descrição."
    EndIf
    If ValType(nValor) != "N" .Or. Round(nValor, 2) <= 0
        Return "O valor deve ser maior que zero."
    EndIf
    If !GcCompetenciaValida(cCompet)
        Return "Competência inválida: use AAAA-MM (ex.: 2026-11)."
    EndIf
    If GcCompetenciaFechada(cCompet)
        Return "A competência " + cCompet + " já foi fechada: a despesa não pode entrar nem mudar."
    EndIf
    If nRecno > 0
        aAnt := TCSqlQuery("SELECT DES_COMPET, DES_LANCADO_CONTABIL FROM DES WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + ;
            " AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")
        If Len(aAnt) == 0
            Return "Despesa não encontrada."
        EndIf
        If GcCompetenciaFechada(AllTrim(aAnt[1]:DES_COMPET)) .Or. Val(aAnt[1]:DES_LANCADO_CONTABIL) != 0
            Return "Despesa de competência fechada ou já contabilizada: não pode mudar."
        EndIf
        cSql := "UPDATE DES SET DES_DESCR = '" + GcSqlLit(AllTrim(cDescr)) + "', DES_CATEG = '" + GcSqlLit(Upper(AllTrim(cCateg))) + "', " + ;
            "DES_VALOR = " + cValToChar(Round(nValor, 2)) + ", DES_COMPET = '" + GcSqlLit(cCompet) + "' " + ;
            "WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + " AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '"
    Else
        cSql := "INSERT INTO DES (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET, DES_DTLANC, FILIAL) VALUES ('" + ;
            GcSqlLit(AllTrim(cDescr)) + "', '" + GcSqlLit(Upper(AllTrim(cCateg))) + "', " + cValToChar(Round(nValor, 2)) + ", '" + ;
            GcSqlLit(cCompet) + "', date('now'), '" + cFil + "')"
    EndIf
    If !TCSqlExec(cSql)
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcExcluirDespesa
    Exclui (lógico) uma despesa de competência ainda aberta e não
    contabilizada.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param nRecno, numeric, R_E_C_N_O_
    @return character, "" se excluiu, ou o motivo
*/
User Function GcExcluirDespesa(nRecno)
    Local cFil := GcSqlLit(FWxFilial('DES')) as character
    Local aAnt := {} as array

    aAnt := TCSqlQuery("SELECT DES_COMPET, DES_LANCADO_CONTABIL FROM DES WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + ;
        " AND FILIAL = '" + cFil + "' AND D_E_L_E_T_ = ' '")
    If Len(aAnt) == 0
        Return "Despesa não encontrada."
    EndIf
    If GcCompetenciaFechada(AllTrim(aAnt[1]:DES_COMPET)) .Or. Val(aAnt[1]:DES_LANCADO_CONTABIL) != 0
        Return "Despesa de competência fechada ou já contabilizada: não pode ser excluída."
    EndIf
    TCSqlExec("UPDATE DES SET D_E_L_E_T_ = '*', R_E_C_D_E_L_ = R_E_C_N_O_ WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + ;
        " AND FILIAL = '" + cFil + "'")
Return ""

/*/{Protheus.doc} GcSalvarCondominio
    Inclui (cFilial vazio: gera o próximo código de 6 dígitos) ou altera um
    condomínio. Só super administrador.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cFilial, character, código do condomínio, ou "" para incluir
    @param cNome, character, nome
    @param cCnpj, character, CNPJ (opcional; aceita o alfanumérico)
    @param cEndereco, character, endereço (opcional)
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarCondominio(cFilial, cNome, cCnpj, cEndereco)
    Local cDoc := GcDocumentoNormal(cCnpj) as character
    Local cFil := AllTrim(cFilial) as character
    Local aMax := {} as array
    Local cSql := "" as character

    If !GcPode(GcPerfilDoLogin(GcUsuarioSessao()), "condominios")
        Return "Só um super administrador cadastra condomínios."
    EndIf
    If Empty(AllTrim(cNome))
        Return "Informe o nome."
    EndIf
    If !Empty(cDoc) .And. (Len(cDoc) != 14 .Or. !GcDocumentoValido(cDoc))
        Return "CNPJ inválido."
    EndIf
    If Empty(cFil)
        aMax := TCSqlQuery("SELECT COALESCE(MAX(CAST(COND_FILIAL AS INTEGER)), 10100) + 1 AS PROX FROM COND " + ;
            "WHERE COND_FILIAL GLOB '[0-9][0-9][0-9][0-9][0-9][0-9]'")
        cFil := StrZero(Val(aMax[1]:PROX), 6)
        cSql := "INSERT INTO COND (COND_FILIAL, COND_NOME, COND_CNPJ, COND_ENDERECO) VALUES ('" + cFil + "', '" + ;
            GcSqlLit(AllTrim(cNome)) + "', '" + cDoc + "', '" + GcSqlLit(AllTrim(cEndereco)) + "')"
    Else
        cSql := "UPDATE COND SET COND_NOME = '" + GcSqlLit(AllTrim(cNome)) + "', COND_CNPJ = '" + cDoc + "', " + ;
            "COND_ENDERECO = '" + GcSqlLit(AllTrim(cEndereco)) + "' WHERE COND_FILIAL = '" + GcSqlLit(cFil) + "' AND D_E_L_E_T_ = ' '"
    EndIf
    If !TCSqlExec(cSql)
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcDataDigitada
    Data digitada em DD/MM/AAAA, AAAA-MM-DD ou AAAAMMDD; data inexistente
    volta vazia.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cTexto, character, data digitada
    @return date, a data ou vazia
*/
User Function GcDataDigitada(cTexto)
    Local c := AllTrim(cTexto) as character

    If Len(c) == 10 .And. SubStr(c, 3, 1) == "/" .And. SubStr(c, 6, 1) == "/"
        c := Right(c, 4) + SubStr(c, 4, 2) + Left(c, 2)
    EndIf
Return GcBoletoDataVenc(c)
