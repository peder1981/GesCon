# GesCon — Motor Financeiro Núcleo (Plano 1 de 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o motor financeiro central do GesCon funcionando de ponta a ponta: cadastro de unidades/condôminos/despesas, fechamento mensal com rateio por fração ideal, e registro de cobrança/pagamento — tudo via web (`advplc serve`) com persistência real em SQLite.

**Architecture:** Duas camadas de código em dois repositórios. (1) AdvPP (`/home/peder/Projetos/AdvPP`): quatro capacidades novas no compilador — `TCSqlExec`/`TCSqlQuery` (SQL direto pra `User Function`), persistência real de `DbAppend`/`RecLock`/`FieldPut`/`MsUnlock` (a API clássica de work-area, hoje um stub sem efeito — achado confirmado por teste direto), e a classe `TMailMessage` (envio de e-mail real via `net/smtp`, stdlib). (2) GesCon (`~/Projetos/GesCon`): aplicação AdvPL/TLPP pura, cadastros via `FWMBrowse` (CRUD grátis, sem código customizado) e lógica de negócio (fechamento mensal) via `TCSqlExec`/`TCSqlQuery`.

**Tech Stack:** Go 1.24 (AdvPP), AdvPL/TLPP (GesCon), SQLite (banco compartilhado `~/.advpp/ADVPP.db`), PO-UI via `advplc serve` (navegador), `net/smtp` (stdlib, sem dependência externa).

## Global Constraints

- Notação húngara obrigatória em todo identificador AdvPL (c=character, n=numeric, l=logical, a=array, o=object, d=date).
- Tabelas: alias 2-3 chars; campos: prefixo da tabela + `_` + nome (convenção Protheus, ex.: `UNI_CODIGO`).
- Toda tabela usa exclusão lógica estilo Protheus: colunas `R_E_C_N_O_`, `D_E_L_E_T_`, `R_E_C_D_E_L_` (mesma convenção do AdvEditor).
- `User Function` (nunca `Function` puro) para toda rotina de negócio do GesCon.
- `IIf()` proibido — usar `If/Else/EndIf`.
- Fechamento mensal nunca recalcula/reescreve uma `Cobrança` já gerada — trava contra fechar a mesma competência duas vezes.
- AdvPP: sem CGO, sem dependências externas novas — só stdlib do Go (mesma exigência do resto do projeto).
- GesCon nesta fase não envia mala direta (fora de escopo do Plano 1, ver spec) — `TMailMessage` é capacidade do compilador, não consumida por nenhuma tela do GesCon ainda; fica disponível pro Plano 2.

---

## Parte A — AdvPP: quatro capacidades novas no compilador

### Task 1: Natives `TCSqlExec`/`TCSqlQuery`

**Files:**
- Modify: `pkg/vm/natives.go` (dentro de `registerNatives`, dentro do bloco `// --- Database stubs ---`)
- Test: `tests/tcsql_test.prw` (novo)
- Test: `cmd/advplc/tcsql_test.go` (novo, segue o padrão de `cmd/advplc/parser_gaps3_test.go`)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Produces: `TCSqlExec(cQuery As Character) As Logical` — roda INSERT/UPDATE/DELETE, `.T.` em sucesso, lança erro AdvPL em falha.
- Produces: `TCSqlQuery(cQuery As Character) As Array` — roda SELECT, devolve array de `JsonObject` (uma entrada por linha, chaves = nomes de coluna em maiúsculas, valores sempre `Character` — o motor SQLite devolve texto bruto).

- [ ] **Step 1: Escrever o fixture AdvPL que exercita as natives (vai falhar — natives não existem ainda)**

Crie `tests/tcsql_test.prw`:

```advpl
// Fixture de regressão pras natives TCSqlExec/TCSqlQuery (SQL direto pra
// User Function, motor de persistência real do FWMBrowse exposto ao AdvPL —
// ver CHANGELOG). Cria uma tabela de teste, insere, consulta e confere.
User Function TCSqlTest()
    Local aRows

    TCSqlExec("CREATE TABLE IF NOT EXISTS TCSQL_TEST (T1_CODIGO TEXT, T1_VALOR REAL)")
    TCSqlExec("DELETE FROM TCSQL_TEST")
    TCSqlExec("INSERT INTO TCSQL_TEST (T1_CODIGO, T1_VALOR) VALUES ('A1', 10.5)")
    TCSqlExec("INSERT INTO TCSQL_TEST (T1_CODIGO, T1_VALOR) VALUES ('A2', 20.5)")

    aRows := TCSqlQuery("SELECT T1_CODIGO, T1_VALOR FROM TCSQL_TEST ORDER BY T1_CODIGO")

    ConOut("linhas=" + Str(Len(aRows)))
    ConOut("linha1_codigo=" + aRows[1]:T1_CODIGO)
    ConOut("linha1_valor=" + aRows[1]:T1_VALOR)
    ConOut("linha2_codigo=" + aRows[2]:T1_CODIGO)
Return
```

- [ ] **Step 2: Rodar o fixture pra confirmar que falha (natives não existem)**

Run: `cd /home/peder/Projetos/AdvPP && go build -o advplc ./cmd/advplc && ./advplc run tests/tcsql_test.prw`
Expected: `Error: unknown function: TCSQLEXEC` (ou similar erro de função desconhecida)

- [ ] **Step 3: Implementar as natives**

Em `pkg/vm/natives.go`, dentro de `registerNatives()`, logo após a entrada `"RETSQLNAME"` (mantém as natives de banco agrupadas):

```go
		// TCSqlExec/TCSqlQuery: acesso SQL direto exposto a User Function —
		// a API clássica de work-area (DbAppend/RecLock/FieldPut/MsUnlock)
		// era um stub sem persistência real (corrigida no Task 2 deste
		// plano); lógica de negócio que precisa gravar programaticamente em
		// lote (ex.: fechamento mensal) usa este caminho, mais direto.
		// Reaproveita a mesma interface SQLEngine (Exec/QueryRows) que o
		// FWMBrowse já usa internamente, só que exposta ao AdvPL.
		"TCSQLEXEC": func(args []advplrt.Value) (advplrt.Value, error) {
			query := advplrt.ToString(getArg(args, 0))
			sqlEng, ok := v.dbEngine.(SQLEngine)
			if !ok || sqlEng == nil {
				return advplrt.False, fmt.Errorf("TCSqlExec: nenhum banco de dados conectado")
			}
			if err := sqlEng.Exec(query); err != nil {
				return advplrt.False, err
			}
			return advplrt.True, nil
		},
		"TCSQLQUERY": func(args []advplrt.Value) (advplrt.Value, error) {
			query := advplrt.ToString(getArg(args, 0))
			sqlEng, ok := v.dbEngine.(SQLEngine)
			if !ok || sqlEng == nil {
				return advplrt.NewArray([]advplrt.Value{}), fmt.Errorf("TCSqlQuery: nenhum banco de dados conectado")
			}
			rows, err := sqlEng.QueryRows(query)
			if err != nil {
				return advplrt.NewArray([]advplrt.Value{}), err
			}
			elems := make([]advplrt.Value, 0, len(rows))
			for _, row := range rows {
				obj := advplrt.NewObject("JsonObject", nil)
				for k, val := range row {
					obj.SetProp(k, advplrt.NewString(val))
				}
				elems = append(elems, obj)
			}
			return advplrt.NewArray(elems), nil
		},
```

- [ ] **Step 4: Rodar o fixture de novo e confirmar que passa**

