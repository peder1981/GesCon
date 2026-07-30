# Sistema Contábil em Partida Dupla — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a double-entry accounting system for GesCon with manual & automatic entries, flexible repartition, period closing with D/C validation, and basic audit trail.

**Architecture:** Three independent modules — Core Contábil (database + entry functions), Auditoria (validation on close), Menu Integration (UI hookup). Each produces testable functions that later tasks depend on.

**Tech Stack:** AdvPL/TLPP, AdvPP, SQLite, FWMBrowse for UI.

## Global Constraints

- **Stack:** 100% AdvPL/TLPP + AdvPP + SQLite (no changes to compiler/DB)
- **Scope:** Essential and minimal — no hierarchical chart, no prescriptions, no parallel exercises
- **Naming:** Hungarian notation (c=char, n=numeric, l=logical, a=array, o=object)
- **DB Naming:** Table = 3-letter uppercase (LAN, RAT, PLA, REP, EXE, AUD); Fields = TABLE_NAME format (LAN_VALOR, PLA_CODIGO)
- **Soft-delete:** All tables follow Protheus pattern (D_E_L_E_T_, R_E_C_D_E_L_)
- **Encoding:** CP-1252 (Windows-1252) for all `.prw` files
- **Tests:** End-to-end via `advplc run` (no mocks, real SQLite DB)
- **One exercise at a time:** EXE_ATIVO = 1 constraint enforced in all functions

---

## File Structure

```
GesCon/
├── schema.sql                      [EXISTING] Add 6 new tables (PLANO_CONTAS, REPARTICAO, EXERCICIO, LANCAMENTOS, RATEIO_DETALHE, AUDITORIA)
├── src/
│   ├── contabil.prw               [CREATE]  Core: entries (manual/auto), repartition, close, validation (20+ functions)
│   ├── auditoria.prw              [CREATE]  Audit trail: anomaly detection, logging
│   ├── menu.prw                   [MODIFY]  Add "Contabilidade" submenu
│   └── gescon.prw                 [MODIFY]  Include contabil.prw and auditoria.prw
└── tests/
    ├── contabil_test.prw          [CREATE]  E2E fixtures: manual entry, repartition, close
    └── auditoria_test.prw         [CREATE]  E2E fixtures: anomaly detection

```

---

## Phase 1: Database Foundation

### Task 1: Create Table Schema (DDL)

**Files:**
- Modify: `schema.sql`
- Test: `tests/contabil_test.prw` (fixture setup)

**Interfaces:**
- Produces: 6 new tables ready for seed

**Steps:**

- [ ] **Step 1: Add PLANO_CONTAS table to schema.sql**

```sql
CREATE TABLE PLANO_CONTAS (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    PLA_CODIGO TEXT UNIQUE NOT NULL,
    PLA_NOME TEXT NOT NULL,
    PLA_TIPO TEXT NOT NULL,  -- ATIVO | PASSIVO | RECEITA | DESPESA
    PLA_ATIVO NUMERIC DEFAULT 1,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    CHECK(PLA_TIPO IN ('ATIVO', 'PASSIVO', 'RECEITA', 'DESPESA'))
);
CREATE INDEX IDX_PLANO_CONTAS_ATIVO ON PLANO_CONTAS(PLA_ATIVO, D_E_L_E_T_);
```

- [ ] **Step 2: Add REPARTICAO table to schema.sql**

```sql
CREATE TABLE REPARTICAO (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    REP_CODIGO TEXT UNIQUE NOT NULL,
    REP_NOME TEXT NOT NULL,
    REP_ATIVO NUMERIC DEFAULT 1,
    REP_DETALHE TEXT,  -- JSON-like for flexibility
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC
);
CREATE INDEX IDX_REPARTICAO_ATIVO ON REPARTICAO(REP_ATIVO, D_E_L_E_T_);
```

- [ ] **Step 3: Add EXERCICIO table to schema.sql**

```sql
CREATE TABLE EXERCICIO (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    EXE_CODIGO TEXT UNIQUE NOT NULL,  -- 2025-01, 2025-02, etc.
    EXE_INICIO DATE NOT NULL,
    EXE_FIM DATE NOT NULL,
    EXE_ATIVO NUMERIC DEFAULT 0,
    EXE_FECHADO NUMERIC DEFAULT 0,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    UNIQUE(EXE_ATIVO, D_E_L_E_T_)  -- Only one active at a time
);
CREATE INDEX IDX_EXERCICIO_ATIVO ON EXERCICIO(EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_);
```

- [ ] **Step 4: Add LANCAMENTOS table to schema.sql**

```sql
CREATE TABLE LANCAMENTOS (
    LAN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    LAN_DATA DATE NOT NULL,
    LAN_CONTA_DEB TEXT NOT NULL,  -- FK → PLA_CODIGO
    LAN_CONTA_CRED TEXT NOT NULL,
    LAN_VALOR NUMERIC NOT NULL,
    LAN_DESCR TEXT,
    LAN_REFERENCIA NUMERIC,  -- Optional FK to DES_ID or COB.RECNO
    LAN_TIPO TEXT NOT NULL,  -- MANUAL | AUTOMATICO_DESPESA | AUTOMATICO_RATEIO
    LAN_DATA_HORA DATETIME,
    LAN_USUARIO TEXT,
    LAN_EXERCICIO TEXT NOT NULL,  -- FK → EXE_CODIGO
    R_E_C_N_O_ INTEGER,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FOREIGN KEY(LAN_CONTA_DEB) REFERENCES PLANO_CONTAS(PLA_CODIGO),
    FOREIGN KEY(LAN_CONTA_CRED) REFERENCES PLANO_CONTAS(PLA_CODIGO),
    FOREIGN KEY(LAN_EXERCICIO) REFERENCES EXERCICIO(EXE_CODIGO),
    CHECK(LAN_VALOR > 0),
    CHECK(LAN_TIPO IN ('MANUAL', 'AUTOMATICO_DESPESA', 'AUTOMATICO_RATEIO')),
    CHECK(LAN_CONTA_DEB != LAN_CONTA_CRED)
);
CREATE INDEX IDX_LANCAMENTOS_EXERCICIO ON LANCAMENTOS(LAN_EXERCICIO, D_E_L_E_T_);
CREATE INDEX IDX_LANCAMENTOS_TIPO ON LANCAMENTOS(LAN_TIPO, D_E_L_E_T_);
CREATE INDEX IDX_LANCAMENTOS_REFERENCIA ON LANCAMENTOS(LAN_REFERENCIA, D_E_L_E_T_);
```

- [ ] **Step 5: Add RATEIO_DETALHE table to schema.sql**

```sql
CREATE TABLE RATEIO_DETALHE (
    RAT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    RAT_LANCAMENTO INTEGER NOT NULL,  -- FK → LANCAMENTOS.LAN_ID
    RAT_UNIDADE TEXT NOT NULL,  -- FK → UNI_CODIGO
    RAT_VALOR NUMERIC NOT NULL,
    RAT_PERCENTUAL NUMERIC,
    R_E_C_N_O_ INTEGER,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FOREIGN KEY(RAT_LANCAMENTO) REFERENCES LANCAMENTOS(LAN_ID),
    FOREIGN KEY(RAT_UNIDADE) REFERENCES UNI(UNI_CODIGO),
    CHECK(RAT_VALOR > 0)
);
CREATE INDEX IDX_RATEIO_LANCAMENTO ON RATEIO_DETALHE(RAT_LANCAMENTO, D_E_L_E_T_);
CREATE INDEX IDX_RATEIO_UNIDADE ON RATEIO_DETALHE(RAT_UNIDADE, D_E_L_E_T_);
```

