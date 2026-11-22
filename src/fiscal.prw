// src/fiscal.prw -- reforma tributária: dados fiscais do condomínio, regime
// (não optante x optante pelo regime regular) e o teste dos 80%.
//
// Base legal (texto conferido em 2026-11-22):
//   - LC 214/2025, art. 26 (redação da LC 227/2026): condomínio edilício não
//     é contribuinte do IBS e da CBS (I); pode optar pelo regime regular
//     (§ 1º I); optante paga sobre todas as taxas e demais valores cobrados
//     de condôminos e terceiros (§ 2º I); não optante cujas taxas e demais
//     valores cobrados dos condôminos sejam menos de 80% da receita total
//     paga sobre as operações que realizar, com crédito proporcional (§ 2º II).
//   - Decreto 12.955/2026, art. 25: a opção vale da data em que é feita, com
//     permanência mínima de 12 meses; a renúncia produz efeito no 1º dia do
//     ano-calendário seguinte.
// O GesCon não calcula IBS/CBS: na NFS-e nacional quem calcula é a Sefin a
// partir do CST e do cClassTrib. Aqui fica o enquadramento e o indicador.
#include "totvs.ch"

/*/{Protheus.doc} GcFiscalCfg
    Dados fiscais do condomínio aberto (padrão da lei quando nunca gravados).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @return array, {regime, dt_opcao AAAAMMDD, dt_renuncia AAAAMMDD, cmun,
        ambiente, serie, ultimo nDPS, certificado}
*/
User Function GcFiscalCfg()
    Local aR := TCSqlQuery("SELECT FIS_REGIME, FIS_DT_OPCAO, IFNULL(FIS_DT_RENUNCIA, '') AS FIS_DT_RENUNCIA, FIS_CMUN, " + ;
        "FIS_AMB, FIS_SERIE, FIS_NDPS, FIS_CERT FROM FIS WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + ;
        GcSqlLit(FWxFilial('FIS')) + "'") as array

    If Len(aR) == 0
        Return {"N", "", "", "", "2", "1", 0, ""}
    EndIf
Return {AllTrim(aR[1]:FIS_REGIME), AllTrim(aR[1]:FIS_DT_OPCAO), AllTrim(aR[1]:FIS_DT_RENUNCIA), AllTrim(aR[1]:FIS_CMUN), ;
    AllTrim(aR[1]:FIS_AMB), AllTrim(aR[1]:FIS_SERIE), Val(cValToChar(aR[1]:FIS_NDPS)), AllTrim(aR[1]:FIS_CERT)}

