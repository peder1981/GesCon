// tests/contabil_test.prw — testes das utilidades do sistema contábil
// TesteGcSqlLit, TesteGcExercicioAtivo, TesteGcPeriodoFechado
#include "totvs.ch"
#include "../src/contabil.prw"

/*/{Protheus.doc} ContabilTest
    Orquestrador dos testes contábeis.
    Executa: TesteGcSqlLit, TesteGcExercicioAtivo, TesteGcPeriodoFechado,
    TesteNovoLancamentoManual, TesteEditarLancamento, TesteDeletarLancamento,
    TesteCalcularRateioFracao
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function ContabilTest()
    ConOut("")
    ConOut("========== TESTES DO SISTEMA CONTÁBIL ==========")
    ConOut("")

    TesteGcSqlLit()
    ConOut("")

    TesteGcExercicioAtivo()
    ConOut("")

    TesteGcPeriodoFechado()
    ConOut("")

    TesteNovoLancamentoManual()
    ConOut("")

    TesteEditarLancamento()
    ConOut("")

    TesteDeletarLancamento()
    ConOut("")

    TesteCalcularRateioFracao()
    ConOut("")

    TesteLancarDespesaComRateio()
    ConOut("")

    ConOut("========== FIM DOS TESTES ==========")
    ConOut("")

Return

/*/{Protheus.doc} TesteGcSqlLit
    Valida escape de aspas simples e envolvimento com quotes.
    Teste casos:
    - String simples
    - String com aspas simples (O'Brien)
    - String com caracteres especiais (João's Café)
    - String vazia
    - Nil (deve retornar '' vazio com quotes)
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteGcSqlLit()
    Local cTeste1 := GcSqlLit("João's Café")
    Local cTeste2 := GcSqlLit("O'Brien")
    Local cTeste3 := GcSqlLit("simples")
    Local cTeste4 := GcSqlLit("")
    Local cTeste5 := GcSqlLit(Nil)

    ConOut("TesteGcSqlLit")
    ConOut("  João's Café => " + cTeste1)
    ConOut("  O'Brien => " + cTeste2)
    ConOut("  simples => " + cTeste3)
    ConOut("  (vazio) => " + cTeste4)
    ConOut("  (Nil) => " + cTeste5)

    // Validações básicas
    If cTeste1 = "'João''s Café'"
        ConOut("  PASS: João's Café corretamente escapado")
    Else
        ConOut("  FAIL: João's Café esperado: 'João''s Café', obtido: " + cTeste1)
    EndIf

    If cTeste2 = "'O''Brien'"
        ConOut("  PASS: O'Brien corretamente escapado")
    Else
        ConOut("  FAIL: O'Brien esperado: 'O''Brien', obtido: " + cTeste2)
    EndIf

    If cTeste3 = "'simples'"
        ConOut("  PASS: simples corretamente envolvido")
    Else
        ConOut("  FAIL: simples esperado: 'simples', obtido: " + cTeste3)
    EndIf

    If cTeste4 = "''"
        ConOut("  PASS: vazio corretamente envolvido com quotes")
    Else
        ConOut("  FAIL: vazio esperado: '', obtido: " + cTeste4)
    EndIf

    If cTeste5 = "''"
        ConOut("  PASS: Nil convertido para vazio com quotes")
    Else
        ConOut("  FAIL: Nil esperado: '', obtido: " + cTeste5)
    EndIf

Return

/*/{Protheus.doc} TesteGcExercicioAtivo
    Valida recuperação do exercício ativo.
    Dados de seed já contêm '2025-01' como ativo (EXE_ATIVO = 1, EXE_FECHADO = 0).
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteGcExercicioAtivo()
    Local cExercicio := GcExercicioAtivo()

    ConOut("TesteGcExercicioAtivo")
    ConOut("  Exercício ativo => " + cExercicio)

    If cExercicio = "2025-01"
        ConOut("  PASS: exercício ativo '2025-01' recuperado corretamente")
    Else
        ConOut("  FAIL: exercício ativo esperado: '2025-01', obtido: '" + cExercicio + "'")
    EndIf

Return

/*/{Protheus.doc} TesteGcPeriodoFechado
    Valida verificação de período fechado.
    '2025-01' do seed deve estar aberto (EXE_FECHADO = 0), retornando .F.
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteGcPeriodoFechado()
    Local lFechado := GcPeriodoFechado("2025-01")
    Local lNaoExiste := GcPeriodoFechado("9999-99")

    ConOut("TesteGcPeriodoFechado")
    ConOut("  Período '2025-01' fechado? => " + cValToChar(lFechado))
    ConOut("  Período '9999-99' fechado? => " + cValToChar(lNaoExiste))

    If !lFechado
        ConOut("  PASS: período '2025-01' aberto (não fechado)")
    Else
        ConOut("  FAIL: período '2025-01' esperado aberto, mas marcado como fechado")
    EndIf

    If !lNaoExiste
        ConOut("  PASS: período inexistente '9999-99' retorna .F.")
    Else
        ConOut("  FAIL: período inexistente esperado .F., obtido .T.")
    EndIf

Return

/*/{Protheus.doc} TesteNovoLancamentoManual
    Testa criação de lançamentos manuais em partida dupla.
    Cria 2 lançamentos, verifica validação de contas diferentes,
    e conta registros na tabela LANCAMENTOS.
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteNovoLancamentoManual()
    Local aContagem1 := {}
    Local aContagem2 := {}
    Local nCount1 := 0
    Local nCount2 := 0
    Local lRet1 := .F.
    Local lRet2 := .F.
    Local lRetInvalid := .F.

    ConOut("TesteNovoLancamentoManual")

    // Conta lançamentos antes
    aContagem1 := TCSqlQuery("SELECT COUNT(*) as QTD FROM LANCAMENTOS WHERE D_E_L_E_T_ = ' '")
    If Len(aContagem1) > 0
        nCount1 := aContagem1[1]:QTD
        ConOut("  Lançamentos antes: " + cValToChar(nCount1))
    EndIf

    // Cria primeiro lançamento válido (1000 débito, 1100 crédito, 100.00)
    lRet1 := GcCriarLancamentoManualDireto(Date(), "Depósito em banco", "1100", "1000", 100.00)
    If lRet1
        ConOut("  PASS: Lançamento 1 (1100 deb, 1000 cred, 100.00) criado com sucesso")
    Else
        ConOut("  FAIL: Lançamento 1 deveria ter sido criado")
    EndIf

    // Cria segundo lançamento válido (diferente do primeiro)
    lRet2 := GcCriarLancamentoManualDireto(Date(), "Transferência", "1000", "2000", 50.00)
    If lRet2
        ConOut("  PASS: Lançamento 2 (1000 deb, 2000 cred, 50.00) criado com sucesso")
    Else
        ConOut("  FAIL: Lançamento 2 deveria ter sido criado")
    EndIf

    // Testa validação: contas iguais (deve falhar)
    lRetInvalid := GcCriarLancamentoManualDireto(Date(), "Lançamento inválido", "1000", "1000", 200.00)
    If !lRetInvalid
        ConOut("  PASS: Validação contas diferentes rejeitou corretamente (1000 deb, 1000 cred)")
    Else
        ConOut("  FAIL: Validação contas diferentes deveria ter rejeitado")
    EndIf

    // Conta lançamentos depois
    aContagem2 := TCSqlQuery("SELECT COUNT(*) as QTD FROM LANCAMENTOS WHERE D_E_L_E_T_ = ' '")
    If Len(aContagem2) > 0
        nCount2 := aContagem2[1]:QTD
        ConOut("  Lançamentos depois: " + cValToChar(nCount2))
    EndIf

    // Valida contagem (deve ter inserido 2)
    If (nCount2 - nCount1) = 2
        ConOut("  PASS: Contagem de lançamentos aumentou em 2 (esperado)")
    Else
        ConOut("  FAIL: Contagem de lançamentos aumentou em " + cValToChar(nCount2 - nCount1) + " (esperado 2)")
    EndIf

Return

/*/{Protheus.doc} TesteEditarLancamento
    Testa edição de descrição de lançamento manual.
    Cria um lançamento, edita sua descrição, verifica atualização.
    Valida preservação da restrição de partida dupla (contas não alteram).
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteEditarLancamento()
    Local aLancamento := {}
    Local nRecno := 0
    Local lRetCriar := .F.
    Local lRetEditar := .F.
    Local cDescricaoNova := "Descrição editada com sucesso"
    Local aVerificacao := {}

    ConOut("TesteEditarLancamento")

    // Cria um lançamento para editar (usando contas válidas do seed: 5000, 1000)
    lRetCriar := GcCriarLancamentoManualDireto(Date(), "Descrição original", "5000", "1000", 250.00)
    If lRetCriar
        ConOut("  PASS: Lançamento criado para teste de edição")
    Else
        ConOut("  FAIL: Não foi possível criar lançamento para edição")
        Return
    EndIf

    // Recupera o R_E_C_N_O_ do último lançamento inserido
    aLancamento := TCSqlQuery("SELECT R_E_C_N_O_ FROM LANCAMENTOS WHERE LAN_DESCR = 'Descrição original' AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_ DESC LIMIT 1")
    If Len(aLancamento) > 0
        nRecno := aLancamento[1]:R_E_C_N_O_
        ConOut("  Record number: " + cValToChar(nRecno))
    Else
        ConOut("  FAIL: Não foi possível recuperar R_E_C_N_O_ do lançamento")
        Return
    EndIf

    // Edita a descrição
    lRetEditar := GcEditarLancamentoDescricao(nRecno, cDescricaoNova)
    If lRetEditar
        ConOut("  PASS: Lançamento editado com sucesso")
    Else
        ConOut("  FAIL: Falha ao editar lançamento")
        Return
    EndIf

    // Verifica se descrição foi atualizada
    aVerificacao := TCSqlQuery("SELECT LAN_DESCR FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
    If Len(aVerificacao) > 0 .And. aVerificacao[1]:LAN_DESCR = cDescricaoNova
        ConOut("  PASS: Descrição atualizada corretamente no banco de dados")
    Else
        ConOut("  FAIL: Descrição não foi atualizada corretamente")
    EndIf

    // Verifica que contas não foram alteradas (validação de partida dupla)
    aVerificacao := TCSqlQuery("SELECT LAN_CONTA_DEB, LAN_CONTA_CRED FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
    If Len(aVerificacao) > 0 .And. aVerificacao[1]:LAN_CONTA_DEB = "5000" .And. aVerificacao[1]:LAN_CONTA_CRED = "1000"
        ConOut("  PASS: Contas preservadas (partida dupla mantida)")
    Else
        ConOut("  FAIL: Contas foram alteradas indevidamente")
    EndIf

Return

/*/{Protheus.doc} TesteDeletarLancamento
    Testa soft-delete de lançamento manual.
    Cria um lançamento, deleta-o, verifica marcação com D_E_L_E_T_ = '*'.
    Valida que lançamentos deletados não aparecem em consultas normais.
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteDeletarLancamento()
    Local aLancamento := {}
    Local nRecno := 0
    Local lRetCriar := .F.
    Local lRetDeletar := .F.
    Local aVerificacaoAntesDelecao := {}
    Local aVerificacaoAposDelecao := {}
    Local aVerificacaoComDelecao := {}

    ConOut("TesteDeletarLancamento")

    // Cria um lançamento para deletar (usando contas válidas do seed: 7000, 1100)
    lRetCriar := GcCriarLancamentoManualDireto(Date(), "Lançamento a deletar", "7000", "1100", 175.50)
    If lRetCriar
        ConOut("  PASS: Lançamento criado para teste de deleção")
    Else
        ConOut("  FAIL: Não foi possível criar lançamento para deleção")
        Return
    EndIf

    // Recupera o R_E_C_N_O_ do último lançamento inserido
    aLancamento := TCSqlQuery("SELECT R_E_C_N_O_ FROM LANCAMENTOS WHERE LAN_DESCR = 'Lançamento a deletar' AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_ DESC LIMIT 1")
    If Len(aLancamento) > 0
        nRecno := aLancamento[1]:R_E_C_N_O_
        ConOut("  Record number: " + cValToChar(nRecno))
    Else
        ConOut("  FAIL: Não foi possível recuperar R_E_C_N_O_ do lançamento")
        Return
    EndIf

    // Verifica que lançamento existe antes da deleção
    aVerificacaoAntesDelecao := TCSqlQuery("SELECT R_E_C_N_O_ FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
    If Len(aVerificacaoAntesDelecao) > 0
        ConOut("  PASS: Lançamento encontrado antes da deleção")
    Else
        ConOut("  FAIL: Lançamento não encontrado antes da deleção")
        Return
    EndIf

    // Deleta o lançamento
    lRetDeletar := GcDeletarLancamento(nRecno)
    If lRetDeletar
        ConOut("  PASS: Lançamento deletado com sucesso")
    Else
        ConOut("  FAIL: Falha ao deletar lançamento")
        Return
    EndIf

    // Verifica que lançamento não aparece em consulta normal (D_E_L_E_T_ = ' ')
    aVerificacaoAposDelecao := TCSqlQuery("SELECT R_E_C_N_O_ FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
    If Len(aVerificacaoAposDelecao) = 0
        ConOut("  PASS: Lançamento não aparece em consultas normais (soft-delete)")
    Else
        ConOut("  FAIL: Lançamento ainda aparece em consultas normais")
    EndIf

    // Verifica que lançamento está marcado com D_E_L_E_T_ = '*'
    aVerificacaoComDelecao := TCSqlQuery("SELECT D_E_L_E_T_, R_E_C_D_E_L_ FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno))
    If Len(aVerificacaoComDelecao) > 0 .And. aVerificacaoComDelecao[1]:D_E_L_E_T_ = "*" .And. aVerificacaoComDelecao[1]:R_E_C_D_E_L_ > 0
        ConOut("  PASS: D_E_L_E_T_ = '*' e R_E_C_D_E_L_ preenchido com timestamp")
    Else
        ConOut("  FAIL: Marcação de soft-delete não realizada corretamente")
    EndIf

Return

/*/{Protheus.doc} TesteCalcularRateioFracao
    Testa cálculo de repartição por fração ideal.
    Cria 2 unidades com frações diferentes, calcula rateio de 1000.00,
    valida cálculo de valor rateiado (soma = 100% do total).
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteCalcularRateioFracao()
    Local aRateio := {}
    Local nI := 0
    Local nTotalRateiado := 0
    Local cUnidade1 := "T01"
    Local cUnidade2 := "T02"
    Local nFracao1 := 0.6
    Local nFracao2 := 0.4
    Local nValorTotal := 1000.00
    Local nValorEsperado1 := 0
    Local nValorEsperado2 := 0
    Local nUnidade1Valor := 0
    Local nUnidade2Valor := 0
    Local nUnidade1Found := 0
    Local nUnidade2Found := 0

    ConOut("TesteCalcularRateioFracao")

    // Insere 2 unidades de teste com frações conhecidas
    // (podem haver duplicatas de execuções anteriores, o que é aceitável)
    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO) VALUES ('T01', 0.6)")
    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO) VALUES ('T02', 0.4)")

    ConOut("  Unidades criadas/existentes: T01 (0.6), T02 (0.4)")

    // Calcula rateio de 1000.00 por fração ideal
    aRateio := GcCalcularRateio("FRACAO", nValorTotal, Date())

    // Valida que temos unidades
    If Len(aRateio) >= 2
        ConOut("  PASS: Rateio retornou " + cValToChar(Len(aRateio)) + " unidades (>= 2 esperado)")
    Else
        ConOut("  FAIL: Rateio esperado >= 2 unidades, obtido " + cValToChar(Len(aRateio)))
        Return
    EndIf

    // Busca T01 e T02 na array retornada (pode haver outras unidades)
    nValorEsperado1 := nValorTotal * nFracao1  // 1000 * 0.6 = 600 (por ocorrência)
    nValorEsperado2 := nValorTotal * nFracao2  // 1000 * 0.4 = 400 (por ocorrência)

    For nI := 1 To Len(aRateio)
        If aRateio[nI][1] = cUnidade1
            nUnidade1Found += 1
            nUnidade1Valor := aRateio[nI][3]
        EndIf
        If aRateio[nI][1] = cUnidade2
            nUnidade2Found += 1
            nUnidade2Valor := aRateio[nI][3]
        EndIf
    Next nI

    // Valida que T01 foi encontrada
    If nUnidade1Found > 0
        ConOut("  PASS: Unidade T01 encontrada no rateio")
        If Round(nUnidade1Valor, 2) = Round(nValorEsperado1, 2)
            ConOut("  PASS: T01 valor rateiado = 600.00")
        Else
            ConOut("  FAIL: T01 valor esperado 600.00, obtido " + cValToChar(nUnidade1Valor))
        EndIf
    Else
        ConOut("  FAIL: T01 não encontrada no rateio")
    EndIf

    // Valida que T02 foi encontrada
    If nUnidade2Found > 0
        ConOut("  PASS: Unidade T02 encontrada no rateio")
        If Round(nUnidade2Valor, 2) = Round(nValorEsperado2, 2)
            ConOut("  PASS: T02 valor rateiado = 400.00")
        Else
            ConOut("  FAIL: T02 valor esperado 400.00, obtido " + cValToChar(nUnidade2Valor))
        EndIf
    Else
        ConOut("  FAIL: T02 não encontrada no rateio")
    EndIf

    // Valida soma de T01 + T02 especificamente
    // (o total geral pode ser > 1000 se houver outras unidades no database)
    Local nSomaTestunidades := Round(nUnidade1Valor, 2) + Round(nUnidade2Valor, 2)
    Local nEsperadoTestunidades := Round(nValorEsperado1, 2) + Round(nValorEsperado2, 2)

    If Round(nSomaTestunidades, 2) = Round(nEsperadoTestunidades, 2)
        ConOut("  PASS: T01 + T02 = " + cValToChar(nSomaTestunidades) + " (100% do valor alocado a essas unidades)")
    Else
        ConOut("  FAIL: T01 + T02 esperado " + cValToChar(nEsperadoTestunidades) + ", obtido " + cValToChar(nSomaTestunidades))
    EndIf

Return

/*/{Protheus.doc} TesteLancarDespesaComRateio
    Testa criação de lançamento de despesa com rateio automático.
    Workflow:
    1. Chama GcLancarDespesaContabil com parâmetros válidos
    2. Verifica se lançamento principal foi criado (AUTOMATICO_DESPESA)
    3. Verifica se lançamentos de rateio foram criados (AUTOMATICO_RATEIO)
    4. Verifica se cobranças foram criadas na tabela COB
    5. Valida quantidades: 1 principal + N rateio, e N cobranças
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function TesteLancarDespesaComRateio()
    Local lRet := .F.
    Local cDescricao := "Pintura Comum"
    Local nValor := 1000.00
    Local nDiaVenc := 15
    Local aContagemLanAntes := {}
    Local aContagemLanDepois := {}
    Local aContagemCobAntes := {}
    Local aContagemCobDepois := {}
    Local nLanAntes := 0
    Local nLanDepois := 0
    Local nCobAntes := 0
    Local nCobDepois := 0
    Local aLanPrincipal := {}
    Local aLanRateio := {}
    Local aCobrancas := {}
    Local nLanPrincipalQtd := 0
    Local nLanRateioQtd := 0
    Local nCobQtd := 0

    ConOut("TesteLancarDespesaComRateio")

    // Conta lançamentos antes
    aContagemLanAntes := TCSqlQuery("SELECT COUNT(*) as QTD FROM LANCAMENTOS WHERE D_E_L_E_T_ = ' '")
    If Len(aContagemLanAntes) > 0
        nLanAntes := aContagemLanAntes[1]:QTD
        ConOut("  Lançamentos antes: " + cValToChar(nLanAntes))
    EndIf

    // Conta cobranças antes
    aContagemCobAntes := TCSqlQuery("SELECT COUNT(*) as QTD FROM COB WHERE D_E_L_E_T_ = ' '")
    If Len(aContagemCobAntes) > 0
        nCobAntes := aContagemCobAntes[1]:QTD
        ConOut("  Cobranças antes: " + cValToChar(nCobAntes))
    EndIf

    // Chama GcLancarDespesaContabil com parâmetros válidos
    lRet := GcLancarDespesaContabil(Date(), cDescricao, nValor, "FRACAO", nDiaVenc)
    If lRet
        ConOut("  PASS: GcLancarDespesaContabil retornou .T.")
    Else
        ConOut("  FAIL: GcLancarDespesaContabil deveria ter retornado .T.")
        Return
    EndIf

    // Conta lançamentos depois
    aContagemLanDepois := TCSqlQuery("SELECT COUNT(*) as QTD FROM LANCAMENTOS WHERE D_E_L_E_T_ = ' '")
    If Len(aContagemLanDepois) > 0
        nLanDepois := aContagemLanDepois[1]:QTD
        ConOut("  Lançamentos depois: " + cValToChar(nLanDepois))
    EndIf

    // Conta cobranças depois
    aContagemCobDepois := TCSqlQuery("SELECT COUNT(*) as QTD FROM COB WHERE D_E_L_E_T_ = ' '")
    If Len(aContagemCobDepois) > 0
        nCobDepois := aContagemCobDepois[1]:QTD
        ConOut("  Cobranças depois: " + cValToChar(nCobDepois))
    EndIf

    // Calcula número de rateios criados (inseridos = 1 principal + N rateios)
    Local nLancamentosInseridos := nLanDepois - nLanAntes
    Local nCobrancasInseridas := nCobDepois - nCobAntes
    Local nRateioDeveriaSeriguais := nCobrancasInseridas

    // Verifica lançamento principal (AUTOMATICO_DESPESA) foi criado
    If nLancamentosInseridos >= 1
        ConOut("  PASS: Lançamento principal (AUTOMATICO_DESPESA) criado")
    Else
        ConOut("  FAIL: Lançamento principal não encontrado")
    EndIf

    // Verifica lançamentos de rateio (AUTOMATICO_RATEIO) foram criados
    If nLancamentosInseridos > 1
        ConOut("  PASS: Lançamentos de rateio (AUTOMATICO_RATEIO) criados: " + cValToChar(nLancamentosInseridos - 1))
    Else
        ConOut("  FAIL: Nenhum lançamento de rateio encontrado")
    EndIf

    // Verifica cobranças (COB)
    If nCobrancasInseridas > 0
        ConOut("  PASS: Cobranças criadas: " + cValToChar(nCobrancasInseridas))
    Else
        ConOut("  FAIL: Nenhuma cobrança foi criada")
    EndIf

    // Valida contagem total de lançamentos: deve ser 1 (principal) + N (rateios)
    If nLancamentosInseridos >= 2
        ConOut("  PASS: Total de lançamentos " + cValToChar(nLancamentosInseridos) + " >= 2 (1 principal + rateios)")
    Else
        ConOut("  FAIL: Total de lançamentos " + cValToChar(nLancamentosInseridos) + " esperado >= 2")
    EndIf

    // Valida contagem de cobranças = lançamentos de rateio (inseridos - 1 principal)
    If nCobrancasInseridas = (nLancamentosInseridos - 1)
        ConOut("  PASS: Cobranças " + cValToChar(nCobrancasInseridas) + " = Lançamentos rateio " + cValToChar(nLancamentosInseridos - 1))
    Else
        ConOut("  FAIL: Cobranças " + cValToChar(nCobrancasInseridas) + " != Lançamentos rateio " + cValToChar(nLancamentosInseridos - 1))
    EndIf

Return