Run: `cd /home/peder/Projetos/AdvPP && go build -o advplc ./cmd/advplc && ./advplc run tests/tcsql_test.prw`
Expected:
```
linhas=2
linha1_codigo=A1
linha1_valor=10.5
linha2_codigo=A2
```

- [ ] **Step 5: Escrever o teste Go de regressão**

Crie `cmd/advplc/tcsql_test.go` (copie a estrutura de `cmd/advplc/parser_gaps3_test.go`, adaptando pro fixture novo):

```go
package main

import (
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// TestTCSqlFixture roda tests/tcsql_test.prw — exercita TCSqlExec/TCSqlQuery,
// a via de persistência real de SQL direto pra User Function. Ver CHANGELOG.
func TestTCSqlFixture(t *testing.T) {
	if testing.Short() {
		t.Skip("builda o binário; pulado com -short")
	}

	repoRoot, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("filepath.Abs: %v", err)
	}
	binName := "advplc"
	if runtime.GOOS == "windows" {
		binName += ".exe"
	}
	binPath := filepath.Join(t.TempDir(), binName)
	build := exec.Command("go", "build", "-o", binPath, "./cmd/advplc")
	build.Dir = repoRoot
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}

	run := exec.Command(binPath, "run", "tests/tcsql_test.prw")
	run.Dir = repoRoot
	out, err := run.CombinedOutput()
	if err != nil {
		t.Fatalf("advplc run tests/tcsql_test.prw falhou: %v\n%s", err, out)
	}
	want := []string{"linhas=2", "linha1_codigo=A1", "linha1_valor=10.5", "linha2_codigo=A2"}
	got := string(out)
	for _, w := range want {
		if !strings.Contains(got, w) {
			t.Errorf("saída não contém %q; saída completa:\n%s", w, got)
		}
	}
}
```

Run: `cd /home/peder/Projetos/AdvPP && go test ./cmd/advplc/... -run TestTCSqlFixture -v`
Expected: `--- PASS: TestTCSqlFixture`

- [ ] **Step 6: Rodar a suíte completa (zero regressão)**

Run: `cd /home/peder/Projetos/AdvPP && go build ./... && go vet ./... && go test ./...`
Expected: todos os pacotes `ok`, nenhum `FAIL`

- [ ] **Step 7: Documentar no CHANGELOG e commitar**

Em `CHANGELOG.md`, adicione no topo de `## [Não lançado]`:

```markdown
### `TCSqlExec`/`TCSqlQuery` — SQL direto pra User Function

A API clássica de work-area (`DbAppend`/`RecLock`/`FieldPut`/`MsUnlock`) não
persistia dados de verdade até este release — só `FWMBrowse` gravava (via
código Go interno acionado por clique na UI web). Lógica de negócio que
precisa gravar programaticamente (loop de inserção, processamento em lote)
não tinha caminho nenhum. `TCSqlExec(cQuery)` (INSERT/UPDATE/DELETE) e
`TCSqlQuery(cQuery)` (SELECT, devolve array de `JsonObject`) expõem a mesma
camada SQL que o `FWMBrowse` já usa internamente. Achado motivado por uso
real (GesCon, sistema de gestão condominial construído sobre o AdvPP).
```

Run:
```bash
cd /home/peder/Projetos/AdvPP
git add pkg/vm/natives.go tests/tcsql_test.prw cmd/advplc/tcsql_test.go CHANGELOG.md
git commit -m "vm: expõe TCSqlExec/TCSqlQuery — SQL direto pra User Function"
```

### Task 2: Persistência real em `DbAppend`/`RecLock`/`FieldPut`/`MsUnlock`

**Files:**
- Modify: `pkg/db/sqlite.go`
- Modify: `pkg/vm/vm.go` (interface `DBEngine`)
- Modify: `pkg/vm/natives.go` (`DBAPPEND`, `FIELDPOS`)
- Test: `tests/workarea_test.prw` (novo)
- Test: `cmd/advplc/workarea_test.go` (novo)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nada do Task 1 (independente — mexe num caminho de código diferente: opcodes `OP_FIELD_GET`/`OP_FIELD_PUT`, não as natives novas).
- Produces:
  - `DbAppend()` — grava um registro em branco de verdade no SQLite (`INSERT`) e posiciona nele. Antes: no-op, `RecCount()` não mudava.
  - `RecLock()`/`MsUnlock()` — `MsUnlock()` agora empurra o registro corrente pro banco via `UPDATE` (fecha o ciclo `DbAppend`/`RecLock` → `alias->campo := valor` → `MsUnlock`).
  - `FieldPos(cCampo As Character) As Numeric` — posição real (1-based) da coluna física. Antes: stub, sempre `0`.

- [ ] **Step 1: Escrever o teste (cenário completo: incluir, editar via `alias->campo`, confirmar persistência reabrindo)**

```advpl
// tests/workarea_test.prw — DbAppend/RecLock/FieldPut(via alias->campo)/
// MsUnlock agora persistem de verdade em SQLite (antes eram stubs sem
// efeito — achado confirmado durante o planejamento do GesCon, ver
// CHANGELOG). Usa TCSqlExec só pra preparar/conferir a tabela de teste,
// não pra exercitar o que este fixture testa.
User Function WorkareaTest()
    TCSqlExec("CREATE TABLE IF NOT EXISTS WA_TEST (R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT, D_E_L_E_T_ TEXT DEFAULT ' ', R_E_C_D_E_L_ INTEGER DEFAULT 0, WA_CODIGO TEXT, WA_VALOR REAL)")
    TCSqlExec("DELETE FROM WA_TEST")

    DbSelectArea("WA_TEST")
    DbAppend()
    RecLock()
    WA_TEST->WA_CODIGO := "X1"
    WA_TEST->WA_VALOR := 42
    MsUnlock()

    Local aConfere := TCSqlQuery("SELECT WA_CODIGO, WA_VALOR FROM WA_TEST")
    ConOut("qtd=" + Str(Len(aConfere)))
    ConOut("codigo=" + aConfere[1]:WA_CODIGO)
    ConOut("valor=" + aConfere[1]:WA_VALOR)

    Local nPos := FieldPos("WA_CODIGO")
    ConOut("fieldpos=" + Str(nPos))
Return
```

- [ ] **Step 2: Rodar e confirmar que falha (ou dá resultado errado)**

Run: `cd /home/peder/Projetos/AdvPP && go build -o advplc ./cmd/advplc && ./advplc run tests/workarea_test.prw`
Expected: `qtd=0` (DbAppend não gravou nada) e/ou `fieldpos=0` — evidência de que a API clássica não persiste

- [ ] **Step 3: Adicionar rastreamento de colunas físicas + `loadColumns` em `pkg/db/sqlite.go`**

No topo do arquivo, adicione o tipo e ajuste o struct:

```go
type columnInfo struct {
	name    string
	sqlType string
}

type SQLiteEngine struct {
	db      *sql.DB
	alias   string
	columns []columnInfo
	records []map[string]advplrt.Value
	current int
}
```

Adicione o método `loadColumns` (usado por `SelectArea`, `Append`, `MsUnlock`, `FieldPos`):

```go
// loadColumns lê a estrutura física da tabela (nome + tipo declarado de
// cada coluna, na ordem real) — base pra Append (valores em branco
// tipo-apropriados), MsUnlock (UPDATE coluna a coluna) e FieldPos.
func (e *SQLiteEngine) loadColumns() error {
	rows, err := e.db.Query(fmt.Sprintf("PRAGMA table_info(%s)", e.alias))
	if err != nil {
		return err
	}
	defer rows.Close()

	e.columns = nil
	for rows.Next() {
		var cid, notnull, pk int
		var name, ctype string
		var dflt interface{}
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dflt, &pk); err != nil {
			return err
		}
		e.columns = append(e.columns, columnInfo{name: strings.ToUpper(name), sqlType: strings.ToUpper(ctype)})
	}
	return rows.Err()
}
```

