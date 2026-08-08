// tests/condominio_selecao_test.prw — GcSelecionarCondominio() é interativo
// (FWGetText) quando há mais de 1 condomínio disponível — mesma limitação
// já documentada em tests/login_test.prw e tests/usuarios_test.prw: sem
// UIProvider, FWGetText sempre devolve o default, então não dá pra dirigir
// o picker via `advplc run`. Este teste valida direto o que o picker faz
// por baixo: as duas queries SQL (SUPERADMIN vê tudo em COND; SINDICO só
// vê o que está vinculado via USR_COND) e a propagação de cLoginAtual.
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

/*/{Protheus.doc} RunCondominioSelecaoTests
    Ponto de entrada da suite de seleção de condomínio.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function RunCondominioSelecaoTests()
    AT06SuperAdminVeTudo()
    AT06SindicoVeSoVinculado()
    AT06LoginAtualPropaga()
    AT06SindicoUmVinculoAutoSeleciona()
    AT06SindicoZeroVinculosBloqueia()
Return

/*/{Protheus.doc} AT06SuperAdminVeTudo
    Reproduz a query que GcSelecionarCondominio roda para um USR_PERFIL =
    'SUPERADMIN': deve trazer todos os condomínios ativos em COND,
    independente de vínculo em USR_COND.
*/
User Function AT06SuperAdminVeTudo()
    Local lOk := .T.
    Local aCond

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'super_test'")
    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'super_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL IN ('090001', '090002', '090003')")

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('super_test', '" + ;
        GcSqlLit(FWHash("senha")) + "', 'SUPERADMIN')")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090001', 'Cond A', 1)")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090002', 'Cond B', 1)")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090003', 'Cond C Inativo', 0)")
    // Sem nenhuma linha em USR_COND para super_test -- SUPERADMIN não
    // depende de vínculo.

    // Mesma query usada dentro de GcSelecionarCondominio pro ramo SUPERADMIN.
    aCond := TCSqlQuery("SELECT COND_FILIAL, COND_NOME FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' " + ;
        "AND COND_FILIAL IN ('090001', '090002', '090003') ORDER BY COND_NOME")

    If Len(aCond) == 2
        ConOut("  PASS: SUPERADMIN vê os 2 condomínios ativos (ignora o inativo)")
    Else
        ConOut("  FALHA: SUPERADMIN deveria ver 2 condomínios ativos, achou " + Str(Len(aCond)))
        lOk := .F.
    EndIf

    If Len(aCond) == 2 .And. aCond[1]:COND_FILIAL == "090001" .And. aCond[2]:COND_FILIAL == "090002"
        ConOut("  PASS: retorno ordenado por COND_NOME (Cond A, Cond B)")
    Else
        ConOut("  FALHA: ordem/conteúdo inesperado do retorno SUPERADMIN")
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'super_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL IN ('090001', '090002', '090003')")
Return lOk

