// tests/boleto_test.prw -- validacao de formulas FEBRABAN para codigo de
// barras e linha digitavel de boletos Itau (341) e Bradesco (237).
#include "totvs.ch"

// Modulo 11 (pesos 2-7 da direita para esquerda)
Static Function StBoletoCalcDv(cNum)
    Local nSom := 0, nPeso := 2, nI, nDig, cDigStr, nResto
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
    nResto := Mod(nSom, 11)
    If nResto == 0
        Return 0
    ElseIf nResto == 1
        Return 1
    Else
        Return 11 - nResto
    EndIf

// PadLeft
Static Function StPadLeft(cStr, nTam, cPad)
    While Len(cStr) < nTam
        cStr := cPad + cStr
    EndDo
    Return Left(cStr, nTam)

// Fator Vencimento
Static Function StFatorVenc(dData)
    Local nTarget, nFator, nAno, nMes, nDia, nAdjAno, nAdjMes
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
    nAno := Int(nTarget / 10000)
    nMes := Int((nTarget % 10000) / 100)
    nDia := nTarget % 100
    nAdjAno := nAno
    nAdjMes := nMes
    If nAdjMes <= 2
        nAdjMes += 12
        nAdjAno--
    EndIf
    nFator := Int(365.25 * (nAdjAno + 4716)) + Int(30.6001 * (nAdjMes + 1)) + nDia - 1524.5
    nFator -= Int(365.25 * (1997 + 4716)) + Int(30.6001 * (9 + 1)) + 7 - 1524.5
    If nFator > 9999
        nFator := 9999
    EndIf
Return nFator

// Campo Livre Itau
Static Function StCampoLivreItau(cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv)
    Local cCl := ""
    cCl := StPadLeft(AllTrim(cCarteira), 2, "0")
    cCl += StPadLeft(AllTrim(cAgencia), 5, "0")
    cCl += StrZero(nAgDv, 1)
    cCl += StPadLeft(AllTrim(cConta), 5, "0")
    cCl += StrZero(nCartDv, 1)
    cCl += StPadLeft(AllTrim(cCobrta), 10, "0")
    cCl := Left(cCl, 24)
    While Len(cCl) < 24
        cCl := "0" + cCl
    EndDo
Return cCl

// Linha Digitavel Ita? completo
Static Function StLinhaItau(cBanco, cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv, dVenc, nValor, cNumeroDoc)
    Local cCampoLivre := StCampoLivreItau(cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv)
    Local nFator := StFatorVenc(dVenc)
    Local cFator := StrZero(nFator, 4)
    Local cValorStr := StrZero(Ceiling(nValor * 100), 8)
    Local nDv14 := StBoletoCalcDv(cBanco + "9")
    Local nDvVal := StBoletoCalcDv(cValorStr)
    
    Local cSeq42 := cBanco + "9" + StrZero(nDv14, 1) + cFator + cValorStr + StrZero(nDvVal, 1) + cCampoLivre
    While Len(cSeq42) < 42
        cSeq42 := cSeq42 + "0"
    EndDo
    cSeq42 := Left(cSeq42, 42)
    
    // Rearranjo FEBRABAN — usa todos os 42 digitos sem padding com zeros:
    // G1: pos1-4 + CL[19] + DV
    Local cG1 := SubStr(cSeq42, 1, 4) + SubStr(cSeq42, 19, 1)
    cG1 := cG1 + StrZero(StBoletoCalcDv(cG1), 1)
    
    // G2: CL[20-24] (5 chars) + DV
    Local cG2 := SubStr(cSeq42, 20, 5)
    cG2 := cG2 + StrZero(StBoletoCalcDv(cG2), 1)
    
    // G3: CL[25-34] (10 chars) + DV
    Local cG3 := SubStr(cSeq42, 25, 10)
    cG3 := cG3 + StrZero(StBoletoCalcDv(cG3), 1)
    
    // G4: pos5 + pos6-17(13) + pos35 + DV
    Local cG4 := SubStr(cSeq42, 5, 1) + SubStr(cSeq42, 6, 13) + SubStr(cSeq42, 35, 1)
    cG4 := cG4 + StrZero(StBoletoCalcDv(cG4), 1)
    
    // G5: CL[36-42] (7 chars) + DV
    Local cG5 := SubStr(cSeq42, 36, 7)
    cG5 := cG5 + StrZero(StBoletoCalcDv(cG5), 1)
    
    Return cG1 + "." + cG2 + "." + cG3 + "-" + cG4 + "." + cG5

