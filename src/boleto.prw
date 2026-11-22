// src/boleto.prw - boleto bancario (Itau 341 e Bradesco 237): codigo de
// barras de 44 posicoes e linha digitavel, pelos manuais dos bancos:
//   - Itau, "Cobranca CNAB 400" (jan/2017): itens 7.3 (layout do codigo de
//     barras), 7.4 (representacao numerica) e anexos 2 (DAC modulo 11),
//     3 (DAC modulo 10), 4 (DAC do nosso numero) e 6 (fator de vencimento)
//   - Bradesco, "Arquivos layout 400 posicoes" (abr/2022): "Montagem dos
//     Dados do Codigo de Barras" e "Composicao da Linha Digitavel"
// tests/boleto_test.prw confere contra os exemplos numericos dos manuais.
#include "totvs.ch"

/*/{Protheus.doc} GcBoletoFatorVenc
    Fator de vencimento (4 digitos): dias desde 07/10/1997, com 1000 =
    03/07/2000 e 9999 = 21/02/2025. Depois de 9999 o fator volta a 1000
    (22/02/2025 = 1000), entao o ciclo e de 9000 dias.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param dData, date, vencimento
    @return numeric, fator (1000-9999), ou 0 se a data e vazia ou anterior a 03/07/2000
*/
User Function GcBoletoFatorVenc(dData)
    Local nDias := 0 as numeric

    If ValType(dData) != "D" .Or. Empty(dData)
        Return 0
    EndIf
    nDias := dData - SToD("19971007")
    If nDias < 1000
        Return 0
    EndIf
Return Mod(nDias - 1000, 9000) + 1000

/*/{Protheus.doc} GcBoletoMod10
    Digito modulo 10 (pesos 2,1,2,1... da direita para a esquerda, soma
    dos algarismos de cada produto; 10 vira 0). Usado nos campos 1 a 3 da
    linha digitavel e nos DACs do Itau.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cNum, character, somente digitos
    @return numeric, digito 0-9
*/
User Function GcBoletoMod10(cNum)
    Local nSoma := 0 as numeric
    Local nPeso := 2 as numeric
    Local nProd := 0 as numeric
    Local nI    := 0 as numeric

    For nI := Len(cNum) To 1 Step -1
        nProd := Val(SubStr(cNum, nI, 1)) * nPeso
        nSoma += Int(nProd / 10) + Mod(nProd, 10)
        If nPeso == 2
            nPeso := 1
        Else
            nPeso := 2
        EndIf
    Next nI
Return Mod(10 - Mod(nSoma, 10), 10)

/*/{Protheus.doc} GcBoletoDacBarras
    DAC do codigo de barras (posicao 5): modulo 11 sobre as outras 43
    posicoes, pesos 2 a 9 da direita para a esquerda; resultado 0, 1, 10
    ou 11 vira 1.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param c43, character, as 43 posicoes sem o DAC
    @return numeric, DAC 1-9
*/
User Function GcBoletoDacBarras(c43)
    Local nSoma := 0 as numeric
    Local nPeso := 2 as numeric
    Local nDac  := 0 as numeric
    Local nI    := 0 as numeric

    For nI := Len(c43) To 1 Step -1
        nSoma += Val(SubStr(c43, nI, 1)) * nPeso
        nPeso++
        If nPeso > 9
            nPeso := 2
        EndIf
    Next nI
    nDac := 11 - Mod(nSoma, 11)
    If nDac == 0 .Or. nDac == 1 .Or. nDac > 9
        nDac := 1
    EndIf
Return nDac

