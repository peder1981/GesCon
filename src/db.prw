// src/db.prw — camada de acesso SQL do GesCon. Toda query direta às
// tabelas UNI/CON/DES/COB/USR passa por aqui, nunca espalhada pelas telas.
#include "totvs.ch"

/*/{Protheus.doc} GcSqlLit
    Escapa aspas simples — todo valor de texto interpolado numa query via
    TCSqlExec/TCSqlQuery precisa passar por aqui (sem parâmetros bind na
    API atual, escapar é a única defesa contra literal quebrado).
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cValor, character, valor a escapar (aceita Nil)
    @return cRet, character, valor com aspas simples duplicadas
*/
User Function GcSqlLit(cValor)
    Local cRet := cValor
    If cRet == Nil
        cRet := ""
    EndIf
Return StrTran(cRet, "'", "''")

/*/{Protheus.doc} GcPerfilDoLogin
    Consulta USR_PERFIL do login informado. Extraída da revisão final
    (achados C2/I4/I5): três telas diferentes (src/usuarios.prw,
    src/condominios-cadastro.prw) precisavam do mesmo "este login é
    SUPERADMIN?" pra fechar buracos de autorização (síndico se
    autovinculando a qualquer condomínio, editando/excluindo condomínio
    alheio, ou criando outro super admin) -- mesma query que
    GcSelecionarCondominio (src/login.prw) já fazia inline, centralizada
    aqui pra não triplicar o SQL.
    @type Function
    @author GesCon
    @since 2026-08-08
    @param cLogin, character, login a consultar (aceita vazio/Nil -- devolve "")
    @return cPerfil, character, USR_PERFIL do login (ex: "SUPERADMIN", "SINDICO") ou "" se não encontrado
*/
User Function GcPerfilDoLogin(cLogin)
    Local aPerfil := {}
    Local cPerfil := ""

    If !Empty(cLogin)
        aPerfil := TCSqlQuery("SELECT USR_PERFIL FROM USR WHERE USR_LOGIN = '" + ;
            GcSqlLit(cLogin) + "' AND D_E_L_E_T_ = ' '")
        If Len(aPerfil) > 0
            cPerfil := aPerfil[1]:USR_PERFIL
        EndIf
    EndIf
Return cPerfil

/*/{Protheus.doc} GcBootstrapDB
    Aplica o schema no banco corrente. Chamado no arranque, antes de
    qualquer tela.

    Existe porque quem criava as tabelas era scripts/bootstrap-db.sh —
    shell mais sqlite3, nenhum dos dois presente num Windows comum. O
    executável abria contra um banco vazio: o ResolveDatabasePath do AdvPP
    cria advpp.db no diretório de trabalho e mais nada.

    Roda sempre, sem verificar se as tabelas já existem. schema.sql é
    idempotente por contrato — CREATE TABLE IF NOT EXISTS, CREATE INDEX IF
    NOT EXISTS, INSERT OR IGNORE nas sementes, e o SX3 reconstruído
    inteiro — e scripts/check.sh reprova o build se deixar de ser. Aplicar
    sempre custa ~40ms e resolve de graça o upgrade de versão: tabela nova
    de um release novo aparece sozinha em banco antigo.

    ponytail: se o schema um dia crescer a ponto de pesar no arranque, o
    passo seguinte é gravar a versão numa tabela de controle e só reaplicar
    quando ela mudar.

    @type Function
    @author GesCon
    @since 2026-08-01
    @return lOk, logical, .T. se o schema foi aplicado
*/
User Function GcBootstrapDB()
    Local lOk := .T.
    Local lPrecisaMigrar := GcPrecisaMigrarFilial()

    // Backup só quando uma migração de verdade vai rodar nesta chamada —
    // não em todo boot normal (GcBackupBanco já é usado com parcimônia,
    // ver seu próprio comentário sobre não ter rotação de arquivos).
    If lPrecisaMigrar
        GcBackupBanco("pre-migracao-filial")
    EndIf

    GcMigrarParaFilial()
    lOk := TCSqlExec(GcSchemaSQL())
    If !lOk
        ConOut("GesCon: falha ao aplicar o schema no banco.")
    EndIf

    // A restauração das _OLD roda SEMPRE, mesmo fora de uma migração
    // "nova" -- é a rede de segurança de uma migração anterior que tenha
    // sido interrompida no meio (native error de TCSqlExec aborta o
    // processo inteiro sem Try/Catch, ver scripts/check-triggers.sh): se
    // uma tabela _OLD sobreviveu de um boot anterior, GcPrecisaMigrarFilial
    // já devolve .F. (UNI já tem FILIAL) e um gate único aqui deixaria
    // esses dados presos lá pra sempre, sem mais nenhum código tentando
    // resgatá-los. O saneamento genérico (FILIAL NULL -> '010101', que
    // esconderia um bug futuro atrás de "vira condomínio 1 sozinho")
    // continua condicionado a uma migração estar de fato acontecendo
    // agora -- por isso os dois viram parâmetro, não dois gates iguais.
    GcSemearMigracaoFilialPadrao(lPrecisaMigrar)
