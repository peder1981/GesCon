#!/bin/bash
# 03-setup-cloudflared.sh — Configura Cloudflare Tunnel para GesCon.
#
# Executar DENTRO da LXC 105 (gescon).
#
# IMPORTANTE: O túnel Cloudflare deve ser criado PRIMEIRO no dashboard:
#   1. Acesse https://one.dash.cloudflare.com → Networks → Tunnels
#   2. Crie um tunnel novo (nome: "gescon")
#   3. Copie o TOKEN do tunnel (string longa base64)
#   4. Cole no campo TUNNEL_TOKEN abaixo ou passe como variável
#
# Uso:
#   export TUNNEL_TOKEN="eyJ..."
#   bash -s < 03-setup-cloudflared.sh
#
# Ou edite o TUNNEL_TOKEN abaixo manualmente.

set -euo pipefail

# --- Parâmetros ---
TUNNEL_TOKEN="${TUNNEL_TOKEN:-}"  # Token do dashboard Cloudflare
HOSTNAME="gescon"
DOMAIN="gescon.itmix.com.br"
APP_PORT=8080

echo "=== Setup Cloudflare Tunnel para GesCon ==="
echo "Data: $(date)"
echo ""

# Verificar token
if [ -z "$TUNNEL_TOKEN" ]; then
    echo "ERRO: TUNNEL_TOKEN não definido!"
    echo ""
    echo "Passos para obter o token:"
    echo "  1. Acesse https://one.dash.cloudflare.com"
    echo "  2. Vá em Networks → Tunnels"
    echo "  3. Crie um tunnel novo (nome: 'gescon')"
    echo "  4. No passo 'Install connector', copie o token"
    echo "  5. Execute:"
    echo "     export TUNNEL_TOKEN='eyJ...'"
    echo "     bash $0"
    exit 1
fi

# --- 1. Instalar cloudflared ---
echo "[1/3] Instalando cloudflared..."
if command -v cloudflared &>/dev/null; then
    echo "cloudflared já instalado: $(cloudflared --version 2>/dev/null | head -1)"
else
    # Instalar binário oficial
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  CF_ARCH="amd64" ;;
        aarch64) CF_ARCH="arm64" ;;
        *)       echo "ERRO: Arquitetura $ARCH não suportada"; exit 1 ;;
    esac
    
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
        -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    echo "cloudflared instalado: $(cloudflared --version 2>/dev/null | head -1)"
fi

# --- 2. Configurar túnel ---
echo "[2/3] Configurando túnel..."
mkdir -p /etc/cloudflared

# Salvar token em arquivo separado (600 root:root)
echo -n "$TUNNEL_TOKEN" > /etc/cloudflared/token
chmod 600 /etc/cloudflared/token

# Criar config.yml
cat > /etc/cloudflared/config.yml << EOF
# GesCon — Cloudflare Tunnel config
# Gerado automaticamente por 03-setup-cloudflared.sh

# Não há credentials-file porque usamos --token (modo remotely-managed)
# O túnel é gerenciado pelo dashboard Cloudflare

ingress:
  - hostname: ${DOMAIN}
    service: http://localhost:${APP_PORT}
    originRequest:
      noTLSVerify: false
      connectTimeout: 30s
      tcpKeepAlive: 30s
  - service: http_status:404
EOF

chmod 600 /etc/cloudflared/config.yml

# --- 3. Criar systemd service ---
echo "[3/3] Criando systemd service..."
cat > /etc/systemd/system/cloudflared.service << 'EOF'
[Unit]
Description=Cloudflare Tunnel for GesCon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared --no-autoupdate --config /etc/cloudflared/config.yml tunnel run
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cloudflared-gescon

# Segurança
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/etc/cloudflared

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudflared.service

echo ""
echo "=== Cloudflare Tunnel configurado ==="
echo ""
echo "Para iniciar:"
echo "  systemctl start cloudflared"
echo ""
echo "Para verificar:"
echo "  systemctl status cloudflared"
echo "  journalctl -u cloudflared -f"
echo ""
echo "IMPORTANTE: Crie o registro DNS no Cloudflare:"
echo " Tipo: CNAME"
echo "  Nome: gescon"
echo "  Alvo: <TUNNEL_ID>.cfargotunnel.com"
echo "  Proxied: Sim"
echo ""
echo "Ou adicione via dashboard no passo 'Public hostname' do tunnel."
echo ""
echo "URL final: https://gescon.itmix.com.br"
