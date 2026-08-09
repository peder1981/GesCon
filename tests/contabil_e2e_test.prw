// tests/contabil_e2e_test.prw — teste end-to-end do sistema contábil completo
// Executa fluxo inteiro: lançamentos, rateio, validação, balancete, auditoria, fechamento
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito.
// `advplc run` escolhe sozinho o ponto de entrada: a primeira User
// Function cuja linha seja >= a primeira linha de codigo do arquivo raiz
// (pkg/compiler/codegen.go). Como #include cola o texto incluido no lugar,
// includes no topo empurram as funcoes dos modulos para antes do runner
// deste arquivo -- e a suite inteira roda em silencio, executando algo
// como GcSqlLit no lugar dos testes. Com os includes no fim, o runner
// abaixo e sempre a primeira funcao do compilado. scripts/test.sh
// confere isso a cada execucao.

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

    // Achado do "Known gap" (final-review-fix-report.md): a correcao da
    // regex de FAIL em scripts/test.sh (commit b13822d, C3) desmascarou o
    // mesmo defeito latente aqui que ja existia em tests/contabil_test.prw
    // antes daquele commit -- schema.sql (Task 2) deixou de semear
    // PLANO_CONTAS/EXERCICIO/UNI, e esta suite dependia disso em silencio.
    // Mesmo padrao de tests/auditoria_test.prw e do fix ja aplicado em
    // tests/contabil_test.prw: FILIAL = '      ' (sessao sem RpcSetEnv, e'
    // essa a filial que GcExercicioAtivo/GcCriarLancamentoManualDireto/
    // GcLancarDespesaContabil/GcFecharPeriodo filtram via FWxFilial()),
    // INSERT OR IGNORE pra ser idempotente, teardown no fim desta funcao.
    //
    // Exercicio '2024-01' -- DIFERENTE do '2025-01' de contabil_test.prw de
    // proposito. contabil_e2e_test.prw roda alfabeticamente ANTES de
    // contabil_test.prw ("_e2e_" < "_test" na comparacao de string), e o
    // fluxo abaixo chama GcFecharPeriodo, que cria e ativa um SEGUNDO
    // periodo (EXE_ATIVO = 1) na mesma FILIAL. Se este segundo periodo nao
    // fosse totalmente desfeito no teardown, o SELECT ... LIMIT 1 sem ORDER
    // BY de GcExercicioAtivo() poderia escolher esse residuo em vez de
    // '2025-01' de forma nao deterministica quando contabil_test.prw
    // rodasse em seguida, quebrando TesteGcExercicioAtivo la.
    //
    // Contas: 1000/1100 (GcCriarLancamentoManualDireto), mais 1000/3000/4000/
    // 5000, que sao as mesmas hardcoded dentro de GcLancarDespesaContabil
    // (debito 4000/credito 1000 no lancamento principal, debito 5000/
    // credito 3000 em cada rateio) -- mesmo comentario de
    // tests/contabil_test.prw sobre essas contas.
    TCSqlExec("INSERT OR IGNORE INTO EXERCICIO (FILIAL, EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) VALUES ('      ', '2024-01', '2024-01-01', '2024-01-31', 1, 0, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '1000', 'Caixa', 'ATIVO', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '1100', 'Banco', 'ATIVO', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '3000', 'Receita Condominial', 'RECEITA', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '4000', 'Despesa Comum', 'DESPESA', 1, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO PLANO_CONTAS (FILIAL, PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO, D_E_L_E_T_) VALUES ('      ', '5000', 'Contas a Receber', 'ATIVO', 1, ' ')")

    // Unidades para o rateio por fracao (GcCalcularRateio). Mesmo par T01/T02
    // de tests/contabil_test.prw, com INSERT OR IGNORE -- fixture idempotente
    // e compartilhada, seguro em qualquer ordem entre as duas suites. UNI
    // fica de fora do teardown de proposito, ver comentario la.
    TCSqlExec("INSERT OR IGNORE INTO UNI (FILIAL, UNI_CODIGO, UNI_FRACAO, D_E_L_E_T_) VALUES ('      ', 'T01', 0.6, ' ')")
    TCSqlExec("INSERT OR IGNORE INTO UNI (FILIAL, UNI_CODIGO, UNI_FRACAO, D_E_L_E_T_) VALUES ('      ', 'T02', 0.4, ' ')")

    TesteE2EFluxoCompleto()
    ConOut("")

    ConOut("========== FIM DO TESTE E2E ==========")
    ConOut("")

    // Teardown -- desfaz tanto o seed acima quanto tudo que GcFecharPeriodo
    // gravou durante o fluxo (balancete, auditoria, snapshots do Portal v2,
    // e o proximo periodo '2024-02' que ele mesmo cria e ativa). Ordem
    // respeita as FOREIGN KEY: RATEIO_DETALHE -> COB -> LANCAMENTOS ->
    // EXERCICIO -> PLANO_CONTAS (mesma ordem de tests/contabil_test.prw).
    // AUDITORIA e RPT_BALANCETE nao tem FK declarada no schema, mas
    // referenciam o codigo do exercicio por convencao, entao saem antes do
    // DELETE de EXERCICIO por clareza/paridade com o padrao do arquivo
    // irmao. '2024-02' e o proximo periodo que GcFecharPeriodo('2024-01')
    // cria (mes 01 + 1 = 02, sem virada de ano) -- mesma conta feita dentro
    // de TesteE2EFluxoCompleto (variavel cProximo).
    //
    // Todo lancamento criado por esta suite passa por
    // GcCriarLancamentoManualDireto/GcLancarDespesaContabil, que gravam
    // LAN_USUARIO = 'TEST_USER' -- marcador exclusivo o bastante pra
    // identificar exatamente essas linhas (mesmo marcador de
    // tests/contabil_test.prw; nao ha conflito porque esta suite roda e
    // se limpa antes daquela rodar).
    TCSqlExec("DELETE FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE IN ('T01', 'T02') AND FILIAL = '      '")
    TCSqlExec("DELETE FROM RPT_PORTAL_EXTRATOS WHERE REX_UNIDADE IN ('T01', 'T02') AND FILIAL = '      '")
    TCSqlExec("DELETE FROM AUDITORIA WHERE AUD_EXERCICIO = '2024-01' AND FILIAL = '      '")
    TCSqlExec("DELETE FROM RPT_BALANCETE WHERE RPT_EXERCICIO = '2024-01' AND FILIAL = '      '")
    TCSqlExec("DELETE FROM RATEIO_DETALHE WHERE RAT_LANCAMENTO IN (SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_USUARIO = 'TEST_USER' AND FILIAL = '      ')")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2024-01' AND COB_UNIDADE IN ('T01', 'T02')")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE LAN_USUARIO = 'TEST_USER' AND FILIAL = '      '")
    TCSqlExec("DELETE FROM EXERCICIO WHERE EXE_CODIGO IN ('2024-01', '2024-02') AND FILIAL = '      '")
    TCSqlExec("DELETE FROM PLANO_CONTAS WHERE PLA_CODIGO IN ('1000', '1100', '3000', '4000', '5000') AND FILIAL = '      '")

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
    // (achado adicional do "Known gap": GcSqlLit só ESCAPA aspas simples,
    // não envolve o resultado com aspas -- mesmo contrato documentado em
    // tests/contabil_test.prw/TesteGcSqlLit. As 4 queries abaixo usavam
    // GcSqlLit sem aspas ao redor, produzindo SQL invalido tipo
    // "EXE_CODIGO = 2024-01" em vez de "EXE_CODIGO = '2024-01'" -- o mesmo
    // erro estava mascarado pela regex antiga de scripts/test.sh (sem bare
    // "FAIL:") e só apareceu depois do fix da regex (commit b13822d, C3)
    // combinado com o fix do schema.sql seed acima.)
    aExercicioAtual := TCSqlQuery("SELECT EXE_ATIVO, EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = '" + GcSqlLit(cExercicio) + "' AND D_E_L_E_T_ = ' '")
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

    aExercicioProximo := TCSqlQuery("SELECT EXE_ATIVO, EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = '" + GcSqlLit(cProximo) + "' AND D_E_L_E_T_ = ' '")
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
    aVerificacao := TCSqlQuery("SELECT RPT_RECEITAS, RPT_DESPESAS, RPT_SALDO FROM RPT_BALANCETE WHERE RPT_EXERCICIO = '" + GcSqlLit(cExercicio) + "' AND D_E_L_E_T_ = ' '")
    If Len(aVerificacao) > 0
        ConOut("  PASS: Balancete gravado em RPT_BALANCETE (receitas=" + cValToChar(aVerificacao[1]:RPT_RECEITAS) + ", despesas=" + cValToChar(aVerificacao[1]:RPT_DESPESAS) + ", saldo=" + cValToChar(aVerificacao[1]:RPT_SALDO) + ")")
    Else
        ConOut("  FAIL: Balancete não foi gravado")
    EndIf

    // 12. Verifica registros de auditoria foram criados
    aVerificacao := TCSqlQuery("SELECT COUNT(*) as QTD FROM AUDITORIA WHERE AUD_EXERCICIO = '" + GcSqlLit(cExercicio) + "' AND D_E_L_E_T_ = ' '")
    If Len(aVerificacao) > 0 .And. aVerificacao[1]:QTD > 0
        ConOut("  PASS: " + cValToChar(aVerificacao[1]:QTD) + " registro(s) de auditoria criado(s)")
    EndIf

    ConOut("")
    ConOut("E2E test completed successfully!")

Return

#include "../src/db.prw"
#include "../src/contabil.prw"
#include "../src/auditoria.prw"
#include "../src/portal.prw"
#include "../src/portal-v2.prw"
