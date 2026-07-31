# Design: Portal v3 + Auditoria Dashboard (Phase 3-4)

**Data:** 2026-07-30  
**Escopo:** Portal web integrada + Auditoria completa com anomalias, dashboards, relatórios e alertas  
**Status:** Design aprovado, pronto para implementação  
**Arquitetura:** Monolítica (REST API em TLPP + Frontend Deno/Node.js)

---

## Visão Geral

Integração de duas interfaces web compartilhando uma REST API:
- **Portal v3:** Condômino acessa extratos, avisos, agenda (reutiliza snapshots v2)
- **Auditoria Dashboard:** Admin vê anomalias contábeis, dashboards, relatórios, alertas

**Stack Tecnológico:**
- Backend: REST API em TLPP (AdvPP)
- Frontend: Deno/Node.js embarcado (servir SPA + proxy)
- Autenticação: Token v2 + roles USR_PERFIL
- Database: SQLite (tabelas novas para anomalias/alertas)
- Alertas: Híbrido (polling dashboard + push para críticos)

---

## Decisões de Design

| Aspecto | Decisão | Motivo |
|---------|---------|--------|
| **Stack Frontend** | Deno/Node.js embarcado | Integrado ao AdvPP, sem dependências externas |
| **Arquitetura API** | Monolítica (3 módulos) | Simples, reutiliza lógica, pode evoluir para modular |
| **Autenticação** | Reusar token v2 + USR_PERFIL | Sem novo sistema, apenas adiciona roles |
| **Acesso Dados** | Condômino vê só suas unidades, Admin vê tudo | Privacidade mantida, auditoria completa |
| **Alertas** | Polling (10 min) + Push (críticos) | Balance entre performance e latência |
| **Validações** | 6 tipos de anomalias | Cobertura: partida dupla, órfãos, rateio, timing, usuário |
| **Relatórios** | PDF/Excel exportável | Conformidade legal, rastreabilidade |

---

## Arquitetura Geral

```
┌─────────────────────────────────────────────┐
│  Frontend (Deno/Node.js)                    │
│  - SPA: Portal v3 + Auditoria               │
│  - Servir estáticos + proxy REST            │
└────────────────┬────────────────────────────┘
                 │ HTTP/REST
┌────────────────┴────────────────────────────┐
│  REST API Backend (TLPP/AdvPP)              │
│  - /auth/* (login, logout, validate)        │
│  - /portal/* (extratos, agenda, avisos)     │
│  - /auditoria/* (anomalias, dashboards)     │
└────────────────┬────────────────────────────┘
                 │ SQL
┌────────────────┴────────────────────────────┐
│  Database (SQLite)                          │
│  - Existing: LANCAMENTOS, COB, UNI, etc     │
│  - New: ANOMALIA_LOG, ALERTA, DASHBOARD     │
└─────────────────────────────────────────────┘
```

---

## Componentes

### Frontend (Deno/Node.js Server)

**Responsabilidades:**
1. Entrega SPA (HTML + JS)
2. Proxya REST calls → TLPP backend
3. Gerencia WebSocket para alertas em tempo real

**Estrutura:**
```
src/
  server.ts              # Deno/Node.js HTTP server
  routes/
    auth.ts              # POST /login, /logout
    portal.ts            # GET /extratos, /agenda, /avisos
    auditoria.ts         # GET /anomalias, /dashboards, /alertas
  ui/
    index.html           # SPA shell
    portal.js            # Condômino views (extratos, avisos, agenda)
    auditoria.js         # Admin views (dashboards, anomalias, relatórios)
    api.js               # HTTP client para REST
```

**Endpoints:**
- `GET /` → serve `index.html`
- `POST /api/auth/login` → proxy `POST http://localhost:8001/auth/login`
- `GET /api/portal/*` → proxy `GET http://localhost:8001/portal/*`
- `GET /api/auditoria/*` → proxy `GET http://localhost:8001/auditoria/*`
- `WebSocket /api/auditoria/alertas/subscribe` → push alerts (críticos)

---

### REST API Backend (TLPP)

**Módulos e Endpoints:**