/*/{Protheus.doc} GcSalvarFiscal
    Grava os dados fiscais do condomínio aberto, com as regras da opção pelo
    regime regular: a opção tem data; a renúncia só depois de 12 meses de
    opção e vale a partir de 1º de janeiro do ano seguinte.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cRegime, character, "N" não optante | "R" optante
    @param cDtOpcao, character, data da opção DD/MM/AAAA (optante)
    @param cCMun, character, código IBGE do município (7 dígitos)
    @param cAmb, character, "2" produção restrita (teste) | "1" produção
    @param cSerie, character, série da DPS
    @param cCert, character, caminho do certificado A1 (.pfx) no servidor
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarFiscal(cRegime, cDtOpcao, cCMun, cAmb, cSerie, cCert)
    Local aAnt     := GcFiscalCfg() as array
    Local dOpcao   := CToD("") as date
    Local cOpcao   := "" as character
    Local cRenun   := aAnt[3] as character
    Local cFil     := GcSqlLit(FWxFilial('FIS')) as character
    Local cSql     := "" as character

    cRegime := Upper(AllTrim(cRegime))
    cCMun   := AllTrim(cCMun)
    cAmb    := AllTrim(cAmb)
    cSerie  := AllTrim(cSerie)
    cCert   := AllTrim(cCert)
    If cRegime != "N" .And. cRegime != "R"
        Return "Regime inválido: N (não optante) ou R (optante pelo regime regular)."
    EndIf
    If !GcSoDigitos(cCMun) .Or. Len(cCMun) != 7
        Return "Município: informe o código IBGE com 7 dígitos (ex.: 3550308 para São Paulo)."
    EndIf
    If cAmb != "1" .And. cAmb != "2"
        Return "Ambiente: 2 (produção restrita, para teste) ou 1 (produção)."
    EndIf
    If !GcSerieDpsValida(cSerie)
        Return "Série da DPS: de 1 a 5 dígitos (até 89999)."
    EndIf
    If !Empty(cCert) .And. !File(cCert)
        Return "Certificado não encontrado no servidor: " + cCert
    EndIf

    If cRegime == "R"
        If aAnt[1] == "R"
            cOpcao := aAnt[2]
        Else
            dOpcao := GcDataDigitada(cDtOpcao)
            If Empty(dOpcao)
                Return "Informe a data da opção pelo regime regular (DD/MM/AAAA)."
            EndIf
            cOpcao := DToS(dOpcao)
            cRenun := ""
        EndIf
    Else
        cOpcao := aAnt[2]
        If aAnt[1] == "R"
            // Decreto 12.955/2026, art. 25, § 1º: permanência mínima de 12 meses.
            If Date() < GcMaisMeses(SToD(aAnt[2]), 12)
                Return "A opção pelo regime regular exige permanência mínima de 12 meses (a partir de " + ;
                    DToC(SToD(aAnt[2])) + "): a renúncia só pode ser feita a partir de " + DToC(GcMaisMeses(SToD(aAnt[2]), 12)) + "."
            EndIf
            cRenun := DToS(Date())
        EndIf
    EndIf

    cSql := "INSERT INTO FIS (FILIAL, FIS_REGIME, FIS_DT_OPCAO, FIS_DT_RENUNCIA, FIS_CMUN, FIS_AMB, FIS_SERIE, FIS_CERT) VALUES ('" + ;
        cFil + "', '" + cRegime + "', '" + cOpcao + "', '" + cRenun + "', '" + cCMun + "', '" + cAmb + "', '" + ;
        GcSqlLit(cSerie) + "', '" + GcSqlLit(cCert) + "') ON CONFLICT(FILIAL) DO UPDATE SET FIS_REGIME = excluded.FIS_REGIME, " + ;
        "FIS_DT_OPCAO = excluded.FIS_DT_OPCAO, FIS_DT_RENUNCIA = excluded.FIS_DT_RENUNCIA, FIS_CMUN = excluded.FIS_CMUN, " + ;
        "FIS_AMB = excluded.FIS_AMB, FIS_SERIE = excluded.FIS_SERIE, FIS_CERT = excluded.FIS_CERT"
    If !TCSqlExec(cSql)
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcRegimeEm
    Regime em vigor numa data: optante da data da opção em diante; depois da
    renúncia, continua optante até 31/12 do ano em que renunciou.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param dData, date, data de referência (competência da cobrança)
    @return character, "R" optante | "N" não optante
*/
User Function GcRegimeEm(dData)
    Local aCfg := GcFiscalCfg() as array

    If Empty(aCfg[2]) .Or. dData < SToD(aCfg[2])
        Return "N"
    EndIf
    If aCfg[1] == "R"
        Return "R"
    EndIf
    If !Empty(aCfg[3]) .And. Year(dData) <= Year(SToD(aCfg[3]))
        Return "R"
    EndIf
Return "N"

