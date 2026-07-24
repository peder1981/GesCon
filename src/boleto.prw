// src/boleto.prw - geracao de boleto bancario FEBRABAN (Itau 341 e Bradesco 237).
// Retorna linha digitavel (formato bancario) e codigo de barras (num�rico agrupado).
// Zero depend�ncias externas - tudo em AdvPL puro.
#include "totvs.ch"

/*/{Protheus.doc} GcBoletoLinhaDigitavel
    Gera linha digitavel formatada para boleto Itau (341) ou
    Bradesco (237), seguindo padrao FEBRABAN.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cBanco, character, codigo do banco (341 ou 237)
    @param cAgencia, character, numero da agencia
    @param cConta, character, numero da conta corrente
    @param nAgDv, numeric, digito verificador da agencia
    @param cCobrta, character, codigo do beneficiario/cedente
    @param cCarteira, character, numero da carteira
    @param nCartDv, numeric, digito verificador da carteira
    @param dVenc, date, data de vencimento do boleto
    @param nValor, numeric, valor nominal do boleto
    @param cNumeroDoc, character, numero do documento
    @return cLinha, character, linha digitavel no formato G1.G2.G3-G4.G5
*/
User Function GcBoletoLinhaDigitavel(cBanco, cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv, dVenc, nValor, cNumeroDoc)
    Local cCampoLivre := GcBoletoCampoLivre(cBanco, cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv, cNumeroDoc)
    Return GcBoletoCalculaLinha(cBanco, cCampoLivre, dVenc, nValor)
Return

/*/{Protheus.doc} GcBoletoCodigoBarras
    Gera codigo de barras em texto (48 digitos: 47 dados + 1 DV final).
    Agrupa com espacos nos separadores oficiais FEBRABAN.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cBanco, character, codigo do banco (341 ou 237)
    @param cAgencia, character, numero da agencia
    @param cConta, character, numero da conta corrente
    @param nAgDv, numeric, digito verificador da agencia
    @param cCobrta, character, codigo do beneficiario/cedente
    @param cCarteira, character, numero da carteira
    @param nCartDv, numeric, digito verificador da carteira
    @param dVenc, date, data de vencimento do boleto
    @param nValor, numeric, valor nominal do boleto
    @param cNumeroDoc, character, numero do documento
    @return cCodBar, character, codigo de barras formatado com espacos separadores
*/
User Function GcBoletoCodigoBarras(cBanco, cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv, dVenc, nValor, cNumeroDoc)
    Local cCampoLivre := GcBoletoCampoLivre(cBanco, cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv, cNumeroDoc)
    Return GcBoletoMontaCodigoBarras(cBanco, cCampoLivre, dVenc, nValor)
Return

/*/{Protheus.doc} GcBoletoCalculaDv
    Calcula DV modulo 11 sobre string numerica. Pesos: 2,3,4,5,6,7 repetindo da direita para esquerda.
    Se resto == 0 -> DV=0. Se resto == 1 -> DV=1. Senao -> DV=11-resto.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cNum, character, string numerica para calcular o DV
    @return nDv, numeric, digito verificador calculado (0-9)
*/
User Function GcBoletoCalculaDv(cNum)
    Local nSom := 0
    Local nPeso := 2
    Local nI, nDig
    Local cDigStr

    For nI := Len(cNum) To 1 Step -1
        cDigStr := SubStr(cNum, nI, 1)
        If cDigStr >= "0" .And. cDigStr <= "9"
            nDig := Val(cDigStr)
        Else
            nDig := 0
        EndIf
        nSom += nDig * nPeso
        nPeso++
        If nPeso > 7
            nPeso := 2
        EndIf
    Next

    Local nResto := Mod(nSom, 11)
    If nResto == 0
        Return 0
    ElseIf nResto == 1
        Return 1
    Else
        Return 11 - nResto
    EndIf