Return lOk

/*/{Protheus.doc} GcPrecisaMigrarFilial
    Detecta se a migração multi-condomínio vai rodar nesta chamada —
    checa só UNI como proxy: as 9 tabelas "compostas" (ver
    GcMigrarParaFilial) sempre migram juntas, na mesma versão, então se
    UNI ainda não tem FILIAL nenhuma das outras tem. Usado pra só fazer
    backup e saneamento quando uma migração de verdade está acontecendo,
    não em todo boot normal.
    @type Static Function
    @author GesCon
    @since 2026-08-08
    @return lPrecisa, logical, .T. se a migração ainda vai rodar
*/
Static Function GcPrecisaMigrarFilial()
    Local aCols := TCSqlQuery("PRAGMA table_info(UNI)")
    Local i

    If Len(aCols) == 0
        Return .F.  // banco novo -- schema.sql cria UNI já com FILIAL, nada pra migrar
    EndIf

    For i := 1 To Len(aCols)
        If Upper(aCols[i]:NAME) == "FILIAL"
            Return .F.  // já migrada
        EndIf
    Next i
Return .T.

/*/{Protheus.doc} GcMigrarParaFilial
    Migração multi-condomínio: garante que toda tabela dependente de
    condomínio tenha a coluna FILIAL, preservando os dados de uma base
    instalada antes desta versão (sem a coluna). Roda ANTES do
    schema.sql normal — decidir "a coluna já existe?" exige PRAGMA
    table_info, que schema.sql (um blob de texto sem lógica condicional)
    não consegue fazer sozinho.

    As 4 tabelas com UNIQUE global no código (UNI, PLANO_CONTAS,
    REPARTICAO, EXERCICIO) — mais as outras 4 que têm FOREIGN KEY
    apontando pra alguma delas (ver comentário abaixo) — precisam de
    recriação completa: SQLite não altera UNIQUE nem FOREIGN KEY de
    coluna existente via ALTER TABLE. A tática: renomeia a tabela antiga
    pra _OLD aqui; schema.sql (chamado logo depois, ainda dentro de
    GcBootstrapDB) recria a tabela do zero, já no formato novo, porque
    CREATE TABLE IF NOT EXISTS só age quando a tabela "não existe" — e
    agora ela não existe mesmo, foi renomeada. GcSemearMigracaoFilialPadrao
    (chamada depois do schema.sql) copia os dados de volta e apaga a _OLD.

    Idempotente: numa base já migrada, todo PRAGMA table_info já acha
    FILIAL e a função não faz nada.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcMigrarParaFilial()
    // Captura ANTES de qualquer rename: GcPrecisaMigrarFilial() decide
    // olhando PRAGMA table_info(UNI), e o loop de GcRenomearSeAntiga logo
    // abaixo renomeia UNI para UNI_OLD -- chamar de novo depois disso
    // devolveria .F. por engano (a tabela "UNI" não existe mais sob esse
    // nome), quebrando o gate do UPDATE de USR_PERFIL no fim desta função.
    Local lPrecisa := GcPrecisaMigrarFilial()

    // LANCAMENTOS/RATEIO_DETALHE/RPT_PORTAL_EXTRATOS/RPT_PORTAL_AGENDA
    // entram na lista de "recriar", não na de "só ganhar a coluna": todas
    // têm FOREIGN KEY apontando pra uma das 4 tabelas com UNIQUE composto
    // (UNI/PLANO_CONTAS/EXERCICIO). O ALTER TABLE ... RENAME TO do SQLite
    // reescreve sozinho a definição de FK de QUALQUER outra tabela que
    // referencie a renomeada -- ex.: renomear UNI faz RATEIO_DETALHE
    // passar a apontar pra "UNI_OLD" no lugar de "UNI", silenciosamente.
    // Sem recriar essas 4 também (com a FK composta corrigida, já em
    // schema.sql), a restauração morre com "FOREIGN KEY constraint
    // failed" ou deixa a tabela presa referenciando uma _OLD que nem
    // existe mais. Descoberto validando contra cópia do banco real.
    Local aSimples := {"CON", "DES", "COB", "RPT_INADIM", "RPT_EXTRATO", ;
        "RPT_DESCAT", "CFG_BOLETO", "GCT_TOKEN", "RPT_COND_COBRANCAS", ;
        "AUDITORIA", "AVISOS", ;
        "ANOMALIA_LOG", "ALERTA", "DASHBOARD_CACHE"}
    // RPT_BALANCETE entra em aCompostas junto com as outras: seu próprio
    // UNIQUE(RPT_EXERCICIO, D_E_L_E_T_) também precisava virar
    // UNIQUE(FILIAL, RPT_EXERCICIO, D_E_L_E_T_) -- sem isso, duas
    // filiais fechando o mesmo EXE_CODIGO colidiriam no balancete uma
    // da outra.
    Local aCompostas := {"UNI", "PLANO_CONTAS", "REPARTICAO", "EXERCICIO", ;
        "LANCAMENTOS", "RATEIO_DETALHE", "RPT_PORTAL_EXTRATOS", "RPT_PORTAL_AGENDA", ;
        "RPT_BALANCETE"}
    Local i

    For i := 1 To Len(aSimples)
        GcAdicionarFilialSeFaltar(aSimples[i])
    Next i

    For i := 1 To Len(aCompostas)
        GcRenomearSeAntiga(aCompostas[i])
    Next i

    // IDX_DASHBOARD_DATA_PERIODO é um índice avulso (não uma constraint
    // de tabela), então dá pra corrigir sem recriar DASHBOARD_CACHE
    // inteira -- só derruba o índice velho; schema.sql recria com FILIAL
    // já na composição. DROP INDEX é idempotente por natureza (IF
    // EXISTS), sem precisar do vaivém de _OLD.
    TCSqlExec("DROP INDEX IF EXISTS IDX_DASHBOARD_DATA_PERIODO")

    // C1 (revisão final): USR_PERFIL default é 'ADMIN' em schema.sql, e
    // toda base instalada antes desta versão (v1.0.10) só tem admins
    // 'ADMIN', nunca 'SUPERADMIN' -- USR_COND (o vínculo usuário-condomínio
    // do síndico) é tabela nova e nasce vazia. Sem esta promoção,
    // GcSelecionarCondominio (src/login.prw) cai no ramo USR_COND para
    // esse admin, o JOIN não acha nada, devolve 0 condomínios, e o login
    // trava sem caminho de recuperação (o menu Usuários fica atrás do
    // próprio login). A spec promete "sobe direto no condomínio nº 1 sem
    // passo manual" -- isto cumpre essa promessa. Roda só quando uma
    // migração de verdade está acontecendo (lPrecisa), não em todo boot:
    // depois da primeira migração, um 'ADMIN' criado deliberadamente (se
    // algum fluxo futuro vier a criar um) não deve ser promovido à força.
    // USR só existe se checado antes: um banco pré-v1.0.10 de verdade pode
    // nem ter chegado a ter tabela de usuários ainda (scripts/
    // check-migracao-filial.sh simula exatamente isso) -- schema.sql, que
    // cria USR, só roda DEPOIS desta função, em GcBootstrapDB.
    If lPrecisa .And. Len(TCSqlQuery("PRAGMA table_info(USR)")) > 0
        TCSqlExec("UPDATE USR SET USR_PERFIL = 'SUPERADMIN' WHERE USR_PERFIL IS NULL OR USR_PERFIL IN ('', 'ADMIN')")
    EndIf
Return

/*/{Protheus.doc} GcAdicionarFilialSeFaltar
    ALTER TABLE ADD COLUMN FILIAL, só se a tabela existir e ainda não
    tiver a coluna.
    @type Static Function
    @author GesCon
    @since 2026-08-08
    @param cTabela, character, nome da tabela
