#!/bin/sh
# packaging/build-package.sh -- monta os pacotes do GesCon:
#   dist/GesCon-<versão>-<plataforma>.tar.gz|.zip  (GesCon + advplc + app/)
#   dist/gescon-setup-<versão>.exe                 (instalador Windows, se houver makensis)
#
# O advplc vem da release do AdvPP fixada em ADVPP_VERSION (pacote
# advpp-cli, sem GUI). Uso: packaging/build-package.sh [versão]
set -e
cd "$(dirname "$0")/.."
RAIZ=$(pwd)
VERSAO="${1:-$(git describe --tags --always 2>/dev/null || echo dev)}"
ADVPP="$(tr -d ' \n\r' < ADVPP_VERSION)"
DIST="$RAIZ/packaging/dist"
TMP="$RAIZ/packaging/.build"
rm -rf "$DIST" "$TMP"
mkdir -p "$DIST" "$TMP"

for PLAT in linux-amd64 windows-amd64 darwin-arm64; do
    GOOS=${PLAT%-*}; GOARCH=${PLAT#*-}
    EXT=""; [ "$GOOS" = windows ] && EXT=".exe"
    P="$TMP/GesCon-$PLAT"
    mkdir -p "$P/app/src"
    echo "== $PLAT"

    # iniciador (sem console no Windows)
    LDF="-s -w"; [ "$GOOS" = windows ] && LDF="$LDF -H=windowsgui"
    (cd packaging/launcher && CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH go build -trimpath -ldflags "$LDF" -o "$P/GesCon$EXT" .)

    # advplc da release fixada
    ARQ="advpp-cli-$ADVPP-$PLAT.tar.gz"; [ "$GOOS" = windows ] && ARQ="advpp-cli-$ADVPP-$PLAT.zip"
    if [ ! -f "$TMP/$ARQ" ]; then
        curl -fsSL "https://github.com/peder1981/AdvPP/releases/download/v$ADVPP/$ARQ" -o "$TMP/$ARQ"
    fi
    mkdir -p "$TMP/cli-$PLAT"
    case "$ARQ" in
        *.zip) unzip -qo "$TMP/$ARQ" -d "$TMP/cli-$PLAT" ;;
        *) tar xzf "$TMP/$ARQ" -C "$TMP/cli-$PLAT" ;;
    esac
    cp "$(find "$TMP/cli-$PLAT" -name "advplc$EXT" -type f | head -1)" "$P/advplc$EXT"
    chmod +x "$P/advplc$EXT" "$P/GesCon$EXT"

    # programa
    cp gescon.prw "$P/app/"
    cp src/*.prw "$P/app/src/"
    cp LICENSE "$P/" 2>/dev/null || true
    cat > "$P/LEIA-ME.txt" <<TXT
GesCon $VERSAO -- gestão condominial

Abra o GesCon pelo programa "GesCon" desta pasta: ele sobe o servidor
local e abre o navegador em http://127.0.0.1:8086 (só esta máquina acessa).
Na primeira vez, o arquivo PRIMEIRO-ACESSO.txt mostra a senha inicial do
usuário admin; o primeiro login pede uma senha nova.

Dados: %LOCALAPPDATA%\\GesCon (Windows) ou ~/.local/share/gescon.
Faça cópia de segurança dessa pasta (gescon.db).
TXT
    (cd "$TMP" && if [ "$GOOS" = windows ]; then zip -qr "$DIST/GesCon-$VERSAO-$PLAT.zip" "GesCon-$PLAT"; \
        else tar czf "$DIST/GesCon-$VERSAO-$PLAT.tar.gz" "GesCon-$PLAT"; fi)
done

if command -v makensis >/dev/null 2>&1; then
    rm -rf packaging/payload && cp -r "$TMP/GesCon-windows-amd64" packaging/payload
    (cd packaging && makensis -V2 -DVERSAO="$VERSAO" gescon.nsi && mv "gescon-setup-$VERSAO.exe" "$DIST/")
    rm -rf packaging/payload
else
    echo "makensis ausente: instalador Windows não gerado"
fi
ls -lh "$DIST"