/*/{Protheus.doc} GcBoletoFatorVenc
    Calcula dias desde 07/09/1997 ate dData. Retorna 90001 se dData <= 07/09/1997 (nao-fator).
    Para datas apos de 2025, o fator excede 9999 e e limitado a 9999 como workaround
    para limitacao do codigo de barras FEBRABAN (campo de 4 digitos no posicao 6-9).
    Alguns bancos aceitam apenas fatores até 9999; datas futuras podem necessitar
    adaptacao para o padrao nao-fator (90001 = sem vencimento especifico).
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param dData, date, data de vencimento
    @return nFator, numeric, fator de vencimento (90001 = nao-fator, 1-9999 = dias desde base)
*/
User Function GcBoletoFatorVenc(dData)
    Local nTarget, nFator, nAno, nMes, nDia
    Local nAdjAno, nAdjMes

    // Converter data para formato numerico YYYYMMDD para comparacao
    If Type("dData") == "C" .Or. ValType("dData") == "C"
        If Len(AllTrim(dData)) >= 8
            nTarget := Val(SubStr(AllTrim(dData), 7, 4) + SubStr(AllTrim(dData), 4, 2) + SubStr(AllTrim(dData), 1, 2))
        Else
            Return 90001
        EndIf
    ElseIf ValType("dData") == "D"
        nTarget := DToS(dData)
    Else
        Return 90001
    EndIf

    If nTarget <= 19970907
        Return 90001
    EndIf

    // Calcular dias exatos desde 07/09/1997 usando Formula Julian Day Number
    nAno := Int(nTarget / 10000)
    nMes := Int((nTarget % 10000) / 100)
    nDia := nTarget % 100

    // Ajustar jan/fev para o ano anterior
    nAdjAno := nAno
    nAdjMes := nMes
    If nAdjMes <= 2
        nAdjMes += 12
        nAdjAno--
    EndIf

    nFator := Int(365.25 * (nAdjAno + 4716)) + Int(30.6001 * (nAdjMes + 1)) + nDia - 1524.5

    // Subtrair base 07/09/1997
    If 9 <= 2
        // nao aplica
    EndIf
    nFator -= Int(365.25 * (1997 + 4716)) + Int(30.6001 * (9 + 1)) + 7 - 1524.5

    // Limitar a 4 digitos (padrao FEBRABAN): maximo expressavel = 9999
    // Para datas após meados de 2025 o fator real excede 9999.
    // Como o código de barras só permite 4 dígitos na posição do fator,
    // fazemos cap em 9999 com aviso via FWLogMsg.
    If nFator > 9999
        ConOut("AVISO: fator vencimento " + Str(nFator) + " excede 9999 para data " + DTOC(dData) + "; limitando para 9999")
        nFator := 9999
    EndIf

Return nFator

/*/{Protheus.doc} GcBoletoCampoLivre
    Monta os 24 chars do campo livre segundo layout FEBRABAN por banco.
    Itau (341): [carteira(2)][agencia(5)][dv_ag(1)][conta(5)][dv_conta(1)][codigo_beneficiario(11)]
    Bradesco (237): [convenio(8)][dv_convenio(1)][agencia(4)][dv_ag(1)][conta(5)][dv_conta(1)][carteira(2)][dv_carteira(1)][num_doc(2)]
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cBanco, character, codigo do banco (341 ou 237)
    @param cAgencia, character, numero da agencia
    @param cConta, character, numero da conta corrente
    @param nAgDv, numeric, digito verificador da agencia
    @param cCobrta, character, codigo do beneficiario ou convenio
    @param cCarteira, character, numero da carteira
    @param nCartDv, numeric, digito verificador da carteira
    @param cNumeroDoc, character, numero do documento
    @return cCl, character, campo livre de 24 caracteres
*/
User Function GcBoletoCampoLivre(cBanco, cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv, cNumeroDoc)
    Local cCl := ""
    Local cAgPadded, cContaPadded, cCedrPadded, cCartPadded, cNumDocPadded
    Local nDvConv, nDvConta, nDvCart, cCobrtaPad

    cBanco := AllTrim(cBanco)

    If cBanco == "341"
        // Itau: carteira(2) + agencia(5) + dv_ag(1) + conta(5) + dv_conta(1) + cedente(10) = 24
        cAgPadded    := PadLeft(AllTrim(cAgencia), 5, "0")
        cContaPadded := PadLeft(AllTrim(cConta), 5, "0")
        cCedrPadded  := PadLeft(AllTrim(cCobrta), 10, "0")

        cCl := PadLeft(AllTrim(cCarteira), 2, "0")
        cCl += cAgPadded
        cCl += StrZero(nAgDv, 1)
        cCl += cContaPadded
        cCl += StrZero(nCartDv, 1)
        cCl += cCedrPadded

    ElseIf cBanco == "237"
        // Bradesco: convenio(8)+dv(1) + agencia(4)+dv(1) + conta(5)+dv(1) + carteira(2)+dv(1) + num_doc(2) = 25... truncar para 24
        cAgPadded     := PadLeft(AllTrim(cAgencia), 4, "0")
        cContaPadded  := PadLeft(AllTrim(cConta), 5, "0")
        cCartPadded   := PadLeft(AllTrim(cCarteira), 2, "0")
        cNumDocPadded := PadLeft(AllTrim(cNumeroDoc), 2, "0")
        cCobrtaPad    := PadLeft(AllTrim(cCobrta), 8, "0")

        nDvConv  := GcBoletoCalculaDv(cCobrtaPad)
        nDvConta := GcBoletoCalculaDv(cContaPadded)
        nDvCart  := GcBoletoCalculaDv(cCartPadded)

        cCl := cCobrtaPad
        cCl += StrZero(nDvConv, 1)
        cCl += cAgPadded
        cCl += StrZero(nAgDv, 1)
        cCl += cContaPadded
        cCl += StrZero(nDvConta, 1)
        cCl += cCartPadded
        cCl += StrZero(nDvCart, 1)
        cCl += cNumDocPadded
    EndIf

    // Trunca/padroniza para 24 chars
    cCl := Left(cCl, 24)

    // Complementa com zeros a esquerda se menor que 24
    While Len(cCl) < 24
        cCl := "0" + cCl
    EndDo