/*/{Protheus.doc} GcSalvarReceita
    Inclui ou altera uma receita do condomínio fora das cobranças do
    fechamento (para o teste dos 80%).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param nRecno, numeric, 0 para incluir
    @param cCompet, character, AAAA-MM
    @param cDescr, character, descrição
    @param cTipo, character, "C" condôminos | "T" terceiros | "F" financeira
    @param nValor, numeric, valor maior que zero
    @return character, "" se gravou, ou o motivo
*/
User Function GcSalvarReceita(nRecno, cCompet, cDescr, cTipo, nValor)
    Local cFil := GcSqlLit(FWxFilial('REC')) as character
    Local lOk  := .F. as logical

    cCompet := AllTrim(cCompet)
    cDescr  := AllTrim(cDescr)
    cTipo   := Upper(Left(AllTrim(cTipo), 1))
    If !GcCompetenciaValida(cCompet)
        Return "Competência inválida: use AAAA-MM."
    EndIf
    If Empty(cDescr)
        Return "Informe a descrição da receita."
    EndIf
    If !(cTipo $ "CTF") .Or. Len(cTipo) != 1
        Return "Origem inválida: C (dos condôminos), T (de terceiros) ou F (financeira)."
    EndIf
    If ValType(nValor) != "N" .Or. Round(nValor, 2) <= 0
        Return "O valor precisa ser maior que zero."
    EndIf
    nValor := Round(nValor, 2)
    If Empty(nRecno)
        lOk := TCSqlExec("INSERT INTO REC (FILIAL, REC_COMPET, REC_DESCR, REC_TIPO, REC_VALOR) VALUES ('" + cFil + "', '" + ;
            cCompet + "', '" + GcSqlLit(cDescr) + "', '" + cTipo + "', " + cValToChar(nValor) + ")")
    Else
        If Len(TCSqlQuery("SELECT 1 FROM REC WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + " AND FILIAL = '" + cFil + ;
                "' AND D_E_L_E_T_ = ' '")) == 0
            Return "Receita não encontrada neste condomínio."
        EndIf
        lOk := TCSqlExec("UPDATE REC SET REC_COMPET = '" + cCompet + "', REC_DESCR = '" + GcSqlLit(cDescr) + "', REC_TIPO = '" + ;
            cTipo + "', REC_VALOR = " + cValToChar(nValor) + " WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + ;
            " AND FILIAL = '" + cFil + "'")
    EndIf
    If !lOk
        Return "Não foi possível gravar: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcExcluirReceita
    Exclui (logicamente) uma receita do condomínio aberto.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param nRecno, numeric, registro
    @return character, "" se excluiu, ou o motivo
*/
User Function GcExcluirReceita(nRecno)
    Local cFil := GcSqlLit(FWxFilial('REC')) as character

    If Len(TCSqlQuery("SELECT 1 FROM REC WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + " AND FILIAL = '" + cFil + ;
            "' AND D_E_L_E_T_ = ' '")) == 0
        Return "Selecione uma receita deste condomínio."
    EndIf
    If !TCSqlExec("UPDATE REC SET D_E_L_E_T_ = '*' WHERE R_E_C_N_O_ = " + cValToChar(Int(nRecno)) + " AND FILIAL = '" + cFil + "'")
        Return "Não foi possível excluir: " + TCSqlError()
    EndIf
Return ""

/*/{Protheus.doc} GcTeste80
    Teste dos 80% (LC 214/2025, art. 26, § 2º, II) no período: taxas e demais
    valores cobrados dos condôminos (cobranças do fechamento + receitas de
    origem C) sobre a receita total (tudo, inclusive terceiros e financeiras).
    A lei não fixa o período de apuração: o padrão da tela são os 12 meses
    até a competência informada; a decisão final é do contador.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cIni, character, competência inicial AAAA-MM
    @param cFim, character, competência final AAAA-MM
    @return array, {nCondominos, nTerceiros, nFinanceiras, nTotal, nPercentual, cSituacao}
*/
User Function GcTeste80(cIni, cFim)
    Local cFilC  := GcSqlLit(FWxFilial('COB')) as character
    Local cFilR  := GcSqlLit(FWxFilial('REC')) as character
    Local aC     := {} as array
    Local aR     := {} as array
    Local nCond  := 0 as numeric
    Local nTerc  := 0 as numeric
    Local nFin   := 0 as numeric
    Local nTotal := 0 as numeric
    Local nPct   := 0 as numeric
    Local nI     := 0 as numeric
    Local cSit   := "" as character

    aC := TCSqlQuery("SELECT IFNULL(SUM(COB_VALOR), 0) AS V FROM COB WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + cFilC + ;
        "' AND COB_COMPET BETWEEN '" + GcSqlLit(cIni) + "' AND '" + GcSqlLit(cFim) + "'")
    nCond := Val(cValToChar(aC[1]:V))
    aR := TCSqlQuery("SELECT REC_TIPO, SUM(REC_VALOR) AS V FROM REC WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + cFilR + ;
        "' AND REC_COMPET BETWEEN '" + GcSqlLit(cIni) + "' AND '" + GcSqlLit(cFim) + "' GROUP BY REC_TIPO")
    For nI := 1 To Len(aR)
        If AllTrim(aR[nI]:REC_TIPO) == "C"
            nCond += Val(cValToChar(aR[nI]:V))
        ElseIf AllTrim(aR[nI]:REC_TIPO) == "T"
            nTerc += Val(cValToChar(aR[nI]:V))
        Else
            nFin += Val(cValToChar(aR[nI]:V))
        EndIf
    Next
    nCond  := Round(nCond, 2)
    nTotal := Round(nCond + nTerc + nFin, 2)

    If GcRegimeEm(GcFimDaCompetencia(cFim)) == "R"
        cSit := "Optante pelo regime regular: IBS e CBS incidem sobre todas as taxas e demais valores cobrados " + ;
            "de condôminos e de terceiros (LC 214/2025, art. 26, § 2º, I)."
    ElseIf nTotal == 0
        cSit := "Sem receita no período."
    Else
        nPct := Round(nCond * 100 / nTotal, 2)
        If nPct >= 80
            cSit := "Não contribuinte: as taxas e demais valores cobrados dos condôminos são " + ;
                AllTrim(Transform(nPct, "@E 999.99")) + "% da receita (80% ou mais). Sem IBS e CBS; a NFS-e das " + ;
                "cobranças é obrigatória mesmo assim, a partir de 01/01/2027."
        Else
            cSit := "Atenção: as taxas e demais valores cobrados dos condôminos são " + AllTrim(Transform(nPct, "@E 999.99")) + ;
                "% da receita, menos de 80%. Sem a opção pelo regime regular, o condomínio fica sujeito ao IBS e à CBS " + ;
                "sobre as operações que realizar (receitas de terceiros), com crédito proporcional (LC 214/2025, art. 26, " + ;
                "§ 2º, II). Leve ao contador."
        EndIf
    EndIf