- [ ] **Step 4: Chamar `loadColumns` em `SelectArea`, implementar `Append`, `FieldPos`, reescrever `MsUnlock`**

Em `SelectArea`, logo depois de `e.alias = strings.ToUpper(alias)`, adicione:

```go
	if err := e.loadColumns(); err != nil {
		return err
	}
```

Substitua o corpo de `MsUnlock` (hoje um comentário sem efeito) por:

```go
// MsUnlock grava o registro corrente no banco via UPDATE — fecha o ciclo
// DbAppend/RecLock -> FieldPut (via alias->campo) -> MsUnlock. Antes desta
// correção, era um no-op: toda mutação via FieldPut ficava só em memória e
// se perdia ao fechar o processo.
func (e *SQLiteEngine) MsUnlock() error {
	if e.current < 0 || e.current >= len(e.records) {
		return nil
	}
	record := e.records[e.current]
	recno, ok := record["R_E_C_N_O_"]
	if !ok {
		return fmt.Errorf("MsUnlock: registro sem R_E_C_N_O_")
	}

	var setClauses []string
	var vals []any
	for _, c := range e.columns {
		if c.name == "R_E_C_N_O_" {
			continue
		}
		setClauses = append(setClauses, c.name+" = ?")
		vals = append(vals, valueToSQL(record[c.name]))
	}
	vals = append(vals, valueToSQL(recno))

	query := fmt.Sprintf("UPDATE %s SET %s WHERE R_E_C_N_O_ = ?", e.alias, strings.Join(setClauses, ", "))
	_, err := e.db.Exec(query, vals...)
	return err
}

// valueToSQL converte um advplrt.Value de volta pro tipo Go que o driver
// SQL espera — inverso de convertDBValue.
func valueToSQL(v advplrt.Value) any {
	if v == nil {
		return nil
	}
	switch v.Type() {
	case "N":
		return v.(*advplrt.NumberValue).Val
	case "C", "M":
		return v.(*advplrt.StringValue).Val
	case "L":
		if v.(*advplrt.BoolValue).Val {
			return 1
		}
		return 0
	default:
		return v.String()
	}
}

// Append insere um registro em branco de verdade (valores tipo-apropriados
// pela coluna: numérico 0, texto "") e posiciona nele — DbAppend() no
// AdvPL. Antes desta correção era um no-op: RecCount() não mudava.
func (e *SQLiteEngine) Append() error {
	if e.alias == "" || len(e.columns) == 0 {
		return fmt.Errorf("DbAppend: nenhuma área selecionada")
	}

	var cols []string
	var placeholders []string
	var vals []any
	blank := make(map[string]advplrt.Value)
	for _, c := range e.columns {
		if c.name == "R_E_C_N_O_" {
			continue
		}
		var v any
		switch {
		case c.name == "D_E_L_E_T_":
			v = " "
			blank[c.name] = advplrt.NewString(" ")
		case c.name == "R_E_C_D_E_L_":
			v = 0
			blank[c.name] = advplrt.NewNumber(0)
		case strings.Contains(c.sqlType, "INT") || strings.Contains(c.sqlType, "REAL") || strings.Contains(c.sqlType, "NUM"):
			v = 0
			blank[c.name] = advplrt.NewNumber(0)
		default:
			v = ""
			blank[c.name] = advplrt.NewString("")
		}
		cols = append(cols, c.name)
		placeholders = append(placeholders, "?")
		vals = append(vals, v)
	}

	query := fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s)", e.alias, strings.Join(cols, ","), strings.Join(placeholders, ","))
	res, err := e.db.Exec(query, vals...)
	if err != nil {
		return err
	}
	newRecno, err := res.LastInsertId()
	if err != nil {
		return err
	}
	blank["R_E_C_N_O_"] = advplrt.NewNumber(float64(newRecno))
	e.records = append(e.records, blank)
	e.current = len(e.records) - 1
	return nil
}

// FieldPos devolve a posição 1-based da coluna física — 0 se não existir.
// Antes desta correção era um stub, sempre devolvia 0.
func (e *SQLiteEngine) FieldPos(field string) int {
	field = strings.ToUpper(field)
	for i, c := range e.columns {
		if c.name == field {
			return i + 1
		}
	}
	return 0
}
```

- [ ] **Step 5: Adicionar `Append`/`FieldPos` à interface `DBEngine` em `pkg/vm/vm.go`**

Localize `type DBEngine interface` e adicione as duas linhas (mantendo o resto igual):

```go
type DBEngine interface {
	SelectArea(alias string) error
	Seek(key string) (bool, error)
	Skip(count int) error
	GoTop() error
	GoBottom() error
	EOF() bool
	BOF() bool
	FieldGet(field string) (advplrt.Value, error)
	FieldPut(field string, val advplrt.Value) error
	RecLock() error
	MsUnlock() error
	RecCount() int
	RecNo() int
	Append() error
	FieldPos(field string) int
}
```

- [ ] **Step 6: Ligar `DBAPPEND` e `FIELDPOS` às novas natives em `pkg/vm/natives.go`**

Substitua o corpo de `"DBAPPEND"` (hoje `return advplrt.Nil, nil`):

```go
		"DBAPPEND": func(args []advplrt.Value) (advplrt.Value, error) {
			if v.dbEngine != nil {
				return advplrt.Nil, v.dbEngine.Append()
			}
			return advplrt.Nil, nil
		},
```

Substitua o corpo de `"FIELDPOS"` (hoje `return advplrt.NewNumber(0), nil`):

```go
		"FIELDPOS": func(args []advplrt.Value) (advplrt.Value, error) {
			if v.dbEngine != nil {
				name := advplrt.ToString(getArg(args, 0))
				return advplrt.NewNumber(float64(v.dbEngine.FieldPos(name))), nil
			}
			return advplrt.NewNumber(0), nil
		},
```

- [ ] **Step 7: Rodar o fixture de novo e confirmar que passa**

Run: `cd /home/peder/Projetos/AdvPP && go build -o advplc ./cmd/advplc && ./advplc run tests/workarea_test.prw`
Expected:
```
qtd=1
codigo=X1
valor=42
fieldpos=1
```

- [ ] **Step 8: Escrever o teste Go de regressão**

Crie `cmd/advplc/workarea_test.go` (mesmo padrão de `cmd/advplc/tcsql_test.go`):

```go
package main

import (
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// TestWorkareaFixture roda tests/workarea_test.prw — exercita a API
// clássica de work-area (DbAppend/RecLock/FieldPut/MsUnlock) com
// persistência real. Ver CHANGELOG.
func TestWorkareaFixture(t *testing.T) {
	if testing.Short() {
		t.Skip("builda o binário; pulado com -short")
	}

	repoRoot, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("filepath.Abs: %v", err)
	}
	binName := "advplc"
	if runtime.GOOS == "windows" {
		binName += ".exe"
	}
	binPath := filepath.Join(t.TempDir(), binName)
	build := exec.Command("go", "build", "-o", binPath, "./cmd/advplc")
	build.Dir = repoRoot
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}

	run := exec.Command(binPath, "run", "tests/workarea_test.prw")
	run.Dir = repoRoot
	out, err := run.CombinedOutput()
	if err != nil {
		t.Fatalf("advplc run tests/workarea_test.prw falhou: %v\n%s", err, out)
	}
	want := []string{"qtd=1", "codigo=X1", "valor=42", "fieldpos=1"}
	got := string(out)
	for _, w := range want {
		if !strings.Contains(got, w) {
			t.Errorf("saída não contém %q; saída completa:\n%s", w, got)
		}
	}
}
```