/*/{Protheus.doc} AT06SindicoVeSoVinculado
    Reproduz a query que GcSelecionarCondominio roda para um USR_PERFIL
    diferente de SUPERADMIN (SINDICO): só deve trazer os condomínios com
    vínculo ativo em USR_COND para aquele login.
*/
User Function AT06SindicoVeSoVinculado()
    Local lOk := .T.
    Local aCond

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'sindico_test'")
    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'sindico_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL IN ('090011', '090012', '090013')")

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('sindico_test', '" + ;
        GcSqlLit(FWHash("senha")) + "', 'SINDICO')")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090011', 'Cond X', 1)")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090012', 'Cond Y', 1)")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090013', 'Cond Z (sem vínculo)', 1)")

    // sindico_test só está vinculado a 090011 e 090012 -- 090013 fica de fora.
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('sindico_test', '090011')")
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('sindico_test', '090012')")

    // Mesma query usada dentro de GcSelecionarCondominio pro ramo != SUPERADMIN.
    aCond := TCSqlQuery("SELECT C.COND_FILIAL, C.COND_NOME FROM COND C " + ;
        "INNER JOIN USR_COND UC ON UC.FILIAL = C.COND_FILIAL AND UC.D_E_L_E_T_ = ' ' " + ;
        "WHERE UC.USR_LOGIN = 'sindico_test' AND C.COND_ATIVO = 1 AND C.D_E_L_E_T_ = ' ' " + ;
        "AND C.COND_FILIAL IN ('090011', '090012', '090013') ORDER BY C.COND_NOME")

    If Len(aCond) == 2
        ConOut("  PASS: SINDICO vê só os 2 condomínios vinculados (não vê o 3º)")
    Else
        ConOut("  FALHA: SINDICO deveria ver 2 condomínios vinculados, achou " + Str(Len(aCond)))
        lOk := .F.
    EndIf

    If Len(aCond) == 2 .And. aCond[1]:COND_FILIAL == "090011" .And. aCond[2]:COND_FILIAL == "090012"
        ConOut("  PASS: retorno restrito e ordenado por COND_NOME (Cond X, Cond Y)")
    Else
        ConOut("  FALHA: conteúdo/ordem inesperado do retorno SINDICO")
        lOk := .F.
    EndIf

    // Revogando o vínculo (soft delete), o condomínio some da lista.
    TCSqlExec("UPDATE USR_COND SET D_E_L_E_T_ = '*' WHERE USR_LOGIN = 'sindico_test' AND FILIAL = '090012'")

    aCond := TCSqlQuery("SELECT C.COND_FILIAL, C.COND_NOME FROM COND C " + ;
        "INNER JOIN USR_COND UC ON UC.FILIAL = C.COND_FILIAL AND UC.D_E_L_E_T_ = ' ' " + ;
        "WHERE UC.USR_LOGIN = 'sindico_test' AND C.COND_ATIVO = 1 AND C.D_E_L_E_T_ = ' ' " + ;
        "AND C.COND_FILIAL IN ('090011', '090012', '090013') ORDER BY C.COND_NOME")

    If Len(aCond) == 1 .And. aCond[1]:COND_FILIAL == "090011"
        ConOut("  PASS: vínculo revogado (D_E_L_E_T_='*') some da lista, sobra 1")
    Else
        ConOut("  FALHA: vínculo revogado deveria sumir da lista, achou " + Str(Len(aCond)))
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'sindico_test'")
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'sindico_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL IN ('090011', '090012', '090013')")
Return lOk

/*/{Protheus.doc} AT06LoginAtualPropaga
    GcCriarAdmin e GcAutenticar gravam cLoginAtual (Private declarado em
    gescon.prw, visível de GesCon() pra baixo) no sucesso -- é o valor que
    GesCon() repassa pra GcSelecionarCondominio(). Sem MSDIALOG/FWGetText
    dá pra chamar GcCredenciaisValidas diretamente (mesmo mecanismo que
    GcAutenticar usa por baixo) e confirmar que o USR_PERFIL gravado no
    bootstrap agora é SUPERADMIN, não ADMIN.
*/
User Function AT06LoginAtualPropaga()
    Local lOk := .T.
    Local aPerfil

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'boot_test'")

    // Mesmo INSERT que GcCriarAdmin agora executa (Step 1 do task-3-brief).
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('boot_test', '" + ;
        GcSqlLit(FWHash("senha_boot")) + "', 'SUPERADMIN')")

    If GcCredenciaisValidas("boot_test", "senha_boot")
        ConOut("  PASS: usuário de bootstrap autentica normalmente")
    Else
        ConOut("  FALHA: usuário de bootstrap deveria autenticar")
        lOk := .F.
    EndIf

    aPerfil := TCSqlQuery("SELECT USR_PERFIL FROM USR WHERE USR_LOGIN = 'boot_test' AND D_E_L_E_T_ = ' '")
    If Len(aPerfil) == 1 .And. AllTrim(aPerfil[1]:USR_PERFIL) == "SUPERADMIN"
        ConOut("  PASS: bootstrap grava USR_PERFIL = SUPERADMIN")
    Else
        ConOut("  FALHA: bootstrap deveria gravar USR_PERFIL = SUPERADMIN")
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'boot_test'")
Return lOk

