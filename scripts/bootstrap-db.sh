#!/bin/sh
# Aplica schema.sql no banco compartilhado do AdvPP. Rodar uma vez antes do
# primeiro `advplc serve gescon.prw`, e de novo sempre que schema.sql mudar
# (usa CREATE TABLE IF NOT EXISTS — seguro rodar mais de uma vez).
set -e
DB="${ADVPP_DB:-$HOME/.advpp/ADVPP.db}"
sqlite3 "$DB" < "$(dirname "$0")/../schema.sql"
echo "Schema aplicado em $DB"