Run: `cd /home/peder/Projetos/AdvPP && go test ./cmd/advplc/... -run TestWorkareaFixture -v`
Expected: `--- PASS: TestWorkareaFixture`

- [ ] **Step 9: Rodar a suíte completa (zero regressão)**

Run: `cd /home/peder/Projetos/AdvPP && go build ./... && go vet ./... && go test ./...`
Expected: todos os pacotes `ok`, nenhum `FAIL`

- [ ] **Step 10: Documentar no CHANGELOG e commitar**

Em `CHANGELOG.md`, adicione no topo de `## [Não lançado]`:

```markdown
### `DbAppend`/`RecLock`/`FieldPut`/`MsUnlock` — persistência real

A API clássica de work-area do AdvPP era stub: `DbAppend()` não criava
registro nenhum (`RecCount()` não mudava), `FieldPut` (via `alias->campo :=
valor`) só mutava memória, `MsUnlock()` não gravava nada, `FieldPos` sempre
devolvia `0`. Corrigido: `DbAppend()` insere um registro real (`INSERT`,
valores em branco tipo-apropriados por coluna), `MsUnlock()` grava o
registro corrente via `UPDATE`, `FieldPos` resolve a posição física real.
Achado confirmado por teste direto durante o planejamento do GesCon.
```

Run:
```bash
cd /home/peder/Projetos/AdvPP
git add pkg/db/sqlite.go pkg/vm/vm.go pkg/vm/natives.go tests/workarea_test.prw cmd/advplc/workarea_test.go CHANGELOG.md
git commit -m "db: persistência real em DbAppend/RecLock/FieldPut/MsUnlock"
```

### Task 3: Classe `TMailMessage` (envio de e-mail via `net/smtp`)

**Files:**
- Create: `pkg/vm/mail_native.go`
- Modify: `pkg/compiler/codegen.go` (mapa de classes nativas)
- Modify: `pkg/vm/vm.go` (instanciação + dispatch de método)
- Test: `tests/mail_test.prw` (novo)
- Test: `cmd/advplc/mail_test.go` (novo)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nenhuma capacidade de outro task deste plano.
- Produces: classe `TMailMessage` — `New()`, `SetServer(cHost, cPorta)`, `SetAuth(cUser, cSenha)`, `SetFrom(cEmail)`, `AddTo(cEmail)`, `SetSubject(cAssunto)`, `SetBody(cCorpo)`, `Send() As Logical` (envia via SMTP real, `.T.`/erro).

**Nota sobre teste**: `Send()` real exige um servidor SMTP de verdade — o fixture testa o caminho de validação (erro claro quando `Send()` é chamado sem `SetServer`/`SetFrom`/`AddTo`), não um envio de rede de fato. Envio real fica pra verificação manual com um servidor SMTP disponível (não é possível automatizar sem credenciais externas).

- [ ] **Step 1: Escrever o teste**

```advpl
// tests/mail_test.prw — TMailMessage: caminho de validação (Send() sem
// configurar servidor/remetente/destinatário deve falhar com erro claro,
// não travar nem enviar nada). Envio real de rede não é testável aqui sem
// um servidor SMTP disponível — ver nota no plano de implementação.
User Function MailTest()
    Local oMail := TMailMessage():New()
    Local lErro := .F.

    Begin Sequence
        oMail:Send()
    Recover
        lErro := .T.
    End Sequence

    ConOut("erro_sem_config=" + cValToChar(lErro))

    oMail:SetServer("smtp.exemplo.invalido", "587")
    oMail:SetFrom("sindico@exemplo.invalido")
    oMail:AddTo("condomino@exemplo.invalido")
    oMail:SetSubject("Teste")
    oMail:SetBody("Corpo do teste")

    // Servidor não existe de verdade — Send() deve falhar (erro de rede),
    // não travar o processo nem devolver sucesso falso.
    Local lErro2 := .F.
    Begin Sequence
        oMail:Send()
    Recover
        lErro2 := .T.
    End Sequence
    ConOut("erro_servidor_invalido=" + cValToChar(lErro2))
Return
```

- [ ] **Step 2: Rodar e confirmar que falha (classe não existe)**

Run: `cd /home/peder/Projetos/AdvPP && go build -o advplc ./cmd/advplc && ./advplc run tests/mail_test.prw`
Expected: erro de classe/função desconhecida (`TMailMessage` ou `TMAILMESSAGE`)

- [ ] **Step 3: Implementar `pkg/vm/mail_native.go`**

```go
package vm

import (
	"fmt"
	"net/smtp"
	"strings"

	advplrt "github.com/advpl/compiler/pkg/runtime"
)

// mailState é o estado Go da classe TMailMessage: parâmetros da mensagem e
// do servidor SMTP, setados via métodos antes de Send() (mesmo estilo de
// configuração por método já usado em WSRestServer/MCPServer neste
// projeto, em vez de emular a API por-propriedade do TMailMessage real do
// Protheus). Envio via net/smtp da stdlib — sem CGO, sem dependência
// externa, mesmo padrão do resto do AdvPP.
type mailState struct {
	from    string
	to      []string
	subject string
	body    string
	server  string
	port    string
	user    string
	pass    string
}

func newTMailMessageObject() *advplrt.ObjectValue {
	obj := advplrt.NewObject("TMailMessage", nil)
	obj.Native = &mailState{port: "587"}
	return obj
}

// callTMailMessageMethod implementa a classe nativa TMailMessage: envio de
// e-mail real via SMTP (net/smtp, stdlib) — capacidade de compilador nova,
// motivada pela necessidade futura de mala direta do GesCon (o GesCon em
// si não consome esta classe ainda; fica disponível pro Plano 2).
func (v *VM) callTMailMessageMethod(obj *advplrt.ObjectValue, method string, args []advplrt.Value) error {
	st, ok := obj.Native.(*mailState)
	if !ok {
		return fmt.Errorf("TMailMessage: objeto sem estado interno")
	}

	switch method {
	case "NEW":
		v.push(obj)
	case "SETSERVER":
		st.server = advplrt.ToString(getArg(args, 0))
		if len(args) > 1 {
			st.port = advplrt.ToString(args[1])
		}
		v.push(advplrt.Nil)
	case "SETAUTH":
		st.user = advplrt.ToString(getArg(args, 0))
		st.pass = advplrt.ToString(getArg(args, 1))
		v.push(advplrt.Nil)
	case "SETFROM":
		st.from = advplrt.ToString(getArg(args, 0))
		v.push(advplrt.Nil)
	case "ADDTO":
		st.to = append(st.to, advplrt.ToString(getArg(args, 0)))
		v.push(advplrt.Nil)
	case "SETSUBJECT":
		st.subject = advplrt.ToString(getArg(args, 0))
		v.push(advplrt.Nil)
	case "SETBODY":
		st.body = advplrt.ToString(getArg(args, 0))
		v.push(advplrt.Nil)
	case "SEND":
		if st.server == "" {
			return fmt.Errorf("TMailMessage:Send: chame SetServer() primeiro")
		}
		if st.from == "" || len(st.to) == 0 {
			return fmt.Errorf("TMailMessage:Send: chame SetFrom() e AddTo() primeiro")
		}
		msg := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s\r\n",
			st.from, strings.Join(st.to, ", "), st.subject, st.body)
		var auth smtp.Auth
		if st.user != "" {
			auth = smtp.PlainAuth("", st.user, st.pass, st.server)
		}
		addr := st.server + ":" + st.port
		if err := smtp.SendMail(addr, auth, st.from, st.to, []byte(msg)); err != nil {
			v.push(advplrt.False)
			return err
		}
		v.push(advplrt.True)
	default:
		return fmt.Errorf("TMailMessage: método desconhecido %s", method)
	}
	return nil
}
```

