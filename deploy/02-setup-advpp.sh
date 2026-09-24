#!/bin/bash
# 02-setup-advpp.sh — Instala AdvPP + GesCon na LXC 105 (gescon).
#
# Executar DENTRO da LXC 105.
# Assume Debian 12 fresh install.
#
# Uso:
#   pct enter 105
#   bash -s < 02-setup-advpp.sh

set -euo pipefail

echo "=== Setup GesCon LXC 105 ==="
echo "Data: $(date)"
echo ""

# --- 1. Dependências do sistema ---
echo "[1/7] Instalando dependências do sistema..."
apt-get update -qq
apt-get install -y -qq \
    git \
    sqlite3 \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    unzip

# --- 2. Instalar AdvPP ---
echo "[2/7] Instalando AdvPP v3.0.0..."
ADVPP_VERSION="3.0.0"
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)  ADVPP_ARCH="linux-amd64" ;;
    aarch64) ADVPP_ARCH="linux-arm64" ;;
    *)       echo "ERRO: Arquitetura $ARCH não suportada"; exit 1 ;;
esac

# Download do release
RELEASE_URL="https://github.com/peder1981/AdvPP/releases/download/v${ADVPP_VERSION}/advpp-${ADVPP_VERSION}-${ADVPP_ARCH}.tar.gz"
echo "Baixando: $RELEASE_URL"
curl -fsSL "$RELEASE_URL" -o /tmp/advpp.tar.gz

# Extrair e instalar
mkdir -p /opt/advpp
tar xzf /tmp/advpp.tar.gz -C /opt/advpp --strip-components=1
rm /tmp/advpp.tar.gz

# Symlink para binários
ln -sf /opt/advpp/advplc /usr/local/bin/advplc
ln -sf /opt/advpp/adveditor /usr/local/bin/adveditor 2>/dev/null || true
ln -sf /opt/advpp/advpp-ide /usr/local/bin/advpp-ide 2>/dev/null || true

# Verificar
echo "AdvPP instalado:"
advplc version 2>/dev/null || echo "(advplc version não disponível)"

# --- 3. Configurar diretório AdvPP ---
echo "[3/7] Configurando diretório AdvPP..."
mkdir -p /root/.advpp

# --- 4. Clonar GesCon ---
echo "[4/7] Clonando GesCon..."
mkdir -p /opt/gescon
cd /opt/gescon

# Clonar repo (read-only, sem deploy key por enquanto)
if [ -d ".git" ]; then
    echo "Repo já existe. Atualizando..."
    git pull --ff-only
else
    git clone https://github.com/peder1981/GesCon.git .
fi

# --- 5. Bootstrap do banco ---
echo "[5/7] Aplicando schema no SQLite..."
chmod +x scripts/bootstrap-db.sh
./scripts/bootstrap-db.sh

# Verificar tabelas
echo "Tabelas criadas:"
sqlite3 "$HOME/.advpp/ADVPP.db" ".tables" 2>/dev/null || echo "(banco será criado no primeiro run)"

# --- 6. Testar execução ---
echo "[6/7] Testando advplc serve..."
echo "Iniciando GesCon em modo web (porta 8080)..."
echo "O GesCon ficará acessível em http://localhost:8080"
echo ""
echo "Para testar manualmente:"
echo "  cd /opt/gescon && advplc serve gescon.prw"
echo ""
echo "Pressione Ctrl+C para parar o teste (5 segundos)..."
timeout 5 advplc serve gescon.prw --port 8080 2>/dev/null || true
echo ""

# --- 7. Criar systemd service ---
echo "[7/7] Criando systemd service..."
cat > /etc/systemd/system/gescon.service << 'EOF'
[Unit]
Description=GesCon - Sistema de Gestão Condominial
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/gescon
ExecStart=/usr/local/bin/advplc serve gescon.prw --port 8080
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gescon

# Segurança
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=/opt/gescon /root/.advpp

# Variáveis de ambiente (mala direta)
Environment=ADVPP_DB=/root/.advpp/ADVPP.db
# Descomente para mala direta:
# Environment=GESCON_SMTP_HOST=smtp.exemplo.com
# Environment=GESCON_SMTP_PORT=587
# Environment=GESCON_SMTP_USER=usuario
# Environment=GESCON_SMTP_PASS=senha
# Environment=GESCON_SMTP_FROM=gescon@seucondominio.com

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gescon.service

echo ""
echo "=== Setup GesCon concluído ==="
echo ""
echo "Para iniciar:"
echo "  systemctl start gescon"
echo ""
echo "Para verificar status:"
echo "  systemctl status gescon"
echo "  curl -s http://localhost:8080 | head -20"
echo ""
echo "Logs:"
echo "  journalctl -u gescon -f"
echo ""
echo "Próximo passo: executar 03-setup-cloudflared.sh"
