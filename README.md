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

```bash
./scripts/bootstrap-db.sh   # cria as tabelas (uma vez, ou após mudar schema.sql)
advplc serve gescon.prw     # sobe em http://localhost:8080
```

## Testes

```bash
advplc run tests/db_test.prw
advplc run tests/fechamento_test.prw
advplc run tests/pagamento_test.prw
```

## Escopo desta fase (Plano 1 de 2)

Cadastros (Unidades, Condôminos, Despesas), Fechamento Mensal (rateio por
fração ideal), Cobranças + Registrar Pagamento. **Relatórios, mala direta e
login ficam pro Plano 2** — ver spec para o escopo completo. `TMailMessage`
(envio real de e-mail) já existe no compilador desde este plano, mas nenhuma
tela do GesCon a consome ainda.