- [ ] **Step 4: Registrar a classe (3 pontos de integração)**

Em `pkg/compiler/codegen.go`, ache o mapa de classes nativas (contém `"MCPSERVER": true,` e `"WSRESTSERVER": true,`) e adicione:

```go
	"TMAILMESSAGE": true,
```

Em `pkg/vm/vm.go`, na função de instanciação (switch que contém `case "MCPSERVER": v.push(newMCPServerObject()); return nil`), adicione:

```go
		case "TMAILMESSAGE":
			v.push(newTMailMessageObject())
			return nil
```

Na função `callNativeMethod` (switch em `obj.ClassName`, contém `case "MCPServer": return v.callMCPServerMethod(...)`), adicione:

```go
	case "TMailMessage":
		return v.callTMailMessageMethod(obj, upperMethod, args)
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `cd /home/peder/Projetos/AdvPP && go build -o advplc ./cmd/advplc && ./advplc run tests/mail_test.prw`
Expected:
```
erro_sem_config=.T.
erro_servidor_invalido=.T.
```

- [ ] **Step 6: Escrever o teste Go de regressão**

Crie `cmd/advplc/mail_test.go` (mesmo padrão dos anteriores):

```go
package main

import (
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// TestMailFixture roda tests/mail_test.prw — exercita a classe
// TMailMessage no caminho de validação (Send() sem config falha com erro
// claro; envio de rede real não é testável sem servidor SMTP). Ver
// CHANGELOG.
func TestMailFixture(t *testing.T) {
	if testing.Short() {
		t.Skip("builda o binário; pulado com -short")
	}

	repoRoot, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("filepath.Abs: %v", err)
	}
	binName := "advplc"
	if runtime.GOOS == "windows" {
		binName += ".exe"
	}
	binPath := filepath.Join(t.TempDir(), binName)
	build := exec.Command("go", "build", "-o", binPath, "./cmd/advplc")
	build.Dir = repoRoot
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}

	run := exec.Command(binPath, "run", "tests/mail_test.prw")
	run.Dir = repoRoot
	out, err := run.CombinedOutput()
	if err != nil {
		t.Fatalf("advplc run tests/mail_test.prw falhou: %v\n%s", err, out)
	}
	want := []string{"erro_sem_config=.T.", "erro_servidor_invalido=.T."}
	got := string(out)
	for _, w := range want {
		if !strings.Contains(got, w) {
			t.Errorf("saída não contém %q; saída completa:\n%s", w, got)
		}
	}
}
```

Run: `cd /home/peder/Projetos/AdvPP && go test ./cmd/advplc/... -run TestMailFixture -v`
Expected: `--- PASS: TestMailFixture`

- [ ] **Step 7: Rodar a suíte completa (zero regressão)**

Run: `cd /home/peder/Projetos/AdvPP && go build ./... && go vet ./... && go test ./...`
Expected: todos os pacotes `ok`, nenhum `FAIL`

- [ ] **Step 8: Documentar no CHANGELOG e commitar**

Em `CHANGELOG.md`, adicione no topo de `## [Não lançado]`:

```markdown
### Classe `TMailMessage` — envio de e-mail real (`net/smtp`)

Nova capacidade de compilador: `TMailMessage():New()` + `SetServer`/
`SetAuth`/`SetFrom`/`AddTo`/`SetSubject`/`SetBody`/`Send()` envia e-mail via
SMTP real (stdlib `net/smtp`, sem CGO, sem dependência externa). Motivada
pela necessidade futura de mala direta do GesCon — capacidade adicionada
ao compilador antes do consumidor de verdade (decisão consciente do
usuário, adiantando um item que já estava no roadmap).
```

Run:
```bash
cd /home/peder/Projetos/AdvPP
git add pkg/vm/mail_native.go pkg/compiler/codegen.go pkg/vm/vm.go tests/mail_test.prw cmd/advplc/mail_test.go CHANGELOG.md
git commit -m "vm: classe TMailMessage — envio de e-mail real via net/smtp"
```

### Task 4: Publicar release v1.22.0 e apontar o GesCon pra ela

**Files:**
- Modify: `CHANGELOG.md` (corte de versão, mesmo padrão das releases anteriores)

**Interfaces:**
- Consumes: commits dos Tasks 1-3, já testados e limpos.
- Produces: binário `advplc` v1.22.0 instalado em `~/.local/bin` (ou onde o GesCon vai rodar), com `TCSqlExec`/`TCSqlQuery`, persistência real de work-area, e `TMailMessage` disponíveis.

- [ ] **Step 1: Cortar a versão no CHANGELOG**

Em `CHANGELOG.md`, adicione logo abaixo de `## [Não lançado]`:

```markdown
## [1.22.0] — 2026-07-24

`TCSqlExec`/`TCSqlQuery`, persistência real de `DbAppend`/`RecLock`/
`FieldPut`/`MsUnlock`, e classe `TMailMessage` — todas motivadas por uso
real (GesCon).
```

Run:
```bash
cd /home/peder/Projetos/AdvPP
git add CHANGELOG.md
git commit -m "release: cut v1.22.0 (TCSql, persistência real, TMailMessage)"
git push origin master
```

- [ ] **Step 2: Publicar a tag**

Run: `cd /home/peder/Projetos/AdvPP && make release VERSION=1.22.0`
Expected: tag `v1.22.0` criada e empurrada, link do GitHub Actions impresso

- [ ] **Step 3: Instalar a versão nova localmente pro GesCon usar**

Run: `cd /home/peder/Projetos/AdvPP && go build -o ~/.local/bin/advplc ./cmd/advplc && ~/.local/bin/advplc version`
Expected: `advplc v1.22.0` (ou a versão local buildada, mesmo se a release do GitHub Actions ainda estiver rodando — o binário local já tem as natives)

---

## Parte B — GesCon: schema e camada de acesso

### Task 5: Schema SQL (DDL + metadados SX3 pros títulos de coluna)

**Files:**
- Create: `~/Projetos/GesCon/schema.sql`
- Create: `~/Projetos/GesCon/scripts/bootstrap-db.sh`

**Interfaces:**
- Produces: tabelas `UNI`, `CON`, `DES`, `COB`, `USR` em `~/.advpp/ADVPP.db`, mais linhas em `SX3` (tabela de metadados já usada pelo `FWMBrowse`, ver `pkg/vm/browse.go`) pros títulos/tipos de coluna aparecerem certos na UI web.

- [ ] **Step 1: Escrever `schema.sql`**