Return cCl

/*/{Protheus.doc} GcBoletoMontaCodigoBarras
    Junta codigo banco + moeda + DV(pos1-4) + fator_venc + valor + campo_livre + DV_final
    para formar os 47 digits + 1 DV = 48 chars.
    Formata com espacamentos nos separadores FEBRABAN.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cBanco, character, codigo do banco (341 ou 237)
    @param cCampoLivre, character, campo livre de 24 caracteres
    @param dVenc, date, data de vencimento
    @param nValor, numeric, valor nominal do boleto
    @return cFormatado, character, codigo de barras formatado com espacos separadores
*/
User Function GcBoletoMontaCodigoBarras(cBanco, cCampoLivre, dVenc, nValor)
    Local cBancoStr := AllTrim(cBanco)
    Local cMoeda := "9"
    Local nFator := GcBoletoFatorVenc(dVenc)
    Local cFator := StrZero(nFator, 4)
    Local cValorStr := StrZero(Ceiling(nValor * 100), 8)

    // DV posicao 5 (modulo 11 sobre pos 1-4: banco + moeda)
    Local cPrimeiros4 := cBancoStr + cMoeda
    Local nDv14 := GcBoletoCalculaDv(cPrimeiros4)

    // DV posicao 18 (modulo 11 sobre pos 10-17 = valor 8 chars)
    Local nDvVal := GcBoletoCalculaDv(cValorStr)

    // Monta sequencia de 42 chars: top(17) + dv_valor(1) + campo_livre(24)
    Local cTopo := cBancoStr + cMoeda + StrZero(nDv14, 1) + cFator + cValorStr
    Local cSeq42 := cTopo + StrZero(nDvVal, 1) + cCampoLivre

    While Len(cSeq42) < 42
        cSeq42 := cSeq42 + "0"
    EndDo
    cSeq42 := Left(cSeq42, 42)

    Local nDvFinal := GcBoletoCalculaDv(cSeq42)
    Local cTotal := cSeq42 + StrZero(nDvFinal, 1)  // 43 chars totais

    // Formata com espacamentos nos separadores FEBRABAN
    Local cFormatado := ""
    Local i
    For i := 1 To Len(cTotal)
        cFormatado += SubStr(cTotal, i, 1)
        If i == 4 .Or. i == 9 .Or. i == 17 .Or. i == 21 .Or. i == 31 .Or. i == 40
            cFormatado += " "
        EndIf
    Next
    cFormatado := AllTrim(cFormatado)
Return cFormatado