*/
Static Function GcAdicionarFilialSeFaltar(cTabela)
    Local aCols := TCSqlQuery("PRAGMA table_info(" + cTabela + ")")
    Local i

    If Len(aCols) == 0
        Return  // tabela ainda não existe (banco novo) -- schema.sql cria já com FILIAL
    EndIf

    For i := 1 To Len(aCols)
        If Upper(aCols[i]:NAME) == "FILIAL"
            Return  // já migrada
        EndIf
    Next i

    TCSqlExec("ALTER TABLE " + cTabela + " ADD COLUMN FILIAL TEXT")
Return

/*/{Protheus.doc} GcRenomearSeAntiga
    Renomeia cTabela para cTabela_OLD se ela existir e ainda não tiver
    FILIAL -- primeira metade da migração das 9 tabelas "compostas" (ver
    GcMigrarParaFilial). A segunda metade é GcSemearMigracaoFilialPadrao,
    chamada depois do schema.sql recriar a tabela do zero.
    @type Static Function
    @author GesCon
    @since 2026-08-08
    @param cTabela, character, nome da tabela
*/
Static Function GcRenomearSeAntiga(cTabela)
    Local aCols := TCSqlQuery("PRAGMA table_info(" + cTabela + ")")
    Local i

    If Len(aCols) == 0
        Return  // banco novo -- nada pra renomear
    EndIf

    For i := 1 To Len(aCols)
        If Upper(aCols[i]:NAME) == "FILIAL"
            Return  // já migrada
        EndIf
    Next i

    TCSqlExec("ALTER TABLE " + cTabela + " RENAME TO " + cTabela + "_OLD")