```sql
-- GesCon — schema v1. Convenção de exclusão lógica estilo Protheus
-- (R_E_C_N_O_/D_E_L_E_T_/R_E_C_D_E_L_), mesma que o AdvEditor usa.

CREATE TABLE IF NOT EXISTS CON (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    CON_CODIGO TEXT NOT NULL,
    CON_NOME TEXT NOT NULL,
    CON_CPF TEXT,
    CON_EMAIL TEXT,
    CON_TEL TEXT
);

CREATE TABLE IF NOT EXISTS UNI (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    UNI_CODIGO TEXT NOT NULL,
    UNI_BLOCO TEXT,
    UNI_FRACAO REAL NOT NULL DEFAULT 0,
    UNI_CONDOMINO TEXT
);

CREATE TABLE IF NOT EXISTS DES (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    DES_DESCR TEXT NOT NULL,
    DES_CATEG TEXT,
    DES_VALOR REAL NOT NULL DEFAULT 0,
    DES_COMPET TEXT NOT NULL,
    DES_DTLANC TEXT
);

CREATE TABLE IF NOT EXISTS COB (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    COB_UNIDADE TEXT NOT NULL,
    COB_COMPET TEXT NOT NULL,
    COB_VALOR REAL NOT NULL DEFAULT 0,
    COB_VENCTO TEXT,
    COB_STATUS TEXT NOT NULL DEFAULT 'pendente',
    COB_DTPAG TEXT
);

CREATE TABLE IF NOT EXISTS USR (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    USR_LOGIN TEXT NOT NULL,
    USR_SENHA TEXT NOT NULL
);

-- Metadados SX3 (títulos/tipos de coluna pro FWMBrowse — ver browseColumns
-- em pkg/vm/browse.go do AdvPP: sem essas linhas, o browse cai no fallback
-- de mostrar toda coluna física como texto, sem título amigável).
DELETE FROM SX3 WHERE X3_ARQUIVO IN ('CON','UNI','DES','COB','USR');

INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('CON', 1, 'CON_CODIGO', 'C', 10, 0, 'Código'),
('CON', 2, 'CON_NOME',   'C', 60, 0, 'Nome'),
('CON', 3, 'CON_CPF',    'C', 14, 0, 'CPF'),
('CON', 4, 'CON_EMAIL',  'C', 60, 0, 'E-mail'),
('CON', 5, 'CON_TEL',    'C', 20, 0, 'Telefone'),

('UNI', 1, 'UNI_CODIGO',    'C', 10, 0, 'Unidade'),
('UNI', 2, 'UNI_BLOCO',     'C', 10, 0, 'Bloco'),
('UNI', 3, 'UNI_FRACAO',    'N', 8,  4, 'Fração Ideal'),
('UNI', 4, 'UNI_CONDOMINO', 'C', 10, 0, 'Cód. Condômino'),

('DES', 1, 'DES_DESCR',   'C', 80, 0, 'Descrição'),
('DES', 2, 'DES_CATEG',   'C', 30, 0, 'Categoria'),
('DES', 3, 'DES_VALOR',   'N', 14, 2, 'Valor'),
('DES', 4, 'DES_COMPET',  'C', 7,  0, 'Competência'),
('DES', 5, 'DES_DTLANC',  'C', 10, 0, 'Data Lançamento'),

('COB', 1, 'COB_UNIDADE', 'C', 10, 0, 'Unidade'),
('COB', 2, 'COB_COMPET',  'C', 7,  0, 'Competência'),
('COB', 3, 'COB_VALOR',   'N', 14, 2, 'Valor'),
('COB', 4, 'COB_VENCTO',  'C', 10, 0, 'Vencimento'),
('COB', 5, 'COB_STATUS',  'C', 10, 0, 'Status'),
('COB', 6, 'COB_DTPAG',   'C', 10, 0, 'Data Pagamento');
```

- [ ] **Step 2: Escrever o script de bootstrap**

```bash
#!/bin/sh
# Aplica schema.sql no banco compartilhado do AdvPP. Rodar uma vez antes do
# primeiro `advplc serve gescon.prw`, e de novo sempre que schema.sql mudar
# (usa CREATE TABLE IF NOT EXISTS — seguro rodar mais de uma vez).
set -e
DB="${ADVPP_DB:-$HOME/.advpp/ADVPP.db}"
sqlite3 "$DB" < "$(dirname "$0")/../schema.sql"
echo "Schema aplicado em $DB"
```

Run: `chmod +x ~/Projetos/GesCon/scripts/bootstrap-db.sh`

- [ ] **Step 3: Rodar o bootstrap e verificar**

Run: `~/Projetos/GesCon/scripts/bootstrap-db.sh && sqlite3 ~/.advpp/ADVPP.db ".tables"`
Expected: saída inclui `COB  CON  DES  SX3  UNI  USR` (entre outras tabelas pré-existentes)

- [ ] **Step 4: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add schema.sql scripts/bootstrap-db.sh
git commit -m "db: schema v1 (Unidade, Condomino, Despesa, Cobranca, Usuario) + metadados SX3"
```

### Task 6: Camada de acesso (`src/db.prw`)

**Files:**
- Create: `~/Projetos/GesCon/src/db.prw`
- Test: `~/Projetos/GesCon/tests/db_test.prw`

**Interfaces:**
- Consumes: `TCSqlExec`/`TCSqlQuery` (Task 1).
- Produces:
  - `GcSqlLit(cValor As Character) As Character` — escapa aspas simples pra literal SQL seguro.

- [ ] **Step 1: Escrever o teste**

```advpl
// tests/db_test.prw
#include "totvs.ch"
User Function DbTest()
    Local cEscapado := GcSqlLit("O'Brien")
    ConOut("escapado=[" + cEscapado + "]")
Return
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd /home/peder/Projetos/GesCon && advplc run tests/db_test.prw`
Expected: erro de função desconhecida (`GcSqlLit`)

- [ ] **Step 3: Implementar `src/db.prw`**

```advpl
// src/db.prw — camada de acesso SQL do GesCon. Toda query direta às
// tabelas UNI/CON/DES/COB/USR passa por aqui, nunca espalhada pelas telas.
#include "totvs.ch"

// GcSqlLit escapa aspas simples — todo valor de texto interpolado numa
// query via TCSqlExec/TCSqlQuery precisa passar por aqui (sem parâmetros
// bind na API atual, escapar é a única defesa contra literal quebrado).
User Function GcSqlLit(cValor)
    Local cRet := cValor
    If cRet == Nil
        cRet := ""
    EndIf
Return StrTran(cRet, "'", "''")
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd /home/peder/Projetos/GesCon && advplc run tests/db_test.prw`
Expected:
```
escapado=[O''Brien]
```

- [ ] **Step 5: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add src/db.prw tests/db_test.prw
git commit -m "db: camada de acesso (GcSqlLit)"
```

---

## Parte C — Cadastros (CRUD via FWMBrowse)

### Task 7: Cadastro de Condôminos

**Files:**
- Create: `~/Projetos/GesCon/src/condominos.prw`

**Interfaces:**
- Consumes: tabela `CON` (Task 5).
- Produces: `User Function GcCondominos()` — abre o browse; CRUD completo (Incluir/Alterar/Excluir) vem de graça do `FWMBrowse`, sem código adicional.

- [ ] **Step 1: Escrever `src/condominos.prw`**

```advpl
// src/condominos.prw — cadastro de condôminos. CRUD via FWMBrowse: a UI
// web (advplc serve) já dá Incluir/Alterar/Excluir sem código customizado
// (ver tests/mvc_browse_test.prw do AdvPP, mesmo padrão).
#include "totvs.ch"

User Function GcCondominos()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("CON")
    oBrowse:SetDescription("Condôminos")
    oBrowse:Activate()
Return
```

- [ ] **Step 2: Verificar que compila**

Run: `cd /home/peder/Projetos/GesCon && advplc check src/condominos.prw`
Expected: `OK: syntax check passed`