/*/{Protheus.doc} GcBoletoCampoLivre
    Campo livre (posicoes 20 a 44) no layout de cada banco.
    Itau: carteira(3) nosso numero(8) DAC(1) agencia(4) conta(5) DAC(1) 000.
      DAC do nosso numero = modulo 10 de agencia+conta+carteira+nosso
      numero; nas carteiras 126, 131, 146, 150 e 168, so carteira+nosso
      numero. DAC da conta = modulo 10 de agencia+conta. As carteiras de
      nosso numero com 15 posicoes (107, 122, 142, 143, 196, 198) tem
      outro layout e nao sao suportadas.
    Bradesco: agencia(4) carteira(2) nosso numero(11) conta(7) 0.
    Agencia e conta podem vir com o digito ("1234-5"): o digito e ignorado.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cBanco, character, "341" ou "237"
    @param cAgencia, character, agencia
    @param cConta, character, conta corrente
    @param cCarteira, character, carteira
    @param cNossoNum, character, nosso numero sem digito
    @return character, 25 digitos, ou "" se algum dado e invalido
*/
User Function GcBoletoCampoLivre(cBanco, cAgencia, cConta, cCarteira, cNossoNum)
    Local cAg   := SemDigito(cAgencia) as character
    Local cCc   := SemDigito(cConta) as character
    Local cCart := Digitos(cCarteira) as character
    Local cNN   := Digitos(cNossoNum) as character
    Local cDacNN := "" as character

    If Empty(cAg) .Or. Empty(cCc) .Or. Empty(cCart) .Or. Empty(cNN) .Or. Len(cAg) > 4
        Return ""
    EndIf
    cAg := PadL(cAg, 4, "0")

    Do Case
        Case AllTrim(cBanco) == "341"
            If Len(cCc) > 5 .Or. Len(cCart) > 3 .Or. Len(cNN) > 8
                Return ""
            EndIf
            cCc   := PadL(cCc, 5, "0")
            cCart := PadL(cCart, 3, "0")
            cNN   := PadL(cNN, 8, "0")
            If cCart $ "107|122|142|143|196|198"
                Return ""
            EndIf
            If cCart $ "126|131|146|150|168"
                cDacNN := cValToChar(GcBoletoMod10(cCart + cNN))
            Else
                cDacNN := cValToChar(GcBoletoMod10(cAg + cCc + cCart + cNN))
            EndIf
            Return cCart + cNN + cDacNN + cAg + cCc + cValToChar(GcBoletoMod10(cAg + cCc)) + "000"
        Case AllTrim(cBanco) == "237"
            If Len(cCc) > 7 .Or. Len(cCart) > 2 .Or. Len(cNN) > 11
                Return ""
            EndIf
            Return cAg + PadL(cCart, 2, "0") + PadL(cNN, 11, "0") + PadL(cCc, 7, "0") + "0"
    EndCase
Return ""

/*/{Protheus.doc} GcBoletoCodigoBarras
    Codigo de barras (44 digitos): banco(3) moeda 9(1) DAC(1) fator(4)
    valor(10) campo livre(25).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cBanco, character, "341" ou "237"
    @param cAgencia, character, agencia
    @param cConta, character, conta corrente
    @param cCarteira, character, carteira
    @param cNossoNum, character, nosso numero sem digito
    @param dVenc, date, vencimento (obrigatorio)
    @param nValor, numeric, valor em reais (0 = valor em aberto)
    @return character, 44 digitos, ou "" se algum dado e invalido
*/
User Function GcBoletoCodigoBarras(cBanco, cAgencia, cConta, cCarteira, cNossoNum, dVenc, nValor)
    Local cLivre := GcBoletoCampoLivre(cBanco, cAgencia, cConta, cCarteira, cNossoNum) as character
    Local nFator := GcBoletoFatorVenc(dVenc) as numeric
    Local c43    := "" as character

    If Empty(cLivre) .Or. nFator == 0 .Or. ValType(nValor) != "N" .Or. nValor < 0 .Or. nValor > 99999999.99
        Return ""
    EndIf
    c43 := AllTrim(cBanco) + "9" + StrZero(nFator, 4) + StrZero(Round(nValor * 100, 0), 10) + cLivre
Return Left(c43, 4) + cValToChar(GcBoletoDacBarras(c43)) + SubStr(c43, 5)

