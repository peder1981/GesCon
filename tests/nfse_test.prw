// tests/nfse_test.prw -- reforma tributária: dados fiscais, regime, teste
// dos 80%, montagem/assinatura/numeração da DPS. O envio (rede) fica em
// scripts/check-nfse.py, que também valida o XML no XSD e confere a
// assinatura com bibliotecas independentes.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} NfseTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-22
*/
User Function NfseTest()
    Local nFalhas := 0 as numeric
    Local aT      := {} as array
    Local aD      := {} as array
    Local aG      := {} as array
    Local aN      := {} as array
    Local cPfx    := "tests/fixtures/nfse/a1-teste.pfx" as character
    Local nCob1   := 0 as numeric
    Local nCob2   := 0 as numeric
    Local cSaida  := GetEnv("GESCON_NFSE_SAIDA") as character
    Private cLoginAtual := "super.nf"
    Private g_cUniPortal := "", g_cConPortal := "", g_cFilialAtiva := "", g_lAutoPortal := .F., g_cCondNomePortal := ""

    RpcSetEnv("010101")
    TCSqlExec("DELETE FROM FIS")
    TCSqlExec("DELETE FROM REC")
    TCSqlExec("DELETE FROM NFS")
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM CON WHERE FILIAL = '010101'")
    TCSqlExec("UPDATE COND SET COND_CNPJ = '' WHERE COND_FILIAL = '010101'")

    // Datas
    nFalhas += Confere("31/01 + 1 mes = 28/02", DToS(GcMaisMeses(SToD("20270131"), 1)), "20270228")
    nFalhas += Confere("29/02/2028 + 12 meses", DToS(GcMaisMeses(SToD("20280229"), 12)), "20290228")
    nFalhas += Confere("22/11/2026 - 11 meses", DToS(GcMaisMeses(SToD("20261122"), -11)), "20251222")
    nFalhas += Confere("31/03 - 1 mes = 28/02", DToS(GcMaisMeses(SToD("20270331"), -1)), "20270228")
    nFalhas += Confere("fim da competencia", DToS(GcFimDaCompetencia("2028-02")), "20280229")
    nFalhas += Confere("data iso", GcIsoData("20270110"), "2027-01-10")
    nFalhas += Confere("data iso invalida", GcIsoData("20270231"), "")
    nFalhas += Confere("agora em Brasilia", Len(GcAgoraBrasilia()) == 25 .And. Right(GcAgoraBrasilia(), 6) == "-03:00" .And. ;
        SubStr(GcAgoraBrasilia(), 11, 1) == "T", .T.)
    nFalhas += Confere("xml escapa", GcXmlTexto(" A & B <x>" + Chr(10) + "  c "), "A &amp; B &lt;x&gt; c")

    // Dados fiscais
    nFalhas += Confere("padrao: nao optante, homologacao", GcFiscalCfg()[1] + GcFiscalCfg()[5], "N2")
    nFalhas += Confere("municipio invalido", Empty(GcSalvarFiscal("N", "", "355030", "2", "1", "")), .F.)
    nFalhas += Confere("serie invalida", Empty(GcSalvarFiscal("N", "", "3550308", "2", "90000", "")), .F.)
    nFalhas += Confere("ambiente invalido", Empty(GcSalvarFiscal("N", "", "3550308", "3", "1", "")), .F.)
    nFalhas += Confere("certificado inexistente", Empty(GcSalvarFiscal("N", "", "3550308", "2", "1", "/nao/existe.pfx")), .F.)
    nFalhas += Confere("opcao sem data", Empty(GcSalvarFiscal("R", "", "3550308", "2", "1", cPfx)), .F.)
    nFalhas += Confere("grava nao optante", GcSalvarFiscal("N", "", "3550308", "2", "1", cPfx), "")
    nFalhas += Confere("um registro por condominio", Len(TCSqlQuery("SELECT 1 FROM FIS WHERE FILIAL = '010101'")), 1)
    nFalhas += Confere("regime N", GcRegimeEm(Date()), "N")

    // Opção pelo regime regular e renúncia (Decreto 12.955/2026, art. 25)
    nFalhas += Confere("opta em 01/02/2027", GcSalvarFiscal("R", "01/02/2027", "3550308", "2", "1", cPfx), "")
    nFalhas += Confere("antes da opcao: N", GcRegimeEm(SToD("20270131")), "N")
    nFalhas += Confere("depois da opcao: R", GcRegimeEm(SToD("20270201")), "R")
    nFalhas += Confere("renuncia antes de 12 meses recusada", Empty(GcSalvarFiscal("N", "", "3550308", "2", "1", cPfx)), .F.)
    TCSqlExec("UPDATE FIS SET FIS_DT_OPCAO = '20250110' WHERE FILIAL = '010101'")
    nFalhas += Confere("renuncia depois de 12 meses", GcSalvarFiscal("N", "", "3550308", "2", "1", cPfx), "")
    nFalhas += Confere("renuncia: optante ate 31/12 do ano", GcRegimeEm(SToD(Left(DToS(Date()), 4) + "1231")), "R")
    nFalhas += Confere("renuncia: nao optante no ano seguinte", GcRegimeEm(SToD(cValToChar(Year(Date()) + 1) + "0101")), "N")
    TCSqlExec("UPDATE FIS SET FIS_DT_OPCAO = '', FIS_DT_RENUNCIA = '' WHERE FILIAL = '010101'")

    // Receitas e teste dos 80% (LC 214/2025, art. 26, § 2º, II)
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES " + ;
        "('101', '2027-01', 700, '2027-02-10', 'pendente', '010101'), ('102', '2027-01', 100, '2027-02-10', 'pendente', '010101')")
    nFalhas += Confere("receita competencia invalida", Empty(GcSalvarReceita(0, "2027-13", "Antena", "T", 100)), .F.)
    nFalhas += Confere("receita origem invalida", Empty(GcSalvarReceita(0, "2027-01", "Antena", "X", 100)), .F.)
    nFalhas += Confere("receita valor zero", Empty(GcSalvarReceita(0, "2027-01", "Antena", "T", 0)), .F.)
    nFalhas += Confere("receita de terceiros", GcSalvarReceita(0, "2027-01", "Aluguel de antena", "T", 150), "")
    nFalhas += Confere("receita financeira", GcSalvarReceita(0, "2027-01", "Rendimento", "F", 50), "")
    aT := GcTeste80("2027-01", "2027-01")
    nFalhas += Confere("80%: taxas 800 de 1000", aT[1] == 800 .And. aT[4] == 1000 .And. aT[5] == 80, .T.)
    nFalhas += Confere("80%: exatamente 80 = nao contribuinte", "Não contribuinte" $ aT[6], .T.)
    nFalhas += Confere("receita dos condominos", GcSalvarReceita(0, "2027-01", "Multa", "C", 10), "")
    TCSqlExec("UPDATE REC SET REC_VALOR = 300 WHERE REC_TIPO = 'T'")
    aT := GcTeste80("2027-01", "2027-01")
    nFalhas += Confere("80%: 810 de 1160", aT[1] == 810 .And. aT[4] == 1160, .T.)
    nFalhas += Confere("80%: abaixo avisa", "menos de 80%" $ aT[6], .T.)
    nFalhas += Confere("sem receita", "Sem receita" $ GcTeste80("2026-01", "2026-01")[6], .T.)
    aN := TCSqlQuery("SELECT R_E_C_N_O_ FROM REC WHERE REC_TIPO = 'C'")
    nFalhas += Confere("exclui receita", GcExcluirReceita(Val(cValToChar(aN[1]:R_E_C_N_O_))), "")
    nFalhas += Confere("excluida some do teste", GcTeste80("2027-01", "2027-01")[1], 800)

    // DPS
    aN := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = '101' AND FILIAL = '010101'")
    nCob1 := Val(cValToChar(aN[1]:R_E_C_N_O_))
    aN := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = '102' AND FILIAL = '010101'")
    nCob2 := Val(cValToChar(aN[1]:R_E_C_N_O_))
    nFalhas += Confere("dps sem CNPJ do condominio", "CNPJ do condomínio" $ GcNfseDps(nCob1, "1", 1, GcAgoraBrasilia())[3], .T.)
    TCSqlExec("UPDATE COND SET COND_CNPJ = '11.222.333/0001-81' WHERE COND_FILIAL = '010101'")
    nFalhas += Confere("dps sem condomino", "condômino" $ GcNfseDps(nCob1, "1", 1, GcAgoraBrasilia())[3], .T.)
    GcSalvarCondomino("C01", "Ana & Filhos", "529.982.247-25", "", "")
    GcSalvarCondomino("C02", "Empresa X", "11.444.777/0001-61", "", "")
    GcSalvarUnidade("101", "", 0.7, "C01")
    GcSalvarUnidade("102", "", 0.3, "C02")
    aD := GcNfseDps(nCob1, "1", 7, "2027-02-01T10:00:00-03:00")
    nFalhas += Confere("dps ok", aD[3], "")
    nFalhas += Confere("id da dps", aD[1], "DPS3550308211222333000181" + "00001" + "000000000000007")
    nFalhas += Confere("dps 99.05.01", "<cTribNac>990501</cTribNac>" $ aD[2], .T.)
    nFalhas += Confere("dps nao optante 410012", "<CST>410</CST><cClassTrib>410012</cClassTrib>" $ aD[2], .T.)
    nFalhas += Confere("dps valor", "<vServ>700.00</vServ>" $ aD[2] .And. "<vCobranca>700.00</vCobranca>" $ aD[2], .T.)
    nFalhas += Confere("dps vencimento original", "<dVencOrig>2027-02-10</dVencOrig>" $ aD[2], .T.)
    nFalhas += Confere("dps tomador CPF", "<toma><CPF>52998224725</CPF><xNome>Ana &amp; Filhos</xNome></toma>" $ aD[2], .T.)
    nFalhas += Confere("dps tomador CNPJ", "<toma><CNPJ>11444777000161</CNPJ>" $ GcNfseDps(nCob2, "1", 8, GcAgoraBrasilia())[2], .T.)
    TCSqlExec("UPDATE FIS SET FIS_REGIME = 'R', FIS_DT_OPCAO = '20270101' WHERE FILIAL = '010101'")
    nFalhas += Confere("dps optante 200046", "<CST>200</CST><cClassTrib>200046</cClassTrib>" $ GcNfseDps(nCob1, "1", 7, GcAgoraBrasilia())[2], .T.)
    TCSqlExec("UPDATE FIS SET FIS_REGIME = 'N', FIS_DT_OPCAO = '' WHERE FILIAL = '010101'")

    // Assinatura e numeração
    aG := GcNfseGerar(nCob1, "senha-errada")
    nFalhas += Confere("senha errada", "certificado" $ aG[1] .And. aG[2] == 0, .T.)
    nFalhas += Confere("senha errada nao gasta numero", GcFiscalCfg()[7], 0)
    aG := GcNfseGerar(nCob1, "teste123")
    nFalhas += Confere("gera e assina", aG[1], "")
    aN := TCSqlQuery("SELECT NFS_NDPS, NFS_STATUS, NFS_XML, NFS_ID FROM NFS WHERE R_E_C_N_O_ = " + cValToChar(aG[2]))
    nFalhas += Confere("dps numero 1", Val(cValToChar(aN[1]:NFS_NDPS)), 1)
    nFalhas += Confere("situacao assinada", AllTrim(aN[1]:NFS_STATUS), "assinada")
    nFalhas += Confere("tem assinatura", "<SignatureValue>" $ aN[1]:NFS_XML .And. '<Reference URI="#' + AllTrim(aN[1]:NFS_ID) + '">' $ aN[1]:NFS_XML, .T.)
    nFalhas += Confere("tem certificado", "<X509Certificate>MII" $ aN[1]:NFS_XML, .T.)
    nFalhas += Confere("sem arquivo temporario de chave", Len(Directory(GetTempPath() + "/gescon-*")), 0)
    If !Empty(cSaida)
        MemoWrite(cSaida, aN[1]:NFS_XML)
    EndIf
    aG := GcNfseGerar(nCob1, "teste123")
    nFalhas += Confere("regerar reaproveita o numero", Val(cValToChar(TCSqlQuery("SELECT NFS_NDPS FROM NFS WHERE R_E_C_N_O_ = " + ;
        cValToChar(aG[2]))[1]:NFS_NDPS)), 1)
    nFalhas += Confere("uma dps por cobranca", Len(TCSqlQuery("SELECT 1 FROM NFS WHERE NFS_COB = " + cValToChar(nCob1))), 1)
    aG := GcNfseGerar(nCob2, "teste123")
    nFalhas += Confere("outra cobranca: numero 2", Val(cValToChar(TCSqlQuery("SELECT NFS_NDPS FROM NFS WHERE R_E_C_N_O_ = " + ;
        cValToChar(aG[2]))[1]:NFS_NDPS)), 2)
    TCSqlExec("UPDATE NFS SET NFS_STATUS = 'autorizada' WHERE NFS_COB = " + cValToChar(nCob2))
    nFalhas += Confere("autorizada nao refaz", "já tem NFS-e" $ GcNfseGerar(nCob2, "teste123")[1], .T.)
    nFalhas += Confere("outro condominio nao ve a cobranca", "não encontrada" $ GcNfseDpsOutraFilial(nCob1), .T.)

    // Resposta da Sefin
    nFalhas += Confere("chave da resposta", GcJsonTexto('{"chaveAcesso":"355030821122233300018100000000000000126010000001","idDps":"x"}', "chaveAcesso"), ;
        "355030821122233300018100000000000000126010000001")
    nFalhas += Confere("json invalido", GcJsonTexto("<html>", "chaveAcesso"), "")
    nFalhas += Confere("erros da resposta", GcNfseErros('{"erros":[{"Codigo":"E0001","Descricao":"Falha A"},{"Codigo":"E0002","Descricao":"Falha B"}]}'), ;
        "E0001 Falha A; E0002 Falha B")
    nFalhas += Confere("url padrao: producao restrita", "producaorestrita" $ GcNfseUrlBase("2") .Or. !Empty(GetEnv("GESCON_NFSE_URL")), .T.)

    ConOut("")
    If nFalhas == 0
        ConOut("NfseTest: todos os casos passaram")
    Else
        ConOut("NfseTest: " + cValToChar(nFalhas) + " FALHA(S)")
    EndIf
Return

// A mesma cobrança vista de outro condomínio.
Static Function GcNfseDpsOutraFilial(nCob)
    Local cRet := "" as character

    RpcSetEnv("020202")
    cRet := GcNfseDps(nCob, "1", 1, GcAgoraBrasilia())[3]
    RpcSetEnv("010101")
Return cRet

/*/{Protheus.doc} Confere
    Compara obtido x esperado e imprime ok/FALHA.
    @type Static Function
    @author GesCon
    @since 2026-11-22
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
#include "../src/fiscal.prw"
#include "../src/nfse.prw"
