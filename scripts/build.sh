#!/bin/sh
# scripts/build.sh -- gera o executavel desktop do GesCon.
#
# `advplc build` embute o bytecode num stub Go e compila com a toolchain do
# Go, entao precisa do Go instalado e de um checkout do AdvPP apontado por
# ADVPP_SRC (o stub gerado importa o modulo).
#
# Uso:
#   scripts/build.sh                 # -> ./GesConApp
#   scripts/build.sh -o outro/nome   # destino alternativo
set -e

cd "$(dirname "$0")/.."

ADVPP_SRC="${ADVPP_SRC:-$HOME/Projetos/AdvPP}"
export ADVPP_SRC

if [ ! -d "$ADVPP_SRC" ]; then
    echo "build: checkout do AdvPP nao encontrado em $ADVPP_SRC" >&2
    echo "Aponte ADVPP_SRC para um checkout do compilador." >&2
    exit 1
fi

SAIDA=GesConApp
if [ "$1" = "-o" ] && [ -n "$2" ]; then
    SAIDA="$2"
fi

echo "build: compilando gescon.prw (ADVPP_SRC=$ADVPP_SRC)"
advplc build gescon.prw -o "$SAIDA"

echo
echo "build: $SAIDA gerado ($(du -h "$SAIDA" | cut -f1))"
echo "Execute com ./gescon -- nunca o executavel direto (ver docs/PADRAO_GUI.md)."
