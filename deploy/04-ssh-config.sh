#!/bin/bash
# 04-ssh-config.sh — Adiciona alias SSH para LXC 105 (gescon).
#
# Executar no LAPTOP (laptop-peder).
# Configura acesso via ProxyJump homelab-lan.

set -euo pipefail

SSH_CONFIG="$HOME/.ssh/config"
ALIAS="lxc105"
HOST_IP="192.168.2.105"

echo "=== Configurando SSH alias para GesCon ==="

# Verificar se o alias já existe
if grep -q "Host $ALIAS" "$SSH_CONFIG" 2>/dev/null; then
    echo "Alias '$ALIAS' já existe em $SSH_CONFIG"
    echo "Remova manualmente se quiser reconfigurar."
    exit 0
fi

# Adicionar alias
cat >> "$SSH_CONFIG" << EOF

# GesCon — LXC 105 (192.168.2.105)
Host $ALIAS
    HostName $HOST_IP
    User root
    ProxyJump homelab-lan
    StrictHostKeyChecking no
EOF

chmod 600 "$SSH_CONFIG"

echo "Alias '$ALIAS' adicionado em $SSH_CONFIG"
echo ""
echo "Acesso:"
echo "  ssh $ALIAS"
echo ""
echo "Testando conexão..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$ALIAS" echo "SSH OK" 2>/dev/null; then
    echo "Conexão OK!"
else
    echo "Conexão falhou (pode ser timeout se a LXC ainda não existe)"
fi
