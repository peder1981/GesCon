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
    lOk := TCSqlExec(GcSchemaSQL())
    If !lOk
        ConOut("GesCon: falha ao aplicar o schema no banco.")
    EndIf
Return lOk

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
