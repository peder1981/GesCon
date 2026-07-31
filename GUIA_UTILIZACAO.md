# Portal v3 + Auditoria Dashboard — Guia de Utilização

**Versão:** 1.0  
**Data:** 2026-07-31  
**Para:** Administradores de Sistema e Condôminos  

---

## Visão Geral

O **Portal v3 + Auditoria Dashboard** é um sistema web integrado para gestão de condomínios com foco em controle de anomalias contábeis e transparência. Este guia cobre:

- **Configuração inicial** (para administradores)
- **Acesso ao Portal** (para condôminos)
- **Dashboard de Auditoria** (para auditores/admins)
- **Gerenciamento de alertas críticos**

---

## 1. Configuração Inicial

### 1.1 Pré-requisitos

- **AdvPP v2.0.3** instalado e funcionando
- **SQLite 3** CLI (para bootstrap do banco)
- Node.js ou Deno (frontend, Tasks 7-12)
- Navegador moderno (Chrome, Firefox, Safari, Edge)

### 1.2 Setup do Banco de Dados

```bash
cd /home/peder/Projetos/GesCon

# 1. Criar/atualizar tabelas de auditoria
./scripts/bootstrap-db.sh

# 2. Verificar criação
sqlite3 ~/.advpp/ADVPP.db ".tables" | grep -E "ANOMALIA|ALERTA|DASHBOARD"
# Saída esperada: ALERTA ANOMALIA_LOG DASHBOARD_CACHE
```

### 1.3 Compilar Backend (AdvPP v2.0.3)

```bash
# Compilar para executável desktop
export ADVPP_SRC=/home/peder/Projetos/AdvPP
advplc build gescon.prw -o GesConApp

# Verificar compilação
ls -lh GesConApp
# Saída esperada: -rwxr-xr-x ... GesConApp
```

### 1.4 Deploy Frontend (Tasks 7-12, próximas)

O frontend será entregue como:
- **Deno/Node.js server** rodando em `localhost:3000`
- **REST proxy** conectando em `localhost:8001` (backend AdvPP)
- **SPA web UI** (Portal + Auditoria Dashboard)

Configuração será documentada em Tasks 7-12.

---

## 2. Rodando o Sistema

### 2.1 Desktop (Executável Compilado)

```bash
./GesConApp
```

A aplicação abre em janela nativa (sem navegador).

**Acesso inicial:**
- Sem usuários cadastrados → sistema pede criação de admin
- Login e senha do administrador (criptografado com SHA-256)
- Acesso menu principal → Portal, Auditoria, Cadastros, etc.

### 2.2 Web (Dev Mode com AdvPP)

```bash
# Terminal 1: Backend AdvPP
advplc serve gescon.prw
# Acessa http://localhost:8080

# Terminal 2: Frontend (quando pronto, Tasks 7-12)
cd frontend/
npm start
# Acessa http://localhost:3000
```

---

## 3. Autenticação e Perfis

### 3.1 Sistema de Tokens

O Portal v3 usa tokens JWT-like com expiração:

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `token` | String | Identificador único (UUID) |
| `perfil` | Enum | `ADMIN`, `CONDOMINO`, `AUDITOR` |
| `unidades_permitidas` | Array | Códigos de unidades de acesso |
| `expirado` | Boolean | Token revogado ou expirado |

**Endpoints:**
- `POST /api/auth/login` — Gera novo token
- `GET /api/auth/validate` — Valida token existente
- `POST /api/auth/logout` — Revoga token

### 3.2 Perfis e Permissões

