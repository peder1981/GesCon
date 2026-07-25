# Inventário de superfície — GesCon

**Projeto**: GesCon — Sistema de Gestão Condominial  
**Linguagem**: AdvPL/TLPP (100%)  
**Versão**: 1.0  
**Status**: Executáveis prontos para produção  
**Entrada de dados**: Scanned 2026-07-25

## Estrutura de diretórios

```
GesCon/
├── docs/                                      # Documentação
│   ├── ARQUITETURA.md                        # Decisões técnicas, stack, modelo de dados
│   ├── FUNCIONAL.md                          # Especificação funcional, telas, limitações
│   └── superpowers/                          # Histórico de design (specs, planos, ledger)
│       ├── plans/
│       │   ├── 2026-07-24-motor-financeiro-nucleo.md
│       │   └── 2026-07-24-plano-2.md
│       └── specs/
│           ├── 2026-07-24-gescon-design.md
│           └── 2026-07-24-plano-2-design.md
├── src/                                       # Código-fonte (12 módulos de negócio)
│   ├── db.prw                                # Escape de SQL literal (GcSqlLit)
│   ├── login.prw                             # Autenticação, hash SHA-256 (GcLogin, GcAutenticar)
│   ├── condominos.prw                        # Cadastro de condôminos (GcCondominos)
│   ├── unidades.prw                          # Cadastro de unidades (GcUnidades)
│   ├── despesas.prw                          # Lançamento de despesas (GcDespesas)
│   ├── fechamento.prw                        # Fechamento mensal, rateio (GcFecharMes)
│   ├── cobrancas.prw                         # Cobranças, registro de pagamento (GcCobrancas)
│   ├── malas.prw                             # Mala direta com envio SMTP (GcMalaDireta)
│   ├── relatorios.prw                        # Balancete/Inadimplência/Extrato/Despesas (GcXxx)
│   ├── usuarios.prw                          # Gestão de usuários, tokens (GcMenuUsuarios)
│   ├── portal.prw                            # Portal do condômino, token-based (GcPortalCondmino)
│   └── boleto.prw                            # Boleto Itaú/Bradesco (GcGeraBoleto)
├── tests/                                     # Testes unitários (9 suítes)
│   ├── db_test.prw
│   ├── login_test.prw
│   ├── fechamento_test.prw
│   ├── pagamento_test.prw
│   ├── malas_test.prw
│   ├── portal_test.prw
│   ├── relatorios_test.prw
│   └── usuarios_test.prw
├── scripts/                                   # Utilitários
│   └── bootstrap-db.sh                       # Aplica schema.sql no banco compartilhado
├── gescon.prw                                 # Ponto de entrada (web e desktop)
├── schema.sql                                 # DDL: 11 tabelas + SX3 (metadados)
├── README.md                                  # Getting started
├── .gitignore
├── .github/                                   # CI/CD stubs
├── .git/                                      # Histórico de commits
└── GesConApp*                                # Binários compilados
    ├── GesConApp                             # Linux x64
    ├── GesConApp-linux                       # Linux x64 (backup)
    └── GesConApp-win.exe                     # Windows x64
```

## Linguagens e extensões

| Extensão | Contagem | Propósito |
|----------|----------|-----------|
| `.prw` | 22 | Código-fonte AdvPL/TLPP (12 módulos + 9 testes + 1 ponto de entrada) |
| `.md` | 7 | Documentação (README, ARQUITETURA, FUNCIONAL, superpowers specs/plans) |
| `.sql` | 1 | Schema DDL (11 tabelas + SX3) |
| `.sh` | 1 | Bootstrap do banco (bootstrap-db.sh) |
| **Total** | **31** | |

## Tecnologias identificadas

### Compilador/Runtime
- **AdvPP** v1.23.1+ — compilador open-source para AdvPL/TLPP, escrito em Go
  - Requerimento: `advplc serve` (web), `advplc build` (desktop)
  - Motivação: GesCon contribuiu 5 bug fixes e 4 capacidades novas (TCSqlExec, TMailMessage, FWMenuSelect/FWGetText, FWHash)

### Banco de dados
- **SQLite** — arquivo único `~/.advpp/ADVPP.db` (compartilhado com outras ferramentas AdvPP)
- Convenção de exclusão lógica estilo Protheus: `D_E_L_E_T_` (soft-delete), `R_E_C_D_E_L_` (timestamp)
- Suporte a SX3 (metadados de coluna) para renderização no FWMBrowse

