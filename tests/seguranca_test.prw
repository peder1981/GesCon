// tests/seguranca_test.prw -- autenticação (etapa 2): Argon2id com salt,
// política de senha, bloqueio temporário após 5 erros, resposta igual para
// usuário inexistente e senha errada, migração do hash SHA-256 antigo,
// troca obrigatória, primeiro acesso sem senha padrão, login único.
#include "totvs.ch"

// Os #include dos modulos ficam no FIM do arquivo, de proposito (ver a
// nota em tests/boleto_test.prw).

/*/{Protheus.doc} SegurancaTest
    Ponto de entrada da suite. Precisa ser a primeira User Function.
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function SegurancaTest()
    Local nFalhas := 0 as numeric
    Local cSalt1  := GcNovoSalt() as character
    Local cSalt2  := GcNovoSalt() as character
    Local cHash   := "" as character
    Local aUsr    := {} as array
    Local nI      := 0 as numeric

    GcAdicionarColunasSeguranca()
    TCSqlExec("DELETE FROM USR")

    // Hash
    nFalhas += Confere("salt 32 hex", Len(cSalt1), 32)
    nFalhas += Confere("salts diferentes", cSalt1 != cSalt2, .T.)
    cHash := GcHashSenha("Senha#Forte1", cSalt1)
    nFalhas += Confere("hash com prefixo de versao", Left(cHash, 12), "argon2id$v1$")
    nFalhas += Confere("hash deterministico", GcHashSenha("Senha#Forte1", cSalt1) == cHash, .T.)
    nFalhas += Confere("salt muda o hash", GcHashSenha("Senha#Forte1", cSalt2) != cHash, .T.)
    nFalhas += Confere("salt vazio = sem hash", GcHashSenha("Senha#Forte1", ""), "")
    nFalhas += Confere("senha vazia = sem hash", GcHashSenha("", cSalt1), "")

    // Login
    nFalhas += Confere("login valido", GcLoginValido("ana.souza"), .T.)
    nFalhas += Confere("login curto", GcLoginValido("ab"), .F.)
    nFalhas += Confere("login com espaco", GcLoginValido("ana souza"), .F.)
    nFalhas += Confere("login com aspas", GcLoginValido("a'b"), .F.)
    nFalhas += Confere("login maiusculo vira minusculo", GcLoginNormal("  Ana.Souza "), "ana.souza")

    // Política
    nFalhas += Confere("senha forte", GcPoliticaSenha("Senha#Forte1", "ana"), "")
    nFalhas += Confere("senha curta", Empty(GcPoliticaSenha("Ab#1", "ana")), .F.)
    nFalhas += Confere("sem maiuscula", Empty(GcPoliticaSenha("senha#forte1", "ana")), .F.)
    nFalhas += Confere("sem minuscula", Empty(GcPoliticaSenha("SENHA#FORTE1", "ana")), .F.)
    nFalhas += Confere("sem digito", Empty(GcPoliticaSenha("Senha#Forte", "ana")), .F.)
    nFalhas += Confere("sem especial", Empty(GcPoliticaSenha("SenhaForte1", "ana")), .F.)
    nFalhas += Confere("contem o login", Empty(GcPoliticaSenha("Mariana#2026", "mariana")), .F.)

    // Primeiro acesso: sem senha configurada não cria ninguém
    nFalhas += Confere("boot sem senha nao cria", GcBootAdmin(""), .F.)
    nFalhas += Confere("nenhum usuario", Len(TCSqlQuery("SELECT 1 FROM USR")), 0)
    nFalhas += Confere("boot com senha fraca nao cria", GcBootAdmin("123456"), .F.)
    nFalhas += Confere("boot com senha forte cria", GcBootAdmin("Inicial#2026x"), .T.)
    aUsr := TCSqlQuery("SELECT USR_LOGIN, USR_PERFIL, USR_TROCA, USR_SENHA FROM USR WHERE D_E_L_E_T_ = ' '")
    nFalhas += Confere("1 usuario admin", Len(aUsr) == 1 .And. aUsr[1]:USR_LOGIN == "admin", .T.)
    nFalhas += Confere("admin super", aUsr[1]:USR_PERFIL, "SUPERADMIN")
    nFalhas += Confere("admin com troca obrigatoria", aUsr[1]:USR_TROCA, "S")
    nFalhas += Confere("senha nao em texto puro", "Inicial" $ aUsr[1]:USR_SENHA, .F.)
    nFalhas += Confere("boot de novo nao mexe", GcBootAdmin("Outra#Senha99"), .T.)
    nFalhas += Confere("primeiro login pede troca", GcAutenticarCredencial("admin", "Inicial#2026x"), "TROCA")
    nFalhas += Confere("troca com senha fraca recusada", Empty(GcDefinirSenha("admin", "fraca", .F.)), .F.)
    nFalhas += Confere("troca com senha forte", GcDefinirSenha("admin", "Nova#Senha2026", .F.), "")
    nFalhas += Confere("login com a nova", GcAutenticarCredencial("admin", "Nova#Senha2026"), "OK")
    nFalhas += Confere("login case-insensitive", GcAutenticarCredencial("ADMIN", "Nova#Senha2026"), "OK")
    nFalhas += Confere("senha antiga nao vale", GcAutenticarCredencial("admin", "Inicial#2026x"), "INVALIDO")

    // Inexistente e senha errada: mesma resposta
    nFalhas += Confere("usuario inexistente", GcAutenticarCredencial("ninguem", "Nova#Senha2026"), "INVALIDO")
    nFalhas += Confere("login com aspas", GcAutenticarCredencial("' OR '1'='1", "x"), "INVALIDO")

    // Bloqueio: 5 erros seguidos bloqueiam por 15 min, mesmo com a senha certa
    TCSqlExec("UPDATE USR SET USR_FALHAS = 0 WHERE USR_LOGIN = 'admin'")
    For nI := 1 To 4
        GcAutenticarCredencial("admin", "errada" + cValToChar(nI))
    Next nI
    nFalhas += Confere("4 erros ainda entra", GcAutenticarCredencial("admin", "Nova#Senha2026"), "OK")
    For nI := 1 To 5
        GcAutenticarCredencial("admin", "errada" + cValToChar(nI))
    Next nI
    nFalhas += Confere("5 erros bloqueia", GcAutenticarCredencial("admin", "Nova#Senha2026"), "BLOQUEADO")
    TCSqlExec("UPDATE USR SET USR_BLOQ_ATE = datetime('now', '-1 minute') WHERE USR_LOGIN = 'admin'")
    nFalhas += Confere("bloqueio vencido libera", GcAutenticarCredencial("admin", "Nova#Senha2026"), "OK")
    aUsr := TCSqlQuery("SELECT USR_FALHAS FROM USR WHERE USR_LOGIN = 'admin'")
    nFalhas += Confere("sucesso zera falhas", Val(aUsr[1]:USR_FALHAS), 0)

    // Hash antigo (SHA-256 sem salt) entra e é migrado para Argon2id
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('legado', '" + FWHash("velha123") + "', 'SINDICO')")
    nFalhas += Confere("legado entra", GcAutenticarCredencial("legado", "velha123"), "OK")
    aUsr := TCSqlQuery("SELECT USR_SENHA, USR_SALT FROM USR WHERE USR_LOGIN = 'legado'")
    nFalhas += Confere("legado migrado", Left(aUsr[1]:USR_SENHA, 12), "argon2id$v1$")
    nFalhas += Confere("legado com salt", Len(AllTrim(aUsr[1]:USR_SALT)), 32)
    nFalhas += Confere("legado segue entrando", GcAutenticarCredencial("legado", "velha123"), "OK")
    nFalhas += Confere("legado senha errada", GcAutenticarCredencial("legado", "velha124"), "INVALIDO")

    // Compatibilidade: GcCredenciaisValidas (troca de senha, portal)
    nFalhas += Confere("credenciais validas", GcCredenciaisValidas("admin", "Nova#Senha2026"), .T.)
    nFalhas += Confere("credenciais invalidas", GcCredenciaisValidas("admin", "x"), .F.)

    // Login único: não cria outro usuário com login existente (era o caminho
    // de um síndico virar super administrador)
    nFalhas += Confere("criar com login existente recusado", Empty(GcCriarUsuarioBase("Admin", "Outra#Senha99", "SINDICO")), .F.)
    nFalhas += Confere("ainda 1 admin", Len(TCSqlQuery("SELECT 1 FROM USR WHERE lower(USR_LOGIN) = 'admin' AND D_E_L_E_T_ = ' '")), 1)
    nFalhas += Confere("criar sindico novo", GcCriarUsuarioBase("bia", "Xyz#Senha2026", "SINDICO"), "")
    nFalhas += Confere("novo usuario com troca obrigatoria", GcAutenticarCredencial("bia", "Xyz#Senha2026"), "TROCA")
    nFalhas += Confere("criar com perfil invalido", Empty(GcCriarUsuarioBase("caio", "Caio#Senha2026", "DEUS")), .F.)
    nFalhas += Confere("indice unico de login", GcCriarIndiceUnicoUsr(), .T.)

    TCSqlExec("DELETE FROM USR")
    If nFalhas == 0
        ConOut("seguranca: todos os casos ok")
    Else
        ConOut("FALHA seguranca: " + cValToChar(nFalhas) + " caso(s)")
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
#include "../src/login.prw"