/*/{Protheus.doc} GcBoletoLinhaDigitavel
    Linha digitavel: AAAAA.AAAAA BBBBB.BBBBBB CCCCC.CCCCCC D EEEEEEEEEEEEEE
    Campo 1 = banco+moeda+campo livre 1-5 + DV; campo 2 = campo livre 6-15
    + DV; campo 3 = campo livre 16-25 + DV (DVs modulo 10); campo 4 = DAC
    do codigo de barras; campo 5 = fator + valor.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cBanco, character, "341" ou "237"
    @param cAgencia, character, agencia
    @param cConta, character, conta corrente
    @param cCarteira, character, carteira
    @param cNossoNum, character, nosso numero sem digito
    @param dVenc, date, vencimento
    @param nValor, numeric, valor em reais
    @return character, linha digitavel, ou "" se algum dado e invalido
*/
User Function GcBoletoLinhaDigitavel(cBanco, cAgencia, cConta, cCarteira, cNossoNum, dVenc, nValor)
    Local cBarras := GcBoletoCodigoBarras(cBanco, cAgencia, cConta, cCarteira, cNossoNum, dVenc, nValor) as character
    Local cLivre  := "" as character
    Local cC1     := "" as character
    Local cC2     := "" as character
    Local cC3     := "" as character

    If Empty(cBarras)
        Return ""
    EndIf
    cLivre := SubStr(cBarras, 20, 25)
    cC1 := Left(cBarras, 4) + Left(cLivre, 5)
    cC1 += cValToChar(GcBoletoMod10(cC1))
    cC2 := SubStr(cLivre, 6, 10)
    cC2 += cValToChar(GcBoletoMod10(cC2))
    cC3 := SubStr(cLivre, 16, 10)
    cC3 += cValToChar(GcBoletoMod10(cC3))
Return Left(cC1, 5) + "." + SubStr(cC1, 6) + " " + ;
    Left(cC2, 5) + "." + SubStr(cC2, 6) + " " + ;
    Left(cC3, 5) + "." + SubStr(cC3, 6) + " " + ;
    SubStr(cBarras, 5, 1) + " " + SubStr(cBarras, 6, 14)

/*/{Protheus.doc} GcBoletoDataVenc
    Converte o vencimento gravado em COB_VENCTO ("AAAA-MM-DD", como o
    Fechamento grava, ou "AAAAMMDD") em data, recusando data inexistente.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cTexto, character, vencimento em texto
    @return date, a data, ou data vazia se invalida
*/
User Function GcBoletoDataVenc(cTexto)
    Local cData := StrTran(AllTrim(cTexto), "-", "") as character
    Local dData := CToD("") as date

    If Len(cData) != 8 .Or. Empty(Digitos(cData))
        Return CToD("")
    EndIf
    dData := SToD(cData)
    If DToS(dData) != cData
        Return CToD("")
    EndIf
Return dData

/*/{Protheus.doc} Digitos
    Devolve o texto sem espacos, ou "" se tiver algo que nao seja digito.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param cTexto, character, texto
    @return character, so digitos ou ""
*/
Static Function Digitos(cTexto)
    Local cRet := "" as character
    Local nI   := 0 as numeric

    If ValType(cTexto) != "C"
        Return ""
    EndIf
    cRet := AllTrim(cTexto)
    For nI := 1 To Len(cRet)
        If !(SubStr(cRet, nI, 1) $ "0123456789")
            Return ""
        EndIf
    Next nI
Return cRet

/*/{Protheus.doc} SemDigito
    Agencia/conta sem o digito verificador ("12345-7" -> "12345").
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param cTexto, character, agencia ou conta
    @return character, so os digitos antes do hifen, ou "" se invalido
*/
Static Function SemDigito(cTexto)
    Local cRet := "" as character

    If ValType(cTexto) != "C"
        Return ""
    EndIf
    cRet := AllTrim(cTexto)
    If "-" $ cRet
        cRet := Left(cRet, At("-", cRet) - 1)
    EndIf
Return Digitos(cRet)

