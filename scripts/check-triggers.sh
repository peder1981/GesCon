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

esperar_erro "UNI com condômino inexistente" \
    "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO, FILIAL) VALUES ('999', 1.0, 'C999', '010101')"

sqlite3 "$db" "INSERT INTO CON (CON_CODIGO, CON_NOME, FILIAL) VALUES ('C001', 'Fulano', '010101')"
esperar_ok "UNI com condômino existente" \
    "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO, FILIAL) VALUES ('999', 1.0, 'C001', '010101')"

esperar_erro "UPDATE de UNI para condômino inexistente" \
    "UPDATE UNI SET UNI_CONDOMINO = 'C999' WHERE UNI_CODIGO = '999'"

# I6 (revisão final): a validação original checava só CON_CODIGO, sem
# FILIAL -- uma UNI da filial 010101 conseguia vincular a um CON que só
# existe na filial 020202 (tenant diferente). C002 abaixo só existe em
# 020202; a UNI de teste é inserida em 010101.
sqlite3 "$db" "INSERT INTO CON (CON_CODIGO, CON_NOME, FILIAL) VALUES ('C002', 'Beltrano', '020202')"
esperar_erro "UNI com condômino de outra filial (cross-tenant)" \
    "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO, FILIAL) VALUES ('998', 1.0, 'C002', '010101')"

sqlite3 "$db" "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, FILIAL) VALUES ('999', '2026-01', 500.0, '2026-01-10', '010101')"
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
