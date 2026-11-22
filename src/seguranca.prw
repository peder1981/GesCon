// src/seguranca.prw — autenticação e senhas.
//
// - Senha: Argon2id (RFC 9106, nativo do AdvPP) com salt aleatório por
//   usuário. Guardada em USR_SENHA como "argon2id$v1$<base64 do digest>";
//   v1 = memória 64 MiB, 2 iterações, 2 lanes, 32 bytes. O prefixo separa o
//   hash antigo (SHA-256 sem salt, 64 hex) do novo e deixa trocar os
//   parâmetros no futuro sem perder as senhas gravadas.
// - Hash antigo: aceito uma última vez e regravado em Argon2id no próprio
//   login bem-sucedido.
// - 5 erros seguidos bloqueiam o usuário por 15 minutos (relógio do banco).
//   Usuário inexistente e senha errada dão a mesma resposta (e o mesmo
//   custo: o Argon2id roda nos dois casos).
// - Primeiro acesso: sem usuários, o administrador só nasce com a senha de
//   GESCON_ADMIN_SENHA (ambiente do servidor) e com troca obrigatória. Não
//   há senha padrão e ninguém cria administrador pela tela.
#include "totvs.ch"

#define GC_HASH_V1 "argon2id$v1$"
#define GC_MAX_FALHAS 5

/*/{Protheus.doc} GcNovoSalt
    Salt aleatório: 32 hexadecimais de um UUID v4 do runtime (gerador
    criptográfico).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return character, 32 hex, ou "" se o runtime não gerou UUID
*/
User Function GcNovoSalt()
    Local cSalt := Lower(StrTran(AllTrim(UUIDRandom()), "-", "")) as character

    If Len(cSalt) != 32
        Return ""
    EndIf
Return cSalt

/*/{Protheus.doc} GcHashSenha
    Hash da senha no formato v1 (ver o cabeçalho do arquivo).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cSenha, character, senha em texto
    @param cSalt, character, salt do usuário
    @return character, "argon2id$v1$..." ou "" se senha ou salt vazios
*/
User Function GcHashSenha(cSenha, cSalt)
    Local cDigest := "" as character

    If ValType(cSenha) != "C" .Or. ValType(cSalt) != "C" .Or. Empty(cSenha) .Or. Empty(cSalt)
        Return ""
    EndIf
    cDigest := Argon2id(cSenha, cSalt, 65536, 2, 2, 32)
    If Empty(cDigest)
        Return ""
    EndIf
Return GC_HASH_V1 + Encode64(cDigest)

/*/{Protheus.doc} GcLoginNormal
    Login sem espaços nas pontas e em minúsculas (login não diferencia
    maiúsculas).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login digitado
    @return character, login normalizado
*/
User Function GcLoginNormal(cLogin)
    If ValType(cLogin) != "C"
        Return ""
    EndIf
Return Lower(AllTrim(cLogin))

/*/{Protheus.doc} GcLoginValido
    Login de 3 a 30 caracteres: letras minúsculas, dígitos, ponto, hífen e
    sublinhado (depois de normalizado). Só isso chega ao SQL.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login
    @return logical, .T. se válido
*/
User Function GcLoginValido(cLogin)
    Local cL := "" as character
    Local nI := 0 as numeric

    If ValType(cLogin) != "C"
        Return .F.
    EndIf
    cL := cLogin
    If Len(cL) < 3 .Or. Len(cL) > 30 .Or. cL != GcLoginNormal(cL)
        Return .F.
    EndIf
    For nI := 1 To Len(cL)
        If !(SubStr(cL, nI, 1) $ "abcdefghijklmnopqrstuvwxyz0123456789._-")
            Return .F.
        EndIf
    Next nI
Return .T.