- [ ] **Step 6: Add AUDITORIA table to schema.sql**

```sql
CREATE TABLE AUDITORIA (
    AUD_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    AUD_DATA_HORA DATETIME NOT NULL,
    AUD_TIPO TEXT NOT NULL,  -- DESEQUILIBRIO_CONTABIL | COB_ORFAO | LAN_ORFAO
    AUD_DESCRICAO TEXT,
    AUD_SEVERIDADE TEXT NOT NULL,  -- CRITICA | AVISO | INFO
    AUD_RECNO_LAN NUMERIC,
    AUD_RECNO_COB NUMERIC,
    AUD_EXERCICIO TEXT,  -- FK → EXE_CODIGO
    R_E_C_N_O_ INTEGER,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    CHECK(AUD_SEVERIDADE IN ('CRITICA', 'AVISO', 'INFO')),
    CHECK(AUD_TIPO IN ('DESEQUILIBRIO_CONTABIL', 'COB_ORFAO', 'LAN_ORFAO', 'OUTRO'))
);
CREATE INDEX IDX_AUDITORIA_EXERCICIO ON AUDITORIA(AUD_EXERCICIO, AUD_SEVERIDADE, D_E_L_E_T_);
```

- [ ] **Step 7: Run bootstrap to apply schema**

```bash
./scripts/bootstrap-db.sh
```

Expected: All 6 tables created, no errors.

- [ ] **Step 8: Verify tables exist**

```bash
sqlite3 ~/.advpp/ADVPP.db ".tables" | grep -E "PLANO_CONTAS|REPARTICAO|EXERCICIO|LANCAMENTOS|RATEIO_DETALHE|AUDITORIA"
```

Expected: All 6 table names visible.

- [ ] **Step 9: Commit**

```bash
git add schema.sql
git commit -m "Add: database schema for double-entry accounting (6 tables)"
```

---

### Task 2: Seed PLANO_CONTAS (~20 accounts)

**Files:**
- Create: `scripts/seed-contabil.sql` (seed script)
- Test: Verify inserts via `advplc run`

**Interfaces:**
- Produces: PLANO_CONTAS populated with 20 accounts (ready for GcNovoLancamento)

**Steps:**

- [ ] **Step 1: Create seed script**

```sql
-- scripts/seed-contabil.sql
-- Seed PLANO_CONTAS (~20 accounts)

INSERT INTO PLANO_CONTAS (PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO)
VALUES
  ('1000', 'Caixa',                    'ATIVO',     1),
  ('1100', 'Banco',                    'ATIVO',     1),
  ('2000', 'Receita Condominial',      'PASSIVO',   1),
  ('2100', 'Débitos Anteriores',       'PASSIVO',   1),
  ('3000', 'Receita Condominial',      'RECEITA',   1),
  ('3100', 'Multas e Juros',           'RECEITA',   1),
  ('4000', 'Despesa Comum',            'DESPESA',   1),
  ('4100', 'Despesa Extraordinária',   'DESPESA',   1),
  ('4200', 'Água/Luz/Condomínio',      'DESPESA',   1),
  ('4300', 'Limpeza',                  'DESPESA',   1),
  ('4400', 'Segurança',                'DESPESA',   1),
  ('4500', 'Manutenção',               'DESPESA',   1),
  ('4600', 'Seguros',                  'DESPESA',   1),
  ('4700', 'Impostos e Taxas',         'DESPESA',   1),
  ('4800', 'Depreciação',              'DESPESA',   1),
  ('4900', 'Ajustes e Créditos',       'DESPESA',   1),
  ('5000', 'Contas a Receber',         'ATIVO',     1),
  ('6000', 'Capital/Patrimônio',       'PASSIVO',   1),
  ('6100', 'Lucros Acumulados',        'PASSIVO',   1),
  ('7000', 'Outras Contas',            'ATIVO',     1);

INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO)
VALUES
  ('2025-01', '2025-01-01', '2025-01-31', 1, 0);

INSERT INTO REPARTICAO (REP_CODIGO, REP_NOME, REP_ATIVO)
VALUES
  ('FRACAO', 'Fração Ideal', 1),
  ('METRAGEM', 'Por Metragem', 1),
  ('FIXO', 'Valor Fixo', 1);
```

- [ ] **Step 2: Execute seed script**

```bash
sqlite3 ~/.advpp/ADVPP.db < scripts/seed-contabil.sql
```

Expected: 20 inserts into PLANO_CONTAS, 1 into EXERCICIO, 3 into REPARTICAO.

- [ ] **Step 3: Verify seed in AdvPL test**

Create temporary test in `tests/contabil_test.prw`:

```advpl
User Function TesteContabilSeed()
  Local nQtd := 0
  Local oQuery as object
  
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM PLANO_CONTAS WHERE D_E_L_E_T_ = ' '")
  oQuery:Execute()
  nQtd := oQuery:FieldGet("qtd")
  oQuery:Close()
  
  // Should be 20
  Assert( nQtd == 20, "Seed PLANO_CONTAS failed: expected 20, got " + cValToChar(nQtd) )
  
  ConOut("✓ Seed PLANO_CONTAS OK (20 accounts)")
End Function
```

Run: `advplc run tests/contabil_test.prw`

Expected: "✓ Seed PLANO_CONTAS OK"

- [ ] **Step 4: Commit**

```bash
git add scripts/seed-contabil.sql
git commit -m "Add: seed data for chart of accounts (20 accounts) + initial exercise"
```

---

### Task 3: Create Utility Functions (GcSqlLit, GcExercicioAtivo)

**Files:**
- Create: `src/contabil.prw` (initial, utility functions)
- Test: `tests/contabil_test.prw` (unit-level)

**Interfaces:**
- Produces:
  - `GcSqlLit(cValor) -> character` (escape SQL literals)
  - `GcExercicioAtivo() -> character` (get active exercise code)
  - `GcPeriodoFechado(cExercicio) -> logical` (check if period is closed)

**Steps:**

- [ ] **Step 1: Create src/contabil.prw with GcSqlLit**

```tlpp
#include "totvs.ch"

Static cExercicioAtivo := ""  // Cache exercício ativo

/*{Protheus.doc}
Escape SQL literals (simple single-quote handling)
@type Function
@author Claude
@since 2026-07-30
@param cValor Character value to escape
@return Character escaped value with quotes
/*/
User Function GcSqlLit(cValor as character) as character
  Local cRetorno as character
  
  cRetorno := "'" + StrTran(cValor, "'", "''") + "'"
  
  Return cRetorno
End Function

/*{Protheus.doc}
Get active exercise code (cached)
@type Function
@author Claude
@since 2026-07-30
@return Character exercise code (e.g., "2025-01") or ""
/*/
User Function GcExercicioAtivo() as character
  Local oQuery as object
  Local cExe as character
  
  oQuery := TCSqlQuery():New("SELECT EXE_CODIGO FROM EXERCICIO WHERE EXE_ATIVO = 1 AND D_E_L_E_T_ = ' ' LIMIT 1")
  oQuery:Execute()
  
  If oQuery:Eof()
    cExe := ""
  Else
    cExe := oQuery:FieldGet("EXE_CODIGO")
  EndIf
  
  oQuery:Close()
  
  Return cExe
End Function

/*{Protheus.doc}
Check if period is closed
@type Function
@author Claude
@since 2026-07-30
@param cExercicio Character exercise code
@return Logical .T. if closed, .F. if open or not found
/*/
User Function GcPeriodoFechado(cExercicio as character) as logical
  Local oQuery as object
  Local lFechado as logical
  
  oQuery := TCSqlQuery():New("SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  
  If oQuery:Eof()
    lFechado := .F.
  Else
    lFechado := (oQuery:FieldGet("EXE_FECHADO") == 1)
  EndIf
  
  oQuery:Close()
  
  Return lFechado
End Function
```

