#!/bin/sh
# scripts/check.sh -- valida a sintaxe de todo fonte AdvPL do projeto.
#
# Roda `advplc check` (que compila de verdade, sem executar) em cada .prw.
# Diferente do lint por grep que existia antes, isto pega erro de sintaxe.
set -e

cd "$(dirname "$0")/.."

falhas=0
total=0

# Encoding. O advplc converte fonte CP-1252 para UTF-8 antes de lexar, entao
# .prw nos dois encodings compila igual -- aqui UTF-8 e convencao do projeto.
# Ja schema.sql nao passa pelo advplc: o sqlite3 grava os bytes literais e o
# Fyne renderiza esperando UTF-8, entao em CP-1252 os titulos do SX3 saem
# corrompidos em TODA grade do sistema. U+FFFD e sempre defeito: indica texto
# ja destruido por uma conversao anterior, que nenhuma reconversao recupera.
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
if ! python3 scripts/alcance.py; then
    falhas=$((falhas + 1))
fi

echo
if [ "$falhas" -eq 0 ]; then
    echo "check: $total fontes, 0 erro"
else
    echo "check: $total fontes, $falhas com erro"
    exit 1
fi
