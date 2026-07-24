// src/fechamento.prw — fechamento mensal: soma as despesas da competência,
// rateia por fração ideal de cada unidade ativa, grava uma Cobrança por
// unidade. Trava contra fechar a mesma competência duas vezes (checa se já
// existe Cobrança pra essa competência antes de gerar) — ver decisão
// registrada na spec: valor travado no fechamento, nunca recalculado
// retroativamente.
#include "totvs.ch"
#include "db.prw"

/*/{Protheus.doc} GcFecharMes
    Fecha uma competência: soma as despesas, rateia por fração ideal de
    cada unidade ativa e grava uma Cobrança por unidade. Trava contra
    fechar a mesma competência duas vezes.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, competência "YYYY-MM" a fechar
    @return lOk, logical, .T. se fechou; .F. se já estava fechada ou
        não há unidade cadastrada
*/
User Function GcFecharMes(cCompetencia)
    Local nTotalDespesas := 0
    Local aExistente := TCSqlQuery("SELECT COB_UNIDADE FROM COB WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' '")
    If Len(aExistente) > 0
        ConOut("GcFecharMes: competência " + cCompetencia + " já foi fechada")
        Return .F.
    EndIf

    Local aDespesas := TCSqlQuery("SELECT COALESCE(SUM(DES_VALOR),0) AS TOTAL FROM DES WHERE DES_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' '")
    nTotalDespesas := Val(aDespesas[1]:TOTAL)
    If nTotalDespesas == 0
        ConOut("GcFecharMes: aviso — competência " + cCompetencia + " não tem nenhuma despesa lançada, fechando mesmo assim")
    EndIf

    Local aUnidades := TCSqlQuery("SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' '")
    If Len(aUnidades) == 0
        ConOut("GcFecharMes: nenhuma unidade cadastrada")
        Return .F.
    EndIf

    Local nSomaFracoes := 0
    Local j
    For j := 1 To Len(aUnidades)
        nSomaFracoes += Val(aUnidades[j]:UNI_FRACAO)
    Next
    If nSomaFracoes < 0.999 .Or. nSomaFracoes > 1.001
        ConOut("GcFecharMes: aviso — soma das frações ideais das unidades ativas é " + cValToChar(nSomaFracoes) + ", não 1.0 (100%)")
    EndIf

    Local cVencimento := GcProximoVencimento(cCompetencia)
    Local i
    For i := 1 To Len(aUnidades)
        Local nValorUnidade := nTotalDespesas * Val(aUnidades[i]:UNI_FRACAO)
        TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('" + ;
            GcSqlLit(aUnidades[i]:UNI_CODIGO) + "', '" + GcSqlLit(cCompetencia) + "', " + ;
            cValToChar(nValorUnidade) + ", '" + cVencimento + "', 'pendente')")
    Next
Return .T.

/*/{Protheus.doc} GcProximoVencimento
    Calcula o dia 10 do mês seguinte à competência informada. Dia fixo
    nesta v1 — configurável fica pra uma fase futura se necessário.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, competência "YYYY-MM"
    @return cVencimento, character, data "YYYY-MM-DD" do mês seguinte
*/
User Function GcProximoVencimento(cCompetencia)
    Local nAno := Val(Left(cCompetencia, 4))
    Local nMes := Val(SubStr(cCompetencia, 6, 2))
    nMes++
    If nMes > 12
        nMes := 1
        nAno++
    EndIf
Return StrZero(nAno, 4) + "-" + StrZero(nMes, 2) + "-10"
