#!/bin/sh
# Gera src/schema-embed.prw a partir de schema.sql.
#
# Por que embutir: no primeiro arranque o GesCon precisa criar as proprias
# tabelas. Ate agora quem fazia isso era scripts/bootstrap-db.sh -- shell +
# sqlite3, que nao existe no Windows. O resultado e que o .exe abria contra um
# banco vazio. Carregar o schema.sql de disco em runtime tambem nao serve: o
# banco nasce no diretorio de trabalho, e o executavel nao sabe de onde foi
# lancado. Dentro do binario ele sempre esta la.
#
# Um unico TCSqlExec da conta do arquivo inteiro: o driver modernc/sqlite
# executa os 66 comandos separados por ';' numa chamada so.
set -e

cd "$(dirname "$0")/.."

destino="${1:-src/schema-embed.prw}"

{
    cat <<'CABECALHO'
// src/schema-embed.prw — GERADO por scripts/gen-schema-embed.sh.
//
// NAO EDITE A MAO. A fonte da verdade e schema.sql; este arquivo so o
// carrega para dentro do executavel, porque no primeiro arranque o app tem
// que criar as proprias tabelas sem depender de shell nem de sqlite3.
// scripts/check.sh reprova se os dois sairem de sincronia.
#include "totvs.ch"

/*/{Protheus.doc} GcSchemaSQL
    Devolve o conteudo de schema.sql embutido no executavel.
    @type Function
    @author GesCon (gerado)
    @return cSQL, character, DDL completo, comandos separados por ';'
*/
User Function GcSchemaSQL()
    Local aLinhas := {}
    Local cSQL := ""
    Local nI := 0

CABECALHO

    # Aspas: o arquivo tem uma unica linha com aspas dupla e nenhuma barra
    # invertida, entao alternar entre "..." e '...' cobre tudo. Se um dia
    # aparecer uma linha com os dois tipos, o awk aborta em vez de gerar
    # fonte quebrado que so falharia na compilacao.
    awk '
    {
        temDupla = index($0, "\"") > 0
        temSimples = index($0, "'"'"'") > 0
        if (temDupla && temSimples) {
            print "ERRO: linha " NR " de schema.sql tem aspas simples e duplas" > "/dev/stderr"
            exit 1
        }
        if (temDupla) {
            printf "    AAdd(aLinhas, %c%s%c)\n", 39, $0, 39
        } else {
            printf "    AAdd(aLinhas, \"%s\")\n", $0
        }
    }' schema.sql

    cat <<'RODAPE'

    For nI := 1 To Len(aLinhas)
        cSQL += aLinhas[nI] + Chr(10)
    Next nI
Return cSQL
RODAPE
} > "$destino"

echo "gerado $destino ($(wc -l < "$destino") linhas) a partir de schema.sql"