### UI — duas formas, mesmo código
- **Web**: `advplc serve` — FWMBrowse renderizado como PO-UI/Angular no navegador (http://localhost:8080)
- **Desktop**: `advplc build` — Executável nativo (Fyne), sem servidor. Mesmo bytecode compilado embutido no binário.
- Navegação: FWMenuSelect, FWGetText (capacidades próprias do AdvPP, não existem em Protheus real)
- Tema visual: Azul-petróleo (não o roxo padrão do PO-UI/Fyne)
- Segurança: Senha mascarada (3º argumento `bIsPassword=.T.` de FWGetText), armazenada como hash SHA-256 (FWHash), nunca em texto puro

### E-mail
- **TMailMessage** (classe nativa AdvPP, usa net/smtp da stdlib Go)
- Configuração via variáveis de ambiente: `GESCON_SMTP_HOST`, `GESCON_SMTP_PORT`, `GESCON_SMTP_USER`, `GESCON_SMTP_PASS`, `GESCON_SMTP_FROM`
- Seguro por padrão: sem `GESCON_SMTP_HOST`, mala direta não tenta enviar

## Pontos de entrada

| Arquivo | Tipo | Propósito |
|---------|------|-----------|
| `gescon.prw` | Função função `MAIN()` (implicit) | Web (`advplc serve`) ou Desktop (`advplc build`) |
| `tests/*_test.prw` | Testes unitários | `advplc run tests/xxx_test.prw` |

## Banco de dados — Schema

### Tabelas (11 total)

| Tabela | Linhas | Propósito |
|--------|--------|-----------|
| `CON` | N/A | Condôminos (CON_CODIGO, CON_NOME, CON_CPF, CON_EMAIL, CON_TEL) |
| `UNI` | N/A | Unidades (UNI_CODIGO, UNI_BLOCO, UNI_FRACAO, UNI_CONDOMINO) |
| `DES` | N/A | Despesas lançadas (DES_DESCR, DES_CATEG, DES_VALOR, DES_COMPET) |
| `COB` | N/A | Cobranças geradas pelo Fechamento (COB_UNIDADE, COB_COMPET, COB_VALOR, COB_STATUS) |
| `USR` | N/A | Usuários administradores (USR_LOGIN, USR_SENHA hash, USR_PERFIL) |
| `RPT_INADIM` | N/A | Snapshot relatório Inadimplência (recalculado) |
| `RPT_EXTRATO` | N/A | Snapshot Extrato por Unidade (recalculado) |
| `RPT_DESCAT` | N/A | Snapshot Despesas por Categoria (recalculado) |
| `CFG_BOLETO` | N/A | Configuração boleto (banco, agência, conta, carteira) |
| `GCT_TOKEN` | N/A | Tokens temporários condômino (válido 48h, marcado como usado) |
| `RPT_COND_COBRANCAS` | N/A | Snapshot cobranças do condômino no portal (recalculado) |
| `SX3` | N/A | Metadados de coluna para FWMBrowse (títulos, tipos, tamanhos) |

### Relacionamentos
- `UNI.UNI_CONDOMINO → CON.CON_CODIGO` (texto livre, sem FK)
- `COB.COB_UNIDADE → UNI.UNI_CODIGO`
- `GCT_TOKEN.UNI_CODIGO → UNI.UNI_CODIGO`
- `GCT_TOKEN.CON_CODIGO → CON.CON_CODIGO`
- Tabelas `RPT_*`: staging area de relatórios (sem relacionamento formal)

### Decisão: Snapshots vs. VIEWs
FWMBrowse só suporta tabelas físicas (não views) — solução: cada relatório tabular tem tabela `RPT_*` própria, recalculada a cada abertura (`DELETE + INSERT` zero).

## Testes

| Framework | Contagem | Status |
|-----------|----------|--------|
| AdvPL nativo (`advplc run`) | 9 suítes | ✓ Cobrindo lógica principal |
| Funcional | FWMBrowse (browse)/FWGetText | Requires `advplc serve`/`build` (UI real) |

**Nota**: Testes de browse (GcCondominos, GcUnidades, etc.) não rodam via `advplc run` (exigem UI).

## Executáveis compilados

| Arquivo | Plataforma | Tamanho | Status |
|---------|-----------|--------|--------|
| `GesConApp` | Linux x64 | 38 MB | ✓ Pronto |
| `GesConApp-linux` | Linux x64 | 38 MB | ✓ Backup |
| `GesConApp-win.exe` | Windows x64 | 53 MB | ✓ Pronto |

**Método de build**: `advplc build gescon.prw -o <output>`  
**Requisito**: `ADVPP_SRC=/caminho/pro/checkout/AdvPP` (para linker das dependências Fyne)

## Documentação existente

- ✓ README.md — instruções de rodagem (web/desktop), requisitos, testes, mala direta, escopo (v1/v2), limitações
- ✓ docs/ARQUITETURA.md — stack, estrutura, modelo de dados, grafo de dependências, decisões (snapshots vs views, tokens)
- ✓ docs/FUNCIONAL.md — telas, regras de negócio, fluxos, limitações de UI
- ✓ docs/superpowers/ — histórico completo de design (specs, planos, ledger de execução)

## Escopo

### v1 (implementado)
- Login, cadastros (condominos, unidades, despesas)
- Fechamento mensal com rateio por fração ideal
- Cobranças + registrar pagamento
- Mala direta
- Relatórios (balancete, inadimplência, extrato, despesas por categoria)

### v2 (implementado)
- Senha mascarada (FWGetText bIsPassword)
- Boleto Itaú/Bradesco (código de barras, linha digitável)
- Gestão de usuários (criar admin, gerar/revogar token)
- Portal do condômino (token-based read-only)

## Limitações conhecidas

1. **Cobranças editáveis na UI** — a garantia de "valor travado no fechamento" é lógica de negócio, não UI (FWMBrowse editável)
2. **Relatórios clicáveis** — telas de browse permitem Incluir/Alterar/Excluir, mas não faz sentido (conteúdo recalculado do zero na próxima abertura)
3. **Sem FK explícitas** — UNI_CONDOMINO é texto livre (sem combo), facilita testes mas reduz validação de integridade

## Recomendações para publicação

- ✓ Executáveis linux/windows testados
- ✓ Schema DDL versionado (v1)
- ✓ Documentação funcional + técnica completa
- ✓ Histórico de design (superpowers specs/plans)
- ✓ Testes unitários cobrindo lógica
- ✓ Segurança: senha hashed (SHA-256), tokens temporários (48h), SMTP env-based
- ⚠ Considerar: adicionar Dockerfile/docker-compose para distribuição em containers
- ⚠ Considerar: CI/CD pipeline (.github/workflows) para auto-build nos releases
