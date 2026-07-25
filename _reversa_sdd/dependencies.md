# Dependências — GesCon

## Dependências de runtime

| Dependência | Versão | Tipo | Propósito | Obs. |
|-------------|--------|------|----------|------|
| **advplc** (AdvPP) | v1.23.1+ | CLI/Runtime | Compilador e VM para AdvPL/TLPP | Requerimento crítico. v1.24.0+ recomendado (FWGetText com bIsPassword) |
| **sqlite3** | 3.x+ | CLI | Bootstrap do schema (one-time) | Necessário só pra rodar `bootstrap-db.sh`. Em runtime, acesso via AdvPP apenas. |

## Dependências de build (desktop)

| Dependência | Versão | Tipo | Propósito | Obs. |
|-------------|--------|------|----------|------|
| **ADVPP_SRC** | (git checkout) | Fonte | Compilador AdvPP local | Exigido por `advplc build` pra linkage de Fyne. Variável de ambiente `ADVPP_SRC=/caminho/pro/checkout` |

## Dependências internas (AdvPP stdlib)

Todas estas são parte do AdvPP e não requerem instalação separada:

| Módulo | Versão | Propósito | Usado por |
|--------|--------|----------|-----------|
| **TCSqlExec/TCSqlQuery** | nativa AdvPP | Execução de SQL compilado e segurontra SQL injection | db.prw, todos os módulos |
| **TMailMessage** | nativa AdvPP (Go net/smtp) | Envio SMTP | malas.prw (GcMalaDireta) |
| **FWMBrowse** | nativa AdvPP | Framework MVC para telas tabulares | Todos os cadastros (condominos, unidades, despesas, cobranças, usuários, relatórios) |
| **FWMenuSelect** | nativa AdvPP (v1.23.0+) | Menu de navegação entre telas | gescon.prw (navegação principal) |
| **FWGetText** | nativa AdvPP (v1.23.0+, v1.24.0 com `bIsPassword`) | Entrada de texto (senha mascarada em v1.24.0+) | login.prw (GcAutenticar, GcTrocarSenha) |
| **FWHash** | nativa AdvPP (v1.23.5+) | Hash SHA-256 | login.prw (GcCriarAdmin — senha hashed) |
| **Logger/console** | nativa AdvPP | Logging de erros | Geral (testes, debug) |

## Dependências externas configuráveis (runtime)

| Variável | Tipo | Obrigatória | Default | Propósito |
|----------|------|-------------|---------|-----------|
| `GESCON_SMTP_HOST` | string | ✗ | vazio | Host SMTP para mala direta |
| `GESCON_SMTP_PORT` | int | ✗ | 587 | Porta SMTP |
| `GESCON_SMTP_USER` | string | ✗ | vazio | Usuário SMTP (opcional se sem auth) |
| `GESCON_SMTP_PASS` | string | ✗ | vazio | Senha SMTP |
| `GESCON_SMTP_FROM` | string | ✗ | vazio | Remetente e-mail |

**Comportamento seguro**: Se `GESCON_SMTP_HOST` não estiver definido, `GcMalaDireta()` não tenta enviar nada (retorna 0).

## Dependências do banco de dados

| Tabela/Schema | Provisionado por | Status |
|---------------|-----------------|--------|
| 11 tabelas + SX3 (metadados) | `schema.sql` | Aplicado via `bootstrap-db.sh` |
| Arquivo `.db` | AdvPP (localização: `~/.advpp/ADVPP.db`) | Criado automaticamente |

## Histórico de contribuições GesCon → AdvPP

GesCon descobriu e motivou melhorias no AdvPP:

### Bug fixes (5)
1. **Persistência de work-area** — corrigido em v1.22.1
2. **`Recover` sem variável nomeada** — corrigido em v1.22.1
3. **Ponto de entrada com `#include`** — corrigido em v1.22.1 (bloqueava multi-arquivo)
4. **Comparação com `Nil` derrubando a VM** — corrigido
5. **Diálogos não bloqueantes no desktop** — corrigido em v1.23.1

### Capacidades novas (4)
1. **TCSqlExec/TCSqlQuery** — execução SQL compilada (v1.23.0+)
2. **TMailMessage** — classe SMTP nativa (v1.23.0+)
3. **FWMenuSelect/FWGetText** — menu de navegação e entrada de texto (v1.23.0+)
4. **FWHash** — hash SHA-256 (v1.23.5+)

Estas capacidades não existem em Protheus real — são motivadas por GesCon.

## Observações para publicação

- ✓ Sem dependências externas (Python, Node, Go toolchain) em runtime
- ✓ AdvPP é open-source (github.com/peder1981/AdvPP) — distribuível junto se necessário
- ✓ SQLite é embarcado (nenhuma instalação necessária no alvo)
- ✓ Configuração de SMTP é env-based (seguro, sem secrets em arquivo)
- ⚠ Requisito: usuário final deve ter `advplc` instalado (CLI) se quiser rodar em modo dev (web/desktop via `advplc serve`/`build`)
- ✓ Executáveis pré-compilados (GesConApp-linux, GesConApp-win.exe) incluem o bytecode e stdlib, nada mais necessário

## Checklist pré-publicação

- [x] Versão mínima AdvPP documentada (v1.23.1)
- [x] Schema versionado (v1) e testado
- [x] Dependências internas cobertas (TCSqlExec, TMailMessage, FWMBrowse, FWHash)
- [x] Configuração SMTP env-based (segura)
- [x] Executáveis multi-plataforma (linux, windows)
- [x] Testes unitários (+9 suítes)
- [x] Documentação (README, ARQUITETURA, FUNCIONAL)