/*/{Protheus.doc} GcPoliticaSenha
    Política de senha: no mínimo 10 caracteres, com maiúscula, minúscula,
    dígito e caractere especial, e sem conter o login.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cSenha, character, senha proposta
    @param cLogin, character, login do usuário
    @return character, "" se atende, ou o motivo da recusa
*/
User Function GcPoliticaSenha(cSenha, cLogin)
    Local lMai := .F. as logical
    Local lMin := .F. as logical
    Local lDig := .F. as logical
    Local lEsp := .F. as logical
    Local cC   := "" as character
    Local nI   := 0 as numeric

    If ValType(cSenha) != "C" .Or. Len(cSenha) < 10
        Return "A senha precisa ter pelo menos 10 caracteres."
    EndIf
    For nI := 1 To Len(cSenha)
        cC := SubStr(cSenha, nI, 1)
        Do Case
            Case cC $ "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                lMai := .T.
            Case cC $ "abcdefghijklmnopqrstuvwxyz"
                lMin := .T.
            Case cC $ "0123456789"
                lDig := .T.
            Otherwise
                lEsp := .T.
        EndCase
    Next nI
    If !(lMai .And. lMin .And. lDig .And. lEsp)
        Return "A senha precisa ter letra maiúscula, letra minúscula, número e caractere especial."
    EndIf
    If ValType(cLogin) == "C" .And. Len(AllTrim(cLogin)) >= 3 .And. Lower(AllTrim(cLogin)) $ Lower(cSenha)
        Return "A senha não pode conter o login."
    EndIf
Return ""

/*/{Protheus.doc} GcAutenticarCredencial
    Confere login e senha.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login digitado
    @param cSenha, character, senha digitada
    @param cLoginReal, character, (por referência) login como está gravado
    @return character, "OK", "TROCA" (senha certa, troca obrigatória),
        "BLOQUEADO" (5 erros seguidos, por 15 min) ou "INVALIDO" (usuário
        inexistente ou senha errada, sem distinguir)
*/
User Function GcAutenticarCredencial(cLogin, cSenha, cLoginReal)
    Local cL      := GcLoginNormal(cLogin) as character
    Local aUsr    := {} as array
    Local cGrav   := "" as character
    Local cSalt   := "" as character
    Local lCerta  := .F. as logical
    Local cWhere  := "" as character

    If ValType(cSenha) != "C"
        cSenha := ""
    EndIf
    If GcLoginValido(cL)
        aUsr := TCSqlQuery("SELECT USR_LOGIN, USR_SENHA, USR_SALT, USR_TROCA, " + ;
            "CASE WHEN IFNULL(USR_BLOQ_ATE, '') > datetime('now') THEN 'S' ELSE 'N' END AS BLOQ " + ;
            "FROM USR WHERE lower(USR_LOGIN) = '" + cL + "' AND D_E_L_E_T_ = ' '")
    EndIf
    // Inexistente, login inválido ou ambíguo (duplicado de base antiga):
    // mesmo retorno e mesmo custo de uma senha errada.
    If Len(aUsr) != 1
        GcHashSenha(cSenha + "x", "00000000000000000000000000000000")
        Return "INVALIDO"
    EndIf
    cWhere := " WHERE lower(USR_LOGIN) = '" + cL + "' AND D_E_L_E_T_ = ' '"
    If aUsr[1]:BLOQ == "S"
        Return "BLOQUEADO"
    EndIf

    cGrav := AllTrim(aUsr[1]:USR_SENHA)
    cSalt := AllTrim(aUsr[1]:USR_SALT)
    If Left(cGrav, Len(GC_HASH_V1)) == GC_HASH_V1
        lCerta := !Empty(cSenha) .And. !Empty(cSalt) .And. GcHashSenha(cSenha, cSalt) == cGrav
    Else
        // Hash antigo (FWHash = SHA-256 sem salt). Custo igualado ao v1.
        GcHashSenha(cSenha + "x", "00000000000000000000000000000000")
        lCerta := !Empty(cSenha) .And. Len(cGrav) == 64 .And. Lower(FWHash(cSenha)) == Lower(cGrav)
    EndIf

    If !lCerta
        TCSqlExec("UPDATE USR SET " + ;
            "USR_BLOQ_ATE = CASE WHEN IFNULL(USR_FALHAS, 0) + 1 >= " + cValToChar(GC_MAX_FALHAS) + ;
            " THEN datetime('now', '+15 minutes') ELSE USR_BLOQ_ATE END, " + ;
            "USR_FALHAS = CASE WHEN IFNULL(USR_FALHAS, 0) + 1 >= " + cValToChar(GC_MAX_FALHAS) + ;
            " THEN 0 ELSE IFNULL(USR_FALHAS, 0) + 1 END" + cWhere)
        Return "INVALIDO"
    EndIf

    cLoginReal := aUsr[1]:USR_LOGIN
    TCSqlExec("UPDATE USR SET USR_FALHAS = 0, USR_BLOQ_ATE = ''" + cWhere)
    // Migra o hash antigo agora que a senha foi conferida.
    If Left(cGrav, Len(GC_HASH_V1)) != GC_HASH_V1
        GcGravarHash(cL, cSenha, AllTrim(aUsr[1]:USR_TROCA) == "S")
    EndIf
    If AllTrim(aUsr[1]:USR_TROCA) == "S"
        Return "TROCA"
    EndIf
