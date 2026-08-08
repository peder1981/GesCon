# Multi-condomínio (GesCon) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o GesCon administrar vários condomínios num banco único, usando a coluna `FILIAL` (6 chars, convenção Protheus) e as natives `RpcSetEnv`/`FWxFilial` do AdvPP — schema, login/sessão, cadastro de condomínios, e toda query manual do app filtrada.

**Architecture:** Coluna `FILIAL` em 22 das 24 tabelas + tabela nova `COND` (cadastro de condomínios) + `USR_COND` (vínculo síndico↔condomínio). Sessão grava a filial ativa via `RpcSetEnv`; toda query manual lê de volta via `FWxFilial(cAlias)`. Telas `FWMBrowse` puras (Unidades, Condôminos, Despesas, Plano de Contas, Repartição) não precisam de nenhuma mudança de código — o auto-filtro já vem do AdvPP (plano irmão, pré-requisito).

**Tech Stack:** AdvPL/AdvPP, SQLite (via `TCSqlQuery`/`TCSqlExec`).

## Global Constraints

- **Pré-requisito bloqueante:** este plano só compila contra uma versão do AdvPP que já tenha `RpcSetEnv`/`FWxFilial`/auto-filtro em `FWMBrowse` — ver `AdvPP/docs/superpowers/plans/2026-08-08-multi-filial-implementation.md`. Não iniciar a Task 2 antes desse release existir.
- Encoding: este repositório usa UTF-8 em todo `.prw`/`.sql` (convenção própria já estabelecida — diverge da regra CP-1252 dos projetos AdvPL em geral, mas é o padrão real deste código).
- Toda interpolação de valor em SQL passa por `GcSqlLit` (deixa as aspas por conta de quem chama) ou `GcSqlVal` (já devolve com aspas) — nunca concatenar direto.
- `Function` pura é proibida — só `User Function` ou `Static Function`.
- Nenhuma tabela do GesCon usa nível de compartilhamento diferente de 6 (exclusiva) — decisão explícita da spec.
- `scripts/check.sh` e `scripts/test.sh` devem continuar em zero erro/zero falha ao fim de cada task.

---

### Task 1: Pin da versão nova do AdvPP

**Files:**
- Modify: `ADVPP_VERSION`
- Modify: `docs/FUNCIONAL.md` (nota de dependência, opcional mas recomendado)

**Interfaces:**
- Consumes: a tag/versão publicada pelo plano AdvPP irmão (Task 4, Step 6 daquele plano).

- [ ] **Step 1: Confirmar que a versão está instalada localmente**

Run: `advplc version` (ou `~/.local/bin/advplc version` se não estiver no PATH)
Expected: a versão bate com a que o plano AdvPP publicou (ex.: `v2.0.17` ou o que tiver sido escolhido lá — não adivinhar, checar o release real).

- [ ] **Step 2: Confirmar que as natives novas existem no binário instalado**

Run:
```bash
cat > /tmp/check_natives.prw <<'EOF'
#include "totvs.ch"
User Function CheckNatives()
    RpcSetEnv("010101")
    ConOut("FWxFilial: " + FWxFilial("X"))
Return
EOF
advplc run /tmp/check_natives.prw
```
Expected: `FWxFilial: 010101` — sem `Error: unknown function`. Se der erro de função desconhecida, a versão local do AdvPP ainda não tem a Task 1-3 daquele plano; pare aqui e resolva isso primeiro (não é algo que este plano do GesCon possa corrigir).

- [ ] **Step 3: Atualizar `ADVPP_VERSION`**

Ler o conteúdo atual (`cat ADVPP_VERSION`) e substituir pela versão confirmada no Step 1, sem o prefixo `v` (mesmo formato já usado — confirmar olhando o conteúdo atual do arquivo antes de editar).

- [ ] **Step 4: Rebuild local pra confirmar que nada quebrou com a nova versão**

Run: `bash scripts/check.sh && bash scripts/test.sh && bash scripts/build.sh`
Expected: os três passam limpo, exatamente como antes — esta task não muda nenhum código do GesCon ainda, só a versão pinada.

- [ ] **Step 5: Commit**

```bash
git add ADVPP_VERSION
git commit -m "build: pin AdvPP com RpcSetEnv/FWxFilial (multi-condominio)"
```

---

### Task 2: Schema — `COND`, `USR_COND`, `FILIAL` em 22 tabelas, migração

**Files:**
- Modify: `schema.sql`
- Modify: `src/db.prw` (nova função de migração, chamada por `GcBootstrapDB`)
- Modify: `scripts/gen-schema-embed.sh` output — regenerar `src/schema-embed.prw` (não editar à mão)
- Modify: `scripts/check-triggers.sh` (os dois casos de teste que inserem em `UNI`/`COB` precisam de `FILIAL` agora que a coluna existe)
- Test: `scripts/check-migracao-filial.sh` (new)

**Interfaces:**
- Produces: toda tabela tenant ganha `FILIAL TEXT`; `UNI_CODIGO`/`PLA_CODIGO`/`REP_CODIGO`/`EXE_CODIGO` passam de `UNIQUE` global para `UNIQUE(FILIAL, campo)`. `User Function GcMigrarParaFilial()` (chamada do `GcBootstrapDB`, `src/db.prw`) faz a migração idempotente de um banco já instalado. Filial padrão da migração: `'010101'`.

- [ ] **Step 1: Adicionar `COND`, `USR_COND`, `X2_FILIAL_COMPART` ao `schema.sql`**

Logo após o bloco `CREATE TABLE IF NOT EXISTS USR (...)` em `schema.sql`, adicionar:

```sql
CREATE TABLE IF NOT EXISTS COND (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    COND_FILIAL TEXT UNIQUE NOT NULL,
    COND_NOME TEXT NOT NULL,
    COND_CNPJ TEXT,
    COND_ENDERECO TEXT,
    COND_ATIVO NUMERIC DEFAULT 1
);

CREATE TABLE IF NOT EXISTS USR_COND (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    USR_LOGIN TEXT NOT NULL,
    FILIAL TEXT NOT NULL
);

-- Nivel de compartilhamento por tabela, lido pela native FWxFilial do
-- AdvPP (ver AdvPP/docs/superpowers/plans/2026-08-08-multi-filial-implementation.md).
-- 6 = exclusiva por filial (unica opcao usada hoje no GesCon).
CREATE TABLE IF NOT EXISTS X2_FILIAL_COMPART (
    TABELA TEXT PRIMARY KEY,
    NIVEL  INTEGER NOT NULL
);
INSERT OR IGNORE INTO X2_FILIAL_COMPART (TABELA, NIVEL) VALUES
    ('CON', 6), ('UNI', 6), ('DES', 6), ('COB', 6),
    ('RPT_INADIM', 6), ('RPT_EXTRATO', 6), ('RPT_DESCAT', 6),
    ('CFG_BOLETO', 6), ('GCT_TOKEN', 6), ('RPT_COND_COBRANCAS', 6),
    ('PLANO_CONTAS', 6), ('REPARTICAO', 6), ('EXERCICIO', 6),
    ('LANCAMENTOS', 6), ('RATEIO_DETALHE', 6), ('AUDITORIA', 6),
    ('RPT_BALANCETE', 6), ('AVISOS', 6), ('RPT_PORTAL_EXTRATOS', 6),
    ('RPT_PORTAL_AGENDA', 6), ('ANOMALIA_LOG', 6), ('ALERTA', 6),
    ('DASHBOARD_CACHE', 6);

-- Migração automática: base já instalada vira o condomínio nº 1.
INSERT OR IGNORE INTO COND (COND_FILIAL, COND_NOME) VALUES ('010101', 'Condomínio 1');
```

Also add `X3` metadata rows for `COND` (mirroring the existing pattern for `UNI`/`COB` around line 169-177 of `schema.sql`):

