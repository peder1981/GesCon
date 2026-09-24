#!/bin/bash
# 05-backup-setup.sh — Configura backup automático do banco GesCon.
#
# Executar DENTRO da LXC 105 (gescon).
# Cria cron de backup diário do ADVPP.db.

set -euo pipefail

echo "=== Configurando backup GesCon ==="

BACKUP_DIR="/opt/gescon/backups"
DB_PATH="$HOME/.advpp/ADVPP.db"
CRON_FILE="/etc/cron.d/gescon-backup"

mkdir -p "$BACKUP_DIR"

# Script de backup
cat > /usr/local/bin/gescon-backup.sh << 'EOF'
#!/bin/bash
# Backup diário do banco GesCon.
# Mantém últimos 30 dias de backup.

set -euo pipefail

DB_PATH="$HOME/.advpp/ADVPP.db"
BACKUP_DIR="/opt/gescon/backups"
DATE=$(date +%Y-%m-%d_%H%M)
BACKUP_FILE="$BACKUP_DIR/gescon_${DATE}.db"

# Verificar se o banco existe
if [ ! -f "$DB_PATH" ]; then
    echo "ERRO: Banco não encontrado em $DB_PATH"
    exit 1
fi

# Backup usando .backup do SQLite (seguro em produção)
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"

# Comprimir
gzip "$BACKUP_FILE"

# Limpar backups antigos (manter 30 dias)
find "$BACKUP_DIR" -name "gescon_*.db.gz" -mtime +30 -delete

echo "Backup concluído: ${BACKUP_FILE}.gz"
EOF

chmod +x /usr/local/bin/gescon-backup.sh

# Criar cron (03:00 diário)
cat > "$CRON_FILE" << 'EOF'
# GesCon — backup diário do banco (03:00)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 3 * * * root /usr/local/bin/gescon-backup.sh >> /var/log/gescon-backup.log 2>&1
EOF

chmod 644 "$CRON_FILE"

echo "Backup configurado:"
echo "  Script: /usr/local/bin/gescon-backup.sh"
echo "  Cron: $CRON_FILE"
echo "  Horário: 03:00 diário"
echo "  Retenção: 30 dias"
echo "  Diretório: $BACKUP_DIR"
echo ""
echo "Teste manual:"
echo "  /usr/local/bin/gescon-backup.sh"