| Perfil | Permissões | Endpoints Acessíveis |
|--------|-----------|----------------------|
| **ADMIN** | Tudo | /api/portal/*, /api/auditoria/*, /api/auth/* |
| **CONDOMINO** | Read-only own unit | /api/portal/extratos, /api/portal/agenda, /api/portal/avisos |
| **AUDITOR** | Read-only all anomalies | /api/auditoria/anomalias, /api/auditoria/dashboard, /api/auditoria/alertas |

---

## 4. Portal do Condômino (v3)

### 4.1 Funcionalidades

#### Extratos de Conta
- **Endpoint:** `GET /api/portal/extratos?unidade=<COD>`
- **Dados:** Lançamentos do mês (débito/crédito), saldo
- **Snapshot:** Atualizado diariamente via `GcGerarPortalExtratos()`

#### Agenda de Vencimentos
- **Endpoint:** `GET /api/portal/agenda?unidade=<COD>`
- **Dados:** Próximas 12 cobranças/vencimentos da unidade
- **Snapshot:** Atualizado diariamente via `GcGerarPortalAgenda()`

#### Avisos Importantes
- **Endpoint:** `GET /api/portal/avisos`
- **Dados:** Notificações do condomínio (avisos gerais, mudanças de regras, etc.)
- **Snapshot:** Atualizado sob demanda via admin

### 4.2 Acesso via Portal

```
1. Condômino acessa http://localhost:3000
2. Digite: usuário (CPF ou email), senha
3. Clica "Entrar"
   → Sistema gera token via POST /api/auth/login
   → Token armazenado no localStorage (browser)
4. Visualiza:
   - Extrato da sua unidade (saldo, últimos 30 dias)
   - Avisos do condomínio
   - Agenda: próximas 12 cobranças com datas de vencimento
5. Clica "Sair"
   → Token revogado via POST /api/auth/logout
```

### 4.3 Segurança

- **Senhas:** Nunca trafegam em texto puro
  - Desktop: hash SHA-256 (FWHash)
  - Web: TLS 1.2+ obrigatório
- **Tokens:** Expiração configurável (padrão: 24h)
- **Read-only:** Condômino não pode editar/deletar dados
- **Filtragem:** Cada usuário vê só suas unidades

---

## 5. Dashboard de Auditoria

### 5.1 Visão Geral

Dashboard de auditoria fornece detecção automática de anomalias contábeis:

| Anomalia | Significado | Ação Recomendada |
|----------|-----------|------------------|
| **Desequilíbrio Contábil** | Débito ≠ Crédito no período | Revisar lançamentos do mês |
| **Lançamentos Órfãos** | Entrada sem cobrança relacionada | Investigar origem da entrada |
| **Cobranças Órfãs** | Cobrança sem lançamento | Processar pagamento ou corrigir cobrança |
| **Rateio Inválido** | Frações ≠ 100% | Corrigir percentuais das unidades |
| **Timing de Lançamentos** | Entrada após vencimento da cobrança | Revisar datas de competência |
| **Alterações em Período Fechado** | Edições após fechamento | Reverter alterações ou reabrir período |

### 5.2 Estrutura de Alertas

```
ANOMALIA_LOG
├── ANL_ID (PK)
├── ANL_TIPO (DESEQUILIBRIO_CONTABIL, LAN_ORFAO, ...)
├── ANL_PERIODO (YYYYMM)
├── ANL_UNIDADE (código da unidade)
├── ANL_VALOR (valor em R$)
├── ANL_DESCRICAO (texto explicativo)
├── ANL_STATUS (ABERTO, RESOLVIDO, IGNORADO)
└── ANL_RESOLVIDO_EM (quando foi resolvido)

ALERTA (notificações críticas em tempo real)
├── ALT_ID (PK)
├── ALT_TIPO (CRITICO, AVISO, INFO)
├── ALT_ANOMALIA_ID (FK → ANOMALIA_LOG)
├── ALT_MENSAGEM (texto da notificação)
├── ALT_VISTO (0/1)
└── ALT_VISTO_EM (timestamp de leitura)

DASHBOARD_CACHE (snapshot diário)
├── DSH_DATA (data do snapshot)
├── DSH_PERIODO (período auditado)
├── DSH_ANOMALIAS_TOTAL (total de anomalias)
├── DSH_DESEQUILIBRIO_COUNT (quantas desse tipo)
├── DSH_LAN_ORFAO_COUNT
├── DSH_COB_ORFAO_COUNT
├── DSH_RATEIO_INVALID_COUNT
├── DSH_TIMING_COUNT
├── DSH_USUARIO_COUNT (edições em período fechado)
└── DSH_JSON (snapshot completo em JSON)
```

### 5.3 Endpoints de Auditoria

#### Dashboard Principal
```bash
GET /api/auditoria/dashboard?periodo=202407

Response:
{
  "ok": true,
  "periodo": "202407",
  "data_snapshot": "2026-07-31",
  "anomalias_total": 8,
  "desequilibrio_contabil": 2,
  "lancamentos_orfaos": 3,
  "cobrancas_orfas": 1,
  "rateio_invalido": 1,
  "timing_lancamentos": 1,
  "alteracoes_periodo_fechado": 0,
  "json_snapshot": "{...}"
}
```

#### Listagem de Anomalias
```bash
GET /api/auditoria/anomalias?periodo=202407&tipo=LAN_ORFAO

Response:
{
  "ok": true,
  "total": 3,
  "anomalias": [
    {
      "id": 142,
      "tipo": "LAN_ORFAO",
      "periodo": "202407",
      "unidade": "101",
      "valor": 1500.00,
      "descricao": "Lançamento de débito sem cobrança associada",
      "status": "ABERTO",
      "criado_em": "2026-07-31 10:00:00"
    },
    ...
  ]
}
```

#### Alertas Críticos (WebSocket quando pronto)
```bash
GET /api/auditoria/alertas

Response:
{
  "ok": true,
  "total_nao_lidos": 5,
  "alertas": [
    {
      "id": 201,
      "tipo": "CRITICO",
      "anomalia_id": 142,
      "mensagem": "Lançamento órfão de R$ 1.500 detectado em julho/2026",
      "visto": false,
      "criado_em": "2026-07-31 10:15:00"
    },
    ...
  ]
}
```

### 5.4 Automação (Scheduler)

Auditoria executa automaticamente a cada período de fechamento:

```
1. Administrador clica "Fechar Período" em julho/2026
   ↓
2. Backend executa GcFecharPeriodo(202407)
   ├→ Calcula rateios
   ├→ Gera cobranças
   └→ CHAMA: GcAuditarPeriodoCompleto(202407)
   ↓
3. GcAuditarPeriodoCompleto() executa 6 validadores:
   ├→ GcValidarDesequilibrioContabil()
   ├→ GcValidarLancamentosOrfaos()
   ├→ GcValidarCobrancasOrfaos()
   ├→ GcValidarRateioValido()
   ├→ GcValidarTimingLancamentos()
   └→ GcValidarAlteracoesEmPeriodoFechado()
   ↓
4. Anomalias inscritas em ANOMALIA_LOG
   ↓
5. Dashboard cache atualizado em DASHBOARD_CACHE
   ↓
6. Se anomalias críticas → Alertas criados em ALERTA
   ↓
7. Frontend (Tasks 7-12) notificado via WebSocket
```

---

## 6. Gerenciamento de Alertas

### 6.1 Fluxo de Alerta

```
Anomalia detectada
  → Severidade: CRITICO / AVISO / INFO
  → Armazenada em ANOMALIA_LOG
  → Se crítica → Alerta criado em ALERTA
  → Status: visto = 0 (não lido)
  ↓
Admin acessa Dashboard
  → Vê lista de 20 alertas não-lidos (máx)
  → Clica em alerta para ver detalhes
  → Sistema marca ALT_VISTO = 1 e ALT_VISTO_EM = NOW()
  ↓
Admin resolve anomalia
  → Edita ANOMALIA_LOG → ANL_STATUS = RESOLVIDO
  → Dashboard atualizado no próximo ciclo
```

### 6.2 Tipos de Alerta

| Tipo | Condição | Ação |
|------|----------|------|
| **CRITICO** | Desequilíbrio contábil detectado | Revisar imediatamente |
| **AVISO** | Lançamento órfão ou timing inválido | Investigar na próxima auditoria |
| **INFO** | Rateio ajustado, período reaberto | Informação apenas |

### 6.3 WebSocket (Tasks 7-12)

Quando implementado (Task 10):

```javascript
// Cliente conecta
const ws = new WebSocket('ws://localhost:3000/alerts');

// Recebe notificações em tempo real (< 2s)
ws.onmessage = (event) => {
  const alert = JSON.parse(event.data);
  console.log('Novo alerta:', alert.tipo, alert.mensagem);
  // Atualiza UI
};

// Fall-back: polling a cada 10 minutos
setInterval(() => {
  fetch('/api/auditoria/alertas')
    .then(r => r.json())
    .then(data => updateDashboard(data.alertas));
}, 600000); // 10 min
```

---

## 7. Integração com Fechamento de Período

### 7.1 Fluxo Completo

```
Admin abre "Fechamento Mensal" → julho/2026
  ↓
Sistema exibe:
  ├─ Total de despesas do mês
  ├─ Fração ideal de cada unidade
  └─ Rateio por unidade (R$ por unidade)
  ↓
Admin clica "Confirmar Fechamento"
  ↓
GcFecharPeriodo(202407) executa:
  ├─ Valida período aberto
  ├─ Calcula rateios
  ├─ Gera cobranças (COB)
  ├─ Marca período como fechado
  └─ CHAMA: GcAuditarPeriodoCompleto(202407) ← **NOVO (Task 11)**
  ↓
GcAuditarPeriodoCompleto() [Tasks 5-6]:
  ├─ Executa 6 validadores
  ├─ Insere anomalias em ANOMALIA_LOG
  ├─ Atualiza DASHBOARD_CACHE
  └─ Cria alertas críticos em ALERTA
  ↓
Dashboard atualizado
  → Admin vê: 8 anomalias encontradas em julho
  → Clica para investigar cada uma
  ↓
Admin resolve ou ignora cada anomalia
  ↓
Período fechado + auditado
```

### 7.2 Reversão de Período

Se anomalias críticas forem descobertas **após** fechamento:

```
1. Admin marca ANL_STATUS = RESOLVIDO (em ANOMALIA_LOG)
2. Admin clica "Reabrir Período"
   → GcReabrirPeriodo(202407) [existente, Portal v2]
   → Período volta a ABERTO
3. Admin edita lançamentos/cobranças
4. Clica "Fechar" novamente
   → Nova auditoria executada
```

---

## 8. Troubleshooting

### 8.1 Banco de Dados

**Erro:** `Error: database locked`
```
Causa: outro processo acessando ADVPP.db
Solução:
  1. Fechar todas instâncias (desktop + web)
  2. Aguardar 10s
  3. Reiniciar
```

**Erro:** `Table ANOMALIA_LOG not found`
```
Causa: bootstrap-db.sh não executado após atualizar schema.sql
Solução:
  ./scripts/bootstrap-db.sh
```

### 8.2 Autenticação

**Erro:** `Token inválido ou expirado`
```
Causa: Token revogado ou passou 24h
Solução:
  1. Fazer logout
  2. Fazer login novamente
  3. Token gerado com expiração de 24h (padrão)
```

**Erro:** `Não autorizado para unidade XXX`
```
Causa: Usuário não tem acesso àquela unidade
Solução:
  1. Admin edita usuário em Cadastro de Usuários
  2. Adiciona unidades permitidas
  3. Gera novo token
```

### 8.3 Auditoria

**Erro:** `Dashboard cache desatualizado`
```
Causa: Scheduler não rodou após fechamento
Solução:
  1. Verificar se GcAuditarPeriodoCompleto() foi chamado
  2. Verificar logs de erro em ANOMALIA_LOG
  3. Executar manualmente (para dev):
     advplc run -c "GcAuditarPeriodoCompleto('202407')"
```

**Dashboard vazio** para determinado período
```
Causa: Sem anomalias detectadas (normal!)
Solução: Nenhuma ação necessária, período está limpo
```

---

## 9. Suporte e Escalação

| Problema | Contato | Tempo |
|----------|---------|-------|
| Bug na auditoria | @peder1981 (GitHub Issues) | ASAP |
| Clarificação de regra | @admin_condominio | 24h |
| Feature request | @peder1981 (Discussions) | Próx. Sprint |

---

## 10. Histórico de Versão

| Versão | Data | Mudanças |
|--------|------|----------|
| 1.0 | 2026-07-31 | Backend v3 (Tasks 1-6) + documentação |
| 2.0 | 2026-08-31 | Frontend (Tasks 7-12) + WebSocket |

---

**Fim do Guia de Utilização**
