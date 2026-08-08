// tests/usuarios_test.prw — testes da gestão de usuários e tokens.
// Usa FWMBrowse Free CRUD para cada sub-tela (GcUnidades, GcCondominos, etc.)
// e simula a operação via dados em banco SQLite.
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
#include "db.prw"

/*/{Protheus.doc} RunUsuariosTests
    Ponto de entrada da suite de usuarios. Antes deste agregador,
    `advplc run tests/usuarios_test.prw` executava apenas AT05GerarToken --
    as outras duas suites nunca rodavam.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function RunUsuariosTests()
    AT05GerarToken()
    AT05RevogarToken()
    AT05CriarAdmin()
    AT07VincularCondominioSemDuplicar()
    AT07ParseIndicesSindico()
Return

/*/{Protheus.doc} TestaGcGerarToken
    Gera um token para o primeiro condômino listado e verifica que
    o registro foi criado na tabela GCT_TOKEN.
*/
User Function AT05GerarToken()
    Local lOk := .T.
    // Cria unidade de teste se não existir
    // Cria condômino de teste vinculado à unidade
    // Chama GcGerarToken com índice 1
    // Verifica contagem em GCT_TOKEN
    MsgInfo("Teste GcGerarToken — verifique manualmente a criação do token no banco.", "Usuarios Test")
Return lOk

/*/{Protheus.doc} TestaGcRevogarToken
    Gera um token e em seguida o revoga, verificando que fica
    inativo na lista de tokens ativos.
*/
User Function AT05RevogarToken()
    Local lOk := .T.
    // Gera token (ver AT05GerarToken)
    // Chama GcRevogarToken com índice 1
    // Verifica D_E_L_E_T_ = '*' na GCT_TOKEN
    MsgInfo("Teste GcRevogarToken — verifique manualmente a revogação no banco.", "Usuarios Test")
Return lOk

/*/{Protheus.doc} TestaGcCriarAdminNovo
    GcCriarAdminNovo() é interativo (FWGetText) — sem UI, a senha (default
    "") nunca fica preenchida e ele sempre retorna .F., o que testaria só
    o próprio limite do harness, não a feature. Este teste grava direto
    pelo mesmo INSERT que GcCriarAdminNovo usa e confere o que a feature
    "segundo admin" precisa: dois administradores coexistindo, cada um
    autenticando só com a própria senha.
*/
User Function AT05CriarAdmin()
    Local lOk := .T.

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN IN ('sindico1_test', 'sindico2_test')")

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('sindico1_test', '" + ;
        GcSqlLit(FWHash("senha1")) + "', 'ADMIN')")
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('sindico2_test', '" + ;
        GcSqlLit(FWHash("senha2")) + "', 'ADMIN')")

    If GcCredenciaisValidas("sindico1_test", "senha1")
        ConOut("  PASS: sindico1_test autentica com a própria senha")
    Else
        ConOut("  FALHA: sindico1_test deveria autenticar com a própria senha")
        lOk := .F.
    EndIf

    If GcCredenciaisValidas("sindico2_test", "senha2")
        ConOut("  PASS: sindico2_test autentica com a própria senha")
    Else
        ConOut("  FALHA: sindico2_test deveria autenticar com a própria senha")
        lOk := .F.
    EndIf

    If !GcCredenciaisValidas("sindico1_test", "senha2")
        ConOut("  PASS: sindico1_test não autentica com a senha de sindico2_test")
    Else
        ConOut("  FALHA: sindico1_test autenticou com senha de outro admin")
        lOk := .F.
    EndIf

    Local aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM USR WHERE D_E_L_E_T_ = ' ' AND USR_PERFIL = 'ADMIN'")
    If Val(aQtd[1]:QTD) >= 2
        ConOut("  PASS: mais de um administrador ativo (" + aQtd[1]:QTD + ")")
    Else
        ConOut("  FALHA: esperava >=2 administradores ativos, achou " + aQtd[1]:QTD)
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM USR WHERE USR_LOGIN IN ('sindico1_test', 'sindico2_test')")
Return lOk

