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
-- A1 (Wilson Kraft, QA v1.2.0): unidade vinculada a condômino. A trigger
-- da UNI nova exige CON.FILIAL = UNI.FILIAL; a ordem da restauração importa.
CREATE TABLE CON (R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT, D_E_L_E_T_ TEXT DEFAULT ' ', R_E_C_D_E_L_ INTEGER DEFAULT 0, CON_CODIGO TEXT NOT NULL, CON_NOME TEXT NOT NULL);
INSERT INTO CON (CON_CODIGO, CON_NOME) VALUES ('C001', 'Teste');
UPDATE UNI SET UNI_CONDOMINO = 'C001' WHERE UNI_CODIGO = '101';
-- A7: cobrança antiga com dízima de ponto flutuante
INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR) VALUES ('102', '2026-01', 25.000500000000002);
-- A2: DES de um banco antigo, sem DES_LANCADO_CONTABIL.
CREATE TABLE DES (R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT, D_E_L_E_T_ TEXT DEFAULT ' ', R_E_C_D_E_L_ INTEGER DEFAULT 0, DES_DESCR TEXT NOT NULL, DES_CATEG TEXT, DES_VALOR REAL NOT NULL DEFAULT 0, DES_COMPET TEXT NOT NULL, DES_DTLANC TEXT);
-- A4: despesa legada com competência "MM/AAAA"
INSERT INTO DES (DES_DESCR, DES_VALOR, DES_COMPET) VALUES ('Legada', 100, '09/2026');
EOF

cat > /tmp/migra_filial_check.prw <<PRW
#include "totvs.ch"
User Function MigraFilialCheck()
    GcBootstrapDB()
    ConOut("uni_com_filial=" + cValToChar(Len(TCSqlQuery("SELECT FILIAL FROM UNI WHERE FILIAL = '010101'"))))
    ConOut("cob_com_filial=" + cValToChar(Len(TCSqlQuery("SELECT FILIAL FROM COB WHERE FILIAL = '010101'"))))
    ConOut("vinculo=" + TCSqlQuery("SELECT UNI_CONDOMINO FROM UNI WHERE UNI_CODIGO = '101'")[1]:UNI_CONDOMINO)
    ConOut("cond_existe=" + cValToChar(Len(TCSqlQuery("SELECT COND_FILIAL FROM COND WHERE COND_FILIAL = '010101'"))))
Return

#include "$(pwd)/src/db.prw"
#include "$(pwd)/src/schema-embed.prw"
PRW

saida=$(advplc run /tmp/migra_filial_check.prw --db-path "$banco" -I "$(pwd)/src" 2>&1) || { echo "FALHA: advplc run retornou erro"; echo "$saida"; exit 1; }
echo "$saida"

echo "$saida" | grep -q "uni_com_filial=2" || { echo "FALHA: UNI não migrou (esperava 2 linhas com FILIAL=010101)"; exit 1; }
echo "$saida" | grep -q "cob_com_filial=2" || { echo "FALHA: COB não migrou"; exit 1; }
echo "$saida" | grep -q "cond_existe=1" || { echo "FALHA: COND não foi semeado"; exit 1; }

echo "$saida" | grep -q "vinculo=C001" || { echo "FALHA A1: vínculo unidade 101 -> C001 não foi preservado"; exit 1; }
sqlite3 "$banco" "SELECT DES_LANCADO_CONTABIL FROM DES LIMIT 0" || { echo "FALHA A2: DES_LANCADO_CONTABIL não foi criada em banco antigo"; exit 1; }

[ "$(sqlite3 "$banco" "SELECT DES_COMPET FROM DES")" = "2026-09" ] || { echo "FALHA A4: DES_COMPET 09/2026 não foi normalizada"; exit 1; }
[ "$(sqlite3 "$banco" "SELECT COB_VALOR FROM COB WHERE COB_UNIDADE = '102'")" = "25.0" ] || { echo "FALHA A7: dízima de COB_VALOR não foi arredondada"; exit 1; }
[ "$(sqlite3 "$banco" "SELECT COUNT(*) FROM sqlite_master WHERE name = 'TRG_COB_TRAVA_VALOR'")" = "1" ] || { echo "FALHA A7: trigger TRG_COB_TRAVA_VALOR não foi recriada"; exit 1; }

# Idempotência: rodar de novo não deve dar erro (coluna já existe).
advplc run /tmp/migra_filial_check.prw --db-path "$banco" -I "$(pwd)/src" >/dev/null 2>&1 || { echo "FALHA: segunda execução (idempotência) deu erro"; exit 1; }

# Unicidade composta: dois condomínios com a mesma UNI_CODIGO devem coexistir.
sqlite3 "$banco" "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, FILIAL) VALUES ('101', 0.3, '010102')" || { echo "FALHA: unicidade composta não permite UNI_CODIGO repetido em filial diferente"; exit 1; }

# A1, banco JÁ travado pelo bug (UNI nova vazia, UNI_OLD com unidade
# vinculada, CON com FILIAL NULL): tem que se recuperar sozinho no boot.
travado=$(mktemp -u --suffix=.db)
trap 'rm -f "$banco" "$travado"' EXIT
sqlite3 "$travado" < schema.sql
sqlite3 "$travado" <<'EOF'
INSERT INTO CON (FILIAL, CON_CODIGO, CON_NOME) VALUES (NULL, 'C001', 'Travado');
CREATE TABLE UNI_OLD (R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT, D_E_L_E_T_ TEXT DEFAULT ' ', R_E_C_D_E_L_ INTEGER DEFAULT 0, UNI_CODIGO TEXT NOT NULL UNIQUE, UNI_BLOCO TEXT, UNI_FRACAO REAL NOT NULL DEFAULT 0, UNI_CONDOMINO TEXT);
INSERT INTO UNI_OLD (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO) VALUES ('101', 0.5, 'C001'), ('102', 0.5, NULL);
-- excluída e ligada a condômino inexistente: a trigger não pode abortar
INSERT INTO UNI_OLD (D_E_L_E_T_, UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO) VALUES ('*', '103', 0.1, 'C999');
EOF
saida=$(advplc run /tmp/migra_filial_check.prw --db-path "$travado" -I "$(pwd)/src" 2>&1) || { echo "FALHA: banco travado não se recuperou"; echo "$saida"; exit 1; }
echo "$saida" | grep -q "vinculo=C001" || { echo "FALHA A1: banco travado não restaurou o vínculo"; echo "$saida"; exit 1; }
[ "$(sqlite3 "$travado" "SELECT COUNT(*) FROM UNI")" = "3" ] || { echo "FALHA A1: unidades não restauradas no banco travado"; exit 1; }
[ "$(sqlite3 "$travado" "SELECT COUNT(*) FROM sqlite_master WHERE name = 'UNI_OLD'")" = "0" ] || { echo "FALHA A1: sobrou UNI_OLD"; exit 1; }

echo "check-migracao-filial: ok"
