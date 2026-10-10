#!/bin/bash
# 05-backup-setup.sh — Configura backup automático do banco GesCon.
#
# Executar DENTRO da LXC 105 (gescon), como root.
# Agendamento: systemd timer (04:30 UTC, Persistent=true) — é o que roda em
# produção. NÃO criar também uma entrada em /etc/cron.d: o script grava
# arquivos com nome por data, então dois agendadores só duplicam o trabalho
# (o tar de /opt/gescon tem ~40 MB).

set -euo pipefail

echo "=== Configurando backup GesCon ==="

# Script de backup (idêntico ao de produção)
cat > /usr/local/bin/gescon-backup.sh << 'EOF'
#!/bin/bash
# GesCon backup diario: SQLite ADVPP.db (online-safe) + /opt/gescon
# Mantém as 7 cópias mais recentes de cada.
set -euo pipefail
DST=/var/backups/gescon
D=$(date +%Y%m%d)
mkdir -p "$DST"
sqlite3 /root/.advpp/ADVPP.db ".backup $DST/ADVPP-$D.db"
tar czf "$DST/gescon-opt-$D.tar.gz" -C /opt gescon 2>/dev/null
ls -t $DST/ADVPP-*.db 2>/dev/null | tail -n +8 | xargs -r rm -f
ls -t $DST/gescon-opt-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
echo "gescon-backup $D OK"
EOF
chmod +x /usr/local/bin/gescon-backup.sh

cat > /etc/systemd/system/gescon-backup.service << 'EOF'
[Unit]
Description=GesCon - backup diario SQLite + app
[Service]
Type=oneshot
ExecStart=/usr/local/bin/gescon-backup.sh
EOF

cat > /etc/systemd/system/gescon-backup.timer << 'EOF'
[Unit]
Description=Roda gescon-backup diariamente
[Timer]
OnCalendar=*-*-* 04:30:00
Persistent=true
[Install]
WantedBy=timers.target
EOF

# Remove o agendamento antigo por cron, se existir
rm -f /etc/cron.d/gescon-backup

systemctl daemon-reload
systemctl enable --now gescon-backup.timer

echo "Backup configurado:"
echo "  Script:    /usr/local/bin/gescon-backup.sh"
echo "  Timer:     gescon-backup.timer (04:30 UTC diário)"
echo "  Retenção:  7 cópias de cada arquivo"
echo "  Diretório: /var/backups/gescon"
echo ""
echo "Teste manual:  systemctl start gescon-backup.service"
echo "Próxima execução:  systemctl list-timers gescon-backup.timer"