Return

/*/{Protheus.doc} GcSemearMigracaoFilialPadrao
    Segunda metade da migração: chamada depois de TCSqlExec(GcSchemaSQL())
    já ter recriado as 9 tabelas "compostas" (agora vazias, no formato
    novo). Copia os dados de cada "_OLD" de volta (se existir) com
    FILIAL='010101' e apaga a _OLD -- isso roda incondicionalmente, toda
    vez, porque uma _OLD sobrevivente é sinal de uma migração anterior
    interrompida (ver GcBootstrapDB) e precisa ser drenada não importa o
    que lPrecisaMigrar diga sobre a chamada atual.

    lPrecisaMigrar controla só a segunda parte: o saneamento genérico
    (FILIAL NULL/vazio -> '010101') nas 14 tabelas "simples" -- esse sim
    só deve rodar quando uma migração está de fato acontecendo agora,
    senão esconderia um bug futuro (INSERT que esqueça de estampar
    FILIAL) atrás de "vira condomínio 1 sozinho".

    Sobre não conferir o retorno do TCSqlExec final: um erro de SQL
    dentro dele é um native error do AdvPP, que aborta o processo inteiro
    sem Try/Catch (mesma limitação documentada em
    scripts/check-triggers.sh) -- não existe "continuar e reportar" nesse
    ponto, só "o processo morre e o usuário vê o erro na tela". O que
    resta fazer de defensivo já está feito: o backup em GcBootstrapDB
    roda antes de qualquer coisa aqui, e a drenagem de _OLD incondicional
    acima é a própria recuperação pro caso de um abort no meio.
    @type Function
    @author GesCon
    @since 2026-08-08
    @param lSanear, logical, .T. pra também rodar o saneamento genérico
        nas tabelas simples (só quando uma migração está de fato
        acontecendo nesta chamada — ver GcBootstrapDB)
*/
User Function GcSemearMigracaoFilialPadrao(lSanear)
    // Ordem importa: LANCAMENTOS referencia PLANO_CONTAS/EXERCICIO (via
    // FK composta), RATEIO_DETALHE referencia UNI e LANCAMENTOS,
    // RPT_PORTAL_EXTRATOS/RPT_PORTAL_AGENDA referenciam UNI -- cada uma
    // só pode ser restaurada depois que quem ela referencia já estiver
    // de volta com FILIAL='010101'. A lista abaixo já está na ordem certa.
    //
    // R_E_C_N_O_ fica de fora da cópia em UNI/PLANO_CONTAS/REPARTICAO/
    // EXERCICIO de propósito defensivo: nelas R_E_C_N_O_ não é referenciado
    // por mais nenhuma tabela, então deixar a tabela nova (recriada do
    // zero pelo schema.sql) distribuir ids frescos via AUTOINCREMENT é
    // seguro e mais simples que preservar o antigo. Nas outras 4,
    // R_E_C_N_O_ NÃO é a chave primária de verdade (é LAN_ID/RAT_ID/
    // REX_ID/REA_ID, cada uma com seu próprio AUTOINCREMENT) -- copiar o
    // id inteiro é seguro e necessário pra RATEIO_DETALHE.RAT_LANCAMENTO
    // continuar apontando pro LAN_ID certo.
    Local aCompostas := {{"UNI", "D_E_L_E_T_,R_E_C_D_E_L_,UNI_CODIGO,UNI_BLOCO,UNI_FRACAO,UNI_CONDOMINO"}, ;
        {"PLANO_CONTAS", "PLA_CODIGO,PLA_NOME,PLA_TIPO,PLA_ATIVO,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"REPARTICAO", "REP_CODIGO,REP_NOME,REP_ATIVO,REP_DETALHE,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"EXERCICIO", "EXE_CODIGO,EXE_INICIO,EXE_FIM,EXE_ATIVO,EXE_FECHADO,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"LANCAMENTOS", "LAN_ID,LAN_DATA,LAN_CONTA_DEB,LAN_CONTA_CRED,LAN_VALOR,LAN_DESCR,LAN_REFERENCIA,LAN_TIPO,LAN_DATA_HORA,LAN_USUARIO,LAN_EXERCICIO,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"RATEIO_DETALHE", "RAT_ID,RAT_LANCAMENTO,RAT_UNIDADE,RAT_VALOR,RAT_PERCENTUAL,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"RPT_PORTAL_EXTRATOS", "REX_ID,REX_COMPETENCIA,REX_UNIDADE,REX_VALOR,REX_VENCIMENTO,REX_STATUS,REX_DATA_PAGAMENTO,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"RPT_PORTAL_AGENDA", "REA_ID,REA_UNIDADE,REA_COMPETENCIA,REA_VENCIMENTO,REA_VALOR,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"RPT_BALANCETE", "RPT_EXERCICIO,RPT_RECEITAS,RPT_DESPESAS,RPT_SALDO,RPT_DATA_GERACAO,D_E_L_E_T_,R_E_C_D_E_L_"}}
    // aTodas NAO inclui as 9 tabelas de aCompostas: essas já saem
    // estampadas com FILIAL='010101' explícito no INSERT acima -- um
    // saneamento genérico ali seria redundante.
    Local aTodas := {"CON", "DES", "COB", "RPT_INADIM", "RPT_EXTRATO", ;
        "RPT_DESCAT", "CFG_BOLETO", "GCT_TOKEN", "RPT_COND_COBRANCAS", ;
        "AUDITORIA", "AVISOS", ;
        "ANOMALIA_LOG", "ALERTA", "DASHBOARD_CACHE"}
    Local i
    Local aExiste
    Local cSql := ""

    // Tudo num TCSqlExec só, entre PRAGMA foreign_keys=OFF/ON: chamadas
    // TCSqlExec separadas podem cair em conexões diferentes do pool do
    // driver Go (cada uma com seu próprio estado de PRAGMA), e restaurar
    // UNI logo depois de recriar RATEIO_DETALHE/RPT_PORTAL_* (que já
    // apontam pra ela via FK composta) disparava "FOREIGN KEY constraint
    // failed" mesmo a operação sendo válida -- confirmado testando contra
    // cópia do banco real e isolando que a mesma sequência via sqlite3 CLI
    // (uma sessão só) funcionava sem erro. Combinar num único Exec garante
    // a mesma conexão do início ao fim.
    cSql := "PRAGMA foreign_keys=OFF;" + Chr(10)

    For i := 1 To Len(aCompostas)
        aExiste := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name = '" + ;
            aCompostas[i][1] + "_OLD'")
        If Len(aExiste) > 0
            cSql += "INSERT INTO " + aCompostas[i][1] + " (" + aCompostas[i][2] + ", FILIAL) SELECT " + ;
                aCompostas[i][2] + ", '010101' FROM " + aCompostas[i][1] + "_OLD;" + Chr(10)
            cSql += "DROP TABLE " + aCompostas[i][1] + "_OLD;" + Chr(10)
        EndIf
    Next i

    If lSanear
        For i := 1 To Len(aTodas)
            cSql += "UPDATE " + aTodas[i] + " SET FILIAL = '010101' WHERE FILIAL IS NULL OR FILIAL = '';" + Chr(10)
        Next i
    EndIf

    cSql += "PRAGMA foreign_keys=ON;" + Chr(10)

    TCSqlExec(cSql)
Return

/*/{Protheus.doc} GcBackupBanco
    Copia o banco corrente para um arquivo -backup-AAAAMMDDHHMMSS.db ao
    lado dele, via VACUUM INTO — cópia atômica e consistente mesmo com o
    WAL ativo (uma cópia ingênua do arquivo .db sozinho perderia
    transação ainda não fechada no -wal). É o único banco do sistema, sem
    servidor: perder o arquivo é perder tudo, e o Fechamento Mensal é o
    maior volume de escrita que o sistema faz de uma vez.

    ponytail: sem rotação/expiração de backups antigos — um fechamento
    por competência é ~12/ano, não acumula a ponto de importar. Se um dia
    importar, apagar os com mais de N meses aqui mesmo.

    @type Function
    @author GesCon
    @since 2026-08-08
    @param cRotulo, character, texto extra no nome do arquivo (ex.: a
        competência sendo fechada) — evita colisão de nome quando duas
        chamadas caem no mesmo segundo; VACUUM INTO recusa gravar por
        cima de um arquivo já existente. Opcional.
    @return cDestino, character, caminho do arquivo de backup gerado
*/
User Function GcBackupBanco(cRotulo)
    Local aBanco := TCSqlQuery("PRAGMA database_list")
    Local cOrigem := aBanco[1]:file
    Local cSufixo := ""
    If !Empty(cRotulo)
        cSufixo := "-" + cRotulo
    EndIf
    Local cDestino := FilePath(cOrigem) + FileNoExt(FileName(cOrigem)) + ;
        "-backup" + cSufixo + "-" + DTOS(Date()) + StrTran(Time(), ":", "") + ".db"
    TCSqlExec("VACUUM INTO '" + GcSqlLit(cDestino) + "'")
    ConOut("GesCon: backup do banco em " + cDestino)
Return cDestino
