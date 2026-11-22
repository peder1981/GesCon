// tests/cadastros_test.prw -- gravação validada de condômino, unidade,
// despesa e condomínio (antes a grade genérica gravava qualquer coisa), e
// CPF/CNPJ com dígito verificador, inclusive o CNPJ alfanumérico (Receita
// Federal, a partir de julho de 2026; exemplo oficial do Serpro:
// 12.ABC.345/01DE-35).
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} CadastrosTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function CadastrosTest()
    Local nFalhas := 0 as numeric
    Local aR      := {} as array
    Local nRec    := 0 as numeric
    Private cLoginAtual := "sindico.teste"

    // Documentos
    nFalhas += Confere("cpf valido", GcDocumentoValido("529.982.247-25"), .T.)
    nFalhas += Confere("cpf dv errado", GcDocumentoValido("529.982.247-24"), .F.)
    nFalhas += Confere("cpf repetido", GcDocumentoValido("111.111.111-11"), .F.)
    nFalhas += Confere("cnpj numerico valido", GcDocumentoValido("11.222.333/0001-81"), .T.)
    nFalhas += Confere("cnpj numerico dv errado", GcDocumentoValido("11.222.333/0001-82"), .F.)
    nFalhas += Confere("cnpj alfanumerico oficial", GcDocumentoValido("12.ABC.345/01DE-35"), .T.)
    nFalhas += Confere("cnpj alfanumerico minusculo vira maiusculo", GcDocumentoValido("12.abc.345/01de-35"), .T.)
    nFalhas += Confere("cnpj alfanumerico dv errado", GcDocumentoValido("12.ABC.345/01DE-36"), .F.)
    nFalhas += Confere("cnpj com letra no dv", GcDocumentoValido("12.ABC.345/01DE-3A"), .F.)
    nFalhas += Confere("tamanho invalido", GcDocumentoValido("123"), .F.)
    nFalhas += Confere("documento normalizado", GcDocumentoNormal("12.abc.345/01de-35"), "12ABC34501DE35")

    RpcSetEnv("010101")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM CON WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM DES WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '010101'")

    // Condômino
    nFalhas += Confere("condomino sem nome", Empty(GcSalvarCondomino("C01", "", "", "", "")), .F.)
    nFalhas += Confere("condomino cpf invalido", Empty(GcSalvarCondomino("C01", "Ana", "123.456.789-00", "", "")), .F.)
    nFalhas += Confere("condomino email invalido", Empty(GcSalvarCondomino("C01", "Ana", "", "ana@", "")), .F.)
    nFalhas += Confere("condomino codigo invalido", Empty(GcSalvarCondomino("C 01", "Ana", "", "", "")), .F.)
    nFalhas += Confere("condomino ok", GcSalvarCondomino("C01", "Ana Souza", "529.982.247-25", "ana@exemplo.com.br", "(11) 99999-0000"), "")
    aR := TCSqlQuery("SELECT CON_NOME, CON_CPF FROM CON WHERE CON_CODIGO = 'C01' AND FILIAL = '010101' AND D_E_L_E_T_ = ' '")
    nFalhas += Confere("condomino gravado com cpf normalizado", Len(aR) == 1 .And. aR[1]:CON_CPF == "52998224725", .T.)
    nFalhas += Confere("condomino altera", GcSalvarCondomino("C01", "Ana S. Lima", "", "ana@exemplo.com.br", ""), "")
    aR := TCSqlQuery("SELECT CON_NOME FROM CON WHERE CON_CODIGO = 'C01' AND FILIAL = '010101' AND D_E_L_E_T_ = ' '")
    nFalhas += Confere("condomino alterado sem duplicar", Len(aR) == 1 .And. aR[1]:CON_NOME == "Ana S. Lima", .T.)

    // Unidade
    nFalhas += Confere("unidade fracao zero", Empty(GcSalvarUnidade("101", "A", 0, "C01")), .F.)
    nFalhas += Confere("unidade fracao maior que 1", Empty(GcSalvarUnidade("101", "A", 1.5, "C01")), .F.)
    nFalhas += Confere("unidade condomino inexistente", Empty(GcSalvarUnidade("101", "A", 0.5, "C99")), .F.)
    nFalhas += Confere("unidade ok", GcSalvarUnidade("101", "A", 0.5, "C01"), "")
    nFalhas += Confere("unidade sem condomino ok", GcSalvarUnidade("102", "A", 0.5, ""), "")
    nFalhas += Confere("unidade altera", GcSalvarUnidade("102", "B", 0.5, "C01"), "")
    aR := TCSqlQuery("SELECT COUNT(*) AS Q FROM UNI WHERE FILIAL = '010101' AND D_E_L_E_T_ = ' '")
    nFalhas += Confere("2 unidades", Val(aR[1]:Q), 2)
    nFalhas += Confere("excluir condomino com unidade recusado", Empty(GcExcluirCondomino("C01")), .F.)

    // Despesa
    nFalhas += Confere("despesa competencia invalida", Empty(GcSalvarDespesa(0, "Água", "AGUA", 300, "2026-13")), .F.)
    nFalhas += Confere("despesa valor zero", Empty(GcSalvarDespesa(0, "Água", "AGUA", 0, "2026-10")), .F.)
    nFalhas += Confere("despesa sem descricao", Empty(GcSalvarDespesa(0, "", "AGUA", 10, "2026-10")), .F.)
    nFalhas += Confere("despesa ok", GcSalvarDespesa(0, "Água", "AGUA", 300.555, "2026-10"), "")
    aR := TCSqlQuery("SELECT R_E_C_N_O_, DES_VALOR FROM DES WHERE FILIAL = '010101' AND D_E_L_E_T_ = ' '")
    nRec := Val(aR[1]:R_E_C_N_O_)
    nFalhas += Confere("despesa arredondada", Val(aR[1]:DES_VALOR), 300.56)
    nFalhas += Confere("despesa altera", GcSalvarDespesa(nRec, "Água e esgoto", "AGUA", 320, "2026-10"), "")
    // Competência fechada: despesa não muda mais
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('101', '2026-10', 160, '2026-11-10', 'pendente', '010101')")
    nFalhas += Confere("despesa de competencia fechada nao altera", Empty(GcSalvarDespesa(nRec, "X", "AGUA", 1, "2026-10")), .F.)
    nFalhas += Confere("despesa de competencia fechada nao exclui", Empty(GcExcluirDespesa(nRec)), .F.)
    nFalhas += Confere("nova despesa em competencia fechada recusada", Empty(GcSalvarDespesa(0, "Luz", "LUZ", 10, "2026-10")), .F.)
    nFalhas += Confere("excluir unidade com cobranca recusado", Empty(GcExcluirUnidade("101")), .F.)
    nFalhas += Confere("excluir unidade sem cobranca", GcExcluirUnidade("102"), "")

    // Condomínio (só super)
    nFalhas += Confere("sindico nao cria condominio", Empty(GcSalvarCondominio("", "Ed. Novo", "", "")), .F.)
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'super.teste'")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('super.teste', '-', 'SUPERADMIN')")
    cLoginAtual := "super.teste"
    nFalhas += Confere("condominio cnpj invalido", Empty(GcSalvarCondominio("", "Ed. Novo", "11.222.333/0001-82", "")), .F.)
    nFalhas += Confere("condominio novo", GcSalvarCondominio("", "Ed. Novo", "12.ABC.345/01DE-35", "Rua A, 1"), "")
    aR := TCSqlQuery("SELECT COND_FILIAL, COND_CNPJ FROM COND WHERE COND_NOME = 'Ed. Novo' AND D_E_L_E_T_ = ' '")
    nFalhas += Confere("condominio com filial de 6 digitos", Len(aR) == 1 .And. Len(AllTrim(aR[1]:COND_FILIAL)) == 6, .T.)
    nFalhas += Confere("condominio cnpj normalizado", aR[1]:COND_CNPJ, "12ABC34501DE35")

    TCSqlExec("DELETE FROM COND WHERE COND_NOME = 'Ed. Novo'")
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'super.teste'")
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM DES WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM CON WHERE FILIAL = '010101'")
    RpcSetEnv("      ")
    If nFalhas == 0
        ConOut("cadastros: todos os casos ok")
    Else
        ConOut("FALHA cadastros: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/cadastros.prw"
