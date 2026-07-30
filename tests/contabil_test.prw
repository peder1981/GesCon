// tests/contabil_test.prw — testes das utilidades do sistema contábil
// TesteGcSqlLit, TesteGcExercicioAtivo, TesteGcPeriodoFechado
#include "totvs.ch"
#include "../src/contabil.prw"

/*/{Protheus.doc} ContabilTest
    Orquestrador dos testes contábeis.
    Executa: TesteGcSqlLit, TesteGcExercicioAtivo, TesteGcPeriodoFechado
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
