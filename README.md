# GesCon — Sistema de Gestão Condominial

Sistema de gestão condominial em AdvPL/TLPP, rodando sobre o
[AdvPP](https://github.com/peder1981/AdvPP) (compilador/VM open-source
para AdvPL/TLPP, escrito em Go). Serve dois propósitos: uso real de
administração de condomínio, e case de validação de robustez do
compilador — o desenvolvimento deste projeto encontrou e corrigiu 5
bugs reais do AdvPP (ver [`ARQUITETURA.md`](docs/ARQUITETURA.md)).

Cadastro de unidades e condôminos, lançamento de despesas, Fechamento
Mensal com rateio por fração ideal, Cobrança e Registro de Pagamento, e
Mala Direta com envio real de e-mail.

- **[Documentação funcional](docs/FUNCIONAL.md)** — o que o sistema faz,
  telas, regras de negócio, limitações conhecidas.
- **[Documentação técnica](docs/ARQUITETURA.md)** — stack, estrutura de
  arquivos, modelo de dados, decisões de implementação.
- **[Histórico de design](docs/superpowers/)** — spec, plano de
  implementação e ledger de execução (processo completo, não só o
  resultado).

## Requisitos

- [`advplc`](https://github.com/peder1981/AdvPP) **v1.22.1+** — versões
  anteriores têm um bug real de ponto de entrada que impede rodar
  qualquer projeto AdvPL multi-arquivo como o GesCon (corrigido na
  v1.22.1, achado durante este projeto).
- `sqlite3` (CLI, só para o bootstrap do schema).

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
categoria) e login ficam pro Plano 2** — ver
[`docs/FUNCIONAL.md`](docs/FUNCIONAL.md) para o escopo completo.

## Limitação conhecida

A tela de Cobranças permite editar/excluir registros livremente pela UI
(mesmo `FWMBrowse` editável dos demais cadastros) — a garantia de "valor
travado no fechamento" é imposta pela lógica de negócio, não pela UI.
Aceitável para a v1 (login único, uso pessoal/piloto). Ver
[`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) para o motivo técnico.
