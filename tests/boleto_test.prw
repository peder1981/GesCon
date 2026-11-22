// tests/boleto_test.prw -- codigo de barras e linha digitavel de boleto
// Itau (341) e Bradesco (237), conferidos contra os exemplos numericos
// dos manuais dos bancos:
//   - Itau, "Cobranca CNAB 400" (jan/2017): itens 7.3/7.4, anexos 2, 3, 4 e 6
//   - Bradesco, "Arquivos layout 400 posicoes" (abr/2022): "Montagem dos
//     Dados do Codigo de Barras" e "Composicao da Linha Digitavel"
// Chama as funcoes reais de src/boleto.prw (a versao anterior deste teste
// reimplementava a formula dentro do proprio teste e comparava copia com
// copia).
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito.
// `advplc run` escolhe sozinho o ponto de entrada: a primeira User
// Function cuja linha seja >= a primeira linha de codigo do arquivo raiz
// (pkg/compiler/codegen.go). Como #include cola o texto incluido no lugar,
// includes no topo empurram as funcoes dos modulos para antes do runner
// deste arquivo -- e a suite inteira roda em silencio. scripts/test.sh
// confere isso a cada execucao.

/*/{Protheus.doc} RunBoletoTests
    Ponto de entrada da suite de boletos. Precisa ser a primeira User
    Function do arquivo -- ver a nota sobre includes no topo.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function RunBoletoTests()
    Local nFalhas := 0 as numeric

    // Fator de vencimento (Itau, anexo 6): base 07/10/1997; 1000 = 03/07/2000;
    // 9999 = 21/02/2025; a partir de 22/02/2025 volta a 1000.
    nFalhas += Confere("fator 03/07/2000", GcBoletoFatorVenc(SToD("20000703")), 1000)
    nFalhas += Confere("fator 01/05/2002", GcBoletoFatorVenc(SToD("20020501")), 1667)
    nFalhas += Confere("fator 17/11/2010", GcBoletoFatorVenc(SToD("20101117")), 4789)
    nFalhas += Confere("fator 21/02/2025", GcBoletoFatorVenc(SToD("20250221")), 9999)
    nFalhas += Confere("fator 22/02/2025", GcBoletoFatorVenc(SToD("20250222")), 1000)
    nFalhas += Confere("fator 26/02/2025", GcBoletoFatorVenc(SToD("20250226")), 1004)
    nFalhas += Confere("fator data vazia", GcBoletoFatorVenc(CToD("")), 0)

    // Modulo 10 (Itau, anexo 3) e modulo 11 do codigo de barras (anexo 2)
    nFalhas += Confere("mod10 campo 1", GcBoletoMod10("341911012"), 1)
    nFalhas += Confere("mod10 campo 2", GcBoletoMod10("3456788005"), 8)
    nFalhas += Confere("mod10 campo 3", GcBoletoMod10("7123457000"), 1)
    nFalhas += Confere("mod10 DAC nosso numero", GcBoletoMod10("00571234511012345678"), 8)
    nFalhas += Confere("mod11 DAC barras", GcBoletoDacBarras("3419166700000123451101234567880057123457000"), 6)

    // Itau: exemplo do manual (ag 0057, conta 12345-7, carteira 110,
    // nosso numero 12345678-8, R$ 123,45, vencimento 01/05/2002)
    nFalhas += Confere("itau campo livre", ;
        GcBoletoCampoLivre("341", "0057", "12345", "110", "12345678"), ;
        "1101234567880057123457000")
    nFalhas += Confere("itau codigo de barras", ;
        GcBoletoCodigoBarras("341", "0057", "12345", "110", "12345678", SToD("20020501"), 123.45), ;
        "34196166700000123451101234567880057123457000")
    nFalhas += Confere("itau linha digitavel", ;
        GcBoletoLinhaDigitavel("341", "0057", "12345", "110", "12345678", SToD("20020501"), 123.45), ;
        "34191.10121 34567.880058 71234.570001 6 16670000012345")
    // Conta informada com DV ("12345-7") da o mesmo resultado
    nFalhas += Confere("itau conta com DV", ;
        GcBoletoCodigoBarras("341", "57", "12345-7", "110", "12345678", SToD("20020501"), 123.45), ;
        "34196166700000123451101234567880057123457000")
    // Carteiras 126/131/146/150/168: DAC do nosso numero so com carteira + nosso numero
    nFalhas += Confere("itau carteira 126 DAC", ;
        SubStr(GcBoletoCampoLivre("341", "0057", "12345", "126", "12345678"), 12, 1), ;
        cValToChar(GcBoletoMod10("12612345678")))

    // Bradesco: exemplo do manual (linha 23790.03102 40031.772003
    // 28009.527905 7 10010000000000). Campo livre = agencia 0031, carteira
    // 04, nosso numero 00317720028, conta 0095279, zero. Fator 1001 =
    // 23/02/2025 (depois do reinicio). Valor zerado como no manual.
    nFalhas += Confere("bradesco campo livre", ;
        GcBoletoCampoLivre("237", "0031", "0095279", "04", "00317720028"), ;
        "0031040031772002800952790")
    nFalhas += Confere("bradesco codigo de barras", ;
        GcBoletoCodigoBarras("237", "0031", "0095279", "04", "00317720028", SToD("20250223"), 0), ;
        "23797100100000000000031040031772002800952790")
    nFalhas += Confere("bradesco linha digitavel", ;
        GcBoletoLinhaDigitavel("237", "0031", "0095279", "04", "00317720028", SToD("20250223"), 0), ;
        "23790.03102 40031.772003 28009.527905 7 10010000000000")

    // Valor: 10 digitos, arredondado (nao para cima)
    nFalhas += Confere("valor 350,50", SubStr( ;
        GcBoletoCodigoBarras("341", "0057", "12345", "110", "12345678", SToD("20261210"), 350.5), 10, 10), ;
        "0000035050")
    nFalhas += Confere("valor 100,004 arredonda", SubStr( ;
        GcBoletoCodigoBarras("341", "0057", "12345", "110", "12345678", SToD("20261210"), 100.004), 10, 10), ;
        "0000010000")

    // Entradas recusadas devolvem ""
    nFalhas += Confere("banco nao suportado", ;
        GcBoletoCodigoBarras("001", "0057", "12345", "110", "12345678", SToD("20261210"), 10), "")
    nFalhas += Confere("sem vencimento", ;
        GcBoletoCodigoBarras("341", "0057", "12345", "110", "12345678", CToD(""), 10), "")
    nFalhas += Confere("valor negativo", ;
        GcBoletoCodigoBarras("341", "0057", "12345", "110", "12345678", SToD("20261210"), -1), "")
    nFalhas += Confere("agencia com letra", ;
        GcBoletoCodigoBarras("341", "00A7", "12345", "110", "12345678", SToD("20261210"), 10), "")
    nFalhas += Confere("nosso numero longo demais (itau)", ;
        GcBoletoCodigoBarras("341", "0057", "12345", "110", "123456789", SToD("20261210"), 10), "")
    nFalhas += Confere("carteira itau de 15 posicoes nao suportada", ;
        GcBoletoCodigoBarras("341", "0057", "12345", "198", "12345678", SToD("20261210"), 10), "")

    // Vencimento gravado pelo Fechamento (AAAA-MM-DD) e lido certo
    nFalhas += Confere("vencimento AAAA-MM-DD", DToS(GcBoletoDataVenc("2026-12-10")), "20261210")
    nFalhas += Confere("vencimento AAAAMMDD", DToS(GcBoletoDataVenc("20261210")), "20261210")
    nFalhas += Confere("vencimento invalido", DToS(GcBoletoDataVenc("2026-13-40")), "")

    If nFalhas == 0
        ConOut("boleto: todos os casos ok")
    Else
        ConOut("FALHA boleto: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/boleto.prw"