- [ ] **Step 3: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add src/condominos.prw
git commit -m "cadastro: condôminos (FWMBrowse sobre CON)"
```

### Task 8: Cadastro de Unidades

**Files:**
- Create: `~/Projetos/GesCon/src/unidades.prw`

**Interfaces:**
- Consumes: tabela `UNI` (Task 5).
- Produces: `User Function GcUnidades()`.

- [ ] **Step 1: Escrever `src/unidades.prw`**

```advpl
// src/unidades.prw — cadastro de unidades. UNI_CONDOMINO guarda o código
// do condômino responsável como texto livre, sem combo/lookup vinculado
// (decisão registrada na spec, seção "Decisões explícitas registradas").
#include "totvs.ch"

User Function GcUnidades()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("UNI")
    oBrowse:SetDescription("Unidades")
    oBrowse:Activate()
Return
```

- [ ] **Step 2: Verificar que compila**

Run: `cd /home/peder/Projetos/GesCon && advplc check src/unidades.prw`
Expected: `OK: syntax check passed`

- [ ] **Step 3: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add src/unidades.prw
git commit -m "cadastro: unidades (FWMBrowse sobre UNI)"
```

### Task 9: Lançamento de Despesas

**Files:**
- Create: `~/Projetos/GesCon/src/despesas.prw`

**Interfaces:**
- Consumes: tabela `DES` (Task 5).
- Produces: `User Function GcDespesas()`.

- [ ] **Step 1: Escrever `src/despesas.prw`**

```advpl
// src/despesas.prw — lançamento de despesas. Mesmo padrão de browse das
// telas anteriores; DES_VALOR <= 0 fica pra validação no Fechamento
// Mensal (Task 10), não bloqueado aqui — FWMBrowse não expõe validação de
// campo customizada na v1 desta integração.
#include "totvs.ch"

User Function GcDespesas()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("DES")
    oBrowse:SetDescription("Despesas")
    oBrowse:Activate()
Return
```

- [ ] **Step 2: Verificar que compila**

Run: `cd /home/peder/Projetos/GesCon && advplc check src/despesas.prw`
Expected: `OK: syntax check passed`

- [ ] **Step 3: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add src/despesas.prw
git commit -m "cadastro: despesas (FWMBrowse sobre DES)"
```

---

## Parte D — Fechamento Mensal (o coração do sistema)

### Task 10: Fechamento Mensal

**Files:**
- Create: `~/Projetos/GesCon/src/fechamento.prw`
- Test: `~/Projetos/GesCon/tests/fechamento_test.prw`

**Interfaces:**
- Consumes: `TCSqlExec`/`TCSqlQuery` (Task 1), `GcSqlLit` (Task 6), tabelas `UNI`/`DES`/`COB`.
- Produces: `User Function GcFecharMes(cCompetencia As Character) As Logical` — `.T.` se fechou, `.F.` se já estava fechada (trava) ou não havia nada a fechar.

- [ ] **Step 1: Escrever o teste (cenário completo)**

```advpl
// tests/fechamento_test.prw
#include "totvs.ch"
User Function FechamentoTest()
    Local lOk

    // Isola a competência de teste pra não colidir com dados reais
    TCSqlExec("DELETE FROM UNI WHERE UNI_CODIGO IN ('T01','T02')")
    TCSqlExec("DELETE FROM DES WHERE DES_COMPET = '2099-01'")
    TCSqlExec("DELETE FROM COB WHERE COB_COMPET = '2099-01'")

    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO) VALUES ('T01', 0.6)")
    TCSqlExec("INSERT INTO UNI (UNI_CODIGO, UNI_FRACAO) VALUES ('T02', 0.4)")
    TCSqlExec("INSERT INTO DES (DES_DESCR, DES_VALOR, DES_COMPET) VALUES ('Teste', 1000, '2099-01')")

    lOk := GcFecharMes("2099-01")
    ConOut("fechou=" + cValToChar(lOk))

    Local aCob := TCSqlQuery("SELECT COB_UNIDADE, COB_VALOR, COB_STATUS FROM COB WHERE COB_COMPET = '2099-01' ORDER BY COB_UNIDADE")
    ConOut("qtd_cobrancas=" + Str(Len(aCob)))
    ConOut("t01_valor=" + aCob[1]:COB_VALOR)
    ConOut("t01_status=" + aCob[1]:COB_STATUS)
    ConOut("t02_valor=" + aCob[2]:COB_VALOR)

    // Fechar de novo deve ser bloqueado (trava contra duplicidade)
    Local lSegundaVez := GcFecharMes("2099-01")
    ConOut("segunda_vez=" + cValToChar(lSegundaVez))
Return
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd /home/peder/Projetos/GesCon && advplc run tests/fechamento_test.prw`
Expected: erro de função desconhecida (`GcFecharMes`)

- [ ] **Step 3: Implementar `src/fechamento.prw`**

```advpl
// src/fechamento.prw — fechamento mensal: soma as despesas da competência,
// rateia por fração ideal de cada unidade ativa, grava uma Cobrança por
// unidade. Trava contra fechar a mesma competência duas vezes (checa se já
// existe Cobrança pra essa competência antes de gerar) — ver decisão
// registrada na spec: valor travado no fechamento, nunca recalculado
// retroativamente.
#include "totvs.ch"

User Function GcFecharMes(cCompetencia)
    Local nTotalDespesas := 0
    Local aExistente := TCSqlQuery("SELECT COB_UNIDADE FROM COB WHERE COB_COMPET = '" + GcSqlLit(cCompetencia) + "'")
    If Len(aExistente) > 0
        ConOut("GcFecharMes: competência " + cCompetencia + " já foi fechada")
        Return .F.
    EndIf

    Local aDespesas := TCSqlQuery("SELECT COALESCE(SUM(DES_VALOR),0) AS TOTAL FROM DES WHERE DES_COMPET = '" + GcSqlLit(cCompetencia) + "' AND D_E_L_E_T_ = ' '")
    nTotalDespesas := Val(aDespesas[1]:TOTAL)

    Local aUnidades := TCSqlQuery("SELECT UNI_CODIGO, UNI_FRACAO FROM UNI WHERE D_E_L_E_T_ = ' '")
    If Len(aUnidades) == 0
        ConOut("GcFecharMes: nenhuma unidade cadastrada")
        Return .F.
    EndIf

    Local cVencimento := GcProximoVencimento(cCompetencia)
    Local i
    For i := 1 To Len(aUnidades)
        Local nValorUnidade := nTotalDespesas * Val(aUnidades[i]:UNI_FRACAO)
        TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS) VALUES ('" + ;
            GcSqlLit(aUnidades[i]:UNI_CODIGO) + "', '" + GcSqlLit(cCompetencia) + "', " + ;
            cValToChar(nValorUnidade) + ", '" + cVencimento + "', 'pendente')")
    Next
Return .T.

// GcProximoVencimento: dia 10 do mês seguinte à competência (formato
// "YYYY-MM" -> "YYYY-MM-DD" do mês seguinte). Dia fixo nesta v1 —
// configurável fica pra uma fase futura se necessário.
User Function GcProximoVencimento(cCompetencia)
    Local nAno := Val(Left(cCompetencia, 4))
    Local nMes := Val(SubStr(cCompetencia, 6, 2))
    nMes++
    If nMes > 12
        nMes := 1
        nAno++
    EndIf
Return StrZero(nAno, 4) + "-" + StrZero(nMes, 2) + "-10"
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd /home/peder/Projetos/GesCon && advplc run tests/fechamento_test.prw`
Expected:
```
fechou=.T.
qtd_cobrancas=2
t01_valor=600
t01_status=pendente
t02_valor=400
segunda_vez=.F.
```

- [ ] **Step 5: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add src/fechamento.prw tests/fechamento_test.prw
git commit -m "negocio: fechamento mensal (rateio por fração ideal, trava contra duplicidade)"
```

