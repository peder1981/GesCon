#!/bin/sh
# scripts/test.sh -- roda todas as suites AdvPL e devolve exit code util.
#
# As suites imprimem PASS/FAIL em texto e sempre saem com codigo 0, entao
# quem decide aqui e a saida: qualquer FALHA/FAIL/Error reprova, e saida
# vazia tambem -- uma suite muda quer dizer que o advplc elegeu o ponto de
# entrada errado (ver a nota sobre includes no topo de cada teste), nao que
# esta tudo bem.
#
# Cada execucao usa um banco descartavel, montado de schema.sql (que ja
# semeia PLANO_CONTAS, EXERCICIO, REPARTICAO e UNI). Rodar contra o banco de desenvolvimento compartilhado
# (~/.advpp/ADVPP.db) fazia sujeira de sessoes antigas reprovar teste bom:
# sobravam cobrancas de unidades T01/T02 que nao existiam em UNI, e a
# geracao da agenda do portal morria em FOREIGN KEY constraint failed.
set -e

cd "$(dirname "$0")/.."

falhas=0
total=0
saida=$(mktemp)
banco=$(mktemp -u --suffix=.db)
trap 'rm -f "$saida" "$banco" "$banco"-wal "$banco"-shm "${banco%.db}"-backup-*.db' EXIT

sqlite3 "$banco" < schema.sql
echo "test: banco descartavel em $banco"
echo

if ! ./scripts/check-triggers.sh; then
    falhas=$((falhas + 1))
fi
total=$((total + 1))
echo

for f in tests/*_test.prw; do
    [ -f "$f" ] || continue
    total=$((total + 1))
    nome=$(basename "$f")

    if ! timeout 300 advplc run "$f" --db-path "$banco" >"$saida" 2>&1; then
        printf '  FALHA %-28s (advplc run retornou erro)\n' "$nome"
        sed 's/^/        /' "$saida" | tail -15
        falhas=$((falhas + 1))
        continue
    fi

    if [ ! -s "$saida" ]; then
        printf '  FALHA %-28s (suite muda: ponto de entrada errado)\n' "$nome"
        falhas=$((falhas + 1))
        continue
    fi

    if grep -qE 'FALHA|FAIL|^Error:|Error: unknown' "$saida"; then
        printf '  FALHA %-28s\n' "$nome"
        grep -nE 'FALHA|FAIL|^Error:' "$saida" | sed 's/^/        /' | head -10
        falhas=$((falhas + 1))
        continue
    fi

    printf '  ok    %-28s (%s linhas)\n' "$nome" "$(wc -l < "$saida")"
done

echo
if [ "$falhas" -eq 0 ]; then
    echo "test: $total suites, 0 falha"
else
    echo "test: $total suites, $falhas com falha"
    exit 1
fi
