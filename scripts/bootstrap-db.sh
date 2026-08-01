#!/bin/sh
# Aplica schema.sql no banco compartilhado do AdvPP. Rodar uma vez antes do
# primeiro `advplc serve gescon.prw`, e de novo sempre que schema.sql mudar
# (usa CREATE TABLE IF NOT EXISTS — seguro rodar mais de uma vez).
set -e
DB="${ADVPP_DB:-$HOME/.advpp/ADVPP.db}"
# -bail: sem isto o sqlite3 apenas imprime o erro e segue, saindo 1 no fim --
# o schema ficava meio aplicado e o "Schema aplicado" nunca aparecia pra
# denunciar. Melhor abortar no primeiro erro.
sqlite3 -bail "$DB" < "$(dirname "$0")/../schema.sql"
echo "Schema aplicado em $DB"