Return "OK"

/*/{Protheus.doc} GcCredenciaisValidas
    .T. se login e senha conferem (inclusive com troca obrigatória
    pendente). Mantida para quem só precisa de sim/não: troca de senha
    (confere a atual) e portal.
    @type User Function
    @author GesCon
    @since 2026-07-24
    @param cLogin, character, login
    @param cSenha, character, senha em texto
    @return logical, .T. se conferem
*/
User Function GcCredenciaisValidas(cLogin, cSenha)
    Local cRet := GcAutenticarCredencial(cLogin, cSenha) as character
Return cRet == "OK" .Or. cRet == "TROCA"

/*/{Protheus.doc} GcDefinirSenha
    Define a senha de um usuário existente, aplicando a política.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login
    @param cSenha, character, nova senha
    @param lTroca, logical, .T. para exigir troca no próximo login
    @return character, "" se gravou, ou o motivo da recusa
*/
User Function GcDefinirSenha(cLogin, cSenha, lTroca)
    Local cL   := GcLoginNormal(cLogin) as character
    Local cMot := "" as character

    If !GcLoginValido(cL)
        Return "Login inválido."
    EndIf
    cMot := GcPoliticaSenha(cSenha, cL)
    If !Empty(cMot)
        Return cMot
    EndIf
    If !GcGravarHash(cL, cSenha, lTroca == .T.)
        Return "Usuário não encontrado ou senha não gravada."
    EndIf
Return ""

/*/{Protheus.doc} GcGravarHash
    Grava salt novo + hash v1, zera falhas e bloqueio. Sem política (quem
    chama já validou, ou é a migração do hash antigo).
    @type Static Function
    @author GesCon
    @since 2026-11-21
    @param cL, character, login normalizado
    @param cSenha, character, senha em texto
    @param lTroca, logical, exigir troca no próximo login
    @return logical, .T. se uma linha foi atualizada
*/
Static Function GcGravarHash(cL, cSenha, lTroca)
    Local cSalt := GcNovoSalt() as character
    Local cHash := GcHashSenha(cSenha, cSalt) as character
    Local cTroca := "N" as character

    If Empty(cSalt) .Or. Empty(cHash)
        Return .F.
    EndIf
    If lTroca
        cTroca := "S"
    EndIf
Return Len(TCSqlQuery("UPDATE USR SET USR_SENHA = '" + cHash + "', USR_SALT = '" + cSalt + "', " + ;
    "USR_FALHAS = 0, USR_BLOQ_ATE = '', USR_TROCA = '" + cTroca + "', USR_SENHA_EM = datetime('now') " + ;
    "WHERE lower(USR_LOGIN) = '" + cL + "' AND D_E_L_E_T_ = ' ' RETURNING USR_LOGIN")) == 1

/*/{Protheus.doc} GcCriarUsuarioBase
    Cria um usuário com login único (sem diferenciar maiúsculas), perfil
    SUPERADMIN ou SINDICO e troca obrigatória no primeiro login. Login
    repetido era o caminho de um síndico virar super administrador: o
    perfil é lido pelo login, e a primeira linha com aquele login era a do
    super.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cLogin, character, login
    @param cSenha, character, senha inicial
    @param cPerfil, character, "SUPERADMIN" ou "SINDICO"
    @return character, "" se criou, ou o motivo da recusa
*/
User Function GcCriarUsuarioBase(cLogin, cSenha, cPerfil)
    Local cL   := GcLoginNormal(cLogin) as character
    Local cMot := "" as character

    If !GcLoginValido(cL)
        Return "Login inválido: use de 3 a 30 letras minúsculas, números, ponto, hífen ou sublinhado."
    EndIf
    If cPerfil != "SUPERADMIN" .And. cPerfil != "SINDICO"
        Return "Perfil inválido."
    EndIf
    cMot := GcPoliticaSenha(cSenha, cL)
    If !Empty(cMot)
        Return cMot
    EndIf
    If Len(TCSqlQuery("SELECT 1 FROM USR WHERE lower(USR_LOGIN) = '" + cL + "' AND D_E_L_E_T_ = ' '")) > 0
        Return "Já existe um usuário com o login " + cL + "."
    EndIf
    If !TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL, USR_TROCA) VALUES ('" + cL + "', '-', '" + cPerfil + "', 'S')")
        Return "Não foi possível criar o usuário: " + TCSqlError()
    EndIf
    If !GcGravarHash(cL, cSenha, .T.)
        TCSqlExec("DELETE FROM USR WHERE USR_LOGIN = '" + cL + "' AND USR_SENHA = '-'")
        Return "Não foi possível gravar a senha."
    EndIf