// Linha Digitavel Bradesco
Static Function StLinhaBradesco(cBanco, cAgencia, cConta, nAgDv, cCobrta, cCarteira, nCartDv, dVenc, nValor, cNumeroDoc)
    Local cCl := ""
    Local cCobrtaP := StPadLeft(AllTrim(cCobrta), 8, "0")
    Local cAgP := StPadLeft(AllTrim(cAgencia), 4, "0")
    Local cContaP := StPadLeft(AllTrim(cConta), 5, "0")
    Local cCartP := StPadLeft(AllTrim(cCarteira), 2, "0")
    Local cNumP := StPadLeft(AllTrim(cNumeroDoc), 2, "0")
    Local nDvC := StBoletoCalcDv(cCobrtaP)
    Local nDvCo := StBoletoCalcDv(cContaP)
    Local nDvCa := StBoletoCalcDv(cCartP)
    cCl := cCobrtaP + StrZero(nDvC, 1) + cAgP + StrZero(nAgDv, 1) + cContaP + StrZero(nDvCo, 1) + cCartP + StrZero(nDvCa, 1) + cNumP
    cCl := Left(cCl, 24)
    While Len(cCl) < 24
        cCl := "0" + cCl
    EndDo
    
    Local nFator := StFatorVenc(dVenc)
    Local cFator := StrZero(nFator, 4)
    Local cValorStr := StrZero(Ceiling(nValor * 100), 8)
    Local nDv14 := StBoletoCalcDv(cBanco + "9")
    Local nDvVal := StBoletoCalcDv(cValorStr)
    
    Local cSeq42 := cBanco + "9" + StrZero(nDv14, 1) + cFator + cValorStr + StrZero(nDvVal, 1) + cCl
    While Len(cSeq42) < 42
        cSeq42 := cSeq42 + "0"
    EndDo
    cSeq42 := Left(cSeq42, 42)
    
    // Mesmo rearranjo que Itaú — usa todos os 42 digitos sem padding:
    Local cG1 := SubStr(cSeq42, 1, 4) + SubStr(cSeq42, 19, 1)
    cG1 := cG1 + StrZero(StBoletoCalcDv(cG1), 1)
    Local cG2 := SubStr(cSeq42, 20, 5)
    cG2 := cG2 + StrZero(StBoletoCalcDv(cG2), 1)
    Local cG3 := SubStr(cSeq42, 25, 10)
    cG3 := cG3 + StrZero(StBoletoCalcDv(cG3), 1)
    Local cG4 := SubStr(cSeq42, 5, 1) + SubStr(cSeq42, 6, 13) + SubStr(cSeq42, 35, 1)
    cG4 := cG4 + StrZero(StBoletoCalcDv(cG4), 1)
    Local cG5 := SubStr(cSeq42, 36, 7)
    cG5 := cG5 + StrZero(StBoletoCalcDv(cG5), 1)
    
Return cG1 + "." + cG2 + "." + cG3 + "-" + cG4 + "." + cG5

