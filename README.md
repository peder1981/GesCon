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
advplc run tests/malas_test.prw
```

## Mala direta (envio real de e-mail)

`GcMalaDireta(cCompetencia)` envia uma mensagem personalizada por
condômino com cobrança não paga na competência. Configuração via
variáveis de ambiente — **não** `GetMV()`, que é um stub no AdvPP (sempre
retorna o valor padrão, nunca lê configuração real):

```bash
export GESCON_SMTP_HOST=smtp.exemplo.com
export GESCON_SMTP_PORT=587       # opcional, default 587
export GESCON_SMTP_USER=usuario   # opcional, sem auth se vazio
export GESCON_SMTP_PASS=senha
export GESCON_SMTP_FROM=gescon@seucondominio.com
```

Sem `GESCON_SMTP_HOST`, `GcMalaDireta` não tenta enviar nada e retorna 0
(comportamento seguro por padrão).

## Escopo desta fase (Plano 1 de 2)

Cadastros (Unidades, Condôminos, Despesas), Fechamento Mensal (rateio por
fração ideal), Cobranças + Registrar Pagamento, Mala Direta (envio real).
**Relatórios (balancete, inadimplência, extrato por unidade, despesas por
categoria) e login ficam pro Plano 2** — ver spec para o escopo completo.

## Limitação conhecida

A tela de Cobranças permite editar/excluir registros livremente pela UI
(mesmo `FWMBrowse` editável dos demais cadastros) — a garantia de "valor
travado no fechamento" é imposta pela lógica de negócio, não pela UI.
Aceitável para a v1 (login único, uso pessoal/piloto). Ver spec, seção
"Decisões explícitas registradas".
