#!/bin/sh
# Verifica os triggers de integridade de schema.sql (vínculo UNI->CON e
# trava de COB) direto no SQLite. Não passa pelo AdvPP de propósito: um
# native error de TCSqlExec aborta o processo inteiro (Try/Catch não
# captura), então provar "isto deve falhar" em AdvPL derrubaria o teste
# junto. sqlite3 CLI prova a mesma regra sem esse problema.
set -e

cd "$(dirname "$0")/.."
db=$(mktemp)
trap 'rm -f "$db"' EXIT

sqlite3 "$db" < schema.sql

falhou=0

esperar_erro() {
    descricao="$1"
    sql="$2"
    if sqlite3 "$db" "$sql" 2>/dev/null; then
        echo "FALHA: $descricao — deveria ter sido rejeitado pelo trigger"
        falhou=1
    else
        echo "ok    $descricao (rejeitado)"
    fi
}

esperar_ok() {
    descricao="$1"
    sql="$2"
    if sqlite3 "$db" "$sql" 2>/dev/null; then
        echo "ok    $descricao"
    else
        echo "FALHA: $descricao — deveria ter sido aceito"
        falhou=1
    fi
}

# 101-120 já vêm semeadas por schema.sql ("Seed units for testing"); usa
# um código fora dessa faixa para não colidir com UNI_CODIGO UNIQUE.
esperar_erro "UNI com condômino inexistente" \
    "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO) VALUES ('999', 1.0, 'C999')"

sqlite3 "$db" "INSERT INTO CON (CON_CODIGO, CON_NOME) VALUES ('C001', 'Fulano')"
esperar_ok "UNI com condômino existente" \
    "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO) VALUES ('999', 1.0, 'C001')"

esperar_erro "UPDATE de UNI para condômino inexistente" \
    "UPDATE UNI SET UNI_CONDOMINO = 'C999' WHERE UNI_CODIGO = '999'"

sqlite3 "$db" "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO) VALUES ('999', '2026-01', 500.0, '2026-01-10')"
esperar_erro "alterar COB_VALOR depois de criado" \
    "UPDATE COB SET COB_VALOR = 999 WHERE COB_UNIDADE = '999'"
esperar_erro "excluir (soft-delete) COB" \
    "UPDATE COB SET D_E_L_E_T_ = '*' WHERE COB_UNIDADE = '999'"
esperar_ok "Registrar Pagamento (status/data) continua permitido" \
    "UPDATE COB SET COB_STATUS = 'pago', COB_DTPAG = '2026-01-15' WHERE COB_UNIDADE = '999'"

if [ "$falhou" = 1 ]; then
    echo "check-triggers: FALHOU"
    exit 1
fi
echo "check-triggers: ok"