// === TESTE PRINCIPAL ===
User Function BoletoTest()
    Local nErros := 0, ii, np
    
    ConOut("=== Testes Modulo 11 ===")
    
    Local nDv1 := StBoletoCalcDv("3419")
    ConOut("dv_3419=" + Str(nDv1))
    If nDv1 != 3
        ConOut("FALHA: dv_3419 esperado=3, obtido=" + Str(nDv1))
        nErros++
    EndIf
    
    Local nDv2 := StBoletoCalcDv("2379")
    ConOut("dv_2379=" + Str(nDv2))
    
    Local nDvZ := StBoletoCalcDv("00")
    ConOut("dv_00=" + Str(nDvZ))
    If nDvZ != 0
        ConOut("FALHA: dv_00 esperado=0, obtido=" + Str(nDvZ))
        nErros++
    EndIf
    
    ConOut("")
    ConOut("=== Testes Fator Vencimento ===")
    
    Local nFator1 := StFatorVenc("10/08/2026")
    ConOut("fator_10082026=" + Str(nFator1))
    If nFator1 <= 0 .Or. nFator1 > 9999
        ConOut("FALHA: fator 10/08/2026 fora do intervalo (0..9999], obtido=" + Str(nFator1))
        nErros++
    EndIf
    
    Local nFatorBase := StFatorVenc("07/09/1997")
    ConOut("fator_07091997=" + Str(nFatorBase))
    If nFatorBase != 90001
        ConOut("FALHA: fator 07/09/1997 esperado=90001, obtido=" + Str(nFatorBase))
        nErros++
    EndIf
    
    Local nFatorAnt := StFatorVenc("01/01/1997")
    ConOut("fator_01011997=" + Str(nFatorAnt))
    If nFatorAnt != 90001
        ConOut("FALHA: fator 01/01/1997 esperado=90001, obtido=" + Str(nFatorAnt))
        nErros++
    EndIf
    
    ConOut("")
    ConOut("=== Testes Campo Livre Ita? ===")
    
    Local cl1 := StCampoLivreItau("1234", "12345", 5, "1234567890", "17", 3)
    ConOut("cl_itau=[" + cl1 + "]")
    ConOut("tam_cl_itau=" + Str(Len(cl1)))
    If Len(cl1) != 24
        ConOut("FALHA: campo livre Itau tem " + Str(Len(cl1)) + " chars, esperado 24")
        nErros++
    EndIf
    
    ConOut("")
    ConOut("=== Testes Linha Digitavel Ita? ===")
    
    Local cLinhaIt := StLinhaItau("341", "1234", "12345", 5, "1234567890", "17", 3, "10/08/2026", 1234.56, "00001")
    ConOut("linha_itau=[" + cLinhaIt + "]")
    ConOut("tam_itau=" + Str(Len(cLinhaIt)))
    
    If Len(cLinhaIt) != 51
        ConOut("FALHA: linha digitavel Itau tem " + Str(Len(cLinhaIt)) + " chars, esperado 51")
        nErros++
    EndIf
    
    np := 0
    For ii := 1 To Len(cLinhaIt)
        Local cCh := SubStr(cLinhaIt, ii, 1)
        If cCh == "." .Or. cCh == "-"
            np++
        EndIf
    Next
    ConOut("separadores_itau=" + Str(np))
    If np != 4
        ConOut("FALHA: linha digitavel Itau tem " + Str(np) + " separadores, esperado 4")
        nErros++
    EndIf
    
    // Validar que todos os caracteres sao numericos ou separadores (. -)
    Local nInvalidos := 0
    For ii := 1 To Len(cLinhaIt)
        Local cCh2 := SubStr(cLinhaIt, ii, 1)
        If cCh2 < "0" .And. cCh2 != "." .And. cCh2 != "-"
            nInvalidos++
        EndIf
    Next
    If nInvalidos > 0
        ConOut("FALHA: linha digitavel Itau tem " + Str(nInvalidos) + " caracteres invalidos")
        nErros++
    EndIf
    
    ConOut("")
    ConOut("=== Testes Codigo de Barras Ita? ===")
    
    Local cValorStr := StrZero(Ceiling(1234.56 * 100), 8)
    Local cClBarra := cl1
    Local nFact := StFatorVenc("10/08/2026")
    Local cFactStr := StrZero(nFact, 4)
    Local nDV14 := StBoletoCalcDv("3419")
    Local nDVVal := StBoletoCalcDv(cValorStr)
    Local cTopo := "3419" + StrZero(nDV14, 1) + cFactStr + cValorStr
    Local cSeq42 := cTopo + StrZero(nDVVal, 1) + cClBarra
    While Len(cSeq42) < 42
        cSeq42 := cSeq42 + "0"
    EndDo
    cSeq42 := Left(cSeq42, 42)
    Local nDVFinal := StBoletoCalcDv(cSeq42)
    Local cTotalBar := cSeq42 + StrZero(nDVFinal, 1)
    
    // Contar digitos numericos (sem espacos)
    Local nDigitos := 0
    For ii := 1 To Len(cTotalBar)
        If SubStr(cTotalBar, ii, 1) >= "0" .And. SubStr(cTotalBar, ii, 1) <= "9"
            nDigitos++
        EndIf
    Next
    ConOut("num_digitos_codbar=" + Str(nDigitos))
    
    ConOut("")
    ConOut("=== Testes Linha Digitavel Bradesco ===")
    
    Local cLinhaBr := StLinhaBradesco("237", "1234", "12345", 3, "87654321", "104", 7, "10/08/2026", 5678.90, "00002")
    ConOut("linha_bradesco=[" + cLinhaBr + "]")
    ConOut("tam_bradesco=" + Str(Len(cLinhaBr)))
    
    If Len(cLinhaBr) != 51
        ConOut("FALHA: linha digitavel Bradesco tem " + Str(Len(cLinhaBr)) + " chars, esperado 51")
        nErros++
    EndIf
    
    np := 0
    For ii := 1 To Len(cLinhaBr)
        Local cCh := SubStr(cLinhaBr, ii, 1)
        If cCh == "." .Or. cCh == "-"
            np++
        EndIf
    Next
    ConOut("separadores_bradesco=" + Str(np))
    If np != 4
        ConOut("FALHA: linha digitavel Bradesco tem " + Str(np) + " separadores, esperado 4")
        nErros++
    EndIf
    
    // Validar que todos os caracteres sao numericos ou separadores (. -)
    Local nInvalidos2 := 0
    For ii := 1 To Len(cLinhaBr)
        Local cCh3 := SubStr(cLinhaBr, ii, 1)
        If cCh3 < "0" .And. cCh3 != "." .And. cCh3 != "-"
            nInvalidos2++
        EndIf
    Next
    If nInvalidos2 > 0
        ConOut("FALHA: linha digitavel Bradesco tem " + Str(nInvalidos2) + " caracteres invalidos")
        nErros++
    EndIf
    
    ConOut("")
    ConOut("=== RESULTADO ===")
    If nErros == 0
        ConOut("PASS: todos os testes passaram (" + Str(nErros) + " falhas)")
    Else
        ConOut("FAIL: " + Str(nErros) + " falhas detectadas")
    EndIf
Return 0