Return {nCond, Round(nTerc, 2), Round(nFin, 2), nTotal, nPct, cSit}

/*/{Protheus.doc} GcFimDaCompetencia
    Último dia da competência AAAA-MM.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cComp, character, AAAA-MM
    @return date, último dia do mês (vazia se a competência for inválida)
*/
User Function GcFimDaCompetencia(cComp)
    If !GcCompetenciaValida(cComp)
        Return CToD("")
    EndIf
Return GcMaisMeses(SToD(StrTran(cComp, "-", "") + "01"), 1) - 1

/*/{Protheus.doc} GcMaisMeses
    Soma meses a uma data; dia que não existe no mês de destino vira o último
    dia dele (31/01 + 1 mês = 28 ou 29/02).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param dData, date, data
    @param nMeses, numeric, meses a somar
    @return date, data resultante
*/
User Function GcMaisMeses(dData, nMeses)
    // Em meses corridos desde o ano 0: vale para nMeses negativo também.
    Local nTot  := Year(dData) * 12 + Month(dData) - 1 + nMeses as numeric
    Local nAno  := Int(nTot / 12) as numeric
    Local nMes  := nTot - nAno * 12 + 1 as numeric
    Local nDia  := Day(dData) as numeric
    Local dRet  := CToD("") as date

    dRet := SToD(StrZero(nAno, 4) + StrZero(nMes, 2) + StrZero(nDia, 2))
    While Empty(dRet) .And. nDia > 28
        nDia--
        dRet := SToD(StrZero(nAno, 4) + StrZero(nMes, 2) + StrZero(nDia, 2))
    EndDo
Return dRet

/*/{Protheus.doc} GcSerieDpsValida
    Série da DPS no padrão do XSD: [0-9]{1,4} ou [0-8][0-9]{4}.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cSerie, character, série
    @return logical, .T. se válida
*/
User Function GcSerieDpsValida(cSerie)
    If !GcSoDigitos(cSerie) .Or. Len(cSerie) < 1 .Or. Len(cSerie) > 5
        Return .F.
    EndIf
    If Len(cSerie) == 5 .And. Left(cSerie, 1) == "9"
        Return .F.
    EndIf
Return .T.

/*/{Protheus.doc} GcSoDigitos
    Verdadeiro se o texto não é vazio e só tem dígitos.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cTxt, character, texto
    @return logical, .T. se só dígitos
*/
User Function GcSoDigitos(cTxt)
    Local nI := 0 as numeric

    If ValType(cTxt) != "C" .Or. Empty(cTxt)
        Return .F.
    EndIf
    For nI := 1 To Len(cTxt)
        If !(SubStr(cTxt, nI, 1) $ "0123456789")
            Return .F.
        EndIf
    Next
Return .T.
