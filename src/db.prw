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
    GcMigrarParaFilial()
    lOk := TCSqlExec(GcSchemaSQL())
    If !lOk
        ConOut("GesCon: falha ao aplicar o schema no banco.")
    EndIf
    GcSemearMigracaoFilialPadrao()
Return lOk

/*/{Protheus.doc} GcMigrarParaFilial
    Migração multi-condomínio: garante que toda tabela dependente de
    condomínio tenha a coluna FILIAL, preservando os dados de uma base
    instalada antes desta versão (sem a coluna). Roda ANTES do
    schema.sql normal — decidir "a coluna já existe?" exige PRAGMA
    table_info, que schema.sql (um blob de texto sem lógica condicional)
    não consegue fazer sozinho.

    As 4 tabelas com UNIQUE global no código (UNI, PLANO_CONTAS,
    REPARTICAO, EXERCICIO) precisam de recriação completa — SQLite não
    altera UNIQUE de coluna existente via ALTER TABLE. A tática: renomeia
    a tabela antiga pra _OLD aqui; schema.sql (chamado logo depois, ainda
    dentro de GcBootstrapDB) recria a tabela do zero, já no formato novo,
    porque CREATE TABLE IF NOT EXISTS só age quando a tabela "não existe"
    — e agora ela não existe mesmo, foi renomeada. GcRestaurarTabelasComposta
    (chamada depois do schema.sql) copia os dados de volta e apaga a _OLD.

    Idempotente: numa base já migrada, todo PRAGMA table_info já acha
    FILIAL e a função não faz nada.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcMigrarParaFilial()
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
        "AUDITORIA", "RPT_BALANCETE", "AVISOS", ;
        "ANOMALIA_LOG", "ALERTA", "DASHBOARD_CACHE"}
    Local aCompostas := {"UNI", "PLANO_CONTAS", "REPARTICAO", "EXERCICIO", ;
        "LANCAMENTOS", "RATEIO_DETALHE", "RPT_PORTAL_EXTRATOS", "RPT_PORTAL_AGENDA"}
    Local i

    For i := 1 To Len(aSimples)
        GcAdicionarFilialSeFaltar(aSimples[i])
    Next i

    For i := 1 To Len(aCompostas)
        GcRenomearSeAntiga(aCompostas[i])
    Next i
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
    FILIAL -- primeira metade da migração das 4 tabelas com UNIQUE
    composto (ver GcMigrarParaFilial). A segunda metade é
    GcRestaurarTabelasComposta, chamada depois do schema.sql recriar a
    tabela do zero.
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
    já ter recriado as 8 tabelas "compostas" (agora vazias, no formato
    novo). Copia os dados de cada "_OLD" de volta (se existir) com
    FILIAL='010101', apaga a _OLD, e faz o mesmo saneamento (FILIAL
    NULL/vazio -> '010101') nas demais tabelas -- cobre tanto as 8
    recém-restauradas quanto as 18 simples que só ganharam a coluna via
    ALTER (Step 6 acima), que fica NULL até este UPDATE rodar.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcSemearMigracaoFilialPadrao()
    // Ordem importa: LANCAMENTOS referencia PLANO_CONTAS/EXERCICIO (via
    // FK composta), RATEIO_DETALHE referencia UNI e LANCAMENTOS,
    // RPT_PORTAL_EXTRATOS/RPT_PORTAL_AGENDA referenciam UNI -- cada uma
    // só pode ser restaurada depois que quem ela referencia já estiver
    // de volta com FILIAL='010101'. A lista abaixo já está na ordem certa.
    //
    // R_E_C_N_O_ fica de fora da cópia em UNI/PLANO_CONTAS/REPARTICAO/
    // EXERCICIO de propósito: a tabela nova (recriada pelo schema.sql no
    // passo anterior) já pode ter ganhado linhas via INSERT OR IGNORE dos
    // blocos de semente ("Seed units for testing" etc.), com R_E_C_N_O_
    // 1, 2, 3... -- copiar o R_E_C_N_O_ antigo verbatim colidia com essas.
    // Nas outras 4, R_E_C_N_O_ NÃO é a chave primária de verdade (é
    // LAN_ID/RAT_ID/REX_ID/REA_ID, cada uma com seu próprio
    // AUTOINCREMENT) e nenhuma delas tem bloco de semente no schema.sql,
    // então copiar o id inteiro é seguro -- e necessário pra
    // RATEIO_DETALHE.RAT_LANCAMENTO continuar apontando pro LAN_ID certo.
    Local aCompostas := {{"UNI", "D_E_L_E_T_,R_E_C_D_E_L_,UNI_CODIGO,UNI_BLOCO,UNI_FRACAO,UNI_CONDOMINO"}, ;
        {"PLANO_CONTAS", "PLA_CODIGO,PLA_NOME,PLA_TIPO,PLA_ATIVO,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"REPARTICAO", "REP_CODIGO,REP_NOME,REP_ATIVO,REP_DETALHE,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"EXERCICIO", "EXE_CODIGO,EXE_INICIO,EXE_FIM,EXE_ATIVO,EXE_FECHADO,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"LANCAMENTOS", "LAN_ID,LAN_DATA,LAN_CONTA_DEB,LAN_CONTA_CRED,LAN_VALOR,LAN_DESCR,LAN_REFERENCIA,LAN_TIPO,LAN_DATA_HORA,LAN_USUARIO,LAN_EXERCICIO,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"RATEIO_DETALHE", "RAT_ID,RAT_LANCAMENTO,RAT_UNIDADE,RAT_VALOR,RAT_PERCENTUAL,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"RPT_PORTAL_EXTRATOS", "REX_ID,REX_COMPETENCIA,REX_UNIDADE,REX_VALOR,REX_VENCIMENTO,REX_STATUS,REX_DATA_PAGAMENTO,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"RPT_PORTAL_AGENDA", "REA_ID,REA_UNIDADE,REA_COMPETENCIA,REA_VENCIMENTO,REA_VALOR,R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_"}}
    // aTodas NAO inclui as 8 tabelas de aCompostas: essas já saem
    // estampadas com FILIAL='010101' explícito no INSERT acima. Um
    // saneamento genérico (FILIAL IS NULL) bateria nas linhas de semente
    // dos blocos INSERT OR IGNORE do schema.sql (ex.: as 20 unidades de
    // teste 101-120), que entram com FILIAL NULL de propósito -- forçá-las
    // pra '010101' colide com a mesma unidade real já restaurada.
    Local aTodas := {"CON", "DES", "COB", "RPT_INADIM", "RPT_EXTRATO", ;
        "RPT_DESCAT", "CFG_BOLETO", "GCT_TOKEN", "RPT_COND_COBRANCAS", ;
        "AUDITORIA", "RPT_BALANCETE", "AVISOS", ;
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

    For i := 1 To Len(aTodas)
        cSql += "UPDATE " + aTodas[i] + " SET FILIAL = '010101' WHERE FILIAL IS NULL OR FILIAL = '';" + Chr(10)
    Next i

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
