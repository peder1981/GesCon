#!/bin/bash
# 01-criar-lxc.sh — Cria LXC 105 (gescon) no Proxmox.
#
# Executar NO HOST Proxmox (não dentro de uma LXC).
# Requer Proxmox VE 8+ e template Debian 12.
#
# Dimensionamento (conservador, baseado no padrão BLU/Justatistic):
#   - 2 vCPUs (AdvPP web + SQLite)
#   - 2GB RAM (AdvPP é leve, mas Comfort threshold)
#   - 20GB disco (SQLite + código + backups)
#   - Bridge vmbr0 (192.168.2.x)
#   - Unprivileged (padrão segurança)
#
# Uso:
#   ssh homelab-lan 'bash -s' < 01-criar-lxc.sh

set -euo pipefail

# --- Parâmetros ---
CTID=105
HOSTNAME="gescon"
IP="192.168.2.105/24"
GW="192.168.2.194"
DISK="20"
RAM=2048
SWAP=512
CORES=2
BRIDGE="vmbr0"

# Template Debian 12 (verificar se existe)
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

echo "=== Criando LXC $CTID ($HOSTNAME) ==="
echo "IP: $IP | GW: $GW | RAM: ${RAM}MB | Disk: ${DISK}GB | Cores: $CORES"

# Verificar se o CTID já existe
if pct status "$CTID" &>/dev/null; then
    echo "ERRO: LXC $CTID já existe!"
    exit 1
fi

# Verificar template
if ! pvesm list local | grep -q "debian-12"; then
    echo "Template Debian 12 não encontrado. Baixando..."
    pveam update
    pveam install "$TEMPLATE"
fi

# Criar LXC
pct create "$CTID" "$TEMPLATE" \
    --hostname "$HOSTNAME" \
    --memory "$RAM" \
    --swap "$SWAP" \
    --cores "$CORES" \
    --net0 "name=eth0,bridge=$BRIDGE,ip=$IP,gw=$GW,type=veth" \
    --rootfs "local-lvm:${DISK}" \
    --unprivileged 1 \
    --onboot 1 \
    --ostype debian

echo "LXC $CTID criada. Iniciando..."
pct start "$CTID"

# Aguardar boot
sleep 5

# Configurar SSH (copiar authorized_keys do host)
pct exec "$CTID" -- mkdir -p /root/.ssh
pct exec "$CTID" -- cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bak 2>/dev/null || true
pct push "$CTID" /root/.ssh/authorized_keys /root/.ssh/authorized_keys

# Testar SSH via pct
echo "Testando SSH..."
pct exec "$CTID" -- ssh -o StrictHostKeyChecking=no localhost echo "SSH OK"

echo ""
echo "=== LXC $CTID ($HOSTNAME) criada com sucesso ==="
echo "IP: $IP"
echo "Acesso: pct enter $CTID"
echo ""
echo "Próximo passo: executar 02-setup-advpp.sh dentro da LXC"