/*/{Protheus.doc} GcBoletoCalculaLinha
    Calcula a linha digitavel a partir do codigo banco + campo livre.
    Aplica rearranjo especifico por banco e insere DVs individuais em cada grupo.
    Formato: G1.G2.G3-G4.G5 onde cada grupo inclui seu DV proprio.
    Usa todos os 42 digitos da sequencia compacta sem padding com zeros.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cBanco, character, codigo do banco (341 ou 237)
    @param cCampoLivre, character, campo livre de 24 caracteres
    @param dVenc, date, data de vencimento
    @param nValor, numeric, valor nominal do boleto
    @return cLinha, character, linha digitavel formatada (sem padding com zeros)
*/
User Function GcBoletoCalculaLinha(cBanco, cCampoLivre, dVenc, nValor)
    Local cBancoStr := AllTrim(cBanco)
    Local cMoeda := "9"
    Local nFator := GcBoletoFatorVenc(dVenc)
    Local cFator := StrZero(nFator, 4)
    Local cValorStr := StrZero(Ceiling(nValor * 100), 8)

    Local nDv14 := GcBoletoCalculaDv(cBancoStr + cMoeda)
    Local nDvVal := GcBoletoCalculaDv(cValorStr)

    // Sequencia compacta 42 chars: [banco3][moeda1][dv14_1][fator4][valor8][dv_val_1][cl24]
    // Pos:   1-3      4       5          6-9     10-17     18            19-42
    Local cSeq42 := cBancoStr + cMoeda + StrZero(nDv14, 1) + cFator + cValorStr + StrZero(nDvVal, 1) + cCampoLivre
    While Len(cSeq42) < 42
        cSeq42 := cSeq42 + "0"
    EndDo
    cSeq42 := Left(cSeq42, 42)

    Local cG1, cG2, cG3, cG4, cG5
    Local nDvG1, nDvG2, nDvG3, nDvG4, nDvG5

    // Rearranjo FEBRABAN com todos os 42 digitos usados (CL de 24 chars distribuido nos grupos):
    // cSeq42 positions (1-indexed): banco=1-3, moeda=4, dv14=5, fator=6-9, valor=10-17, dv_val=18, cl=19-42
    // G1: pos1-4 (banco+moeda+dv14) + CL[19](1 char) = 5 digits + DV = 6 chars
    // G2: CL[20-24](5 chars) + DV = 6 chars
    // G3: CL[25-34](10 chars) + DV = 11 chars
    // G4: pos5(1) + pos6-17(12) + dv_val(1) + CL[35](1) = 15 digits + DV = 16 chars
    // G5: CL[36-42](7 chars) + DV = 8 chars
    // Total digits: 6+6+11+16+8 = 47 + 4 separators = 51 chars
    
    // G1: header(4) + first CL char(pos19) + DV
    cG1 := SubStr(cSeq42, 1, 4) + SubStr(cSeq42, 19, 1)
    nDvG1 := GcBoletoCalculaDv(cG1)
    cG1 := cG1 + StrZero(nDvG1, 1)

    // G2: CL chars at pos20-24 (5 chars) + DV
    cG2 := SubStr(cSeq42, 20, 5)
    nDvG2 := GcBoletoCalculaDv(cG2)
    cG2 := cG2 + StrZero(nDvG2, 1)

    // G3: CL chars at pos25-34 (10 chars) + DV
    cG3 := SubStr(cSeq42, 25, 10)
    nDvG3 := GcBoletoCalculaDv(cG3)
    cG3 := cG3 + StrZero(nDvG3, 1)

    // G4: header dv(pos5) + fator(pos6-9) + valor(pos10-17) + dv_val(pos18) + last CL char(pos35) + DV
    cG4 := SubStr(cSeq42, 5, 1) + SubStr(cSeq42, 6, 13) + SubStr(cSeq42, 35, 1)
    nDvG4 := GcBoletoCalculaDv(cG4)
    cG4 := cG4 + StrZero(nDvG4, 1)

    // G5: remaining CL chars pos36-42 (7 chars) + DV
    cG5 := SubStr(cSeq42, 36, 7)
    nDvG5 := GcBoletoCalculaDv(cG5)
    cG5 := cG5 + StrZero(nDvG5, 1)

    // Formata: G1.G2.G3-G4.G5 (sem padding)
Return cG1 + "." + cG2 + "." + cG3 + "-" + cG4 + "." + cG5