/*/{Protheus.doc} GcBoletoConfigurar
    Tela de configuracao do beneficio para boletos.
    Salva configuracao no banco CFG_BOLETO.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcBoletoConfigurar()
    Local oDlg
    Local aCfg      := {}
    Local cBanco    := "237"
    Local cAgencia  := ""
    Local cConta    := ""
    Local cCobrta   := ""
    Local cCarteira := "09"
    Local lOk       := .F.

    // Pre-carrega a configuracao atual, se houver: a tela edita o que existe
    // em vez de comecar em branco toda vez.
    aCfg := TCSqlQuery("SELECT CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA " + ;
        "FROM CFG_BOLETO WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('CFG_BOLETO')) + "'")
    If Len(aCfg) > 0
        cBanco    := AllTrim(aCfg[1]["CFG_BANCO"])
        cAgencia  := AllTrim(aCfg[1]["CFG_AGENCIA"])
        cConta    := AllTrim(aCfg[1]["CFG_CONTA"])
        cCobrta   := AllTrim(aCfg[1]["CFG_COBRT"])
        cCarteira := AllTrim(aCfg[1]["CFG_CARTEIRA"])
    EndIf

    DEFINE MSDIALOG oDlg TITLE "Configuração de Boleto" FROM 0,0 TO 260,440 PIXEL

    @ 10, 10 SAY "Banco (341=Itaú, 237=Bradesco):" PIXEL
    @ 10,140 GET cBanco SIZE 50,10                            PIXEL
    @ 30, 10 SAY "Agência:"                        PIXEL
    @ 30,140 GET cAgencia SIZE 70,10                          PIXEL
    @ 50, 10 SAY "Conta corrente:"                 PIXEL
    @ 50,140 GET cConta SIZE 90,10                            PIXEL
    @ 70, 10 SAY "Cedente / Convênio:"             PIXEL
    @ 70,140 GET cCobrta SIZE 90,10                           PIXEL
    @ 90, 10 SAY "Carteira:"                       PIXEL
    @ 90,140 GET cCarteira SIZE 50,10                         PIXEL
    @125, 10 BUTTON "Confirmar" ACTION (lOk := .T.) SIZE 40,12 PIXEL
    @125,140 BUTTON "Cancelar"                      SIZE 40,12 PIXEL

    ACTIVATE MSDIALOG oDlg CENTERED

    If !lOk
        Return .F.
    EndIf

    cBanco    := AllTrim(cBanco)
    cAgencia  := AllTrim(cAgencia)
    cConta    := AllTrim(StrTran(cConta, "-", ""))
    cCobrta   := AllTrim(cCobrta)
    cCarteira := AllTrim(cCarteira)

    If Empty(cBanco) .Or. Empty(cAgencia) .Or. Empty(cConta)
        MsgAlert("Banco, agência e conta são obrigatórios.", "Configuração de Boleto")
        Return .F.
    EndIf

    If cBanco != "341" .And. cBanco != "237"
        MsgAlert("Apenas Itaú (341) e Bradesco (237) têm fórmula implementada.", "Configuração de Boleto")
        Return .F.
    EndIf
    // Confere o layout do banco com um nosso numero de teste: agencia ate
    // 4 digitos; Itau conta ate 5 e carteira ate 3 (exceto as de 15
    // posicoes); Bradesco conta ate 7 e carteira ate 2.
    If Empty(GcBoletoCampoLivre(cBanco, cAgencia, cConta, cCarteira, "1"))
        MsgAlert("Agência, conta ou carteira fora do layout do banco " + cBanco + ;
            ". Itaú: agência até 4 dígitos, conta até 5, carteira até 3 (107, 122, 142, 143, 196 e 198 não são suportadas). " + ;
            "Bradesco: agência até 4 dígitos, conta até 7, carteira até 2.", "Configuração de Boleto")
        Return .F.
    EndIf

    // Snapshot: uma configuracao por vez, entao limpa tudo antes de gravar
    TCSqlExec("DELETE FROM CFG_BOLETO WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('CFG_BOLETO')) + "'")
    TCSqlExec("INSERT INTO CFG_BOLETO (CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA, FILIAL) VALUES (" + ;
        "'" + GcSqlLit(cBanco) + "', '" + GcSqlLit(cAgencia) + "', '" + GcSqlLit(cConta) + "', " + ;
        "'" + GcSqlLit(cCobrta) + "', '" + GcSqlLit(cCarteira) + "', '" + GcSqlLit(FWxFilial('CFG_BOLETO')) + "')")

    MsgInfo("Configuração de boleto salva.", "Configuração de Boleto")
Return .T.


/*/{Protheus.doc} GcBoletoDados
    Monta o boleto de uma cobrança do condomínio da sessão, sem diálogo.
    O nosso número é o R_E_C_N_O_ da cobrança (único e estável). Com
    cUnidade, só aceita cobrança dessa unidade (portal do condômino).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param nRecno, numeric, R_E_C_N_O_ da cobrança em COB
    @param cUnidade, character, (opcional) unidade a que a cobrança tem de pertencer
    @return array, {lOk, cMensagem, cLinha, cCodBarras, dVenc, nValor, cCompetencia}