/*/{Protheus.doc} AT06SindicoUmVinculoAutoSeleciona
    Caso-limite Len(aCond) == 1: GcSelecionarCondominio faz RpcSetEnv +
    grava g_cFilialAtiva e retorna .T. sem nunca chamar FWGetText -- o
    branch de auto-seleção retorna antes do picker ser montado, então dá
    pra chamar a função de verdade (não só reproduzir a query) e confirmar
    o comportamento fim-a-fim sem UI.
*/
User Function AT06SindicoUmVinculoAutoSeleciona()
    Local lOk := .T.
    Local lRet
    // g_cFilialAtiva precisa ser declarado Private AQUI, antes de chamar
    // GcSelecionarCondominio: em gescon.prw quem declara é GesCon(), e como
    // este teste chama a função direto (sem passar por GesCon()), sem esta
    // declaração o "g_cFilialAtiva := ..." dentro da função criaria uma
    // PRIVATE nova só visível no frame dela, liberada no Return -- este
    // teste não veria o valor gravado.
    Private g_cFilialAtiva := ""

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'sindico_um_test'")
    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'sindico_um_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL = '090021'")

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('sindico_um_test', '" + ;
        GcSqlLit(FWHash("senha")) + "', 'SINDICO')")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090021', 'Cond Único', 1)")
    TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('sindico_um_test', '090021')")

    lRet := GcSelecionarCondominio("sindico_um_test")

    If lRet
        ConOut("  PASS: síndico com 1 vínculo ativo -- GcSelecionarCondominio retorna .T. sem picker")
    Else
        ConOut("  FALHA: síndico com 1 vínculo ativo deveria auto-selecionar e retornar .T.")
        lOk := .F.
    EndIf

    If g_cFilialAtiva == "090021"
        ConOut("  PASS: g_cFilialAtiva gravado com o único COND_FILIAL vinculado (090021)")
    Else
        ConOut("  FALHA: g_cFilialAtiva deveria ser '090021', achou '" + g_cFilialAtiva + "'")
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'sindico_um_test'")
    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'sindico_um_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL = '090021'")
Return lOk

/*/{Protheus.doc} AT06SindicoZeroVinculosBloqueia
    Caso-limite Len(aCond) == 0: GcSelecionarCondominio deve bloquear
    (retornar .F.) sem quebrar e sem tentar montar o picker -- também sem
    nunca chamar FWGetText, então dá pra chamar a função direto.
*/
User Function AT06SindicoZeroVinculosBloqueia()
    Local lOk := .T.
    Local lRet
    Private g_cFilialAtiva := ""

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'sindico_zero_test'")
    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'sindico_zero_test'")

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('sindico_zero_test', '" + ;
        GcSqlLit(FWHash("senha")) + "', 'SINDICO')")
    // Nenhuma linha em USR_COND para este login -- 0 condomínios disponíveis.

    lRet := GcSelecionarCondominio("sindico_zero_test")

    If !lRet
        ConOut("  PASS: síndico sem vínculo algum -- GcSelecionarCondominio bloqueia (.F.)")
    Else
        ConOut("  FALHA: síndico sem vínculo deveria ser bloqueado (.F.)")
        lOk := .F.
    EndIf

    If Empty(g_cFilialAtiva)
        ConOut("  PASS: g_cFilialAtiva permanece vazio quando bloqueado")
    Else
        ConOut("  FALHA: g_cFilialAtiva não deveria ter sido gravado, achou '" + g_cFilialAtiva + "'")
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = 'sindico_zero_test'")
Return lOk

#include "../src/db.prw"
#include "../src/login.prw"