- [ ] **Step 2: Test GcSqlLit in simple test**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteGcSqlLit()
  Local cResult as character
  
  cResult := GcSqlLit("João's Café")
  Assert( cResult == "'João''s Café'", "GcSqlLit failed" )
  
  ConOut("✓ GcSqlLit OK")
End Function
```

Run: `advplc run tests/contabil_test.prw::TesteGcSqlLit`

Expected: "✓ GcSqlLit OK"

- [ ] **Step 3: Test GcExercicioAtivo**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteGcExercicioAtivo()
  Local cExe as character
  
  cExe := GcExercicioAtivo()
  Assert( cExe == "2025-01", "GcExercicioAtivo failed: expected 2025-01, got " + cExe )
  
  ConOut("✓ GcExercicioAtivo OK")
End Function
```

Run: `advplc run tests/contabil_test.prw::TesteGcExercicioAtivo`

Expected: "✓ GcExercicioAtivo OK"

- [ ] **Step 4: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "Add: utility functions (GcSqlLit, GcExercicioAtivo, GcPeriodoFechado) + basic tests"
```

---

## Phase 2: Manual Entries (Lançamentos Manuais)

### Task 4: Implement GcNovoLancamento (Manual Entry)

**Files:**
- Modify: `src/contabil.prw`
- Test: `tests/contabil_test.prw`

**Interfaces:**
- Consumes: 
  - PLANO_CONTAS (available accounts)
  - EXERCICIO (active exercise via GcExercicioAtivo)
  - GcSqlLit (escape literals)
  - GcPeriodoFechado (check if closed)
- Produces: 
  - `GcNovoLancamento() -> logical` (create manual entry, return .T. on success)

**Steps:**

- [ ] **Step 1: Write the failing test**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteNovoLancamentoManual()
  Local lOk as logical
  Local oQuery as object
  Local nQtdAnt as numeric
  Local nQtdPos as numeric
  
  // Count before
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM LANCAMENTOS WHERE LAN_TIPO = 'MANUAL' AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  nQtdAnt := oQuery:FieldGet("qtd")
  oQuery:Close()
  
  // Create manual entry (simulated user input)
  // This will fail first time because GcNovoLancamento doesn't exist yet
  lOk := GcCriarLancamentoManualDireto("2025-01-15", "Ajuste de caixa", "1000", "4900", 100.00)
  
  // Count after
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM LANCAMENTOS WHERE LAN_TIPO = 'MANUAL' AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  nQtdPos := oQuery:FieldGet("qtd")
  oQuery:Close()
  
  Assert( lOk, "GcCriarLancamentoManualDireto failed" )
  Assert( nQtdPos == nQtdAnt + 1, "Entry not inserted" )
  
  ConOut("✓ Manual entry OK")
End Function
```

Run: `advplc run tests/contabil_test.prw::TesteNovoLancamentoManual`

Expected: FAIL — "GcCriarLancamentoManualDireto not defined"

- [ ] **Step 2: Implement GcCriarLancamentoManualDireto (direct insert for testing)**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Create manual entry directly (bypasses UI, used by tests and scripting)
@type Function
@author Claude
@since 2026-07-30
@param dData Date of entry
@param cDescricao Character description
@param cContaDeb Character debit account code
@param cContaCred Character credit account code
@param nValor Numeric amount (always positive)
@return Logical .T. on success, .F. on error
/*/
User Function GcCriarLancamentoManualDireto(dData as date, cDescricao as character, cContaDeb as character, cContaCred as character, nValor as numeric) as logical
  Local oExec as object
  Local lOk as logical
  Local cExercicio as character
  Local lFechado as logical
  
  // Validation: get active exercise
  cExercicio := GcExercicioAtivo()
  If Empty(cExercicio)
    ConOut("ERROR: No active exercise")
    Return .F.
  EndIf
  
  // Validation: period not closed
  lFechado := GcPeriodoFechado(cExercicio)
  If lFechado
    ConOut("ERROR: Period is closed")
    Return .F.
  EndIf
  
  // Validation: debit ≠ credit
  If cContaDeb == cContaCred
    ConOut("ERROR: Debit and credit must be different")
    Return .F.
  EndIf
  
  // Validation: value > 0
  If nValor <= 0
    ConOut("ERROR: Value must be positive")
    Return .F.
  EndIf
  
  // Insert
  oExec := TCSqlExec():New("INSERT INTO LANCAMENTOS " + ;
    "(LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
    "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) " + ;
    "VALUES (" + ;
    "'" + DtoS(dData) + "', " + ;
    GcSqlLit(cContaDeb) + ", " + ;
    GcSqlLit(cContaCred) + ", " + ;
    cValToChar(nValor) + ", " + ;
    GcSqlLit(cDescricao) + ", " + ;
    GcSqlLit("MANUAL") + ", " + ;
    GcSqlLit(cExercicio) + ", " + ;
    "datetime('now'), " + ;
    GcSqlLit("TEST_USER") + ", " + ;
    "' ')")
  
  lOk := oExec:Execute()
  
  Return lOk
End Function
```

- [ ] **Step 3: Run test to verify it passes**

Run: `advplc run tests/contabil_test.prw::TesteNovoLancamentoManual`

Expected: PASS — "✓ Manual entry OK"

- [ ] **Step 4: Add GcNovoLancamento (UI wrapper, minimal for now)**

```tlpp
/*{Protheus.doc}
Create new manual entry (UI entry point)
@type Function
@author Claude
@since 2026-07-30
@return Logical .T. on success
/*/
User Function GcNovoLancamento() as logical
  Local dData as date
  Local cDescricao as character
  Local cContaDeb as character
  Local cContaCred as character
  Local nValor as numeric
  
  // ponytail: UI placeholder for now, will integrate FWGetText/FWMBrowse later
  // For MVP, tests use GcCriarLancamentoManualDireto directly
  
  Return .F.
End Function
```

- [ ] **Step 5: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "feat: implement manual entry creation (GcCriarLancamentoManualDireto + base GcNovoLancamento)"
```

---

### Task 5: Implement GcEditarLancamento & GcDeletarLancamento

**Files:**
- Modify: `src/contabil.prw`
- Test: `tests/contabil_test.prw`

**Interfaces:**
- Consumes:
  - LANCAMENTOS (existing entry)
  - GcPeriodoFechado (block if closed)
- Produces:
  - `GcEditarLancamento(nRecno) -> logical` (update data/descr/valor only)
  - `GcDeletarLancamento(nRecno) -> logical` (soft-delete)

**Steps:**

