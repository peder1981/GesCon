// tests/login_test.prw — GcLogin/GcCriarAdmin/GcAutenticar dependem de
// FWGetText, que em execução headless sempre retorna o valor default
// (sem UIProvider) — não dá pra testar o fluxo interativo via
// `advplc run` (mesmo motivo de GcUnidades/GcCondominos/etc nunca serem
// testadas assim). Este teste valida o mecanismo que GcAutenticar usa
// por baixo: FWHash + comparação de hash na tabela USR.
#include "totvs.ch"
#include "../src/db.prw"

User Function LoginTest()
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'testeuser'")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA) VALUES ('testeuser', '" + FWHash("senha_certa") + "')")

    // Senha certa: deve achar a linha
    Local aOk := TCSqlQuery("SELECT USR_LOGIN FROM USR WHERE USR_LOGIN = 'testeuser' AND USR_SENHA = '" + ;
        FWHash("senha_certa") + "' AND D_E_L_E_T_ = ' '")
    ConOut("senha_certa_qtd=" + Str(Len(aOk)))

    // Senha errada: não deve achar nada
    Local aErrada := TCSqlQuery("SELECT USR_LOGIN FROM USR WHERE USR_LOGIN = 'testeuser' AND USR_SENHA = '" + ;
        FWHash("senha_errada") + "' AND D_E_L_E_T_ = ' '")
    ConOut("senha_errada_qtd=" + Str(Len(aErrada)))

    // Confirma que a senha NÃO fica gravada em texto puro
    Local aRaw := TCSqlQuery("SELECT USR_SENHA FROM USR WHERE USR_LOGIN = 'testeuser'")
    ConOut("senha_nao_e_texto_puro=" + cValToChar(aRaw[1]:USR_SENHA != "senha_certa"))

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'testeuser'")
Return
