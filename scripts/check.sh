#!/bin/sh
# scripts/check.sh -- valida a sintaxe de todo fonte AdvPL do projeto.
#
# Roda `advplc check` (que compila de verdade, sem executar) em cada .prw.
# Diferente do lint por grep que existia antes, isto pega erro de sintaxe.
set -e

cd "$(dirname "$0")/.."

falhas=0
total=0

for f in gescon.prw src/*.prw tests/*.prw; do
    [ -f "$f" ] || continue
    total=$((total + 1))
    if advplc check "$f" >/dev/null 2>&1; then
        printf '  ok   %s\n' "$f"
    else
        printf '  FALHA %s\n' "$f"
        advplc check "$f" 2>&1 | sed 's/^/        /'
        falhas=$((falhas + 1))
    fi
done

echo
if [ "$falhas" -eq 0 ]; then
    echo "check: $total fontes, 0 erro"
else
    echo "check: $total fontes, $falhas com erro"
    exit 1
fi
