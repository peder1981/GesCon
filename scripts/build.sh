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

# --gui marca o programa como app desktop: a janela Fyne abre sempre, mesmo
# lancado de um terminal, e no Windows o executavel sai no subsistema GUI
# (sem console). Sem isso o .exe do Windows abre um console ao ser clicado,
# o stub ve stdin como TTY e escolhe a UI de terminal, que nao tem MSDIALOG.
echo "build: compilando gescon.prw (ADVPP_SRC=$ADVPP_SRC)"
advplc build gescon.prw -o "$SAIDA" --gui

echo
echo "build: $SAIDA gerado ($(du -h "$SAIDA" | cut -f1))"
echo "Execute com ./gescon ou direto -- o binario ja abre em janela."