Return ""

/*/{Protheus.doc} GcBootAdmin
    Primeiro acesso: com a tabela USR vazia, cria "admin" (SUPERADMIN) com a
    senha inicial recebida -- em produção, GESCON_ADMIN_SENHA do ambiente
    do servidor -- e troca obrigatória no primeiro login. Sem senha (ou
    fora da política), não cria nada. Com usuários, não faz nada.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cSenhaInicial, character, senha inicial
    @return logical, .T. se há usuário ao final
*/
User Function GcBootAdmin(cSenhaInicial)
    Local cMot := "" as character

    If Len(TCSqlQuery("SELECT 1 FROM USR WHERE D_E_L_E_T_ = ' ' LIMIT 1")) > 0
        Return .T.
    EndIf
    If ValType(cSenhaInicial) != "C" .Or. Empty(cSenhaInicial)
        ConOut("GesCon: nenhum usuário cadastrado. Defina GESCON_ADMIN_SENHA no ambiente do servidor " + ;
            "para criar o administrador (login admin, troca obrigatória no primeiro acesso).")
        Return .F.
    EndIf
    cMot := GcCriarUsuarioBase("admin", cSenhaInicial, "SUPERADMIN")
    If !Empty(cMot)
        ConOut("GesCon: administrador não criado -- GESCON_ADMIN_SENHA recusada: " + cMot)
        Return .F.
    EndIf
    ConOut("GesCon: administrador 'admin' criado (troca de senha obrigatória no primeiro acesso).")
Return .T.

/*/{Protheus.doc} GcAdicionarColunasSeguranca
    Colunas de segurança de USR em bancos criados antes desta versão
    (CREATE TABLE IF NOT EXISTS do schema.sql não acrescenta coluna).
    @type User Function
    @author GesCon
    @since 2026-11-21
*/
User Function GcAdicionarColunasSeguranca()
    GcAdicionarColunaSeFaltar("USR", "USR_SALT", "TEXT DEFAULT ''")
    GcAdicionarColunaSeFaltar("USR", "USR_FALHAS", "INTEGER DEFAULT 0")
    GcAdicionarColunaSeFaltar("USR", "USR_BLOQ_ATE", "TEXT DEFAULT ''")
    GcAdicionarColunaSeFaltar("USR", "USR_TROCA", "TEXT DEFAULT 'N'")
    GcAdicionarColunaSeFaltar("USR", "USR_SENHA_EM", "TEXT DEFAULT ''")
Return

/*/{Protheus.doc} GcCriarIndiceUnicoUsr
    Índice único de login ativo, sem diferenciar maiúsculas. Num banco
    antigo com login repetido, não cria (o CREATE falharia) e avisa no log;
    o login ambíguo fica impedido de entrar (GcAutenticarCredencial exige
    exatamente uma linha).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return logical, .T. se o índice existe ao final
*/
User Function GcCriarIndiceUnicoUsr()
    Local aDup := {} as array

    If Len(TCSqlQuery("SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'UQ_USR_LOGIN'")) > 0
        Return .T.
    EndIf
    aDup := TCSqlQuery("SELECT lower(USR_LOGIN) AS L FROM USR WHERE D_E_L_E_T_ = ' ' GROUP BY lower(USR_LOGIN) HAVING COUNT(*) > 1")
    If Len(aDup) > 0
        ConOut("GesCon: AVISO -- login repetido em USR (ex.: " + aDup[1]:L + "). Esses logins não entram até a " + ;
            "duplicata ser removida; o índice único de login não foi criado.")
        Return .F.
    EndIf
Return TCSqlExec("CREATE UNIQUE INDEX IF NOT EXISTS UQ_USR_LOGIN ON USR (lower(USR_LOGIN)) WHERE D_E_L_E_T_ = ' '")