#### Auth
- `POST /auth/login` — valida username/password → retorna token (reusar GcAuthPortalToken)
- `POST /auth/logout` — invalida token
- `GET /auth/validate` — verifica token válido + retorna `{perfil, unidades_permitidas}`

#### Portal (reutiliza v2)
- `GET /portal/extratos?unidade=T01` → RPT_PORTAL_EXTRATOS filtrado
- `GET /portal/agenda?unidade=T01` → RPT_PORTAL_AGENDA filtrado (próximos 12 meses)
- `GET /portal/avisos` → AVISOS com AVI_ATIVO = 1

#### Auditoria (novo)
- `GET /auditoria/anomalias?periodo=2025-01&tipo=DESEQUILIBRIO_CONTABIL` → ANOMALIA_LOG
- `GET /auditoria/anomalias/resumo` → contagem por tipo
- `GET /auditoria/dashboards` → DASHBOARD_CACHE (atualizado a cada 10 min)
- `GET /auditoria/relatorio/{tipo}?formato=pdf|excel` → download relatório
- `POST /auditoria/alertas/dismiss/{id}` → marca ALERTA como visto
- `WebSocket /auditoria/alertas/subscribe` → push de alertas críticos

---

### Auditoria (Motor de Detecção)

**Scheduler (a cada 10 minutos):**
```tlpp
Function GcAuditarPeriodoCompleto(cPeriodo)
  // Checa 6 validações
  GcValidarDesequilibrioContabil(cPeriodo)
  GcValidarLancamentosOrfaos(cPeriodo)
  GcValidarCobrancasOrfaos(cPeriodo)
  GcValidarRateioValido(cPeriodo)
  GcValidarTimingLancamentos(cPeriodo)
  GcValidarAlteracoesEmPeriodoFechado(cPeriodo)
  
  // Atualiza dashboard cache
  GcAtualizarDashboardCache(cPeriodo)
End Function
```

**Event-driven (imediato no GcFecharPeriodo):**
- Se DESEQUILIBRIO_CONTABIL detectado:
  - `INSERT INTO ALERTA {tipo: 'CRITICO', msg: '...'}`
  - `GcEnviarWebSocketBroadcast('/auditoria/alertas', {tipo: 'DESEQUILIBRIO', ...})`

**6 Tipos de Anomalias:**
1. **DESEQUILIBRIO_CONTABIL** — débito ≠ crédito no período
2. **LAN_ORFAO** — lançamento sem cobrança correspondente
3. **COB_ORFAO** — cobrança sem lançamento
4. **RATEIO_INVALIDO** — soma frações ideais ≠ 100%
5. **TIMING_ANOMALIA** — lançamento com data > vencimento cobrança
6. **USUARIO_ANOMALIA** — alteração em período fechado (audit trail)

---

## Banco de Dados

### ANOMALIA_LOG (histórico de anomalias)
```
├── ANL_ID (INTEGER PK AUTOINCREMENT)
├── ANL_TIPO (TEXT: DESEQUILIBRIO, LAN_ORFAO, COB_ORFAO, RATEIO_INVALIDO, TIMING, USUARIO)
├── ANL_PERIODO (TEXT: "2025-01")
├── ANL_UNIDADE (TEXT: "T01", NULL se global)
├── ANL_VALOR (NUMERIC: diferença/valor)
├── ANL_DESCRICAO (TEXT: detalhes — qual lançamento, qual cobrança, etc)
├── ANL_LANCAMENTO_ID (INTEGER FK → LANCAMENTOS.id, nullable)
├── ANL_COBRANCA_ID (INTEGER FK → COB.id, nullable)
├── ANL_CRIADO_EM (DATETIME)
├── ANL_RESOLVIDO_EM (DATETIME, nullable)
├── ANL_STATUS (TEXT: "ABERTO", "RESOLVIDO", "IGNORADO")
├── R_E_C_N_O_, D_E_L_E_T_, R_E_C_D_E_L_ (soft-delete)
```

