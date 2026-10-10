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
//
// Refinamentos (Wilson Kraft, QA 2026-08-23, docs/superpowers/... ver
// Wilson/Proposta_Integracao_Contabil_Condominial_GesCon.doc):
// - Conta de débito por categoria (GcContaDespesaPorCategoria, contabil.prw),
//   fallback 4000 sem categoria/mapeamento.
// - DES.DES_LANCADO_CONTABIL marcado por linha, pra "Lançar Despesa com
//   Rateio" não duplicar uma despesa que já passou por aqui.
// - Sem exercício aberto, pergunta ANTES de fechar (MsgYesNo) e, se já foi
//   fechada sem contabilizar, oferece contabilizar depois de abrir o exercício.
//
// QA v1.2.0 (Wilson Kraft, 2026-10-10): contabilização idempotente e
// transacional (GcContabilizarCompetencia), resíduo de arredondamento do
// rateio, normalização de DES_COMPET.
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
    Local aUnidades := {}
    Local aExercicio := {}
    Local aValores := {}
    Local aFracoes := {}
    Local nSomaFracoes := 0
    Local cVencimento := ""
    Local lLancarContabil := .F.
    Local j
    Local i

    // "MM/AAAA" digitado no prompt vira "AAAA-MM" (mesmo achado A4).
    If Len(cCompetencia) == 7 .And. SubStr(cCompetencia, 3, 1) == "/"
        cCompetencia := Right(cCompetencia, 4) + "-" + Left(cCompetencia, 2)
    EndIf
    GcNormalizarCompetDespesas()

    Local aExistente := TCSqlQuery("SELECT COB_UNIDADE FROM COB WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
    If Len(aExistente) > 0
        // Já fechada. Se agora há exercício aberto e a competência nunca foi
        // contabilizada (fechada antes de abrir o exercício), oferece
        // contabilizar -- sem isto a orientação "abra o exercício" do
        // alerta levava a um beco sem saída (achado A5, Wilson Kraft).
        If GcCompetenciaPendenteContabil(cCompetencia)
            If MsgYesNo("A competência " + cCompetencia + " já foi fechada, mas ainda não foi contabilizada (o exercício estava fechado/inexistente). Contabilizar agora?", "Fechamento Mensal")
                GcContabilizarCompetencia(cCompetencia)
                Return .T.
            EndIf
        Else
            MsgAlert("A competência " + cCompetencia + " já foi fechada.", "Fechamento Mensal")
        EndIf
        ConOut("GcFecharMes: competência " + cCompetencia + " já foi fechada")
        Return .F.
    EndIf

    Local aDespesas := TCSqlQuery("SELECT COALESCE(SUM(DES_VALOR),0) AS TOTAL FROM DES WHERE DES_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "'")
    nTotalDespesas := Val(aDespesas[1]:TOTAL)
    If nTotalDespesas == 0
        ConOut("GcFecharMes: aviso — competência " + cCompetencia + " não tem nenhuma despesa lançada, fechando mesmo assim")
    EndIf

    aUnidades := TCSqlQuery("SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('UNI')) + "'")
    If Len(aUnidades) == 0
        ConOut("GcFecharMes: nenhuma unidade cadastrada")
        MsgAlert("Não foi possível fechar " + cCompetencia + ": não há unidade cadastrada neste condomínio.", "Fechamento Mensal")
        Return .F.
    EndIf

    For j := 1 To Len(aUnidades)
        nSomaFracoes += Val(aUnidades[j]:UNI_FRACAO)
    Next
    If nSomaFracoes < 0.999 .Or. nSomaFracoes > 1.001
        ConOut("GcFecharMes: aviso — soma das frações ideais das unidades ativas é " + cValToChar(nSomaFracoes) + ", não 1.0 (100%)")
    EndIf

    // Sem exercício aberto pra competência o Balancete não reflete o
    // fechamento: pergunta ANTES de gravar qualquer coisa, em vez de avisar
    // depois sem opção de cancelar (achado A5, Wilson Kraft, QA v1.2.0).
    aExercicio := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_CODIGO = '" + GcSqlLit(cCompetencia) + "' AND EXE_FECHADO = 0 AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('EXERCICIO')) + "'")
    lLancarContabil := (Len(aExercicio) > 0)
    If !lLancarContabil
        If !MsgYesNo("Não há exercício aberto para " + cCompetencia + " — o fechamento gerará só as cobranças e o Balancete não refletirá. Para contabilizar, abra o exercício em Contabilidade > Abrir Exercício e feche esta competência de novo (ela será contabilizada). Continuar mesmo assim?", "Fechamento Mensal")
            ConOut("GcFecharMes: fechamento de " + cCompetencia + " cancelado pelo usuário (sem exercício aberto)")
            Return .F.
        EndIf
    EndIf

    cVencimento := GcProximoVencimento(cCompetencia, nDiaVencimento)
    GcBackupBanco(cCompetencia) // ver src/db.prw — antes de gravar qualquer Cobrança

    // Round + resíduo na unidade de maior fração (A6): a soma das cobranças
    // fecha exatamente no total das despesas.
    For i := 1 To Len(aUnidades)
        // Round: mesmo achado de resíduo de ponto flutuante do rateio
        // manual (GcCalcularRateio, contabil.prw) -- valor monetário
        // sempre tem 2 casas.
        AAdd(aValores, Round(nTotalDespesas * Val(aUnidades[i]:UNI_FRACAO), 2))
        AAdd(aFracoes, Val(aUnidades[i]:UNI_FRACAO))
    Next
    GcAjustarResiduoRateio(Round(nTotalDespesas, 2), aFracoes, aValores)

    For i := 1 To Len(aUnidades)
        TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('" + ;
            GcSqlLit(aUnidades[i]:UNI_CODIGO) + "', '" + GcSqlLit(cCompetencia) + "', " + ;
            cValToChar(aValores[i]) + ", '" + cVencimento + "', 'pendente', '" + GcSqlLit(FWxFilial('COB')) + "')")
    Next

    // Cobranças primeiro, contabilidade depois: se a contabilização falhar
    // no meio, a competência já consta como fechada e o próximo "Fechar"
    // oferece contabilizar -- idempotente (ver GcContabilizarCompetencia),
    // sem duplicar lançamento como acontecia no A2.
    If lLancarContabil
        GcContabilizarCompetencia(cCompetencia)
    EndIf
Return .T.

/*/{Protheus.doc} GcCompetenciaPendenteContabil
    .T. se existe exercício aberto para a competência, ela tem cobranças e
    o Fechamento Mensal ainda não gravou nenhum lançamento nesse exercício.

    ponytail: heurística "nenhum lançamento FECHAMENTO_MENSAL no exercício".
    Se, depois de abrir o exercício, alguém também lançar despesa manual
    nele, a contabilização retroativa vai somar o rateio das cobranças
    manuais -- raro; troque por marca explícita em COB se acontecer.
    @type Function
    @author GesCon
    @since 2026-10-10
    @param cCompetencia, character, "AAAA-MM"
    @return lPendente, logical
*/
User Function GcCompetenciaPendenteContabil(cCompetencia)
    Local aExe := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_CODIGO = '" + GcSqlLit(cCompetencia) + "' AND EXE_FECHADO = 0 AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('EXERCICIO')) + "'")
    Local aJa := {}
    If Len(aExe) == 0
        Return .F.
    EndIf
    aJa := TCSqlQuery("SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_EXERCICIO = '" + GcSqlLit(cCompetencia) + "' AND LAN_USUARIO = 'FECHAMENTO_MENSAL' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('LANCAMENTOS')) + "'")
Return (Len(aJa) == 0)

/*/{Protheus.doc} GcContabilizarCompetencia
    Grava os LANCAMENTOS de uma competência já com cobranças: débito
    despesa (conta por categoria)/crédito Caixa(1000) por despesa ainda
    não contabilizada, e débito Contas a Receber(5000)/crédito
    Receita(3000) por cobrança. Idempotente: a despesa só entra se
    DES_LANCADO_CONTABIL = 0 e o rateio só entra se a unidade ainda não tem
    o lançamento "Rateio <competência> - Unidade <x>". Cada despesa grava
    lançamento + flag na mesma transação (A2: um erro entre os dois
    duplicava o lançamento a cada nova tentativa).
    @type Function
    @author GesCon
    @since 2026-10-10
    @param cCompetencia, character, "AAAA-MM" (EXE_CODIGO do exercício aberto)
    @return lOk, logical, .F. se não há exercício aberto
*/
User Function GcContabilizarCompetencia(cCompetencia)
    Local cDataLan := StrTran(cCompetencia, "-", "") + "01"
    Local cFil := GcSqlLit(FWxFilial('LANCAMENTOS'))
    Local aExe := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_CODIGO = '" + GcSqlLit(cCompetencia) + "' AND EXE_FECHADO = 0 AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('EXERCICIO')) + "'")
    Local aDesp := {}
    Local aCob := {}
    Local cContaDeb := ""
    Local cDescr := ""
    Local k

    If Len(aExe) == 0
        Return .F.
    EndIf

    // Traz DES_CATEG e R_E_C_N_O_ pra mapear conta por categoria
    // (GcContaDespesaPorCategoria) e marcar DES_LANCADO_CONTABIL.
    aDesp := TCSqlQuery("SELECT R_E_C_N_O_, DES_DESCR, DES_VALOR, DES_CATEG FROM DES WHERE DES_COMPET = '" + GcSqlLit(cCompetencia) + "' AND DES_LANCADO_CONTABIL = 0 AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "'")
    For k := 1 To Len(aDesp)
        If Val(aDesp[k]:DES_VALOR) > 0
            cContaDeb := GcContaDespesaPorCategoria(aDesp[k]:DES_CATEG)
            // Débito conta de despesa (por categoria, fallback 4000) / Crédito 1000 (Caixa)
            TCSqlExec("BEGIN;" + Chr(10) + ;
                "INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_, FILIAL) VALUES ('" + ;
                GcSqlLit(cDataLan) + "', '" + GcSqlLit(cContaDeb) + "', '1000', " + cValToChar(Val(aDesp[k]:DES_VALOR)) + ", '" + ;
                GcSqlLit(aDesp[k]:DES_DESCR) + "', 'AUTOMATICO_DESPESA', '" + GcSqlLit(cCompetencia) + "', datetime('now'), 'FECHAMENTO_MENSAL', ' ', " + ;
                "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS), '" + cFil + "');" + Chr(10) + ;
                "UPDATE DES SET DES_LANCADO_CONTABIL = 1 WHERE R_E_C_N_O_ = " + cValToChar(aDesp[k]:R_E_C_N_O_) + ";" + Chr(10) + ;
                "COMMIT;")
        EndIf
    Next

    aCob := TCSqlQuery("SELECT COB_UNIDADE, COB_VALOR FROM COB WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
    For k := 1 To Len(aCob)
        If Val(aCob[k]:COB_VALOR) > 0
            cDescr := "Rateio " + cCompetencia + " - Unidade " + aCob[k]:COB_UNIDADE
            If Len(TCSqlQuery("SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_TIPO = 'AUTOMATICO_RATEIO' AND LAN_EXERCICIO = '" + GcSqlLit(cCompetencia) + "' AND LAN_DESCR = '" + GcSqlLit(cDescr) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + cFil + "'")) == 0
                // Débito 5000 (Contas a Receber) / Crédito 3000 (Receita Condominial) — rateio da unidade
                TCSqlExec("INSERT INTO LANCAMENTOS (LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_, R_E_C_N_O_, FILIAL) VALUES ('" + ;
                    GcSqlLit(cDataLan) + "', '5000', '3000', " + cValToChar(Val(aCob[k]:COB_VALOR)) + ", '" + ;
                    GcSqlLit(cDescr) + "', 'AUTOMATICO_RATEIO', '" + GcSqlLit(cCompetencia) + "', datetime('now'), 'FECHAMENTO_MENSAL', ' ', " + ;
                    "(SELECT COALESCE(MAX(R_E_C_N_O_), 0) + 1 FROM LANCAMENTOS), '" + cFil + "')")
            EndIf
        EndIf
    Next
    ConOut("GcContabilizarCompetencia: lançamentos contábeis gravados no exercício " + cCompetencia)
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
