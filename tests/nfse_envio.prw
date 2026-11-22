// tests/nfse_envio.prw -- envio da DPS à Sefin Nacional, contra a Sefin
// simulada de scripts/check-nfse.py (GESCON_NFSE_URL e SSL_CERT_FILE vêm de
// lá). Não segue o padrão *_test.prw de propósito: sozinho, sem o servidor,
// não tem para onde enviar.
#include "totvs.ch"

/*/{Protheus.doc} NfseEnvio
    Autoriza a primeira cobrança e vê a segunda ser rejeitada.
    @type User Function
    @author GesCon
    @since 2026-11-22
*/
User Function NfseEnvio()
    Local cPfx  := "tests/fixtures/nfse/a1-teste.pfx" as character
    Local aN    := {} as array
    Local nCob1 := 0 as numeric
    Local nCob2 := 0 as numeric
    Local cR1   := "" as character
    Local cR2   := "" as character
    Local cErro := "" as character
    Private cLoginAtual := "super.nf"
    Private g_cUniPortal := "", g_cConPortal := "", g_cFilialAtiva := "", g_lAutoPortal := .F., g_cCondNomePortal := ""

    RpcSetEnv("010101")
    TCSqlExec("DELETE FROM FIS")
    TCSqlExec("DELETE FROM NFS")
    TCSqlExec("DELETE FROM COB WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM UNI WHERE FILIAL = '010101'")
    TCSqlExec("DELETE FROM CON WHERE FILIAL = '010101'")
    TCSqlExec("UPDATE COND SET COND_CNPJ = '11222333000181' WHERE COND_FILIAL = '010101'")
    GcSalvarCondomino("C01", "Ana", "52998224725", "", "")
    GcSalvarUnidade("101", "", 0.5, "C01")
    GcSalvarUnidade("102", "", 0.5, "C01")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES " + ;
        "('101', '2026-10', 500, '2026-11-10', 'pendente', '010101'), ('102', '2026-10', 500, '2026-11-10', 'pendente', '010101')")
    GcSalvarFiscal("N", "", "3550308", "2", "1", cPfx)
    aN := TCSqlQuery("SELECT R_E_C_N_O_, COB_UNIDADE FROM COB WHERE FILIAL = '010101' ORDER BY COB_UNIDADE")
    nCob1 := Val(cValToChar(aN[1]:R_E_C_N_O_))
    nCob2 := Val(cValToChar(aN[2]:R_E_C_N_O_))

    cR1 := GcNfseEmitir(nCob1, "teste123")
    aN := TCSqlQuery("SELECT NFS_STATUS, NFS_CHAVE FROM NFS WHERE NFS_COB = " + cValToChar(nCob1))
    If !Empty(cR1) .Or. Len(aN) != 1 .Or. AllTrim(aN[1]:NFS_STATUS) != "autorizada" .Or. Len(AllTrim(aN[1]:NFS_CHAVE)) != 50
        cErro += " [autorizacao: " + cR1 + "]"
    EndIf
    cR2 := GcNfseEmitir(nCob2, "teste123")
    aN := TCSqlQuery("SELECT NFS_STATUS, NFS_RETORNO FROM NFS WHERE NFS_COB = " + cValToChar(nCob2))
    If !("E9999" $ cR2) .Or. Len(aN) != 1 .Or. AllTrim(aN[1]:NFS_STATUS) != "rejeitada"
        cErro += " [rejeicao: " + cR2 + "]"
    EndIf
    If Empty(cErro)
        ConOut("envio ok")
    Else
        ConOut("envio FALHOU" + cErro)
    EndIf
Return

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
