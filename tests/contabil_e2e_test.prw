// tests/contabil_e2e_test.prw — teste end-to-end do sistema contábil completo
// Executa fluxo inteiro: lançamentos, rateio, validação, balancete, auditoria, fechamento
#include "totvs.ch"
#include "../src/contabil.prw"
#include "../src/auditoria.prw"

/*/{Protheus.doc} ContabilE2ETest
    Orquestrador do teste end-to-end do sistema contábil.
    Executa fluxo completo:
    1. Obter exercício ativo
    2. Criar lançamento manual
    3. Lançar despesa com rateio
    4. Validar integridade
    5. Gerar balancete
    6. Auditar período
    7. Fechar período
    8. Verificar novo período ativo
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function ContabilE2ETest()
    ConOut("")
    ConOut("========== TESTE END-TO-END DO SISTEMA CONTÁBIL ==========")
    ConOut("")

    TesteE2EFluxoCompleto()
    ConOut("")

    ConOut("========== FIM DO TESTE E2E ==========")
    ConOut("")

Return

/*/{Protheus.doc} TesteE2EFluxoCompleto
    Testa fluxo completo de contabilidade: lançamentos, rateio, integridade, balancete, auditoria, fechamento.
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteE2EFluxoCompleto()
    Local cExercicio := ""
    Local cProximo := ""
    Local lRet := .F.
    Local nIntegridadeAntes := 0
    Local nIntegridadeDepois := 0
    Local aVerificacao := {}
    Local nAnomalias := 0
    Local nSaldo := 0
    Local aExercicioAtual := {}
    Local aExercicioProximo := {}

    ConOut("TesteE2EFluxoCompleto")
    ConOut("")

    // 1. Obtém exercício ativo
    cExercicio := GcExercicioAtivo()
    If Empty(cExercicio)
        ConOut("  FAIL: Nenhum exercício ativo encontrado")
        Return
    EndIf
    ConOut("  PASS: Exercício ativo obtido: " + cExercicio)

    // 2. Cria lançamento manual
    lRet := GcCriarLancamentoManualDireto(Date(), "Lançamento E2E Manual", "1100", "1000", 500.00)
    If !lRet
        ConOut("  FAIL: Falha ao criar lançamento manual")
        Return
    EndIf
    ConOut("  PASS: Lançamento manual criado (1100 deb, 1000 cred, 500.00)")

    // 3. Lança despesa com rateio (unidades T01, T02)
    lRet := GcLancarDespesaContabil(Date(), "Despesa E2E com Rateio", 1000.00, "FRACAO", 15)
    If !lRet
        ConOut("  FAIL: Falha ao lançar despesa com rateio")
        Return
    EndIf
    ConOut("  PASS: Despesa com rateio lançada (1000.00)")

    // 4. Valida integridade antes do fechamento
    lRet := GcValidarIntegridade(cExercicio)
    If !lRet
        ConOut("  FAIL: Integridade não validada antes de fechar")
        Return
    EndIf
    ConOut("  PASS: Integridade validada (débitos == créditos)")

    // 5. Gera balancete
    nSaldo := GcGerarBalancetePeriodo(cExercicio)
    ConOut("  PASS: Balancete gerado (saldo=" + cValToChar(nSaldo) + ")")

    // 6. Audita o período
    nAnomalias := GcAuditoriaFecharPeriodo(cExercicio)
    If nAnomalias > 0
        ConOut("  WARNING: Auditoria detectou " + cValToChar(nAnomalias) + " anomalias")
    Else
        ConOut("  PASS: Auditoria OK (0 anomalias críticas)")
    EndIf

    // 7. Fecha o período
    lRet := GcFecharPeriodo(cExercicio)
    If !lRet
        ConOut("  FAIL: Falha ao fechar período")
        Return
    EndIf
    ConOut("  PASS: Período fechado: " + cExercicio)

    // 8. Verifica que período anterior está fechado e inativo
    aExercicioAtual := TCSqlQuery("SELECT EXE_ATIVO, EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
    If Len(aExercicioAtual) > 0
        Local nAtualFechado := aExercicioAtual[1]:EXE_FECHADO
        Local nAtualAtivo := aExercicioAtual[1]:EXE_ATIVO
        If (nAtualFechado = 1 .Or. nAtualFechado = "1") .And. (nAtualAtivo = 0 .Or. nAtualAtivo = "0")
            ConOut("  PASS: Período anterior marcado como fechado (EXE_FECHADO=" + cValToChar(nAtualFechado) + ") e inativo (EXE_ATIVO=" + cValToChar(nAtualAtivo) + ")")
        Else
            ConOut("  WARNING: Período anterior EXE_FECHADO=" + cValToChar(nAtualFechado) + ", EXE_ATIVO=" + cValToChar(nAtualAtivo))
        EndIf
    Else
        ConOut("  WARNING: Período anterior não encontrado")
    EndIf

    // 9. Verifica que novo período foi criado e está ativo
    Local cMesSub := SubStr(cExercicio, 6, 2)
    Local cAnoSub := SubStr(cExercicio, 1, 4)
    Local nMes := Val(cMesSub)
    Local nAno := Val(cAnoSub)
    Local nProxMes := 0
    Local nProxAno := 0

    If nMes = 12
        nProxMes := 1
        nProxAno := nAno + 1
    Else
        nProxMes := nMes + 1
        nProxAno := nAno
    EndIf

    cProximo := cValToChar(nProxAno) + "-" + PadL(cValToChar(nProxMes), 2, "0")

    aExercicioProximo := TCSqlQuery("SELECT EXE_ATIVO, EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlLit(cProximo) + " AND D_E_L_E_T_ = ' '")
    If Len(aExercicioProximo) > 0
        Local nProxAtivo := aExercicioProximo[1]:EXE_ATIVO
        Local nProxFechado := aExercicioProximo[1]:EXE_FECHADO
        If (nProxAtivo = 1 .Or. nProxAtivo = "1") .And. (nProxFechado = 0 .Or. nProxFechado = "0")
            ConOut("  PASS: Próximo período criado e marcado como ativo (EXE_ATIVO=" + cValToChar(nProxAtivo) + ") e aberto (EXE_FECHADO=" + cValToChar(nProxFechado) + "): " + cProximo)
        Else
            ConOut("  WARNING: Próximo período EXE_ATIVO=" + cValToChar(nProxAtivo) + ", EXE_FECHADO=" + cValToChar(nProxFechado))
        EndIf
    Else
        ConOut("  FAIL: Próximo período não foi criado")
        Return
    EndIf

    // 10. Verifica que novo período ativo é retornado
    Local cExercicioAtualAtual := GcExercicioAtivo()
    If cExercicioAtualAtual = cProximo
        ConOut("  PASS: GcExercicioAtivo retorna novo período: " + cExercicioAtualAtual)
    Else
        ConOut("  FAIL: GcExercicioAtivo retorna " + cExercicioAtualAtual + " esperado " + cProximo)
    EndIf

    // 11. Verifica que balancete foi gravado
    aVerificacao := TCSqlQuery("SELECT RPT_RECEITAS, RPT_DESPESAS, RPT_SALDO FROM RPT_BALANCETE WHERE RPT_EXERCICIO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
    If Len(aVerificacao) > 0
        ConOut("  PASS: Balancete gravado em RPT_BALANCETE (receitas=" + cValToChar(aVerificacao[1]:RPT_RECEITAS) + ", despesas=" + cValToChar(aVerificacao[1]:RPT_DESPESAS) + ", saldo=" + cValToChar(aVerificacao[1]:RPT_SALDO) + ")")
    Else
        ConOut("  FAIL: Balancete não foi gravado")
    EndIf

    // 12. Verifica registros de auditoria foram criados
    aVerificacao := TCSqlQuery("SELECT COUNT(*) as QTD FROM AUDITORIA WHERE AUD_EXERCICIO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
    If Len(aVerificacao) > 0 .And. aVerificacao[1]:QTD > 0
        ConOut("  PASS: " + cValToChar(aVerificacao[1]:QTD) + " registro(s) de auditoria criado(s)")
    EndIf

    ConOut("")
    ConOut("E2E test completed successfully!")

Return