```sql
('COND', 1, 'COND_FILIAL', 'C', 6, 0, 'Filial'),
('COND', 2, 'COND_NOME', 'C', 60, 0, 'Nome'),
('COND', 3, 'COND_CNPJ', 'C', 18, 0, 'CNPJ'),
('COND', 4, 'COND_ENDERECO', 'C', 100, 0, 'Endereço'),
('COND', 5, 'COND_ATIVO', 'N', 1, 0, 'Ativo'),
```
(append these to whichever `INSERT INTO SX3 (...) VALUES (...)` block already exists — check the exact multi-row `VALUES` list around line 169 and add a comma-separated continuation, don't start a second `INSERT`.)

- [ ] **Step 2: Add `FILIAL TEXT` to each of the 18 "simple" tenant tables**

Add `FILIAL TEXT,` as a new column (right after `R_E_C_D_E_L_` where that column exists, otherwise right after `D_E_L_E_T_`) in each `CREATE TABLE IF NOT EXISTS` block for: `CON`, `DES`, `COB`, `RPT_INADIM`, `RPT_EXTRATO`, `RPT_DESCAT`, `CFG_BOLETO`, `GCT_TOKEN`, `RPT_COND_COBRANCAS`, `LANCAMENTOS`, `RATEIO_DETALHE`, `AUDITORIA`, `RPT_BALANCETE`, `AVISOS`, `RPT_PORTAL_EXTRATOS`, `RPT_PORTAL_AGENDA`, `ANOMALIA_LOG`, `ALERTA`, `DASHBOARD_CACHE`.

Example (`CON`, already read at the top of `schema.sql`):

```sql
CREATE TABLE IF NOT EXISTS CON (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    FILIAL TEXT,
    CON_CODIGO TEXT NOT NULL,
    CON_NOME TEXT NOT NULL,
    CON_CPF TEXT,
    CON_EMAIL TEXT,
    CON_TEL TEXT
);
```

Apply the identical one-line addition (`FILIAL TEXT,` right after the delete-tracking columns) to the other 17. `NOT NULL` is deliberately **not** added at the column-definition level here — `ALTER TABLE ADD COLUMN` (Step 5, migration path) cannot add a `NOT NULL` column without a `DEFAULT` on a non-empty table, and this schema needs one `CREATE TABLE` shape that works for both the fresh-install and the migrated-install path. The `FILIAL` column is enforced as effectively-required by application discipline (every `INSERT` sets it — see Tasks 5-9) and by the migration backfill (Step 6), not by a DB-level `NOT NULL`.

- [ ] **Step 3: Add `FILIAL TEXT` + fix composite uniqueness on the 4 remaining tables**

`UNI`, `PLANO_CONTAS`, `REPARTICAO`, `EXERCICIO` each have a `UNIQUE` constraint on their code column that must become `UNIQUE(FILIAL, campo)`. Current `UNI` (already read):

```sql
CREATE TABLE IF NOT EXISTS UNI (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    UNI_CODIGO TEXT NOT NULL UNIQUE,
    UNI_BLOCO TEXT,
    UNI_FRACAO REAL NOT NULL DEFAULT 0,
    UNI_CONDOMINO TEXT
);
```

becomes:

```sql
CREATE TABLE IF NOT EXISTS UNI (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    FILIAL TEXT,
    UNI_CODIGO TEXT NOT NULL,
    UNI_BLOCO TEXT,
    UNI_FRACAO REAL NOT NULL DEFAULT 0,
    UNI_CONDOMINO TEXT,
    UNIQUE(FILIAL, UNI_CODIGO)
);
```

Same shape change for the other three — remove the inline `UNIQUE` from the code column, add `FILIAL TEXT,`, add `UNIQUE(FILIAL, <campo>)` as the last item before the closing `)`:
- `PLANO_CONTAS`: `PLA_CODIGO TEXT UNIQUE NOT NULL` → `PLA_CODIGO TEXT NOT NULL`, add `UNIQUE(FILIAL, PLA_CODIGO)`.
- `REPARTICAO`: `REP_CODIGO TEXT UNIQUE NOT NULL` → `REP_CODIGO TEXT NOT NULL`, add `UNIQUE(FILIAL, REP_CODIGO)`.
- `EXERCICIO`: `EXE_CODIGO TEXT UNIQUE NOT NULL` → `EXE_CODIGO TEXT NOT NULL`, add `UNIQUE(FILIAL, EXE_CODIGO)`.

(These four keep the existing `CHECK(...)` clauses, if any, unchanged — only the uniqueness shape and the new column change.)

- [ ] **Step 4: Write the migration test (before the migration code exists)**

Create `scripts/check-migracao-filial.sh`:

```sh
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

cat > /tmp/migra_filial_check.prw <<'PRW'
#include "totvs.ch"
User Function MigraFilialCheck()
    GcBootstrapDB()
    ConOut("uni_com_filial=" + cValToChar(Len(TCSqlQuery("SELECT FILIAL FROM UNI WHERE FILIAL = '010101'"))))
    ConOut("cob_com_filial=" + cValToChar(Len(TCSqlQuery("SELECT FILIAL FROM COB WHERE FILIAL = '010101'"))))
    ConOut("cond_existe=" + cValToChar(Len(TCSqlQuery("SELECT COND_FILIAL FROM COND WHERE COND_FILIAL = '010101'"))))
Return
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
```

- [ ] **Step 5: Run to verify it fails**

Run: `chmod +x scripts/check-migracao-filial.sh && bash scripts/check-migracao-filial.sh`
Expected: FAIL — `GcMigrarParaFilial`/the `FILIAL` column/`COND` table don't exist yet (either `advplc run` errors with `unknown function` if you jump ahead and reference it, or the `grep -q "uni_com_filial=2"` check fails because the column is empty/absent).

- [ ] **Step 6: Implement the migration in `src/db.prw`**

Add to `src/db.prw`, and call `GcMigrarParaFilial()` as the **first line** of `GcBootstrapDB()` (before `TCSqlExec(GcSchemaSQL())`):

```advpl
User Function GcBootstrapDB()
    Local lOk := .T.
    GcMigrarParaFilial()
    lOk := TCSqlExec(GcSchemaSQL())
    If !lOk
        ConOut("GesCon: falha ao aplicar o schema no banco.")
    EndIf
    GcSemearMigracaoFilialPadrao()
Return lOk

/*/{Protheus.doc} GcMigrarParaFilial
    Migração multi-condomínio: garante que toda tabela dependente de
    condomínio tenha a coluna FILIAL, preservando os dados de uma base
    instalada antes desta versão (sem a coluna). Roda ANTES do
    schema.sql normal — decidir "a coluna já existe?" exige PRAGMA
    table_info, que schema.sql (um blob de texto sem lógica condicional)
    não consegue fazer sozinho.

    As 4 tabelas com UNIQUE global no código (UNI, PLANO_CONTAS,
    REPARTICAO, EXERCICIO) precisam de recriação completa — SQLite não
    altera UNIQUE de coluna existente via ALTER TABLE. A tática: renomeia
    a tabela antiga pra _OLD aqui; schema.sql (chamado logo depois, ainda
    dentro de GcBootstrapDB) recria a tabela do zero, já no formato novo,
    porque CREATE TABLE IF NOT EXISTS só age quando a tabela "não existe"
    — e agora ela não existe mesmo, foi renomeada. GcRestaurarTabelasComposta
    (chamada depois do schema.sql) copia os dados de volta e apaga a _OLD.

    Idempotente: numa base já migrada, todo PRAGMA table_info já acha
    FILIAL e a função não faz nada.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcMigrarParaFilial()
    Local aSimples := {"CON", "DES", "COB", "RPT_INADIM", "RPT_EXTRATO", ;
        "RPT_DESCAT", "CFG_BOLETO", "GCT_TOKEN", "RPT_COND_COBRANCAS", ;
        "LANCAMENTOS", "RATEIO_DETALHE", "AUDITORIA", "RPT_BALANCETE", "AVISOS", ;
        "RPT_PORTAL_EXTRATOS", "RPT_PORTAL_AGENDA", "ANOMALIA_LOG", "ALERTA", "DASHBOARD_CACHE"}
    Local aCompostas := {"UNI", "PLANO_CONTAS", "REPARTICAO", "EXERCICIO"}
    Local i

    For i := 1 To Len(aSimples)
        GcAdicionarFilialSeFaltar(aSimples[i])
    Next i

    For i := 1 To Len(aCompostas)
        GcRenomearSeAntiga(aCompostas[i])
    Next i
Return

/*/{Protheus.doc} GcAdicionarFilialSeFaltar
    ALTER TABLE ADD COLUMN FILIAL, só se a tabela existir e ainda não
    tiver a coluna.
    @type Static Function
    @author GesCon
    @since 2026-08-08
    @param cTabela, character, nome da tabela
*/
Static Function GcAdicionarFilialSeFaltar(cTabela)
    Local aCols := TCSqlQuery("PRAGMA table_info(" + cTabela + ")")
    Local i

    If Len(aCols) == 0
        Return  // tabela ainda não existe (banco novo) -- schema.sql cria já com FILIAL
    EndIf

    For i := 1 To Len(aCols)
        If Upper(aCols[i]:NAME) == "FILIAL"
            Return  // já migrada
        EndIf
    Next i

    TCSqlExec("ALTER TABLE " + cTabela + " ADD COLUMN FILIAL TEXT")
Return

/*/{Protheus.doc} GcRenomearSeAntiga
    Renomeia cTabela para cTabela_OLD se ela existir e ainda não tiver
    FILIAL -- primeira metade da migração das 4 tabelas com UNIQUE
    composto (ver GcMigrarParaFilial). A segunda metade é
    GcRestaurarTabelasComposta, chamada depois do schema.sql recriar a
    tabela do zero.
    @type Static Function
    @author GesCon
    @since 2026-08-08
    @param cTabela, character, nome da tabela
*/
Static Function GcRenomearSeAntiga(cTabela)
    Local aCols := TCSqlQuery("PRAGMA table_info(" + cTabela + ")")
    Local i

    If Len(aCols) == 0
        Return  // banco novo -- nada pra renomear
    EndIf

    For i := 1 To Len(aCols)
        If Upper(aCols[i]:NAME) == "FILIAL"
            Return  // já migrada
        EndIf
    Next i

    TCSqlExec("ALTER TABLE " + cTabela + " RENAME TO " + cTabela + "_OLD")
Return

/*/{Protheus.doc} GcSemearMigracaoFilialPadrao
    Segunda metade da migração: chamada depois de TCSqlExec(GcSchemaSQL())
    já ter recriado as 4 tabelas compostas (agora vazias, no formato
    novo). Copia os dados de cada "_OLD" de volta (se existir) com
    FILIAL='010101', apaga a _OLD, e faz o mesmo saneamento (FILIAL
    NULL/vazio -> '010101') em todas as 22 tabelas -- cobre tanto as 4
    recém-restauradas quanto as 18 simples que só ganharam a coluna via
    ALTER (Step 6 acima), que fica NULL até este UPDATE rodar.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcSemearMigracaoFilialPadrao()
    Local aCompostas := {{"UNI", "R_E_C_N_O_,D_E_L_E_T_,R_E_C_D_E_L_,UNI_CODIGO,UNI_BLOCO,UNI_FRACAO,UNI_CONDOMINO"}, ;
        {"PLANO_CONTAS", "R_E_C_N_O_,PLA_CODIGO,PLA_NOME,PLA_TIPO,PLA_ATIVO,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"REPARTICAO", "R_E_C_N_O_,REP_CODIGO,REP_NOME,REP_ATIVO,REP_DETALHE,D_E_L_E_T_,R_E_C_D_E_L_"}, ;
        {"EXERCICIO", "R_E_C_N_O_,EXE_CODIGO,EXE_INICIO,EXE_FIM,EXE_ATIVO,EXE_FECHADO,D_E_L_E_T_,R_E_C_D_E_L_"}}
    Local aTodas := {"CON", "UNI", "DES", "COB", "RPT_INADIM", "RPT_EXTRATO", ;
        "RPT_DESCAT", "CFG_BOLETO", "GCT_TOKEN", "RPT_COND_COBRANCAS", ;
        "PLANO_CONTAS", "REPARTICAO", "EXERCICIO", "LANCAMENTOS", "RATEIO_DETALHE", ;
        "AUDITORIA", "RPT_BALANCETE", "AVISOS", "RPT_PORTAL_EXTRATOS", ;
        "RPT_PORTAL_AGENDA", "ANOMALIA_LOG", "ALERTA", "DASHBOARD_CACHE"}
    Local i
    Local aExiste

    For i := 1 To Len(aCompostas)
        aExiste := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name = '" + ;
            aCompostas[i][1] + "_OLD'")
        If Len(aExiste) > 0
            TCSqlExec("INSERT INTO " + aCompostas[i][1] + " (" + aCompostas[i][2] + ", FILIAL) SELECT " + ;
                aCompostas[i][2] + ", '010101' FROM " + aCompostas[i][1] + "_OLD")
            TCSqlExec("DROP TABLE " + aCompostas[i][1] + "_OLD")
        EndIf
    Next i

    For i := 1 To Len(aTodas)
        TCSqlExec("UPDATE " + aTodas[i] + " SET FILIAL = '010101' WHERE FILIAL IS NULL OR FILIAL = ''")
    Next i
Return
```

- [ ] **Step 7: Regenerate the embedded schema**

Run: `bash scripts/gen-schema-embed.sh`
Expected: `gerado src/schema-embed.prw (NNN linhas)` — commit the regenerated file, never hand-edit it.

- [ ] **Step 8: Run to verify the migration test passes**

Run: `bash scripts/check-migracao-filial.sh`
Expected: `check-migracao-filial: ok`

- [ ] **Step 9: Fix `scripts/check-triggers.sh` for the new `FILIAL` column**

The existing trigger tests insert into `UNI`/`COB` without a `FILIAL` value. That's still valid SQL (the column allows `NULL`), but add `FILIAL` to the two `INSERT` statements in `scripts/check-triggers.sh` so the fixture matches what real code will always send going forward:

Find (in `scripts/check-triggers.sh`):
```sh
esperar_ok "UNI com condômino existente" \
    "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO) VALUES ('999', 1.0, 'C001')"
```
Replace with:
```sh
esperar_ok "UNI com condômino existente" \
    "INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO, UNI_CONDOMINO, FILIAL) VALUES ('999', 1.0, 'C001', '010101')"
```
And find:
```sh
sqlite3 "$db" "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO) VALUES ('999', '2026-01', 500.0, '2026-01-10')"
```
Replace with:
```sh
sqlite3 "$db" "INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, FILIAL) VALUES ('999', '2026-01', 500.0, '2026-01-10', '010101')"
```

- [ ] **Step 10: Run the whole suite**

Run: `bash scripts/check.sh && bash scripts/test.sh && bash scripts/check-migracao-filial.sh`
Expected: all clean. `check.sh`'s "alcance" count will show 4-6 more `Gc*` functions than before (the new migration functions) — confirm they show as reachable (called from `GcBootstrapDB`, itself always reachable), not in the "diferidas" pile.

- [ ] **Step 11: Commit**

```bash
git add schema.sql src/db.prw src/schema-embed.prw scripts/check-triggers.sh scripts/check-migracao-filial.sh
git commit -m "feat(schema): FILIAL em 22 tabelas + COND/USR_COND + migracao automatica"
```

---

### Task 3: Login e sessão — `SUPERADMIN`/`SINDICO`, seletor de condomínio, `RpcSetEnv`

**Files:**
- Modify: `src/login.prw`
- Modify: `gescon.prw` (menu principal — item "Trocar Condomínio", chamada ao seletor logo após login)

**Interfaces:**
- Consumes: `RpcSetEnv` (native, AdvPP), `COND`/`USR_COND` (Task 2).
- Produces: `User Function GcSelecionarCondominio()` — mostra o picker, chama `RpcSetEnv`, grava `Private g_cFilialAtiva`, devolve `.T./.F.`. Chamada por `gescon.prw` logo após `GcLogin()` bater, e de novo pelo item de menu "Trocar Condomínio".

- [ ] **Step 1: `GcCriarAdmin` (bootstrap) vira `SUPERADMIN`**

Em `src/login.prw`, função `GcCriarAdmin` (linha ~44), o `INSERT` atual:

```advpl
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA) VALUES ('" + ;
        GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "')")
```

vira:

```advpl
    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('" + ;
        GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', 'SUPERADMIN')")
```

- [ ] **Step 2: Nova função `GcSelecionarCondominio`**

Adicionar em `src/login.prw`:

```advpl
/*/{Protheus.doc} GcSelecionarCondominio
    Lista os condomínios disponíveis para o login corrente (todos, se
    SUPERADMIN; só os vinculados via USR_COND, se SINDICO), e grava a
    escolha como filial ativa da sessão (RpcSetEnv + Private
    g_cFilialAtiva). Se houver exatamente 1 disponível, seleciona sozinho
    sem mostrar tela. Se houver 0, bloqueia.
    @type Function
    @author GesCon
    @since 2026-08-08
    @param cLogin, character, login já autenticado
    @return lOk, logical, .T. se uma filial foi selecionada
*/
User Function GcSelecionarCondominio(cLogin)
    Local aPerfil := TCSqlQuery("SELECT USR_PERFIL FROM USR WHERE USR_LOGIN = '" + ;
        GcSqlLit(cLogin) + "' AND D_E_L_E_T_ = ' '")
    Local cPerfil := ""
    Local aCond := {}
    Local cLista := ""
    Local nJ
    Local cSel
    Local nIdx

    If Len(aPerfil) > 0
        cPerfil := aPerfil[1]:USR_PERFIL
    EndIf

    If cPerfil == "SUPERADMIN"
        aCond := TCSqlQuery("SELECT COND_FILIAL, COND_NOME FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY COND_NOME")
    Else
        aCond := TCSqlQuery("SELECT C.COND_FILIAL, C.COND_NOME FROM COND C " + ;
            "INNER JOIN USR_COND UC ON UC.FILIAL = C.COND_FILIAL AND UC.D_E_L_E_T_ = ' ' " + ;
            "WHERE UC.USR_LOGIN = '" + GcSqlLit(cLogin) + "' AND C.COND_ATIVO = 1 AND C.D_E_L_E_T_ = ' ' " + ;
            "ORDER BY C.COND_NOME")
    EndIf

    If Len(aCond) == 0
        MsgStop("Nenhum condomínio vinculado a este usuário. Fale com o administrador.", "GesCon")
        Return .F.
    EndIf

    If Len(aCond) == 1
        RpcSetEnv(aCond[1]:COND_FILIAL)
        g_cFilialAtiva := aCond[1]:COND_FILIAL
        Return .T.
    EndIf

    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:COND_NOME + Chr(10)
    Next nJ
    cLista += "\nSelecione o número do condomínio:"

    cSel := FWGetText(cLista, "")
    nIdx := Val(cSel)

    If nIdx < 1 .Or. nIdx > Len(aCond)
        MsgStop("Índice inválido.", "GesCon")
        Return .F.
    EndIf

    RpcSetEnv(aCond[nIdx]:COND_FILIAL)
    g_cFilialAtiva := aCond[nIdx]:COND_FILIAL
Return .T.
```

- [ ] **Step 3: Declare `g_cFilialAtiva` and wire it into `gescon.prw`**

In `gescon.prw`, right after the existing `Private g_cUniPortal := ""` / `Private g_cConPortal := ""` / `Private g_lAutoPortal := .F.` block (line ~48-50), add:

```advpl
    Private g_cFilialAtiva := ""
    Private cLoginAtual := ""
```

Then find where `GcLogin()` is called (inside `Case nEscolha == 1`, around line 64):

```advpl
        Case nEscolha == 1
            If !GcLogin()
                MsgStop("Acesso não autorizado.", "GesCon")
                Return
            EndIf
```

`GcLogin()` doesn't currently return which login succeeded — it needs to for `GcSelecionarCondominio` to know whose vínculo to check. Modify `GcAutenticar` (`src/login.prw`) to store the successful login in a module-level way the caller can read: the simplest fix consistent with existing `Private` session-var usage is to have `GcLogin`/`GcAutenticar`/`GcCriarAdmin` set `cLoginAtual` (declared as `Private` in `gescon.prw` above — visible to every function called from `GesCon()`, same mechanism as `g_cUniPortal`).

In `src/login.prw`, `GcCriarAdmin` — right after the successful `INSERT`, before `Return .T.`:
```advpl
    cLoginAtual := cLogin
```
In `GcAutenticar` — right after `If !GcCredenciaisValidas(...)` passes (i.e. right before the final `Return .T.`):
```advpl
    cLoginAtual := cLogin
```

Then in `gescon.prw`:
```advpl
        Case nEscolha == 1
            If !GcLogin()
                MsgStop("Acesso não autorizado.", "GesCon")
                Return
            EndIf

            If !GcSelecionarCondominio(cLoginAtual)
                Return
            EndIf
```

- [ ] **Step 4: "Trocar Condomínio" menu item**

In `gescon.prw`, the admin menu array (find `Local aMenu := {"Unidades", ...}`, ~line 49-50) gains one entry before `"Sair"`:

```advpl
    Local aMenu := {"Unidades", "Condôminos", "Despesas", "Cobranças", "Fechamento Mensal", ;
        "Mala Direta", "Relatórios", "Contabilidade", "Auditoria", "Boletos", "Avisos", ;
        "Usuários", "Trocar Senha", "Trocar Condomínio", "Sair"}
```

And in the `Do Case` handling `nOpcao` (find `Case nOpcao == 13` for "Trocar Senha", ~line 111), add a new case right after it, renumbering `Otherwise` doesn't change (it stays the fallback for "Sair", whatever number that ends up being — count the array again after the edit to get the right number):

```advpl
                    Case nOpcao == 13
                        GcTrocarSenha()
                    Case nOpcao == 14
                        GcSelecionarCondominio(cLoginAtual)
                    Otherwise
                        Exit
```

- [ ] **Step 5: Manual verification (interactive — no automated test for `FWGetText`-driven flows, matches existing project convention)**

Run: `bash scripts/build.sh && ADVPP_FORCE_GUI=1 ./GesConApp`
Walk through: first-run bootstrap creates a `SUPERADMIN`; with only `COND '010101'` existing (from Task 2's migration seed), login should skip the picker (exactly 1 option) and land directly in the menu; "Trocar Condomínio" reopens the picker. This can't be scripted (interactive `MSDIALOG`/`FWGetText`), so it's a manual check — same limitation already accepted for `tests/usuarios_test.prw`'s interactive paths.

- [ ] **Step 6: Run the automatable suite**

Run: `bash scripts/check.sh && bash scripts/test.sh`
Expected: clean — this task doesn't change any existing automated test's behavior (login flow for the existing single-admin tests is unaffected; `USR_PERFIL='SUPERADMIN'` instead of `'ADMIN'` for the bootstrap admin doesn't break `GcCredenciaisValidas`, which doesn't filter by perfil).

- [ ] **Step 7: Commit**

```bash
git add src/login.prw gescon.prw
git commit -m "feat(login): SUPERADMIN/SINDICO, seletor de condominio, RpcSetEnv"
```

---

### Task 4: Cadastro de Condomínios + perfil/vínculo em Criar Usuário

**Files:**
- Create: `src/condominios-cadastro.prw`
- Modify: `gescon.prw` (novo item de menu)
- Modify: `src/usuarios.prw` (`GcCriarUsuario`/`GcCriarAdminNovo`)

**Interfaces:**
- Consumes: `COND`, `USR_COND` (Task 2).
- Produces: `User Function GcCadastroCondominios()` (menu novo); `GcCriarAdminNovo` ganha parâmetro de perfil implícito via novo submenu.

- [ ] **Step 1: Tela de condomínios**

Create `src/condominios-cadastro.prw`:

```advpl
// src/condominios-cadastro.prw — cadastro de condomínios (tabela COND).
// Browse CRUD puro — COND não tem coluna FILIAL (é ELA que define as
// filiais dos outros, não é filtrada por uma).
#include "totvs.ch"

/*/{Protheus.doc} GcCadastroCondominios
    Abre o cadastro de condomínios (browse CRUD sobre COND). Disponível
    tanto pro super admin quanto pro síndico — quem cadastra um
    condomínio novo ainda não fica vinculado a ele automaticamente por
    este browse puro; ver GcVincularCondominioAoCriador.
    @type Function
    @author GesCon
    @since 2026-08-08
*/
User Function GcCadastroCondominios()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("COND")
    oBrowse:SetDescription("Condomínios")
    oBrowse:Activate()
Return

/*/{Protheus.doc} GcVincularCondominioAoCriador
    Vincula cLogin ao condomínio cFilial em USR_COND, se o vínculo ainda
    não existir. Chamada depois que um síndico cadastra um condomínio
    novo (GcCadastroCondominios não sabe "quem" criou a linha — é um
    FWMBrowse cru — então este passo roda como uma ação separada no
    menu, não automaticamente dentro do Incluir).
    @type Function
    @author GesCon
    @since 2026-08-08
    @param cLogin, character
    @param cFilial, character
*/
User Function GcVincularCondominioAoCriador(cLogin, cFilial)
    Local aJa := TCSqlQuery("SELECT R_E_C_N_O_ FROM USR_COND WHERE USR_LOGIN = '" + ;
        GcSqlLit(cLogin) + "' AND FILIAL = '" + GcSqlLit(cFilial) + "' AND D_E_L_E_T_ = ' '")
    If Len(aJa) == 0
        TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('" + ;
            GcSqlLit(cLogin) + "', '" + GcSqlLit(cFilial) + "')")
    EndIf
Return
```

- [ ] **Step 2: Menu**

In `gescon.prw`, add `"Condomínios"` to `aMenu` (right after `"Usuários"`) and a matching `Case`:

```advpl
                    Case nOpcao == 12
                        GcMenuUsuarios()
                    Case nOpcao == 13
                        GcCadastroCondominios()
```

Renumber the subsequent cases ("Trocar Senha", "Trocar Condomínio") by +1 to match the new array position — count the final `aMenu` array carefully and match every `Case nOpcao == N` to its 1-based position.

- [ ] **Step 3: `GcCriarUsuario` ganha o passo de perfil**

In `src/usuarios.prw`, `GcCriarUsuario` (line ~144) currently:

```advpl
User Function GcCriarUsuario()
    Local aTipo := {"Admin"}
    Local nTipo := FWMenuSelect(aTipo, "Tipo de usuário")

    Do Case
        Case nTipo == 1
            GcCriarAdminNovo()
    EndCase
Return
```

Replace the whole function:

```advpl
User Function GcCriarUsuario()
    Local aTipo := {"Super Admin", "Síndico"}
    Local nTipo := FWMenuSelect(aTipo, "Tipo de usuário")

    Do Case
        Case nTipo == 1
            GcCriarAdminNovo("SUPERADMIN")
        Case nTipo == 2
            GcCriarSindicoNovo()
    EndCase
Return
```

- [ ] **Step 4: `GcCriarAdminNovo` ganha o parâmetro de perfil**

`GcCriarAdminNovo` (line ~162) currently hardcodes `USR_PERFIL='ADMIN'`:

```advpl
User Function GcCriarAdminNovo()
    Local cLogin := FWGetText("Login do novo admin:", "admin2")
    If Empty(cLogin)
        Return .F.
    EndIf

    Local cSenha := FWGetText("Senha:", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) " + ;
        "VALUES ('" + GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', 'ADMIN')")
    MsgInfo("Administrador '" + cLogin + "' criado.", "GesCon")
Return .T.
```

becomes (accepts the profile as a parameter, defaults to `'SUPERADMIN'` for backward compatibility with any other caller):

```advpl
User Function GcCriarAdminNovo(cPerfil)
    Local cLogin := FWGetText("Login do novo admin:", "admin2")
    If Empty(cLogin)
        Return .F.
    EndIf

    Local cSenha := FWGetText("Senha:", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf

    If Empty(cPerfil)
        cPerfil := "SUPERADMIN"
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) " + ;
        "VALUES ('" + GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', '" + GcSqlLit(cPerfil) + "')")
    MsgInfo("Administrador '" + cLogin + "' criado.", "GesCon")
Return .T.
```

- [ ] **Step 5: New `GcCriarSindicoNovo`**

Add to `src/usuarios.prw`:

```advpl
/*/{Protheus.doc} GcCriarSindicoNovo
    Cria um síndico (USR_PERFIL='SINDICO') e vincula a 1+ condomínios
    escolhidos de uma lista (índices separados por vírgula, ex: "1,3").
    @type Function
    @author GesCon
    @since 2026-08-08
    @return lOk, logical
*/
User Function GcCriarSindicoNovo()
    Local cLogin := FWGetText("Login do novo síndico:", "")
    Local cSenha
    Local aCond
    Local cLista := ""
    Local nJ
    Local cSel
    Local aIdx
    Local i
    Local nIdx

    If Empty(cLogin)
        Return .F.
    EndIf

    cSenha := FWGetText("Senha:", "", .T.)
    If Empty(cSenha)
        Return .F.
    EndIf

    aCond := TCSqlQuery("SELECT COND_FILIAL, COND_NOME FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY COND_NOME")
    If Len(aCond) == 0
        MsgAlert("Nenhum condomínio cadastrado ainda.", "Criar Síndico")
        Return .F.
    EndIf

    For nJ := 1 To Len(aCond)
        cLista += Str(nJ, 3) + ". " + aCond[nJ]:COND_NOME + Chr(10)
    Next nJ
    cLista += "\nNúmeros dos condomínios (separados por vírgula, ex: 1,3):"

    cSel := FWGetText(cLista, "")
    If Empty(cSel)
        Return .F.
    EndIf

    TCSqlExec("INSERT INTO USR (USR_LOGIN, USR_SENHA, USR_PERFIL) VALUES ('" + ;
        GcSqlLit(cLogin) + "', '" + GcSqlLit(FWHash(cSenha)) + "', 'SINDICO')")

    aIdx := StrTokArr(cSel, ",")
    For i := 1 To Len(aIdx)
        nIdx := Val(AllTrim(aIdx[i]))
        If nIdx >= 1 .And. nIdx <= Len(aCond)
            TCSqlExec("INSERT INTO USR_COND (USR_LOGIN, FILIAL) VALUES ('" + ;
                GcSqlLit(cLogin) + "', '" + GcSqlLit(aCond[nIdx]:COND_FILIAL) + "')")
        EndIf
    Next i

    MsgInfo("Síndico '" + cLogin + "' criado e vinculado.", "GesCon")
Return .T.
```

If `StrTokArr` isn't an available AdvPP native (check: `grep -n "STRTOKARR" /home/peder/Projetos/AdvPP/pkg/vm/natives.go`), replace the tokenizing with a manual loop using `At(",", cSel)`/`SubStr` — same pattern already used elsewhere in this codebase for comma-free single-value parsing; consult `docs/PADRAO_GUI.md` for the project's preferred idiom if one is documented, otherwise write the simplest byte-scanning loop.

- [ ] **Step 6: Run check + test**

Run: `bash scripts/check.sh && bash scripts/test.sh`
Expected: clean. Note `check.sh`'s "alcance" report — `GcCriarSindicoNovo`/`GcVincularCondominioAoCriador`/`GcCadastroCondominios` should show as reachable from the menu (not "diferidas").

- [ ] **Step 7: Commit**

```bash
git add src/condominios-cadastro.prw gescon.prw src/usuarios.prw
git commit -m "feat(condominios): cadastro + sindico multi-condominio"
```

---

### Task 5: Núcleo — `fechamento.prw` + `cobrancas.prw`

**Files:**
- Modify: `src/fechamento.prw`
- Modify: `src/cobrancas.prw`

**Interfaces:**
- Consumes: `FWxFilial(cAlias)` (AdvPP native), `GcSqlLit` (`src/db.prw`).

- [ ] **Step 1: `fechamento.prw` — as 3 leituras e o `INSERT`**

`GcFecharMes` (already read in full during design). Each `TCSqlQuery` gains the filter, and the `INSERT` gains the `FILIAL` column:

```advpl
    Local aExistente := TCSqlQuery("SELECT COB_UNIDADE FROM COB WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
```
```advpl
    Local aDespesas := TCSqlQuery("SELECT COALESCE(SUM(DES_VALOR),0) AS TOTAL FROM DES WHERE DES_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "'")
```
```advpl
    Local aUnidades := TCSqlQuery("SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('UNI')) + "'")
```
```advpl
        TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, FILIAL) VALUES ('" + ;
            GcSqlLit(aUnidades[i]:UNI_CODIGO) + "', '" + GcSqlLit(cCompetencia) + "', " + ;
            cValToChar(nValorUnidade) + ", '" + cVencimento + "', 'pendente', '" + GcSqlLit(FWxFilial('COB')) + "')")
```

- [ ] **Step 2: `cobrancas.prw` — `GcRegistrarPagamento` and `GcSelecionarCobranca`**

```advpl
Return TCSqlExec("UPDATE COB SET COB_STATUS = 'pago', COB_DTPAG = '" + cDataFmt + "' WHERE R_E_C_N_O_ = " + Str(nRecno) + " AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")
```
```advpl
    cSql := "SELECT R_E_C_N_O_, COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS " + ;
        "FROM COB WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "' "
```

- [ ] **Step 3: `db.prw` — confirm no change needed**

`GcBootstrapDB` (schema DDL, no table filter applicable) and `GcBackupBanco` (`PRAGMA database_list`, `VACUUM INTO` — whole-database operations, not per-table) touch no tenant table by name in their SQL text. No change here — record this explicitly in the commit message so a later reviewer doesn't wonder why `db.prw` was skipped.

- [ ] **Step 4: Run check + test**

Run: `bash scripts/check.sh && bash scripts/test.sh`
Expected: `tests/fechamento_test.prw` and the pagamento-related assertions still pass — they run against a single freshly-bootstrapped throwaway DB (`scripts/test.sh` creates one via `sqlite3 "$banco" < schema.sql`, which per Task 2 now seeds `COND '010101'`), but the test **never calls `RpcSetEnv`**, so `FWxFilial('COB')` returns `"      "` (6 spaces, empty session) inside these tests — the `INSERT`s from `GcFecharMes` will write `FILIAL='      '` and the `SELECT`s will filter on the same value, so they still match each other (self-consistent), and the test should still pass. If it doesn't, add `RpcSetEnv("010101")` as the first line of `tests/fechamento_test.prw`'s `FechamentoTest()` runner function to match what a real session does.

- [ ] **Step 5: Commit**

```bash
git add src/fechamento.prw src/cobrancas.prw
git commit -m "feat(filial): filtro FILIAL em fechamento e cobrancas"
```

---

### Task 6: Contabilidade — `contabil.prw` + `exercicios.prw`

**Files:**
- Modify: `src/contabil.prw`
- Modify: `src/exercicios.prw`

**Interfaces:**
- Consumes: `FWxFilial(cAlias)`, `GcSqlLit`/`GcSqlVal` (both already used in these files — keep using whichever the surrounding line already uses).

- [ ] **Step 1: Worked example — `exercicios.prw`**

`GcAbrirExercicio` (already read in full):

```advpl
    aJa := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_CODIGO = '" + ;
        GcSqlLit(cCodigo) + "' AND D_E_L_E_T_ = ' '")
```
becomes:
```advpl
    aJa := TCSqlQuery("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_CODIGO = '" + ;
        GcSqlLit(cCodigo) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('EXERCICIO')) + "'")
```
```advpl
    TCSqlExec("UPDATE EXERCICIO SET EXE_ATIVO = 0 WHERE D_E_L_E_T_ = ' '")
```
becomes:
```advpl
    TCSqlExec("UPDATE EXERCICIO SET EXE_ATIVO = 0 WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('EXERCICIO')) + "'")
```
```advpl
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
        "VALUES ('" + GcSqlLit(cCodigo) + "', '" + GcSqlLit(cInicio) + "', '" + ;
        GcSqlLit(cFim) + "', 1, 0, ' ')")
```
becomes:
```advpl
    TCSqlExec("INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_, FILIAL) " + ;
        "VALUES ('" + GcSqlLit(cCodigo) + "', '" + GcSqlLit(cInicio) + "', '" + ;
        GcSqlLit(cFim) + "', 1, 0, ' ', '" + GcSqlLit(FWxFilial('EXERCICIO')) + "')")
```

That's all 3 sites in `exercicios.prw`.

- [ ] **Step 2: Worked example — `contabil.prw` (`GcSqlVal` style)**

Line 85 (already read via grep):
```advpl
        aExercicio := TCSqlQuery("SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlVal(cExercicio) + " AND D_E_L_E_T_ = ' '")
```
becomes (note: `GcSqlVal` already returns a quoted literal, so `FWxFilial('EXERCICIO')` also needs `GcSqlVal`, not `GcSqlLit` + manual quotes, to match the surrounding style):
```advpl
        aExercicio := TCSqlQuery("SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlVal(cExercicio) + " AND D_E_L_E_T_ = ' ' AND FILIAL = " + GcSqlVal(FWxFilial('EXERCICIO')))
```

Apply this exact `AND FILIAL = " + GcSqlVal(FWxFilial('<TABELA>')) ` pattern (or the `GcSqlLit`+manual-quotes variant when the surrounding line already uses `GcSqlLit`) to every remaining site in `src/contabil.prw`, matching the table each query targets:

| Linha (antes da task) | Tabela alvo | Query |
|---|---|---|
| 59 | `EXERCICIO` | `SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_ATIVO = 1...` |
| 163 | (variável `cSql` — ler as ~10 linhas acima para ver o `INSERT`/`UPDATE` que monta) | `TCSqlExec(cSql)` |
| 198 | `LANCAMENTOS` | `SELECT LAN_EXERCICIO FROM LANCAMENTOS WHERE R_E_C_N_O_ = ...` |
| 217 | (idem 163 — ler o `cSql` acima) | `TCSqlExec(cSql)` |
| 251 | `LANCAMENTOS` | `SELECT LAN_EXERCICIO FROM LANCAMENTOS WHERE R_E_C_N_O_ = ...` |
| 270 | (idem 163) | `TCSqlExec(cSql)` |
| 308 | `UNI` | `SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' ' ORDER BY UNI_CODIGO` |
| 422 | (idem 163) | `TCSqlExec(cSql)` |
| 425 | `LANCAMENTOS` | `SELECT LAN_ID FROM LANCAMENTOS WHERE LAN_DESCR = ... AND LAN_TIPO = 'AUTOMATICO_DESPESA'...` |
| 460 | (idem 163) | `TCSqlExec(cSql)` |
| 494 | (idem 163) | `TCSqlExec(cSql)` |
| 614 | `PLANO_CONTAS` | `SELECT PLA_CODIGO FROM PLANO_CONTAS WHERE PLA_CODIGO = ...` |
| 694 | `LANCAMENTOS` | `SELECT R_E_C_N_O_, LAN_DATA, ... FROM LANCAMENTOS ...` |
| 748 | `LANCAMENTOS` | `SELECT COALESCE(SUM(LAN_VALOR), 0)... WHERE LAN_EXERCICIO = ...` |
| 818 | `EXERCICIO` | `SELECT EXE_CODIGO, EXE_INICIO, EXE_FIM FROM EXERCICIO WHERE EXE_CODIGO = ...` |
| 826 | (idem 163) | `TCSqlExec(cSql)` |
| 878 | (idem 163) | `TCSqlExec(cSql)` |
| 928 | `LANCAMENTOS` | `SELECT COALESCE(SUM(LAN_VALOR), 0)... LAN_CONTA_CRED >= '3000'...` |
| 934 | `LANCAMENTOS` | `SELECT COALESCE(SUM(LAN_VALOR), 0)... LAN_CONTA_DEB >= '4000'...` |
| 943 | `RPT_BALANCETE` | `SELECT R_E_C_N_O_ FROM RPT_BALANCETE WHERE RPT_EXERCICIO = ...` |
| 948 | (idem 163) | `TCSqlExec(cSql)` |
| 960 | (idem 163) | `TCSqlExec(cSql)` |
| 1005 | `REPARTICAO` | `SELECT REP_CODIGO, REP_NOME FROM REPARTICAO ...` |

For every `TCSqlExec(cSql)` row above (163, 217, 270, 422, 460, 494, 826, 878, 948, 960): read the lines immediately above where `cSql` is built (`Local cSql := "..."` or `cSql := "..." + ...`), identify whether it's an `INSERT` (add `, FILIAL` to the column list and `, ` + the right helper-wrapped `FWxFilial(...)` to the `VALUES` list) or an `UPDATE`/`DELETE` (add `AND FILIAL = ...` to its `WHERE`), and apply the same helper convention (`GcSqlLit`+quotes or `GcSqlVal`) already used by that specific `cSql` block.

- [ ] **Step 3: Run check + test after every 3-4 sites (not just at the end)**

Run: `bash scripts/check.sh` after each batch of edits — a syntax slip in a 24-site file is easy to make and `advplc check` is fast; don't wait until all 24 are done to find out line 460 has a dangling quote.

- [ ] **Step 4: Full suite**

Run: `bash scripts/check.sh && bash scripts/test.sh`
Expected: clean, including `tests/contabil_test.prw` and `tests/contabil_e2e_test.prw` (add `RpcSetEnv("010101")` at the top of their runner functions if they fail for the same self-consistency reason noted in Task 5 Step 4).

- [ ] **Step 5: Commit**

```bash
git add src/contabil.prw src/exercicios.prw
git commit -m "feat(filial): filtro FILIAL na contabilidade"
```

---

### Task 7: Auditoria — `auditoria.prw` + `auditoria-validacoes.prw` + `auditoria-menu.prw`

**Files:**
- Modify: `src/auditoria.prw`, `src/auditoria-validacoes.prw`, `src/auditoria-menu.prw`

**Interfaces:**
- Consumes: `FWxFilial(cAlias)`.

- [ ] **Step 1: Worked example — `auditoria-menu.prw`**

Line 85 (already grepped):
```advpl
    aTot := TCSqlQuery("SELECT COUNT(*) as CNT FROM ANOMALIA_LOG WHERE ANL_PERIODO = '" + ;
```
Read the full statement (it continues past line 85) and add ` AND FILIAL = '" + GcSqlLit(FWxFilial('ANOMALIA_LOG')) + "'` before its closing quote, following the same `GcSqlLit` convention already visible at that call site.

- [ ] **Step 2: Apply the same pattern to every remaining site**

| Arquivo | Linhas | Tabela(s) |
|---|---|---|
| `src/auditoria.prw` | 72 (`TCSqlExec(cSql)` — ler o `cSql` acima), 131 (`LANCAMENTOS`, alias `L`), 144 (`COB`, alias `C`) | `LANCAMENTOS`, `COB` |
| `src/auditoria-validacoes.prw` | 48, 64, 91, 104, 130, 143, 173, 186, 217, 230, 260, 273 (todos `cQuery` — ler cada bloco acima pra ver a tabela), 354, 393, 404, 427 | (ler cada `cQuery` — provavelmente `LANCAMENTOS`/`COB`/`ANOMALIA_LOG`/`ALERTA`, confirmar por arquivo) |
| `src/auditoria-menu.prw` | 85 (`ANOMALIA_LOG`), 160 (`ALERTA`), 177 (`UPDATE ALERTA`), 200 (`DASHBOARD_CACHE`) | `ANOMALIA_LOG`, `ALERTA`, `DASHBOARD_CACHE` |

Multi-table `JOIN` queries (like `auditoria.prw:131`/`144`, which alias `LANCAMENTOS L`/`COB C`) need the filter on **both** aliased tables if both carry `FILIAL` independently — e.g. `... WHERE ... AND L.FILIAL = '<x>' AND C.FILIAL = '<x>'` (same value both times, since it's the same session) — not just one, or a row from another condomínio could still leak in through the unfiltered side of the join.

- [ ] **Step 3: Run check + test incrementally**

Run: `bash scripts/check.sh` after each file.

- [ ] **Step 4: Full suite**

Run: `bash scripts/check.sh && bash scripts/test.sh` (add `RpcSetEnv("010101")` to `tests/auditoria_test.prw`'s runner if needed, same as Task 5/6).

- [ ] **Step 5: Commit**

```bash
git add src/auditoria.prw src/auditoria-validacoes.prw src/auditoria-menu.prw
git commit -m "feat(filial): filtro FILIAL na auditoria"
```

---

### Task 8: Relatórios + Mala Direta — `relatorios.prw` + `malas.prw`

**Files:**
- Modify: `src/relatorios.prw`, `src/malas.prw`

**Interfaces:**
- Consumes: `FWxFilial(cAlias)`.

- [ ] **Step 1: Worked example — `relatorios.prw`**

Line 28 (already grepped):
```advpl
    Local aReceitas := TCSqlQuery("SELECT COALESCE(SUM(COB_VALOR),0) AS TOTAL FROM COB WHERE COB_COMPET = '" + ;
```
Read the continuation and add `AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'` following the existing quoting style at that site.

Note: `relatorios.prw` regenerates its `RPT_*` snapshot tables via `DELETE FROM RPT_X` + `INSERT INTO RPT_X (...) SELECT ...` (lines 73-74, 106-107, 145-146) — since `RPT_INADIM`/`RPT_EXTRATO`/`RPT_DESCAT` also carry `FILIAL` now (Task 2), **both** the `DELETE` and the `INSERT ... SELECT` need the filter: the `DELETE` needs `WHERE FILIAL = ...` (otherwise it wipes every condomínio's snapshot, not just the active one's), and the `INSERT ... SELECT` needs to both stamp `FILIAL` in its column list AND filter the source `SELECT` by the same value.

- [ ] **Step 2: Apply to every remaining site**

| Arquivo | Linhas | Tabela(s) |
|---|---|---|
| `src/relatorios.prw` | 32 (`DES`), 56 (`UPDATE COB`), 58 (`COB`), 73-74 (`DELETE`/`INSERT` em `RPT_INADIM`, fonte `COB`), 79 (`RPT_INADIM`), 106-107 (`RPT_EXTRATO`, fonte `COB`), 111 (`RPT_EXTRATO`), 145-146 (`RPT_DESCAT`, fonte `DES`), 150 (`RPT_DESCAT`) | `COB`, `DES`, `RPT_INADIM`, `RPT_EXTRATO`, `RPT_DESCAT` |
| `src/malas.prw` | 27 (`COB` + provável `JOIN` — ler o `SELECT` completo pra ver todo alias envolvido) | `COB` (e o que mais o `JOIN` trouxer) |

- [ ] **Step 3: Run check + test**

Run: `bash scripts/check.sh && bash scripts/test.sh` (adicionar `RpcSetEnv("010101")` nos runners de `tests/relatorios_test.prw`/`tests/malas_test.prw` se necessário).

- [ ] **Step 4: Commit**

```bash
git add src/relatorios.prw src/malas.prw
git commit -m "feat(filial): filtro FILIAL em relatorios e mala direta"
```

---

### Task 9: Portal, token e boletos — `portal.prw`, `portal-v2.prw`, `usuarios.prw`, `auth-primitives.prw`, `boleto.prw`

**Files:**
- Modify: `src/portal.prw`, `src/portal-v2.prw`, `src/usuarios.prw`, `src/auth-primitives.prw`, `src/boleto.prw`

**Interfaces:**
- Consumes: `FWxFilial(cAlias)`.
- Produces: `GCT_TOKEN` gravado com `FILIAL` em todo `INSERT` (3 sites: `usuarios.prw:81`, `auth-primitives.prw:121`); a consulta que resolve token→condômino→unidade ganha `JOIN COND` para devolver `COND_NOME` junto (spec, "Token do portal").

- [ ] **Step 1: Worked example — `usuarios.prw`, `GcGerarToken` (o `INSERT` de token)**

Linha 81-83 (já lida por completo antes desta task):
```advpl
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO) " + ;
        "VALUES ('" + GcSqlLit(cToken) + "', '" + GcSqlLit(cLoginAtual) + "', '" + GcSqlLit(cConCod) + "', " + ;
        "'" + GcSqlLit(cUniCod) + "', '" + GcSqlLit(cCriadoIso) + "', '" + GcSqlLit(cValidadeIso) + "', 0)")
```
becomes:
```advpl
    TCSqlExec("INSERT INTO GCT_TOKEN (TOKEN, USR_LOGIN, CON_CODIGO, UNI_CODIGO, CRIPTADO, VALIDO_ATE, USADO, FILIAL) " + ;
        "VALUES ('" + GcSqlLit(cToken) + "', '" + GcSqlLit(cLoginAtual) + "', '" + GcSqlLit(cConCod) + "', " + ;
        "'" + GcSqlLit(cUniCod) + "', '" + GcSqlLit(cCriadoIso) + "', '" + GcSqlLit(cValidadeIso) + "', 0, '" + GcSqlLit(FWxFilial('GCT_TOKEN')) + "')")
```

Note: `cLoginAtual` here is `GcGerarToken`'s own local variable (`Local cLoginAtual := GetEnv("USER")`, line 79 of the original file) — **not** the `Private cLoginAtual` introduced in Task 3. Same name, different scope, don't confuse them; this local one stays untouched.

- [ ] **Step 2: Apply the identical `INSERT`-gains-`FILIAL` pattern + read-side filter to every remaining site**

| Arquivo | Linhas | O quê |
|---|---|---|
| `src/usuarios.prw` | 36 (`CON`+`UNI` join — `GcGerarToken`'s picker list), 101 (`GCT_TOKEN`, `GcRevogarToken`'s list), 131 (`UPDATE GCT_TOKEN`, revogar) | `CON`, `UNI`, `GCT_TOKEN` |
| `src/portal.prw` | 40 (`GCT_TOKEN`, valida token — **ganha `JOIN COND ON COND.COND_FILIAL = GCT_TOKEN.FILIAL`** para trazer o nome do condomínio, spec "Token do portal"), 52 (`UPDATE GCT_TOKEN`, marca usado), 94-95 (`DELETE`/`INSERT` em `RPT_COND_COBRANCAS`), 100 (`RPT_COND_COBRANCAS`) | `GCT_TOKEN`, `COND`, `RPT_COND_COBRANCAS` |
| `src/portal-v2.prw` | 163, 170, 177 (`cSql` — ler cada bloco acima), 242, 250, 304, 378, 400, 432, 492, 543, 552 (idem — todos `cSql`, ler o contexto de cada um pra saber a tabela) | (ler cada bloco — provavelmente `AVISOS`, `RPT_PORTAL_EXTRATOS`, `RPT_PORTAL_AGENDA`, `COB`, `GCT_TOKEN` conforme a função) |
| `src/auth-primitives.prw` | 48 (`GCT_TOKEN`), 121 (`INSERT INTO GCT_TOKEN` — mesmo padrão do Step 1), 149 (`GCT_TOKEN`), 156 (`UPDATE GCT_TOKEN`) — **linha 104 (`SELECT USR_PERFIL FROM USR`) fica sem mudança, `USR` é global** | `GCT_TOKEN` |
| `src/boleto.prw` | 376 (`CFG_BOLETO`), 424-425 (`DELETE`/`INSERT` em `CFG_BOLETO`), 442 (`COB`), 458 (`CFG_BOLETO`) | `CFG_BOLETO`, `COB` |

For `src/portal.prw:40` specifically, since the spec calls for the `JOIN COND` here: read the full `SELECT` (lines 40-41) and change it from:
```advpl
    Local aToken := TCSqlQuery("SELECT TOKEN, UNI_CODIGO, CON_CODIGO, VALIDO_ATE, USADO " + ;
        "FROM GCT_TOKEN WHERE TOKEN = '" + GcSqlLit(cToken) + "' AND D_E_L_E_T_ = ' '")
```
to:
```advpl
    Local aToken := TCSqlQuery("SELECT GCT_TOKEN.TOKEN, GCT_TOKEN.UNI_CODIGO, GCT_TOKEN.CON_CODIGO, " + ;
        "GCT_TOKEN.VALIDO_ATE, GCT_TOKEN.USADO, COND.COND_NOME " + ;
        "FROM GCT_TOKEN LEFT JOIN COND ON COND.COND_FILIAL = GCT_TOKEN.FILIAL " + ;
        "WHERE GCT_TOKEN.TOKEN = '" + GcSqlLit(cToken) + "' AND GCT_TOKEN.D_E_L_E_T_ = ' '")
```
(`LEFT JOIN`, not inner — a token generated before this migration has `FILIAL=''`/`NULL` and no matching `COND` row; the login should still work, just without a condomínio name to show. Read the rest of the function below this query to see if/where `aToken[1]:COND_NOME` should now be surfaced to the user — e.g. in a `MsgInfo`/screen title — and wire it in if there's an obvious spot; if not, leave the column available and unused rather than guessing at UI that isn't there yet.)

- [ ] **Step 3: Run check + test incrementally, per file**

Run: `bash scripts/check.sh` after each file — this task touches the most files of any single task in this plan.

- [ ] **Step 4: Full suite**

Run: `bash scripts/check.sh && bash scripts/test.sh` (adicionar `RpcSetEnv("010101")` nos runners de `tests/portal_test.prw`, `tests/portal-v2_test.prw`, `tests/usuarios_test.prw`, `tests/boleto_test.prw`, `tests/auditoria_test.prw` — este último por causa de `auth-primitives.prw` — se algum falhar por inconsistência de filial vazia vs `'010101'`).

- [ ] **Step 5: Commit**

```bash
git add src/portal.prw src/portal-v2.prw src/usuarios.prw src/auth-primitives.prw src/boleto.prw
git commit -m "feat(filial): filtro FILIAL em portal, token e boletos"
```

---

### Task 10: Verificação final — script de completude + suíte inteira

**Files:**
- Create: `scripts/check-filial.sh`
- Modify: `scripts/check.sh` (chamar o novo script)
- Modify: `docs/FUNCIONAL.md` (documentar a feature, tirar a limitação "um condomínio por instância")

**Interfaces:**
- Consumes: nenhuma — é puramente verificação sobre o código já escrito nas Tasks 5-9.

- [ ] **Step 1: Write the completeness tripwire**

Create `scripts/check-filial.sh`:

```sh
#!/bin/sh
# scripts/check-filial.sh -- tripwire, nao prova formal: para cada .prw em
# src/ que chama TCSqlQuery/TCSqlExec E menciona uma das 22 tabelas
# por-condominio, exige que o mesmo arquivo tambem mencione "FILIAL" em
# algum lugar. Pega o caso "esqueci completamente do arquivo"; nao pega
# "filtrei 5 de 6 queries do mesmo arquivo" -- isso as checklists das
# Tasks 5-9 cobrem por leitura humana.
set -e
cd "$(dirname "$0")/.."

TENANT_TABLES="CON UNI DES COB RPT_INADIM RPT_EXTRATO RPT_DESCAT CFG_BOLETO GCT_TOKEN RPT_COND_COBRANCAS PLANO_CONTAS REPARTICAO EXERCICIO LANCAMENTOS RATEIO_DETALHE AUDITORIA RPT_BALANCETE AVISOS RPT_PORTAL_EXTRATOS RPT_PORTAL_AGENDA ANOMALIA_LOG ALERTA DASHBOARD_CACHE"

falhou=0
for f in src/*.prw; do
    [ -f "$f" ] || continue
    grep -q "TCSqlQuery(\|TCSqlExec(" "$f" || continue
    for t in $TENANT_TABLES; do
        if grep -qw "$t" "$f" && ! grep -q "FILIAL" "$f"; then
            echo "FALHA: $f menciona $t (com TCSqlQuery/TCSqlExec no arquivo) mas nunca FILIAL"
            falhou=1
            break
        fi
    done
done

if [ "$falhou" = 1 ]; then
    echo "check-filial: FALHOU"
    exit 1
fi
echo "check-filial: ok"
```

- [ ] **Step 2: Run it**

Run: `chmod +x scripts/check-filial.sh && bash scripts/check-filial.sh`
Expected: `check-filial: ok`. If it fails, it names the exact file that still needs a Task 5-9-style pass — go back and finish that file before continuing.

- [ ] **Step 3: Wire into `scripts/check.sh`**

Open `scripts/check.sh`, find where it currently runs the "alcance" check near the end, and add a call to the new script right after:

```sh
bash scripts/check-filial.sh || exit 1
```

- [ ] **Step 4: Update `docs/FUNCIONAL.md`**

Remove/replace the "um condomínio por instância" framing wherever it appears (search: `grep -n "um condomínio por instância" docs/FUNCIONAL.md`) with a short paragraph describing: banco único, `FILIAL` por condomínio, `SUPERADMIN` vê todos, `SINDICO` vê os vinculados, "Trocar Condomínio" no menu.

- [ ] **Step 5: Full suite, one last time**

Run: `bash scripts/check.sh && bash scripts/test.sh && bash scripts/check-triggers.sh && bash scripts/check-migracao-filial.sh && bash scripts/build.sh`
Expected: everything green. This is the gate for the whole plan.

- [ ] **Step 6: Commit**

```bash
git add scripts/check-filial.sh scripts/check.sh docs/FUNCIONAL.md
git commit -m "test: tripwire de completude do filtro FILIAL + doc atualizada"
```
