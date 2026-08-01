#!/bin/sh
# scripts/check.sh -- valida a sintaxe de todo fonte AdvPL do projeto.
#
# Roda `advplc check` (que compila de verdade, sem executar) em cada .prw.
# Diferente do lint por grep que existia antes, isto pega erro de sintaxe.
set -e

cd "$(dirname "$0")/.."

falhas=0
total=0

# Encoding: o AdvPP le os fontes como UTF-8. Fonte em CP-1252 compila, mas
# todo acento sai como mojibake na tela (menus, mensagens, titulos de
# coluna). Isto ja aconteceu neste projeto -- "Condominos" virava
# "Cond\xc3\xb4minos" no menu -- entao vira erro de build, nao surpresa em
# producao. U+FFFD indica texto ja destruido por uma conversao anterior.
echo "encoding (UTF-8, sem U+FFFD):"
for f in gescon.prw src/*.prw tests/*.prw schema.sql; do
    [ -f "$f" ] || continue
    if ! iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1; then
        printf '  FALHA %s nao e UTF-8 valido\n' "$f"
        falhas=$((falhas + 1))
    elif grep -q $'\xef\xbf\xbd' "$f"; then
        printf '  FALHA %s contem U+FFFD (texto perdido)\n' "$f"
        falhas=$((falhas + 1))
    fi
done
[ "$falhas" -eq 0 ] && echo "  ok"
echo


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
# Alcancabilidade: funcao de negocio sem caminho de menu e o defeito que
# motivou esta fase do projeto -- modulos inteiros compilados e invisiveis.
if ! python3 "$(dirname "$0")/alcance.py"; then
    falhas=$((falhas + 1))
fi

echo
if [ "$falhas" -eq 0 ]; then
    echo "check: $total fontes, 0 erro"
else
    echo "check: $total fontes, $falhas com erro"
    exit 1
fi