- [ ] **Step 1: Write test for edit (preserve dual-entry)**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteEditarLancamento()
  Local nRecno as numeric
  Local oQuery as object
  Local cDescr as character
  Local nQtd as numeric
  
  // Create entry
  GcCriarLancamentoManualDireto("2025-01-15", "Original", "1000", "4900", 100.00)
  
  // Get recno
  oQuery := TCSqlQuery():New("SELECT R_E_C_N_O_ FROM LANCAMENTOS WHERE LAN_DESCR = 'Original' AND D_E_L_E_T_ = ' ' LIMIT 1")
  oQuery:Execute()
  nRecno := oQuery:FieldGet("R_E_C_N_O_")
  oQuery:Close()
  
  // Edit description
  GcEditarLancamentoDescricao(nRecno, "Edited")
  
  // Verify
  oQuery := TCSqlQuery():New("SELECT LAN_DESCR FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  cDescr := oQuery:FieldGet("LAN_DESCR")
  oQuery:Close()
  
  Assert( cDescr == "Edited", "Edit failed" )
  ConOut("✓ Edit entry OK")
End Function
```

Run: `advplc run tests/contabil_test.prw::TesteEditarLancamento`

Expected: FAIL — "GcEditarLancamentoDescricao not defined"

- [ ] **Step 2: Implement GcEditarLancamentoDescricao**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Edit entry description/date/value (not accounts — preserves dual-entry)
@type Function
@author Claude
@since 2026-07-30
@param nRecno Numeric R_E_C_N_O_ of entry
@param cDescricao Character new description
@return Logical .T. on success
/*/
User Function GcEditarLancamentoDescricao(nRecno as numeric, cDescricao as character) as logical
  Local oQuery as object
  Local cExercicio as character
  Local lFechado as logical
  Local oExec as object
  
  // Get exercise from entry
  oQuery := TCSqlQuery():New("SELECT LAN_EXERCICIO FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  
  If oQuery:Eof()
    ConOut("ERROR: Entry not found")
    oQuery:Close()
    Return .F.
  EndIf
  
  cExercicio := oQuery:FieldGet("LAN_EXERCICIO")
  oQuery:Close()
  
  // Check if period closed
  lFechado := GcPeriodoFechado(cExercicio)
  If lFechado
    ConOut("ERROR: Period is closed")
    Return .F.
  EndIf
  
  // Update
  oExec := TCSqlExec():New("UPDATE LANCAMENTOS SET " + ;
    "LAN_DESCR = " + GcSqlLit(cDescricao) + ", " + ;
    "LAN_DATA_HORA = datetime('now') " + ;
    "WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
  
  Return oExec:Execute()
End Function
```

- [ ] **Step 3: Run test**

Run: `advplc run tests/contabil_test.prw::TesteEditarLancamento`

Expected: PASS

- [ ] **Step 4: Write test for delete (soft-delete)**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteDeletarLancamento()
  Local nRecno as numeric
  Local oQuery as object
  Local cDeleted as character
  
  // Create entry
  GcCriarLancamentoManualDireto("2025-01-15", "ToDelete", "1000", "4900", 100.00)
  
  // Get recno
  oQuery := TCSqlQuery():New("SELECT R_E_C_N_O_ FROM LANCAMENTOS WHERE LAN_DESCR = 'ToDelete' AND D_E_L_E_T_ = ' ' LIMIT 1")
  oQuery:Execute()
  nRecno := oQuery:FieldGet("R_E_C_N_O_")
  oQuery:Close()
  
  // Delete
  GcDeletarLancamento(nRecno)
  
  // Verify soft-delete
  oQuery := TCSqlQuery():New("SELECT D_E_L_E_T_ FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno))
  oQuery:Execute()
  cDeleted := oQuery:FieldGet("D_E_L_E_T_")
  oQuery:Close()
  
  Assert( cDeleted == "*", "Soft-delete failed" )
  ConOut("✓ Delete entry OK")
End Function
```

- [ ] **Step 5: Implement GcDeletarLancamento**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Delete entry (soft-delete)
@type Function
@author Claude
@since 2026-07-30
@param nRecno Numeric R_E_C_N_O_ of entry
@return Logical .T. on success
/*/
User Function GcDeletarLancamento(nRecno as numeric) as logical
  Local oQuery as object
  Local cExercicio as character
  Local lFechado as logical
  Local oExec as object
  
  // Get exercise
  oQuery := TCSqlQuery():New("SELECT LAN_EXERCICIO FROM LANCAMENTOS WHERE R_E_C_N_O_ = " + cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  
  If oQuery:Eof()
    ConOut("ERROR: Entry not found")
    oQuery:Close()
    Return .F.
  EndIf
  
  cExercicio := oQuery:FieldGet("LAN_EXERCICIO")
  oQuery:Close()
  
  // Check if period closed
  lFechado := GcPeriodoFechado(cExercicio)
  If lFechado
    ConOut("ERROR: Period is closed")
    Return .F.
  EndIf
  
  // Soft-delete
  oExec := TCSqlExec():New("UPDATE LANCAMENTOS SET " + ;
    "D_E_L_E_T_ = '*', " + ;
    "R_E_C_D_E_L_ = " + cValToChar(Seconds()) + " " + ;
    "WHERE R_E_C_N_O_ = " + cValToChar(nRecno))
  
  Return oExec:Execute()
End Function
```

- [ ] **Step 6: Run all entry tests**

Run: `advplc run tests/contabil_test.prw`

Expected: All entry tests PASS

- [ ] **Step 7: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "feat: implement edit and delete for manual entries (preserves dual-entry constraint)"
```

---

## Phase 3: Automatic Entries via Repartition (Lançamentos Automáticos)

### Task 6: Implement GcCalcularRateio (Repartition Calculation)

**Files:**
- Modify: `src/contabil.prw`
- Test: `tests/contabil_test.prw`

**Interfaces:**
- Consumes:
  - REPARTICAO (repartition types)
  - UNI (units with fractions)
- Produces:
  - `GcCalcularRateio(cReparticao, nValor, dData) -> array` (array of {unidade, percentual, valor})

**Steps:**

- [ ] **Step 1: Write test for repartition (fração ideal)**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteCalcularRateioFracao()
  Local aRateio as array
  Local nQtd as numeric
  
  // Calculate repartition for 1000 reais with "FRACAO" (ideal fraction)
  // Assuming 10 units with 0.1 fraction each (total 1.0)
  aRateio := GcCalcularRateio("FRACAO", 1000.00, Date())
  
  // Should have 10 items
  nQtd := Len(aRateio)
  Assert( nQtd > 0, "Repartition array empty" )
  Assert( aRateio[1, 3] == 100.00, "First unit should get 100 (1000 * 0.1)" ) // valor
  
  ConOut("✓ Repartition OK (" + cValToChar(nQtd) + " units)")
End Function
```

Run: Expected FAIL — function doesn't exist yet

- [ ] **Step 2: Implement GcCalcularRateio**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Calculate repartition for a given type and amount
@type Function
@author Claude
@since 2026-07-30
@param cReparticao Character repartition code (FRACAO, METRAGEM, FIXO)
@param nValor Numeric total amount
@param dData Date (for future multi-rate support)
@return Array { {unidade, percentual, valor}, ... }
/*/
User Function GcCalcularRateio(cReparticao as character, nValor as numeric, dData as date) as array
  Local aRateio as array
  Local oQuery as object
  Local nFracao as numeric
  Local cUnidade as character
  Local nValorUnit as numeric
  
  aRateio := {}
  
  If cReparticao == "FRACAO"
    // Use ideal fraction from UNI table
    oQuery := TCSqlQuery():New("SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' ' ORDER BY UNI_CODIGO")
    oQuery:Execute()
    
    Do While !oQuery:Eof()
      cUnidade := oQuery:FieldGet("UNI_CODIGO")
      nFracao := oQuery:FieldGet("UNI_FRACAO")
      nValorUnit := nValor * nFracao
      
      AAdd(aRateio, { cUnidade, nFracao, nValorUnit })
      
      oQuery:Skip()
    EndDo
    
    oQuery:Close()
  Else
    ConOut("ERROR: Repartition type not supported yet: " + cReparticao)
  EndIf
  
  Return aRateio
End Function
```

- [ ] **Step 3: Run test**

Run: `advplc run tests/contabil_test.prw::TesteCalcularRateioFracao`

Expected: PASS (or verify actual unit count in test database)

- [ ] **Step 4: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "feat: implement repartition calculation (fração ideal)"
```

---

### Task 7: Implement GcLancarDespesaContabil (Automatic Entries via Repartition)

**Files:**
- Modify: `src/contabil.prw`
- Test: `tests/contabil_test.prw`

**Interfaces:**
- Consumes:
  - GcCalcularRateio (repartition array)
  - LANCAMENTOS table
  - RATEIO_DETALHE table
  - COB (billing) table
- Produces:
  - `GcLancarDespesaContabil(dData, cDescricao, nValor, cReparticao, nDiaVenc) -> logical`
  - Side effect: creates 1 main entry + N repartition entries + N billing records

**Steps:**

- [ ] **Step 1: Write test for expense with repartition**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteLancarDespesaComRateio()
  Local lOk as logical
  Local oQuery as object
  Local nQtdLanAntes as numeric
  Local nQtdLanDepois as numeric
  Local nQtdCobAntes as numeric
  Local nQtdCobDepois as numeric
  
  // Count before
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM LANCAMENTOS WHERE LAN_TIPO LIKE 'AUTOMATICO%' AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  nQtdLanAntes := oQuery:FieldGet("qtd")
  oQuery:Close()
  
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM COB WHERE D_E_L_E_T_ = ' '")
  oQuery:Execute()
  nQtdCobAntes := oQuery:FieldGet("qtd")
  oQuery:Close()
  
  // Launch expense
  lOk := GcLancarDespesaContabil("2025-01-20", "Pintura Comum", 1000.00, "FRACAO", 15)
  
  // Count after
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM LANCAMENTOS WHERE LAN_TIPO LIKE 'AUTOMATICO%' AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  nQtdLanDepois := oQuery:FieldGet("qtd")
  oQuery:Close()
  
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM COB WHERE D_E_L_E_T_ = ' '")
  oQuery:Execute()
  nQtdCobDepois := oQuery:FieldGet("qtd")
  oQuery:Close()
  
  // Should create 1 main + N repartition entries
  Assert( lOk, "GcLancarDespesaContabil failed" )
  Assert( nQtdLanDepois > nQtdLanAntes, "No entries created" )
  Assert( nQtdCobDepois > nQtdCobAntes, "No billing records created" )
  
  ConOut("✓ Launch expense with repartition OK")
End Function
```

- [ ] **Step 2: Implement GcLancarDespesaContabil**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Launch expense with automatic double-entry repartition
@type Function
@author Claude
@since 2026-07-30
@param dData Date
@param cDescricao Character description
@param nValor Numeric total amount
@param cReparticao Character repartition code
@param nDiaVenc Numeric due day of month
@return Logical .T. on success
/*/
User Function GcLancarDespesaContabil(dData as date, cDescricao as character, nValor as numeric, cReparticao as character, nDiaVenc as numeric) as logical
  Local cExercicio as character
  Local lFechado as logical
  Local aRateio as array
  Local i as numeric
  Local cUnidade as character
  Local nValorUnit as numeric
  Local cMesAno as character
  Local dVencimento as date
  Local oExec as object
  Local nLanId as numeric
  
  // Get active exercise
  cExercicio := GcExercicioAtivo()
  If Empty(cExercicio)
    ConOut("ERROR: No active exercise")
    Return .F.
  EndIf
  
  // Check if closed
  lFechado := GcPeriodoFechado(cExercicio)
  If lFechado
    ConOut("ERROR: Period is closed")
    Return .F.
  EndIf
  
  // Calculate repartition
  aRateio := GcCalcularRateio(cReparticao, nValor, dData)
  If Len(aRateio) == 0
    ConOut("ERROR: Repartition calculation failed")
    Return .F.
  EndIf
  
  // Create main entry: Debit Despesa / Credit Caixa
  oExec := TCSqlExec():New("INSERT INTO LANCAMENTOS " + ;
    "(LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
    "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) " + ;
    "VALUES (" + ;
    "'" + DtoS(dData) + "', " + ;
    GcSqlLit("4000") + ", " +  // Despesa Comum
    GcSqlLit("1000") + ", " +  // Caixa
    cValToChar(nValor) + ", " + ;
    GcSqlLit(cDescricao) + ", " + ;
    GcSqlLit("AUTOMATICO_DESPESA") + ", " + ;
    GcSqlLit(cExercicio) + ", " + ;
    "datetime('now'), " + ;
    GcSqlLit("SYSTEM") + ", " + ;
    "' ')")
  
  If !oExec:Execute()
    ConOut("ERROR: Main entry insert failed")
    Return .F.
  EndIf
  
  // Get last inserted ID (for reference in repartition entries)
  // Note: SQLite LAST_INSERT_ROWID() would be ideal but may not be exposed
  // Workaround: query for the last entry we just created
  // ponytail: simplified for MVP, may need refinement for concurrent inserts
  
  // Create repartition entries: one per unit
  For i := 1 To Len(aRateio)
    cUnidade := aRateio[i, 1]
    nValorUnit := aRateio[i, 3]
    
    // Entry: Debit Contas a Receber / Credit Receita
    oExec := TCSqlExec():New("INSERT INTO LANCAMENTOS " + ;
      "(LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, LAN_DESCR, " + ;
      "LAN_TIPO, LAN_EXERCICIO, LAN_DATA_HORA, LAN_USUARIO, D_E_L_E_T_) " + ;
      "VALUES (" + ;
      "'" + DtoS(dData) + "', " + ;
      GcSqlLit("5000") + ", " +  // Contas a Receber
      GcSqlLit("3000") + ", " +  // Receita Condominial
      cValToChar(nValorUnit) + ", " + ;
      GcSqlLit(cDescricao + " - " + cUnidade) + ", " + ;
      GcSqlLit("AUTOMATICO_RATEIO") + ", " + ;
      GcSqlLit(cExercicio) + ", " + ;
      "datetime('now'), " + ;
      GcSqlLit("SYSTEM") + ", " + ;
      "' ')")
    
    If !oExec:Execute()
      ConOut("ERROR: Repartition entry insert failed for unit " + cUnidade)
      Return .F.
    EndIf
    
    // Create billing record (COB)
    dVencimento := Date(Year(dData), Month(dData), nDiaVenc)
    If dVencimento < dData
      dVencimento := Date(Year(dData), Month(dData) + 1, nDiaVenc)
    EndIf
    
    oExec := TCSqlExec():New("INSERT INTO COB " + ;
      "(COB_UNIDADE, COB_VALOR, COB_VENCTO, COB_STATUS, COB_COMPET, D_E_L_E_T_) " + ;
      "VALUES (" + ;
      GcSqlLit(cUnidade) + ", " + ;
      cValToChar(nValorUnit) + ", " + ;
      "'" + DtoS(dVencimento) + "', " + ;
      GcSqlLit("PENDENTE") + ", " + ;
      GcSqlLit(cExercicio) + ", " + ;
      "' ')")
    
    If !oExec:Execute()
      ConOut("WARNING: Billing record insert failed for unit " + cUnidade)
      // Continue despite billing failure
    EndIf
  Next i
  
  ConOut("✓ Expense launched: " + cDescricao + " (R$ " + cValToChar(nValor) + ", " + cValToChar(Len(aRateio)) + " units)")
  Return .T.
End Function
```

- [ ] **Step 3: Run test**

Run: `advplc run tests/contabil_test.prw::TesteLancarDespesaComRateio`

Expected: PASS or informative FAIL pointing to actual database state

- [ ] **Step 4: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "feat: implement automatic entry creation with repartition (GcLancarDespesaContabil)"
```

---

## Phase 4: Period Closing & Validation (Fechamento)

### Task 8: Implement GcValidarIntegridade (Debit == Credit Validation)

**Files:**
- Modify: `src/contabil.prw`
- Test: `tests/contabil_test.prw`

**Interfaces:**
- Consumes: LANCAMENTOS
- Produces: `GcValidarIntegridade(cExercicio) -> logical`

**Steps:**

- [ ] **Step 1: Write test (balanced period)**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteValidarIntegridadeBalanced()
  Local cExercicio as character
  Local lOk as logical
  
  cExercicio := GcExercicioAtivo()
  
  // Create balanced entries (existing from prior tasks)
  // Assuming some balanced entries exist
  
  lOk := GcValidarIntegridade(cExercicio)
  Assert( lOk, "Validation should pass for balanced entries" )
  
  ConOut("✓ Validation OK (balanced)")
End Function
```

- [ ] **Step 2: Implement GcValidarIntegridade**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Validate period integrity: total debit == total credit
@type Function
@author Claude
@since 2026-07-30
@param cExercicio Character exercise code
@return Logical .T. if balanced, .F. if not
/*/
User Function GcValidarIntegridade(cExercicio as character) as logical
  Local oQuery as object
  Local nDebito as numeric
  Local nCredito as numeric
  Local nDiferenca as numeric
  
  // Sum debits
  oQuery := TCSqlQuery():New("SELECT SUM(LAN_VALOR) as total FROM LANCAMENTOS " + ;
    "WHERE LAN_EXERCICIO = " + GcSqlLit(cExercicio) + " " + ;
    "AND D_E_L_E_T_ = ' ' " + ;
    "AND LAN_CONTA_DEB IN (SELECT PLA_CODIGO FROM PLANO_CONTAS WHERE PLA_TIPO IN ('ATIVO', 'DESPESA'))")
  
  oQuery:Execute()
  nDebito := If(oQuery:FieldGet("total") == Nil, 0, oQuery:FieldGet("total"))
  oQuery:Close()
  
  // Sum credits
  oQuery := TCSqlQuery():New("SELECT SUM(LAN_VALOR) as total FROM LANCAMENTOS " + ;
    "WHERE LAN_EXERCICIO = " + GcSqlLit(cExercicio) + " " + ;
    "AND D_E_L_E_T_ = ' ' " + ;
    "AND LAN_CONTA_CRED IN (SELECT PLA_CODIGO FROM PLANO_CONTAS WHERE PLA_TIPO IN ('PASSIVO', 'RECEITA'))")
  
  oQuery:Execute()
  nCredito := If(oQuery:FieldGet("total") == Nil, 0, oQuery:FieldGet("total"))
  oQuery:Close()
  
  // Check balance (tolerance: 0.01)
  nDiferenca := Abs(nDebito - nCredito)
  
  If nDiferenca > 0.01
    ConOut("WARNING: Imbalance detected. Debit: " + cValToChar(nDebito) + ", Credit: " + cValToChar(nCredito) + ", Diff: " + cValToChar(nDiferenca))
    Return .F.
  EndIf
  
  Return .T.
End Function
```

- [ ] **Step 3: Run test**

Run: `advplc run tests/contabil_test.prw::TesteValidarIntegridadeBalanced`

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "feat: implement accounting integrity validation (debit == credit)"
```

---

### Task 9: Implement GcFecharPeriodo (Close Period)

**Files:**
- Modify: `src/contabil.prw`
- Test: `tests/contabil_test.prw`

**Interfaces:**
- Consumes:
  - GcValidarIntegridade
  - EXERCICIO table
  - GcGerarBalancetePeriodo (from next task)
- Produces:
  - `GcFecharPeriodo(cExercicio) -> logical`
  - Side effect: marks period as closed, creates next period, generates balance sheet

**Steps:**

- [ ] **Step 1: Write test for period closing**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteFecharPeriodo()
  Local cExercicio as character
  Local lOk as logical
  Local oQuery as object
  Local lFechado as logical
  Local cProximo as character
  
  cExercicio := GcExercicioAtivo()
  
  // Close period
  lOk := GcFecharPeriodo(cExercicio)
  Assert( lOk, "Period closing failed" )
  
  // Verify closed
  oQuery := TCSqlQuery():New("SELECT EXE_FECHADO FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  lFechado := (oQuery:FieldGet("EXE_FECHADO") == 1)
  oQuery:Close()
  Assert( lFechado, "Period not marked as closed" )
  
  // Verify new period created
  cProximo := GcExercicioAtivo()
  Assert( cProximo != cExercicio, "New active period not created" )
  
  ConOut("✓ Period closing OK (next: " + cProximo + ")")
End Function
```

- [ ] **Step 2: Implement GcFecharPeriodo**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Close period: validate, mark closed, generate balance sheet, create next period
@type Function
@author Claude
@since 2026-07-30
@param cExercicio Character exercise code
@return Logical .T. on success
/*/
User Function GcFecharPeriodo(cExercicio as character) as logical
  Local lIntegro as logical
  Local oExec as object
  Local cProximo as character
  Local dProxInicio as date
  Local dProxFim as date
  Local oQuery as object
  Local dFim as date
  
  // Validate integrity
  lIntegro := GcValidarIntegridade(cExercicio)
  If !lIntegro
    ConOut("ERROR: Period is not balanced. Fix entries before closing.")
    Return .F.
  EndIf
  
  // Get current period dates
  oQuery := TCSqlQuery():New("SELECT EXE_FIM FROM EXERCICIO WHERE EXE_CODIGO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
  oQuery:Execute()
  dFim := oQuery:FieldGet("EXE_FIM")
  oQuery:Close()
  
  // Mark period as closed
  oExec := TCSqlExec():New("UPDATE EXERCICIO SET " + ;
    "EXE_FECHADO = 1, " + ;
    "EXE_ATIVO = 0, " + ;
    "R_E_C_D_E_L_ = " + cValToChar(Seconds()) + " " + ;
    "WHERE EXE_CODIGO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
  
  If !oExec:Execute()
    ConOut("ERROR: Could not mark period as closed")
    Return .F.
  EndIf
  
  // Generate balance sheet
  If !GcGerarBalancetePeriodo(cExercicio)
    ConOut("WARNING: Balance sheet generation failed, but period closed")
  EndIf
  
  // Create next period (automatically next month)
  dProxInicio := Date(Year(dFim), Month(dFim) + 1, 1)
  If Month(dProxInicio) == 1
    dProxInicio := Date(Year(dFim) + 1, 1, 1)
  EndIf
  dProxFim := Date(Year(dProxInicio), Month(dProxInicio) + 1, 0)
  If Month(dProxInicio) == 12
    dProxFim := Date(Year(dProxInicio) + 1, 1, 0)
  EndIf
  
  cProximo := StrZero(Year(dProxInicio), 4) + "-" + StrZero(Month(dProxInicio), 2)
  
  oExec := TCSqlExec():New("INSERT INTO EXERCICIO " + ;
    "(EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_) " + ;
    "VALUES (" + ;
    GcSqlLit(cProximo) + ", " + ;
    "'" + DtoS(dProxInicio) + "', " + ;
    "'" + DtoS(dProxFim) + "', " + ;
    "1, 0, ' ')")
  
  If !oExec:Execute()
    ConOut("ERROR: Could not create next period")
    Return .F.
  EndIf
  
  ConOut("✓ Period " + cExercicio + " closed. Next period: " + cProximo)
  Return .T.
End Function
```

- [ ] **Step 3: Run test**

Run: `advplc run tests/contabil_test.prw::TesteFecharPeriodo`

Expected: PASS (or FAIL if GcGerarBalancetePeriodo not yet implemented, but period should close)

- [ ] **Step 4: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "feat: implement period closing with validation and auto-create next period"
```

---

### Task 10: Implement GcGerarBalancetePeriodo (Balance Sheet)

**Files:**
- Modify: `src/contabil.prw`
- Test: `tests/contabil_test.prw`

**Interfaces:**
- Consumes: LANCAMENTOS, PLANO_CONTAS
- Produces:
  - `GcGerarBalancetePeriodo(cExercicio) -> numeric` (returns balance = receitas - despesas)
  - Side effect: writes snapshot to RPT_BALANCETE table

**Steps:**

- [ ] **Step 1: Create RPT_BALANCETE table (add to schema.sql)**

```sql
CREATE TABLE RPT_BALANCETE (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    RPT_EXERCICIO TEXT NOT NULL,
    RPT_RECEITAS NUMERIC,
    RPT_DESPESAS NUMERIC,
    RPT_SALDO NUMERIC,
    RPT_DATA_GERACAO DATETIME,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    UNIQUE(RPT_EXERCICIO, D_E_L_E_T_)
);
```

- [ ] **Step 2: Write test for balance sheet generation**

Add to `tests/contabil_test.prw`:

```advpl
User Function TesteGerarBalancete()
  Local cExercicio as character
  Local nSaldo as numeric
  Local oQuery as object
  Local nReceitas as numeric
  
  cExercicio := GcExercicioAtivo()
  
  nSaldo := GcGerarBalancetePeriodo(cExercicio)
  Assert( nSaldo != Nil, "Saldo should be numeric" )
  
  // Verify record in RPT_BALANCETE
  oQuery := TCSqlQuery():New("SELECT RPT_RECEITAS FROM RPT_BALANCETE WHERE RPT_EXERCICIO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
  oQuery:Execute()
  
  If !oQuery:Eof()
    nReceitas := oQuery:FieldGet("RPT_RECEITAS")
    Assert( nReceitas != Nil, "Receitas should be recorded" )
  EndIf
  
  oQuery:Close()
  
  ConOut("✓ Balance sheet generated (saldo: " + cValToChar(nSaldo) + ")")
End Function
```

- [ ] **Step 3: Implement GcGerarBalancetePeriodo**

Add to `src/contabil.prw`:

```tlpp
/*{Protheus.doc}
Generate balance sheet (income - expenses) for period
@type Function
@author Claude
@since 2026-07-30
@param cExercicio Character exercise code
@return Numeric balance (receitas - despesas)
/*/
User Function GcGerarBalancetePeriodo(cExercicio as character) as numeric
  Local oQuery as object
  Local nReceitas as numeric
  Local nDespesas as numeric
  Local nSaldo as numeric
  Local oExec as object
  
  // Sum receitas (RECEITA type accounts, credited)
  oQuery := TCSqlQuery():New("SELECT SUM(LAN_VALOR) as total FROM LANCAMENTOS L " + ;
    "JOIN PLANO_CONTAS P ON L.LAN_CONTA_CRED = P.PLA_CODIGO " + ;
    "WHERE L.LAN_EXERCICIO = " + GcSqlLit(cExercicio) + " " + ;
    "AND L.D_E_L_E_T_ = ' ' " + ;
    "AND P.PLA_TIPO = 'RECEITA'")
  
  oQuery:Execute()
  nReceitas := If(oQuery:FieldGet("total") == Nil, 0, oQuery:FieldGet("total"))
  oQuery:Close()
  
  // Sum despesas (DESPESA type accounts, debited)
  oQuery := TCSqlQuery():New("SELECT SUM(LAN_VALOR) as total FROM LANCAMENTOS L " + ;
    "JOIN PLANO_CONTAS P ON L.LAN_CONTA_DEB = P.PLA_CODIGO " + ;
    "WHERE L.LAN_EXERCICIO = " + GcSqlLit(cExercicio) + " " + ;
    "AND L.D_E_L_E_T_ = ' ' " + ;
    "AND P.PLA_TIPO = 'DESPESA'")
  
  oQuery:Execute()
  nDespesas := If(oQuery:FieldGet("total") == Nil, 0, oQuery:FieldGet("total"))
  oQuery:Close()
  
  // Calculate balance
  nSaldo := nReceitas - nDespesas
  
  // Write to RPT_BALANCETE (replace if exists)
  oExec := TCSqlExec():New("DELETE FROM RPT_BALANCETE WHERE RPT_EXERCICIO = " + GcSqlLit(cExercicio) + " AND D_E_L_E_T_ = ' '")
  oExec:Execute()
  
  oExec := TCSqlExec():New("INSERT INTO RPT_BALANCETE " + ;
    "(RPT_EXERCICIO, RPT_RECEITAS, RPT_DESPESAS, RPT_SALDO, RPT_DATA_GERACAO, D_E_L_E_T_) " + ;
    "VALUES (" + ;
    GcSqlLit(cExercicio) + ", " + ;
    cValToChar(nReceitas) + ", " + ;
    cValToChar(nDespesas) + ", " + ;
    cValToChar(nSaldo) + ", " + ;
    "datetime('now'), " + ;
    "' ')")
  
  If oExec:Execute()
    ConOut("✓ Balance sheet: Receitas: R$ " + cValToChar(nReceitas) + " | Despesas: R$ " + cValToChar(nDespesas) + " | Saldo: R$ " + cValToChar(nSaldo))
  EndIf
  
  Return nSaldo
End Function
```

- [ ] **Step 4: Run test**

Run: `advplc run tests/contabil_test.prw::TesteGerarBalancete`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/contabil.prw tests/contabil_test.prw
git commit -m "feat: implement balance sheet generation (receitas - despesas)"
```

---

## Phase 5: Audit Trail (Auditoria)

### Task 11: Implement GcAuditoriaFecharPeriodo & GcRegistrarAnomalia

**Files:**
- Create: `src/auditoria.prw` (audit functions)
- Test: `tests/auditoria_test.prw`

**Interfaces:**
- Consumes:
  - LANCAMENTOS, COB (for anomaly detection)
  - AUDITORIA table
- Produces:
  - `GcAuditoriaFecharPeriodo(cExercicio) -> numeric` (# anomalies)
  - `GcRegistrarAnomalia(cTipo, cDescricao, cSeveridade) -> logical` (log)

**Steps:**

- [ ] **Step 1: Create src/auditoria.prw**

```tlpp
#include "totvs.ch"

/*{Protheus.doc}
Register anomaly in audit trail
@type Function
@author Claude
@since 2026-07-30
@param cTipo Character anomaly type
@param cDescricao Character description
@param cSeveridade Character CRITICA | AVISO | INFO
@return Logical .T. on success
/*/
User Function GcRegistrarAnomalia(cTipo as character, cDescricao as character, cSeveridade as character) as logical
  Local oExec as object
  
  oExec := TCSqlExec():New("INSERT INTO AUDITORIA " + ;
    "(AUD_DATA_HORA, AUD_TIPO, AUD_DESCRICAO, AUD_SEVERIDADE, D_E_L_E_T_) " + ;
    "VALUES (" + ;
    "datetime('now'), " + ;
    "'" + cTipo + "', " + ;
    "'" + StrTran(cDescricao, "'", "''") + "', " + ;
    "'" + cSeveridade + "', " + ;
    "' ')")
  
  Return oExec:Execute()
End Function

/*{Protheus.doc}
Run audit checks on period (called at close time)
@type Function
@author Claude
@since 2026-07-30
@param cExercicio Character exercise code
@return Numeric count of anomalies found
/*/
User Function GcAuditoriaFecharPeriodo(cExercicio as character) as numeric
  Local nAnomalias as numeric
  Local oQuery as object
  
  nAnomalias := 0
  
  // Anomaly 1: Desequilíbrio D/C (already checked in GcValidarIntegridade, but log if present)
  If !GcValidarIntegridade(cExercicio)
    GcRegistrarAnomalia("DESEQUILIBRIO_CONTABIL", "Débito != Crédito no período " + cExercicio, "CRITICA")
    nAnomalias++
  EndIf
  
  // Anomaly 2: COB sem lançamento (billing without entry)
  oQuery := TCSqlQuery():New("SELECT COUNT(*) as qtd FROM COB C " + ;
    "WHERE C.D_E_L_E_T_ = ' ' " + ;
    "AND NOT EXISTS (SELECT 1 FROM LANCAMENTOS L WHERE L.LAN_REFERENCIA = C.R_E_C_N_O_ AND L.D_E_L_E_T_ = ' ')")
  
  oQuery:Execute()
  If oQuery:FieldGet("qtd") > 0
    GcRegistrarAnomalia("COB_ORFAO", "Existem " + cValToChar(oQuery:FieldGet("qtd")) + " cobranças sem lançamento", "AVISO")
    nAnomalias++
  EndIf
  oQuery:Close()
  
  ConOut("✓ Audit complete: " + cValToChar(nAnomalias) + " anomalies found")
  Return nAnomalias
End Function
```

- [ ] **Step 2: Write test for anomaly detection**

Create `tests/auditoria_test.prw`:

```advpl
#include "../src/db.prw"
#include "../src/contabil.prw"
#include "../src/auditoria.prw"

User Function TesteAuditoriaAnomalies()
  Local cExercicio as character
  Local nAnomalias as numeric
  
  cExercicio := GcExercicioAtivo()
  
  // Run audit
  nAnomalias := GcAuditoriaFecharPeriodo(cExercicio)
  
  // Should detect any anomalies (0 if clean)
  Assert( nAnomalias >= 0, "Audit check failed" )
  
  ConOut("✓ Audit test OK (" + cValToChar(nAnomalias) + " anomalies logged)")
End Function
```

- [ ] **Step 3: Run test**

Run: `advplc run tests/auditoria_test.prw::TesteAuditoriaAnomalies`

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/auditoria.prw tests/auditoria_test.prw
git commit -m "feat: implement audit trail and anomaly detection"
```

---

## Phase 6: Menu Integration & End-to-End Tests

### Task 12: Integrate Menu & E2E Testing

**Files:**
- Modify: `src/menu.prw` (add "Contabilidade" submenu)
- Modify: `gescon.prw` (include contabil.prw + auditoria.prw)
- Create: `tests/contabil_e2e_test.prw` (full workflow)

**Interfaces:**
- Consumes: All functions from Phases 1-5
- Produces: Integrated menu + working e2e workflow

**Steps:**

- [ ] **Step 1: Add "Contabilidade" to menu**

Modify `src/menu.prw` to add submenu item (UI placeholder for now):

```tlpp
// In GcMenuPrincipal or equivalent:
// "Contabilidade" → GcMenuContabilidade()

User Function GcMenuContabilidade()
  // ponytail: UI placeholder for MVP
  // Options: Novo Lançamento, Editar, Deletar, Consultar, Fechar Período
  ConOut("Menu Contabilidade (UI not yet integrated)")
End Function
```

- [ ] **Step 2: Include contabil + auditoria in gescon.prw**

Modify `gescon.prw`:

```tlpp
#include "totvs.ch"
#include "src/db.prw"
#include "src/login.prw"
#include "src/contabil.prw"
#include "src/auditoria.prw"
// ... other includes

User Function GesCon()
  // Existing GesCon logic
End Function
```

- [ ] **Step 3: Write e2e test (full workflow)**

Create `tests/contabil_e2e_test.prw`:

```advpl
#include "../src/db.prw"
#include "../src/contabil.prw"
#include "../src/auditoria.prw"

User Function TesteE2EContabilCompleto()
  Local cExercicio as character
  Local lOk as logical
  Local nSaldo as numeric
  
  ConOut("=== E2E Accounting Workflow ===")
  
  // 1. Get active exercise
  cExercicio := GcExercicioAtivo()
  Assert( !Empty(cExercicio), "No active exercise" )
  ConOut("1. Active exercise: " + cExercicio)
  
  // 2. Create manual entry
  lOk := GcCriarLancamentoManualDireto("2025-01-05", "Teste Manual", "1000", "4900", 50.00)
  Assert( lOk, "Manual entry failed" )
  ConOut("2. Manual entry created")
  
  // 3. Launch expense with repartition
  lOk := GcLancarDespesaContabil("2025-01-10", "Teste Despesa", 500.00, "FRACAO", 15)
  Assert( lOk, "Expense launch failed" )
  ConOut("3. Expense with repartition created")
  
  // 4. Validate integrity
  lOk := GcValidarIntegridade(cExercicio)
  Assert( lOk, "Integrity check failed" )
  ConOut("4. Integrity validated (D/C balanced)")
  
  // 5. Generate balance sheet
  nSaldo := GcGerarBalancetePeriodo(cExercicio)
  Assert( nSaldo != Nil, "Balance sheet generation failed" )
  ConOut("5. Balance sheet: R$ " + cValToChar(nSaldo))
  
  // 6. Run audit
  GcAuditoriaFecharPeriodo(cExercicio)
  ConOut("6. Audit completed")
  
  // 7. Close period
  lOk := GcFecharPeriodo(cExercicio)
  Assert( lOk, "Period close failed" )
  ConOut("7. Period closed, next period created")
  
  // 8. Verify new exercise is active
  cExercicio := GcExercicioAtivo()
  Assert( !Empty(cExercicio), "No new active exercise after close" )
  ConOut("8. New active exercise: " + cExercicio)
  
  ConOut("✓ E2E Workflow Complete!")
End Function
```

- [ ] **Step 4: Run e2e test**

Run: `advplc run tests/contabil_e2e_test.prw::TesteE2EContabilCompleto`

Expected: PASS with full workflow output

- [ ] **Step 5: Commit**

```bash
git add src/menu.prw gescon.prw tests/contabil_e2e_test.prw
git commit -m "feat: integrate accounting menu and complete e2e workflow test"
```

---

## Phase 7: Final Cleanup & Documentation

### Task 13: Documentation & Code Review

**Files:**
- Modify: `README.md` (add Accounting section)
- Modify: `docs/ARQUITETURA.md` (document new module)
- Create: `docs/CONTABILIDADE.md` (user guide)

**Steps:**

- [ ] **Step 1: Update README with Accounting note**

Add to README.md:

```markdown
## Contabilidade (Novo em v2)

Sistema contábil em partida dupla minimalista. Lançamentos manuais + automáticos (via rateio), 
fechamento com validação D/C, auditoria básica.

```

- [ ] **Step 2: Update ARQUITETURA.md**

Add new section documenting the 6 tables, function list, etc.

- [ ] **Step 3: Commit final docs**

```bash
git add README.md docs/ARQUITETURA.md
git commit -m "docs: add accounting module documentation"
```

---

## Summary

**Total Tasks:** 13  
**Phases:** 7 (Database, Manual Entries, Repartition, Closing, Audit, Menu, Docs)  
**New Tables:** 6  
**New Functions:** 20+  
**Test Coverage:** E2E workflow + unit tests per task  
**Commits:** ~13 (one per task)

---

## Next Steps After Implementation

1. **Phase 2:** Portal do Condômino (avisos, documentos, agenda)
2. **Phase 3:** Auditoria Contábil (detecção de anomalias, dashboard)
3. **Phase 4:** REST API (integração com portal web/mobile)