### ALERTA (notificações críticas)
```
├── ALT_ID (INTEGER PK AUTOINCREMENT)
├── ALT_TIPO (TEXT: "CRITICO", "AVISO", "INFO")
├── ALT_ANOMALIA_ID (INTEGER FK → ANOMALIA_LOG.id, nullable)
├── ALT_MENSAGEM (TEXT)
├── ALT_CRIADO_EM (DATETIME)
├── ALT_VISTO (LOGICAL: .T. se admin viu)
├── ALT_VISTO_EM (DATETIME, nullable)
├── R_E_C_N_O_, D_E_L_E_T_, R_E_C_D_E_L_
```

### DASHBOARD_CACHE (snapshot diário)
```
├── DSH_ID (INTEGER PK AUTOINCREMENT)
├── DSH_DATA (DATE: data do snapshot)
├── DSH_PERIODO (TEXT: "2025-01")
├── DSH_ANOMALIAS_TOTAL (NUMERIC)
├── DSH_DESEQUILIBRIO_COUNT (NUMERIC)
├── DSH_LAN_ORFAO_COUNT (NUMERIC)
├── DSH_COB_ORFAO_COUNT (NUMERIC)
├── DSH_RATEIO_INVALID_COUNT (NUMERIC)
├── DSH_TIMING_COUNT (NUMERIC)
├── DSH_USUARIO_COUNT (NUMERIC)
├── DSH_JSON (TEXT: compressed JSON com timeline, heatmap, etc)
├── DSH_ATUALIZADO_EM (DATETIME)
├── R_E_C_N_O_, D_E_L_E_T_, R_E_C_D_E_L_
```

---

## Autenticação & Acesso

**Token v2 Reutilizado + USR_PERFIL:**

**Condômino:**
- Token: gerado via `GcAuthPortalToken(cUnidade)` (existente)
- Perfil: `USR_PERFIL = 'CONDOMINO'`
- Acesso:
  - `/api/portal/*` filtrado por UNI_CODIGO
  - `/api/auditoria/anomalias` mas VÊ APENAS anomalias de suas unidades

**Admin:**
- Token: `GcAuthPortalToken(cUnidade)` com `USR_PERFIL = 'ADMIN'`
- Perfil: `USR_PERFIL = 'ADMIN'`
- Acesso: TUDO sem filtro

**Validação em cada endpoint:**
```tlpp
Function ValidaAcesso(cToken, cAcao)
  oToken := GcValidarToken(cToken)
  If !oToken .Or. oToken:expirado
    Return .F.
  EndIf
  
  // Admin sempre acessa
  If oToken:perfil = 'ADMIN'
    Return .T.
  EndIf
  
  // Condômino: filtro por unidade
  If cAcao = 'VER_AUDITORIA'
    Return .F.  // Condômino não acessa auditoria completa
  EndIf
  
  Return oToken:unidade <> ''
End Function
```

---

## Fluxo de Dados

### Condômino Acessa Portal
```
1. GET http://gescon.local:8000?token=XXX
2. SPA carrega, valida token
3. GET /api/portal/extratos?unidade=T01
   → API: SELECT * FROM RPT_PORTAL_EXTRATOS WHERE REA_UNIDADE = 'T01'
4. GET /api/portal/agenda?unidade=T01
   → API: SELECT * FROM RPT_PORTAL_AGENDA WHERE REA_UNIDADE = 'T01'
5. GET /api/portal/avisos
   → API: SELECT * FROM AVISOS WHERE AVI_ATIVO = 1
6. SPA renderiza tabelas e avisos
```

### Admin Acessa Auditoria
```
1. GET http://gescon.local:8000?token=ADMIN_TOKEN
2. POST /api/auth/validate → {ok: true, perfil: 'ADMIN'}
3. SPA mostra ambas abas: Portal + Auditoria
4. GET /api/auditoria/dashboards
   → API: SELECT * FROM DASHBOARD_CACHE WHERE data = TODAY()
   → Se vazio, roda GcAuditarPeriodoCompleto()
5. GET /api/auditoria/anomalias?status=ABERTO
   → API: SELECT * FROM ANOMALIA_LOG WHERE status = 'ABERTO'
6. SPA renderiza dashboards com charts, anomalias em lista
```