*/
User Function GcBoletoDados(nRecno, cUnidade)
    Local aCob   := {} as array
    Local aCfg   := {} as array
    Local nValor := 0 as numeric
    Local dVenc  := CToD("") as date
    Local cBanco := "" as character
    Local cLinha := "" as character
    Local cBarra := "" as character
    Local cUni   := "" as character

    If ValType(nRecno) != "N" .Or. nRecno <= 0
        Return {.F., "Cobrança não encontrada.", "", "", dVenc, 0, ""}
    EndIf
    If ValType(cUnidade) == "C" .And. !Empty(cUnidade)
        cUni := " AND COB_UNIDADE = '" + GcSqlLit(cUnidade) + "'"
    EndIf
    aCob := TCSqlQuery("SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS FROM COB WHERE R_E_C_N_O_ = " + ;
        cValToChar(Int(nRecno)) + cUni + " AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
    If Len(aCob) == 0
        Return {.F., "Cobrança não encontrada.", "", "", dVenc, 0, ""}
    EndIf
    If AllTrim(aCob[1]["COB_STATUS"]) == "pago"
        Return {.F., "Esta cobrança já está paga.", "", "", dVenc, 0, ""}
    EndIf
    nValor := Val(aCob[1]["COB_VALOR"])
    dVenc  := GcBoletoDataVenc(aCob[1]["COB_VENCTO"])
    If nValor <= 0 .Or. Empty(dVenc)
        Return {.F., "Cobrança sem valor ou sem vencimento válido.", "", "", dVenc, nValor, ""}
    EndIf
    aCfg := TCSqlQuery("SELECT CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_CARTEIRA FROM CFG_BOLETO " + ;
        "WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('CFG_BOLETO')) + "'")
    If Len(aCfg) == 0
        Return {.F., "Dados bancários do boleto não configurados neste condomínio.", "", "", dVenc, nValor, ""}
    EndIf
    cBanco := AllTrim(aCfg[1]["CFG_BANCO"])
    cLinha := GcBoletoLinhaDigitavel(cBanco, aCfg[1]["CFG_AGENCIA"], aCfg[1]["CFG_CONTA"], ;
        aCfg[1]["CFG_CARTEIRA"], cValToChar(Int(nRecno)), dVenc, nValor)
    cBarra := GcBoletoCodigoBarras(cBanco, aCfg[1]["CFG_AGENCIA"], aCfg[1]["CFG_CONTA"], ;
        aCfg[1]["CFG_CARTEIRA"], cValToChar(Int(nRecno)), dVenc, nValor)
    If Empty(cLinha)
        Return {.F., "Não foi possível montar o boleto: confira banco, agência, conta e carteira.", "", "", dVenc, nValor, ""}
    EndIf
Return {.T., "", cLinha, cBarra, dVenc, nValor, AllTrim(aCob[1]["COB_COMPET"])}

/*/{Protheus.doc} GcBoletoGera
    Gera o boleto de uma cobranca: le COB e CFG_BOLETO e mostra a linha
    digitavel e o codigo de barras. O nosso numero e o R_E_C_N_O_ da
    cobranca (unico e estavel no condominio).
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param nRecno, numeric, numero do registro na tabela COB
    @return logical, .T. se gerou
*/
User Function GcBoletoGera(nRecno)
    Local aB := GcBoletoDados(nRecno) as array

    If !aB[1]
        MsgStop(aB[2], "Gerar Boleto")
        Return .F.
    EndIf
    MsgInfo("Linha digitável:" + Chr(10) + aB[3] + Chr(10) + ;
        Chr(10) + "Código de barras:" + Chr(10) + aB[4] + Chr(10) + ;
        Chr(10) + "Vencimento: " + DToC(aB[5]) + "   Valor: R$ " + AllTrim(Transform(aB[6], "@E 999,999,999.99")), ;
        "Boleto — " + aB[7])
Return .T.