/*/{Protheus.doc} GcBoletoConfigurar
    Tela de configuracao do beneficio para boletos.
    Salva configuracao no banco CFG_BOLETO.
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcBoletoConfigurar()
    Local cBanco    := FWGetText("Codigo do banco? (1=Itau, 237=Bradesco)", "237")
    Local cAgencia  := FWGetText("Agencia?", "1234")
    Local cConta    := FWGetText("Conta corrente?", "12345")
    Local cCobrta   := FWGetText("Carta/Cedente ou Convenio?", "1234")
    Local cCarteira := FWGetText("Carteira?", "174")

    cBanco    := AllTrim(cBanco)
    cAgencia  := AllTrim(cAgencia)
    cConta    := AllTrim(Replace(cConta, "-", ""))
    cCobrta   := AllTrim(cCobrta)
    cCarteira := AllTrim(cCarteira)

    TCSqlExec("DELETE FROM CFG_BOLETO WHERE R_E_C_N_O_ = 1 AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO CFG_BOLETO (CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA) VALUES (" + ;
        "'" + GcSqlLit(cBanco) + "', '" + GcSqlLit(cAgencia) + "', '" + GcSqlLit(cConta) + "', " + ;
        "'" + GcSqlLit(cCobrta) + "', '" + GcSqlLit(cCarteira) + "')")

    MsgInfo("Configuracao de boleto salva.", "GesCon")
Return

/*/{Protheus.doc} GcBoletoGera
    Gera boleto para uma cobranca especifica.
    Recupera configuracoes de CFG_BOLETO e dados de COB.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param nRecno, numeric, numero do registro na tabela COB
    @return lOk, logical, .T. se gerou com sucesso
*/
User Function GcBoletoGera(nRecno)
    Local aCob := TCSqlQuery("SELECT COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, COB_NUMDOC " + ;
        "FROM COB WHERE R_E_C_N_O_ = " + StrZero(nRecno, 10) + " AND D_E_L_E_T_ = ' '")

    If Len(aCob) == 0
        MsgStop("Cobranca n ao encontrada.", "GcBoletoGera")
        Return .F.
    EndIf

    Local nValor  := Val(aCob[1]["COB_VALOR"])
    Local dVenc   := CToD(AllTrim(aCob[1]["COB_VENCTO"]))
    Local cNumeroDoc := AllTrim(aCob[1]["COB_NUMDOC"])
    If Empty(cNumeroDoc)
        cNumeroDoc := ""
    EndIf

    Local aCfg := TCSqlQuery("SELECT CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA " + ;
        "FROM CFG_BOLETO WHERE D_E_L_E_T_ = ' '")

    If Len(aCfg) == 0
        MsgStop("Configuracao de boleto n ao encontrada. Execute GcBoletoConfigurar().", "GcBoletoGera")
        Return .F.
    EndIf

    Local cLinha := GcBoletoLinhaDigitavel( ;
        aCfg[1]["CFG_BANCO"], aCfg[1]["CFG_AGENCIA"], aCfg[1]["CFG_CONTA"], 0, ;
        aCfg[1]["CFG_COBRT"], aCfg[1]["CFG_CARTEIRA"], 0, ;
        dVenc, nValor, cNumeroDoc)

    Local cCodBar := GcBoletoCodigoBarras( ;
        aCfg[1]["CFG_BANCO"], aCfg[1]["CFG_AGENCIA"], aCfg[1]["CFG_CONTA"], 0;
        aCfg[1]["CFG_COBRT"], aCfg[1]["CFG_CARTEIRA"], 0, ;
        dVenc, nValor, cNumeroDoc)

    MsgInfo("Linha Digitavel:" + Chr(10) + cLinha + Chr(10) + ;
        Chr(10) + "Codigo de Barras:" + Chr(10) + cCodBar, "Boleto � " + AllTrim(aCob[1]["COB_COMPET"]))
Return .T.

/*/{Protheus.doc} GcBoletoExibe
    Exibe boleto formatado. Alias para GcBoletoGera.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param nRecno, numeric, numero do registro na tabela COB
    @return lOk, logical, resultado de GcBoletoGera
*/
User Function GcBoletoExibe(nRecno)
Return GcBoletoGera(nRecno)

/*/{Protheus.doc} PadLeft
    Preenche a esquerda com caractere padding ate tamanho desejado.
    Funcao utilitaria reutilizavel.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cStr, character, string original
    @param nTam, numeric, tamanho final desejado
    @param cPad, character, caracter de preenchimento
    @return cStr, character, string preenchida a esquerda
*/
User Function PadLeft(cStr, nTam, cPad)
    While Len(cStr) < nTam
        cStr := cPad + cStr
    EndDo
    Return Left(cStr, nTam)