---

## Parte E — Cobranças e Pagamento

### Task 11: Tela de Cobranças + Registrar Pagamento

**Files:**
- Create: `~/Projetos/GesCon/src/cobrancas.prw`
- Test: `~/Projetos/GesCon/tests/pagamento_test.prw`

**Interfaces:**
- Consumes: `TCSqlExec`/`TCSqlQuery` (Task 1), `GcSqlLit` (Task 6), tabela `COB`.
- Produces:
  - `User Function GcCobrancas()` — browse (FWMBrowse sobre `COB`, leitura/consulta).
  - `User Function GcRegistrarPagamento(nRecno As Numeric, dData As Date) As Logical` — marca uma cobrança como paga.

- [ ] **Step 1: Escrever o teste**

```advpl
// tests/pagamento_test.prw
#include "totvs.ch"
User Function PagamentoTest()
    TCSqlExec("DELETE FROM COB WHERE COB_UNIDADE = 'PAGTEST'")
    TCSqlExec("INSERT INTO COB (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_STATUS) VALUES ('PAGTEST', '2099-02', 500, 'pendente')")

    Local aCob := TCSqlQuery("SELECT R_E_C_N_O_ FROM COB WHERE COB_UNIDADE = 'PAGTEST'")
    Local nRecno := Val(aCob[1]:R_E_C_N_O_)

    Local lOk := GcRegistrarPagamento(nRecno, CToD("15/02/2099"))
    ConOut("registrou=" + cValToChar(lOk))

    Local aConfere := TCSqlQuery("SELECT COB_STATUS, COB_DTPAG FROM COB WHERE R_E_C_N_O_ = " + Str(nRecno))
    ConOut("status=" + aConfere[1]:COB_STATUS)
    ConOut("dtpag=" + aConfere[1]:COB_DTPAG)
Return
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd /home/peder/Projetos/GesCon && advplc run tests/pagamento_test.prw`
Expected: erro de função desconhecida (`GcRegistrarPagamento`)

- [ ] **Step 3: Implementar `src/cobrancas.prw`**

```advpl
// src/cobrancas.prw — consulta de cobranças (browse read-mostly, edição de
// status feita só via GcRegistrarPagamento, nunca por edição livre de
// campo — mantém a garantia de "valor travado no fechamento" da spec).
#include "totvs.ch"

User Function GcCobrancas()
    Local oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("COB")
    oBrowse:SetDescription("Cobranças")
    oBrowse:Activate()
Return

// GcRegistrarPagamento marca uma cobrança (identificada por R_E_C_N_O_)
// como paga, com a data informada.
User Function GcRegistrarPagamento(nRecno, dData)
    Local cData := DToS(dData)
    Local cDataFmt := Left(cData, 4) + "-" + SubStr(cData, 5, 2) + "-" + SubStr(cData, 7, 2)
Return TCSqlExec("UPDATE COB SET COB_STATUS = 'pago', COB_DTPAG = '" + cDataFmt + "' WHERE R_E_C_N_O_ = " + Str(nRecno))
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd /home/peder/Projetos/GesCon && advplc run tests/pagamento_test.prw`
Expected:
```
registrou=.T.
status=pago
dtpag=2099-02-15
```

- [ ] **Step 5: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add src/cobrancas.prw tests/pagamento_test.prw
git commit -m "cobranca: tela de cobranças + registrar pagamento"
```

---

## Parte F — Ponto de entrada

### Task 12: `gescon.prw` (entrada + navegação)

**Files:**
- Create: `~/Projetos/GesCon/gescon.prw`

**Interfaces:**
- Consumes: `GcCondominos` (Task 7), `GcUnidades` (Task 8), `GcDespesas` (Task 9), `GcCobrancas` (Task 11).
- Produces: ponto de entrada rodável via `advplc serve gescon.prw`.

- [ ] **Step 1: Escrever `gescon.prw`**

```advpl
// gescon.prw — ponto de entrada do GesCon. `advplc serve gescon.prw` sobe
// a UI web; esta função abre o cadastro de Unidades como tela inicial
// (menu de navegação entre módulos fica pra Plano 2, junto com login).
#include "totvs.ch"

User Function GesCon()
    ConOut("GesCon — Sistema de Gestão Condominial")
    GcUnidades()
Return
```

- [ ] **Step 2: Verificar que compila**

Run: `cd /home/peder/Projetos/GesCon && advplc check gescon.prw`
Expected: `OK: syntax check passed`

- [ ] **Step 3: Testar manualmente via `advplc serve`**

Run: `cd /home/peder/Projetos/GesCon && advplc serve gescon.prw --port 8090`
Expected: servidor sobe, `http://localhost:8090` mostra o browse de Unidades. Confirme manualmente no navegador que Incluir/Alterar/Excluir funcionam. Encerre com Ctrl+C.

- [ ] **Step 4: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add gescon.prw
git commit -m "app: ponto de entrada (gescon.prw)"
```

### Task 13: README do projeto

**Files:**
- Create: `~/Projetos/GesCon/README.md`

- [ ] **Step 1: Escrever o README**

```markdown
# GesCon — Sistema de Gestão Condominial

Sistema de gestão condominial em AdvPL/TLPP, rodando sobre o
[AdvPP](https://github.com/peder1981/AdvPP) (compilador/VM open-source).
Serve dois propósitos: uso real de administração de condomínio, e case de
validação de robustez do compilador.

Ver design completo em
`docs/superpowers/specs/2026-07-24-gescon-design.md`.

## Requisitos

- `advplc` v1.22.0+ (natives `TCSqlExec`/`TCSqlQuery`, persistência real de
  work-area, classe `TMailMessage`)
- `sqlite3` (CLI, só para o bootstrap do schema)

## Rodando

\`\`\`bash
./scripts/bootstrap-db.sh   # cria as tabelas (uma vez, ou após mudar schema.sql)
advplc serve gescon.prw     # sobe em http://localhost:8080
\`\`\`

## Testes

\`\`\`bash
advplc run tests/db_test.prw
advplc run tests/fechamento_test.prw
advplc run tests/pagamento_test.prw
\`\`\`

## Escopo desta fase (Plano 1 de 2)

Cadastros (Unidades, Condôminos, Despesas), Fechamento Mensal (rateio por
fração ideal), Cobranças + Registrar Pagamento. **Relatórios, mala direta e
login ficam pro Plano 2** — ver spec para o escopo completo. `TMailMessage`
(envio real de e-mail) já existe no compilador desde este plano, mas nenhuma
tela do GesCon a consome ainda.
```

- [ ] **Step 2: Commitar**

```bash
cd /home/peder/Projetos/GesCon
git add README.md
git commit -m "docs: README inicial"
```

---

## Nota de escopo

Este plano cobre o **motor financeiro núcleo** — a fatia que já produz um
sistema funcional e testável de ponta a ponta (cadastro → despesa →
fechamento → cobrança → pagamento) — mais três capacidades novas no
compilador AdvPP (`TCSqlExec`/`TCSqlQuery`, persistência real de work-area,
`TMailMessage`) motivadas por essa necessidade. **Relatórios (balancete,
inadimplência, extrato por unidade, despesas por categoria), mala direta
(agora com `TMailMessage` disponível pra envio real) e login** ficam para
um Plano 2 separado, depois que este estiver implementado e validado —
evita um plano único grande demais pra revisar com qualidade de uma vez, e
cada plano entrega software funcionando por si só (ver critério de
decomposição do `writing-plans`).
