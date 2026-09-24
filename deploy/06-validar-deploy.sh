#!/bin/bash
# 06-validar-deploy.sh — Valida o deploy completo do GesCon.
#
# Executar DENTRO da LXC 105 (gescon) após todos os passos.
# Verifica: AdvPP, GesCon, systemd, cloudflared, banco.

set -euo pipefail

echo "=== Validação do Deploy GesCon ==="
echo "Data: $(date)"
echo ""

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" &>/dev/null; then
        echo "  ✅ $desc"
        ((PASS++))
    else
        echo "  ❌ $desc"
        ((FAIL++))
    fi
}

# --- 1. AdvPP ---
echo "[1/5] AdvPP"
check "advplc instalado" command -v advplc
check "advplc version" advplc version

# --- 2. GesCon ---
echo "[2/5] GesCon"
check "repo clonado" test -d /opt/gescon/.git
check "gescon.prw existe" test -f /opt/gescon/gescon.prw
check "schema.sql existe" test -f /opt/gescon/schema.sql
check "bootstrap executado" test -f "$HOME/.advpp/ADVPP.db"

# --- 3. Banco ---
echo "[3/5] Banco de Dados"
check "ADVPP.db existe" test -f "$HOME/.advpp/ADVPP.db"
TABELAS=$(sqlite3 "$HOME/.advpp/ADVPP.db" ".tables" 2>/dev/null | wc -w)
if [ "$TABELAS" -ge 10 ]; then
    echo "  ✅ Tabelas: $TABELAS (esperado >= 10)"
    ((PASS++))
else
    echo "  ❌ Tabelas: $TABELAS (esperado >= 10)"
    ((FAIL++))
fi

# --- 4. Systemd ---
echo "[4/5] Systemd"
check "gescon.service existe" systemctl is-enabled gescon.service
check "cloudflared.service existe" systemctl is-enabled cloudflared.service

# --- 5. Portas ---
echo "[5/5] Portas"
if ss -tlnp | grep -q ":8080"; then
    echo "  ✅ Porta 8080 aberta"
    ((PASS++))
else
    echo "  ⚠️  Porta 8080 não aberta (GesCon pode não estar rodando)"
fi

if ss -tlnp | grep -q ":7844\|:8854"; then
    echo "  ✅ Cloudflared conectando"
    ((PASS++))
else
    echo "  ⚠️  Cloudflared pode não estar conectado"
fi

# --- Resumo ---
echo ""
echo "=== Resultado ==="
echo "✅ Passou: $PASS"
echo "❌ Falhou: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "ALGUNS CHECKS FALHARAM. Verifique os itens marcados com ❌."
    exit 1
else
    echo ""
    echo "🎉 Deploy válido! GesCon está pronto para uso."
    echo ""
    echo "Acesse: https://gescon.itmix.com.br"
fi