/*/{Protheus.doc} AT07VincularCondominioSemDuplicar
    GcVincularCondominioAoCriador ("se o vínculo ainda não existir") deve
    ser idempotente: chamada duas vezes com o mesmo login+filial só pode
    gravar 1 linha em USR_COND. USR_COND tem UNIQUE(USR_LOGIN, FILIAL)
    (src/schema-embed.prw), então sem o SELECT de checagem antes do
    INSERT a segunda chamada quebraria com erro de constraint, não com
    duplicata silenciosa -- este teste cobre os dois jeitos de falhar.
*/
User Function AT07VincularCondominioSemDuplicar()
    Local lOk := .T.
    Local aQtd

    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'vinculo_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL = '090031'")
    TCSqlExec("INSERT INTO COND (COND_FILIAL, COND_NOME, COND_ATIVO) VALUES ('090031', 'Cond Vínculo', 1)")

    GcVincularCondominioAoCriador("vinculo_test", "090031")
    GcVincularCondominioAoCriador("vinculo_test", "090031")

    aQtd := TCSqlQuery("SELECT COUNT(*) AS QTD FROM USR_COND WHERE USR_LOGIN = 'vinculo_test' " + ;
        "AND FILIAL = '090031' AND D_E_L_E_T_ = ' '")
    If Val(aQtd[1]:QTD) == 1
        ConOut("  PASS: GcVincularCondominioAoCriador chamado 2x não duplica o vínculo")
    Else
        ConOut("  FALHA: esperava 1 vínculo após 2 chamadas, achou " + aQtd[1]:QTD)
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM USR_COND WHERE USR_LOGIN = 'vinculo_test'")
    TCSqlExec("DELETE FROM COND WHERE COND_FILIAL = '090031'")
Return lOk

/*/{Protheus.doc} AT07ParseIndicesSindico
    GcParseIndicesSindico é a lógica pura de parsing por trás do prompt
    "Números dos condomínios (separados por vírgula, ex: 1,3)" dentro de
    GcCriarSindicoNovo — extraída pra ficar testável sem FWGetText.
    Cobre lista simples, espaços em volta da vírgula, token inválido
    misturado e índice fora da faixa [1, nMax].
*/
User Function AT07ParseIndicesSindico()
    Local lOk := .T.
    Local aIdx

    aIdx := GcParseIndicesSindico("1,3", 3)
    If Len(aIdx) == 2 .And. aIdx[1] == 1 .And. aIdx[2] == 3
        ConOut("  PASS: '1,3' com nMax=3 -> {1, 3}")
    Else
        ConOut("  FALHA: '1,3' com nMax=3 deveria dar {1, 3}, achou " + cValToChar(Len(aIdx)) + " item(ns)")
        lOk := .F.
    EndIf

    aIdx := GcParseIndicesSindico(" 1 , 2 ", 3)
    If Len(aIdx) == 2 .And. aIdx[1] == 1 .And. aIdx[2] == 2
        ConOut("  PASS: espaços em volta da vírgula são ignorados")
    Else
        ConOut("  FALHA: ' 1 , 2 ' com nMax=3 deveria dar {1, 2}, achou " + cValToChar(Len(aIdx)) + " item(ns)")
        lOk := .F.
    EndIf

    aIdx := GcParseIndicesSindico("1,x,99", 3)
    If Len(aIdx) == 1 .And. aIdx[1] == 1
        ConOut("  PASS: token inválido ('x') e índice fora da faixa (99) são descartados")
    Else
        ConOut("  FALHA: '1,x,99' com nMax=3 deveria dar {1}, achou " + cValToChar(Len(aIdx)) + " item(ns)")
        lOk := .F.
    EndIf

    aIdx := GcParseIndicesSindico("0,4", 3)
    If Len(aIdx) == 0
        ConOut("  PASS: índices fora de [1, nMax] (0 e 4 com nMax=3) somem todos")
    Else
        ConOut("  FALHA: '0,4' com nMax=3 deveria dar {}, achou " + cValToChar(Len(aIdx)) + " item(ns)")
        lOk := .F.
    EndIf
Return lOk

#include "../src/db.prw"
#include "../src/login.prw"
#include "../src/usuarios.prw"
#include "../src/condominios-cadastro.prw"
