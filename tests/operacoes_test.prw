// tests/operacoes_test.prw -- operações da interface web: token do portal
// (emitir, revogar, só da própria unidade), configuração do boleto,
// abertura de exercício e gestão de usuários com o escopo do perfil.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} OperacoesTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function OperacoesTest()
    Local nFalhas := 0 as numeric
    Local aT      := {} as array
    Local aQ      := {} as array
    Private cLoginAtual := "super.op"
    Private g_cUniPortal := "", g_cConPortal := "", g_cFilialAtiva := "", g_lAutoPortal := .F., g_cCondNomePortal := ""

    GcAdicionarColunasSeguranca()
    RpcSetEnv("010101")
    TCSqlExec("DELETE FROM USR")
    TCSqlExec("DELETE FROM USR_COND")
    TCSqlExec("DELETE FROM GCT_TOKEN")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM CON WHERE FILIAL = '010101'")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('super.op', '-', 'SUPERADMIN')")
    GcSalvarCondomino("C01", "Ana", "", "", "")
    GcSalvarUnidade("101", "", 0.5, "C01")
    GcSalvarUnidade("102", "", 0.5, "")

    // Token
    aT := GcEmitirToken("102")
    nFalhas += Confere("token recusado sem condomino", Empty(aT[1]) .And. !Empty(aT[3]), .T.)
    aT := GcEmitirToken("999")
    nFalhas += Confere("token recusado unidade inexistente", Empty(aT[1]), .T.)
    aT := GcEmitirToken("101")
    nFalhas += Confere("token emitido", Len(aT[1]), 64)
    nFalhas += Confere("validade em DD/MM/AAAA hh:mm", Len(aT[2]) == 16 .And. SubStr(aT[2], 3, 1) == "/", .T.)
    aQ := GcQTokens()
    nFalhas += Confere("lista de tokens sem o token", Len(aQ[2]) == 1 .And. aScan(aQ[2][1], aT[1]) == 0, .T.)
    nFalhas += Confere("emissor gravado", aQ[2][1][3], "super.op")
    nFalhas += Confere("revoga", GcRevogarTokenUnidade("101"), "")
    nFalhas += Confere("token revogado nao entra", GcAuthPortalToken(aT[1]), .F.)
    nFalhas += Confere("revogar sem token", Empty(GcRevogarTokenUnidade("101")), .F.)

    // Boleto
    nFalhas += Confere("cfg banco invalido", Empty(GcSalvarCfgBoleto("001", "0057", "12345", "", "110")), .F.)
    nFalhas += Confere("cfg carteira bradesco longa", Empty(GcSalvarCfgBoleto("237", "0031", "95279", "", "174")), .F.)
    nFalhas += Confere("cfg itau ok", GcSalvarCfgBoleto("341", "0057", "12345-7", "123", "110"), "")
    nFalhas += Confere("cfg uma por condominio", Len(TCSqlQuery("SELECT 1 FROM CFG_BOLETO WHERE FILIAL = '010101'")), 1)

    // Exercício
    TCSqlExec("DELETE FROM EXERCICIO WHERE FILIAL = '010101'")
    nFalhas += Confere("exercicio codigo invalido", Empty(GcAbrirExercicioDados("2026", "20260101", "20261231")), .F.)
    nFalhas += Confere("exercicio fim antes do inicio", Empty(GcAbrirExercicioDados("2026-01", "20261231", "20260101")), .F.)
    nFalhas += Confere("exercicio data inexistente", Empty(GcAbrirExercicioDados("2026-01", "20260230", "20261231")), .F.)
    nFalhas += Confere("exercicio ok", GcAbrirExercicioDados("2026-01", "20260101", "20261231"), "")
    nFalhas += Confere("exercicio repetido", Empty(GcAbrirExercicioDados("2026-01", "20260101", "20261231")), .F.)
    nFalhas += Confere("exercicio ativo", GcExercicioAtivo(), "2026-01")

    // Plano de contas e lançamento manual
    TCSqlExec("DELETE FROM PLANO_CONTAS WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE FILIAL = '010101'")
    nFalhas += Confere("conta codigo com letra", Empty(GcSalvarConta("10A", "Caixa", "ATIVO")), .F.)
    nFalhas += Confere("conta tipo invalido", Empty(GcSalvarConta("1000", "Caixa", "OUTRO")), .F.)
    nFalhas += Confere("conta caixa", GcSalvarConta("1000", "Caixa", "ATIVO"), "")
    nFalhas += Confere("conta receita", GcSalvarConta("3000", "Receita condominial", "RECEITA"), "")
    nFalhas += Confere("conta altera", GcSalvarConta("3000", "Receita de cotas", "RECEITA"), "")
    nFalhas += Confere("lancamento contas iguais", Empty(GcLancamentoManual(SToD("20260315"), "X", "1000", "1000", 10)), .F.)
    nFalhas += Confere("lancamento conta inexistente", Empty(GcLancamentoManual(SToD("20260315"), "X", "1000", "9999", 10)), .F.)
    nFalhas += Confere("lancamento fora do exercicio", Empty(GcLancamentoManual(SToD("20250315"), "X", "1000", "3000", 10)), .F.)
    nFalhas += Confere("lancamento sem historico", Empty(GcLancamentoManual(SToD("20260315"), "", "1000", "3000", 10)), .F.)
    nFalhas += Confere("lancamento ok", GcLancamentoManual(SToD("20260315"), "Cota de março", "1000", "3000", 1500), "")
    aQ := GcQBalancete("2026-01")
    nFalhas += Confere("balancete caixa (ativo) saldo devedor", aQ[2][1][1] == "1000" .And. aQ[2][1][6] == "1.500,00", .T.)
    nFalhas += Confere("balancete receita saldo credor", aQ[2][2][1] == "3000" .And. aQ[2][2][6] == "1.500,00", .T.)
    nFalhas += Confere("lancamentos listados", Len(GcQLancamentos("2026-01")[2]), 1)

    // Resultado do mês e indicadores
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM DES WHERE FILIAL = '010101'")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('101', '2026-03', 700, '2026-04-10', 'pago', '010101')")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('102', '2026-03', 300, '2000-01-10', 'pendente', '010101')")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_VALOR, DES_COMPET, FILIAL) VALUES ('Luz', 800, '2026-03', '010101')")
    aQ := GcResultadoMensal("2026-03")
    nFalhas += Confere("resultado: recebido, despesa, saldo, aberto", aQ[1] == 700 .And. aQ[2] == 800 .And. aQ[3] == -100 .And. aQ[4] == 300, .T.)
    aQ := GcIndicadores()
    nFalhas += Confere("indicadores: unidades e fracoes", aQ[1] == 2 .And. aQ[2] == 100, .T.)
    nFalhas += Confere("indicadores: atrasado", aQ[4] == 300 .And. aQ[5] == 1, .T.)
    nFalhas += Confere("inadimplencia lista a atrasada", Len(GcQInadimplencia()[2]), 1)
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM DES WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM LANCAMENTOS WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM PLANO_CONTAS WHERE FILIAL = '010101'")

    // Usuários
    nFalhas += Confere("super cria sindico", GcCriarUsuarioCondominio("bia", "Xyz#Senha2026", "SINDICO"), "")
    nFalhas += Confere("sindico vinculado ao condominio", Len(TCSqlQuery("SELECT 1 FROM USR_COND WHERE USR_LOGIN = 'bia' AND FILIAL = '010101'")), 1)
    nFalhas += Confere("super ve usuarios", Len(GcQUsuarios()[2]), 2)
    nFalhas += Confere("lista sem credencial", aScan(GcQUsuarios()[1], {|c| "SENHA" $ Upper(c[1]) .Or. "SALT" $ Upper(c[1])}), 0)
    nFalhas += Confere("super redefine senha", GcRedefinirSenha("bia", "Prov#Senha2026"), "")
    nFalhas += Confere("redefinida pede troca", GcAutenticarCredencial("bia", "Prov#Senha2026"), "TROCA")
    TCSqlExec("UPDATE USR SET USR_BLOQ_ATE = datetime('now', '+10 minutes') WHERE USR_LOGIN = 'bia'")
    nFalhas += Confere("desbloqueia", GcDesbloquearUsuario("bia"), "")
    nFalhas += Confere("desbloqueado entra", GcAutenticarCredencial("bia", "Prov#Senha2026"), "TROCA")
    nFalhas += Confere("nao redefine a propria", Empty(GcRedefinirSenha("super.op", "Prov#Senha2026")), .F.)

    // Síndico: só síndico do condomínio, não super
    cLoginAtual := "bia"
    nFalhas += Confere("sindico nao cria super", Empty(GcCriarUsuarioCondominio("caio", "Qwe#Xyz20260", "SUPERADMIN")), .F.)
    nFalhas += Confere("sindico cria sindico", GcCriarUsuarioCondominio("davi", "Qwe#Xyz20260", "SINDICO"), "")
    nFalhas += Confere("sindico ve so sindicos do condominio", Len(GcQUsuarios()[2]), 2)
    nFalhas += Confere("sindico nao mexe no super", Empty(GcRedefinirSenha("super.op", "Prov#Senha2026")), .F.)
    nFalhas += Confere("sindico redefine sindico do condominio", GcRedefinirSenha("davi", "Prov#Senha2026"), "")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('outro', '-', 'SINDICO')")
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('outro', '020202')")
    nFalhas += Confere("sindico nao mexe em sindico de outro condominio", Empty(GcDesbloquearUsuario("outro")), .F.)

    TCSqlExec("DELETE FROM USR")
    TCSqlExec("DELETE FROM USR_COND")
    TCSqlExec("DELETE FROM GCT_TOKEN")
    TCSqlExec("DELETE FROM CFG_BOLETO WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM EXERCICIO WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM CON WHERE FILIAL = '010101'")
    RpcSetEnv("      ")
    If nFalhas == 0
        ConOut("operacoes: todos os casos ok")
    Else
        ConOut("FALHA operacoes: " + cValToChar(nFalhas) + " caso(s)")
    EndIf
Return

/*/{Protheus.doc} Confere
    Compara obtido x esperado e imprime ok/FALHA.
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param cNome, character, nome do caso
    @param xObtido, variant, valor obtido
    @param xEsperado, variant, valor esperado
    @return numeric, 0 se bateu, 1 se falhou
*/
Static Function Confere(cNome, xObtido, xEsperado)
    If ValType(xObtido) == ValType(xEsperado) .And. xObtido == xEsperado
        ConOut("ok    " + cNome)
        Return 0
    EndIf
    ConOut("FALHA " + cNome + ": obtido [" + cValToChar(xObtido) + "] esperado [" + cValToChar(xEsperado) + "]")
Return 1

#include "../src/db.prw"
#include "../src/seguranca.prw"
#include "../src/fechamento.prw"
#include "../src/malas.prw"
#include "../src/boleto.prw"
#include "../src/usuarios.prw"
#include "../src/portal.prw"
#include "../src/contabil.prw"
#include "../src/cadastros.prw"
#include "../src/relatorios.prw"
#include "../src/consultas.prw"
#include "../src/operacoes.prw"
