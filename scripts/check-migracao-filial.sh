#!/bin/sh
# scripts/check-migracao-filial.sh -- prova que um banco no formato ANTIGO
# (pre-multi-condominio, sem FILIAL) sobe limpo depois de GcBootstrapDB:
# ganha a coluna, os dados antigos viram o condominio 010101, e a
# unicidade composta funciona.
set -e
cd "$(dirname "$0")/.."

banco=$(mktemp -u --suffix=.db)
trap 'rm -f "$banco"' EXIT

# Monta um banco no formato ANTIGO (sem FILIAL, UNIQUE simples) -- o
# formato que a v1.0.10 já instalada tem de verdade.
sqlite3 "$banco" <<'EOF'
CREATE TABLE UNI (R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT, D_E_L_E_T_ TEXT DEFAULT ' ', R_E_C_D_E_L_ INTEGER DEFAULT 0, UNI_CODIGO TEXT NOT NULL UNIQUE, UNI_BLOCO TEXT, UNI_FRACAO REAL NOT NULL DEFAULT 0, UNI_CONDOMINO TEXT);
INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO) VALUES ('101', 0.5), ('102', 0.5);
CREATE TABLE COB (R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT, D_E_L_E_T_ TEXT DEFAULT ' ', R_E_C_D_E_L_ INTEGER DEFAULT 0, COB_UNIDADE TEXT NOT NULL, COB_COMPET TEXT NOT NULL, COB_VALOR REAL NOT NULL DEFAULT 0, COB_VENCTO TEXT, COB_STATUS TEXT NOT NULL DEFAULT 'pendente', COB_DTPAG TEXT);
INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR) VALUES ('101', '2026-01', 500);
EOF

cat > /tmp/migra_filial_check.prw <<PRW
#include "totvs.ch"
User Function MigraFilialCheck()
    GcBootstrapDB()
    ConOut("uni_com_filial=" + cValToChar(Len(TCSqlQuery("SELECT FILIAL FROM UNI WHERE FILIAL = '010101'"))))
    ConOut("cob_com_filial=" + cValToChar(Len(TCSqlQuery("SELECT FILIAL FROM COB WHERE FILIAL = '010101'"))))
    ConOut("cond_existe=" + cValToChar(Len(TCSqlQuery("SELECT COND_FILIAL FROM COND WHERE COND_FILIAL = '010101'"))))
Return

#include "$(pwd)/src/db.prw"
#include "$(pwd)/src/schema-embed.prw"
PRW

saida=$(advplc run /tmp/migra_filial_check.prw --db-path "$banco" -I "$(pwd)/src" 2>&1) || { echo "FALHA: advplc run retornou erro"; echo "$saida"; exit 1; }
echo "$saida"

echo "$saida" | grep -q "uni_com_filial=2" || { echo "FALHA: UNI não migrou (esperava 2 linhas com FILIAL=010101)"; exit 1; }
echo "$saida" | grep -q "cob_com_filial=1" || { echo "FALHA: COB não migrou"; exit 1; }
echo "$saida" | grep -q "cond_existe=1" || { echo "FALHA: COND não foi semeado"; exit 1; }

# Idempotência: rodar de novo não deve dar erro (coluna já existe).
advplc run /tmp/migra_filial_check.prw --db-path "$banco" -I "$(pwd)/src" >/dev/null 2>&1 || { echo "FALHA: segunda execução (idempotência) deu erro"; exit 1; }

# Unicidade composta: dois condomínios com a mesma UNI_CODIGO devem coexistir.
sqlite3 "$banco" "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, FILIAL) VALUES ('101', 0.3, '010102')" || { echo "FALHA: unicidade composta não permite UNI_CODIGO repetido em filial diferente"; exit 1; }

echo "check-migracao-filial: ok"