### Alerta Crítico (Push em Tempo Real)
```
1. GcFecharPeriodo() detecta DESEQUILIBRIO_CONTABIL
2. INSERT INTO ALERTA {tipo: 'CRITICO', msg: '...'}
3. GcEnviarWebSocketBroadcast('/auditoria/alertas', event)
4. Frontend (admin) recebe via WebSocket
5. Toast notificação: "⚠️ Desequilíbrio detectado"
6. Admin clica → vai para /auditoria/anomalias
```

---

## Alertas (Polling + Push)

**Polling (Dashboard, a cada 10 min):**
```javascript
// Frontend
setInterval(() => {
  GET /api/auditoria/dashboards
  Atualiza charts com contagem de anomalias
}, 600000)  // 10 minutos
```

**Push (Alertas Críticos, < 2s):**
```tlpp
// Backend: GcCriarAlertaCritico(cTipo, oDetalhe)
INSERT INTO ALERTA {tipo: 'CRITICO', anomalia_id: nId, msg: cMsg}
GcEnviarWebSocketBroadcast('/auditoria/alertas', {
  tipo: cTipo,
  msg: cMsg,
  criado_em: NOW()
})
```

```javascript
// Frontend
ws = new WebSocket('ws://gescon.local:8000/api/auditoria/alertas')
ws.onmessage = (e) => {
  const alert = JSON.parse(e.data)
  showToast(`⚠️ ${alert.msg}`)  // Toast notification
  playSound()  // Opcional: som de alerta
}
```

---

## Componentes da UI

### Portal Tab (Condômino)
- **Extratos:** Tabela com RPT_PORTAL_EXTRATOS (valor, vencimento, status)
- **Avisos:** Banner com últimos 5 AVISOS (título, corpo, data)
- **Agenda:** Tabela/calendário com RPT_PORTAL_AGENDA (próximos 12 meses)

### Auditoria Tab (Admin only)
- **Dashboard:**
  - Números: # anomalias total, por tipo
  - Timeline: anomalias por período (gráfico de linha)
  - Heatmap: unidades mais afetadas
  
- **Anomalias:**
  - Filtro: tipo, período, status
  - Tabela: ANL_ID, tipo, unidade, valor, status, criado_em
  - Ação: clique para expandir detalhes, botão "Marcar Resolvido"
  
- **Relatórios:**
  - Botão "Exportar PDF" → download relatório completo
  - Botão "Exportar Excel" → CSV com todas anomalias

---

## Testes Esperados

**Unit Tests (TLPP):**
- GcAuditarPeriodoCompleto() detecta todos 6 tipos de anomalias
- GcValidarAcesso() filtra corretamente por perfil/unidade
- GcCriarAlertaCritico() insere em ALERTA + dispara WebSocket
- GcAtualizarDashboardCache() calcula contagens corretas

**E2E Tests (Deno/Node.js + API):**
- Condômino login → acessa Portal → não vê Auditoria
- Admin login → acessa ambas abas → vê todas anomalias sem filtro
- Anomalia criada → alerta dispara em < 2s via WebSocket
- Dashboard cache atualiza a cada 10 min
- Relatório PDF/Excel gerado com dados corretos

---

## Integração com Fases Anteriores

- **Portal v2:** Reutiliza tabelas RPT_PORTAL_EXTRATOS, RPT_PORTAL_AGENDA, AVISOS
- **Sistema Contábil v2:** Reutiliza LANCAMENTOS, COB, RATEIO_DETALHE, EXERCICIO
- **GcFecharPeriodo:** Dispara GcAuditarPeriodoCompleto() + alertas críticos

---

## Próximas Fases

**Phase 5 (futuro):** Integração com N8N workflows (notificações por email, SMS para anomalias)

---

## Referências

- Portal v2 spec: `docs/superpowers/specs/2026-07-30-portal-condomino-v2-design.md`
- Sistema Contábil v2 spec: `docs/superpowers/specs/2026-07-30-sistema-contabil-design.md`
- CLAUDE.md: conventions for ADVPL/TLPP development
