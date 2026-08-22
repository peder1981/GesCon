// src/fechamento.prw — fechamento mensal: soma as despesas da competência,
// rateia por fração ideal de cada unidade ativa, grava uma Cobrança por
// unidade. Trava contra fechar a mesma competência duas vezes (checa se já
// existe Cobrança pra essa competência antes de gerar) — ver decisão
// registrada na spec: valor travado no fechamento, nunca recalculado
// retroativamente.
//
// Ponte pra Contabilidade formal (apontada pelo Wilson Kraft em QA,
// 2026-08-21): se existir um EXERCICIO aberto com EXE_CODIGO igual à
// competência, este fechamento também grava LANCAMENTOS -- débito Despesa
// Comum(4000)/crédito Caixa(1000) por despesa, débito Contas a
// Receber(5000)/crédito Receita(3000) por unidade rateada -- no mesmo
// padrão que GcLancarDespesaContabil já usa pro lançamento avulso
// (src/contabil.prw). Sem exercício aberto pra competência, o fechamento
// segue gerando só as Cobranças, como sempre fez -- LANCAMENTOS tem FK
// obrigatória pra EXERCICIO, não dá pra gravar sem ele.
#include "totvs.ch"

/*/{Protheus.doc} GcFecharMes
    Fecha uma competência: soma as despesas, rateia por fração ideal de
    cada unidade ativa e grava uma Cobrança por unidade. Trava contra
    fechar a mesma competência duas vezes. Se existir um EXERCICIO aberto
    com EXE_CODIGO igual à competência, também grava os LANCAMENTOS
    correspondentes (despesa + rateio), alimentando o Balancete.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, competência "YYYY-MM" a fechar
    @param nDiaVencimento, numeric, dia do mês seguinte pro vencimento
        (1-28; fora dessa faixa ou não informado usa 10 — padrão que
        existe em todo mês, evitando datas inválidas em fevereiro)
    @return lOk, logical, .T. se fechou; .F. se já estava fechada ou
        não há unidade cadastrada
*/
User Function GcFecharMes(cCompetencia, nDiaVencimento)
    Local nTotalDespesas := 0
    Local aExistente := TCSqlQuery("SELECT COB_UNIDADE FROM COB WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
    If Len(aExistente) > 0
        ConOut("GcFecharMes: competência " + cCompetencia + " já foi fechada")
        Return .F.
    EndIf

    Local aDespesas := TCSqlQuery("SELECT COALESCE(SUM(DES_VALOR),0) AS TOTAL FROM DES WHERE DES_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "'")
    nTotalDespesas := Val(aDespesas[1]:TOTAL)
    If nTotalDespesas == 0
        ConOut("GcFecharMes: aviso — competência " + cCompetencia + " não tem nenhuma despesa lançada, fechando mesmo assim")
    EndIf

    Local aUnidades := TCSqlQuery("SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('UNI')) + "'")
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

    Local cVencimento := GcProximoVencimento(cCompetencia, nDiaVencimento)
    GcBackupBanco(cCompetencia) // ver src/db.prw — antes de gravar qualquer Cobrança

    // Ponte pra Contabilidade formal: só grava LANCAMENTOS se existir um
    // exercício aberto com EXE_CODIGO igual à competência (FK obrigatória).
    Local cDataLan := StrTran(cCompetencia, "-", "") + "01"
    Local aExercicio := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_CODIGO = '" + GcSqlLit(cCompetencia) + "' AND EXE_FECHADO = 0 AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('EXERCICIO')) + "'")
    Local lLancarContabil := (Len(aExercicio) > 0)

    If lLancarContabil
        Local aDespesasDet := TCSqlQuery("SELECT DES_DESCR, DES_VALOR FROM DES WHERE DES_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "'")
        Local k
        For k := 1 To Len(aDespesasDet)
            If Val(aDespesasDet[k]:DES_VALOR) > 0
                // Débito 4000 (Despesa Comum) / Crédito 1000 (Caixa) — mesmo padrão de GcLancarDespesaContabil
                TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_, FILIAL) VALUES ('" + ;
                    GcSqlLit(cDataLan) + "', '4000', '1000', " + cValToChar(Val(aDespesasDet[k]:DES_VALOR)) + ", '" + ;
                    GcSqlLit(aDespesasDet[k]:DES_DESCR) + "', 'AUTOMATICO_DESPESA', '" + GcSqlLit(cCompetencia) + "', datetime('now'), 'FECHAMENTO_MENSAL', ' ', " + ;
                    "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS), '" + GcSqlLit(FWxFilial('LANCAMENTOS')) + "')")
            EndIf
        Next
        ConOut("GcFecharMes: lançamentos contábeis gravados no exercício " + cCompetencia)
    Else
        ConOut("GcFecharMes: aviso — sem exercício aberto para " + cCompetencia + "; Balancete não vai refletir este fechamento")
    EndIf

    Local i
    For i := 1 To Len(aUnidades)
        Local nValorUnidade := nTotalDespesas * Val(aUnidades[i]:UNI_FRACAO)
        TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('" + ;
            GcSqlLit(aUnidades[i]:UNI_CODIGO) + "', '" + GcSqlLit(cCompetencia) + "', " + ;
            cValToChar(nValorUnidade) + ", '" + cVencimento + "', 'pendente', '" + GcSqlLit(FWxFilial('COB')) + "')")

        If lLancarContabil .And. nValorUnidade > 0
            // Débito 5000 (Contas a Receber) / Crédito 3000 (Receita Condominial) — rateio da unidade
            TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_, FILIAL) VALUES ('" + ;
                GcSqlLit(cDataLan) + "', '5000', '3000', " + cValToChar(nValorUnidade) + ", '" + ;
                GcSqlLit("Rateio " + cCompetencia + " - Unidade " + aUnidades[i]:UNI_CODIGO) + "', 'AUTOMATICO_RATEIO', '" + GcSqlLit(cCompetencia) + "', datetime('now'), 'FECHAMENTO_MENSAL', ' ', " + ;
                "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS), '" + GcSqlLit(FWxFilial('LANCAMENTOS')) + "')")
        EndIf
    Next
Return .T.

/*/{Protheus.doc} GcProximoVencimento
    Calcula um dia do mês seguinte à competência informada — dia
    configurável (1-28; fora da faixa ou não informado usa 10).
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, competência "YYYY-MM"
    @param nDia, numeric, dia do vencimento (1-28; default 10)
    @return cVencimento, character, data "YYYY-MM-DD" do mês seguinte
*/
User Function GcProximoVencimento(cCompetencia, nDia)
    Local nAno := Val(Left(cCompetencia, 4))
    Local nMes := Val(SubStr(cCompetencia, 6, 2))
    Local nDiaUsar := nDia
    nMes++
    If nMes > 12
        nMes := 1
        nAno++
    EndIf
    If nDiaUsar == Nil .Or. nDiaUsar < 1 .Or. nDiaUsar > 28
        nDiaUsar := 10
    EndIf
Return StrZero(nAno, 4) + "-" + StrZero(nMes, 2) + "-" + StrZero(nDiaUsar, 2)
