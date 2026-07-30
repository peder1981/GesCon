# Design: Portal do Condômino v2 — Snapshots Pré-Calculados

**Data:** 2026-07-30  
**Escopo:** Essencial e minimalista  
**Status:** Design aprovado, pronto para implementação  

---

## Visão Geral

Implementar um **portal melhorado para condôminos** que integra dados do Sistema Contábil v2 com avisos gerais e agenda de vencimentos. Usa snapshots pré-calculados no fechamento mensal para performance.

**Componentes:**
- **Avisos:** Quadro de comunicados gerais (admin posta manualmente)
- **Extratos:** Cobranças por unidade (snapshot gerado no fechamento)
- **Agenda:** Próximos vencimentos (snapshot gerado no fechamento)
- **Autenticação:** Token-based (reutiliza lógica v1)

---

## Decisões de Design

| Aspecto | Decisão | Motivo |
|---------|---------|--------|
| **Avisos** | Quadro manual | Admin controla comunicados gerais (não automatizados) |
| **Documentos** | Apenas extratos | Minimalista; upload de docs é Phase 3 |
| **Agenda** | Próximos vencimentos | Simples, relevante para condômino |
| **Autenticação** | Token-based | Reusa v1, seguro, sem cadastro de senha |
| **Dados** | Por unidade | Privacidade: cada condômino vê apenas suas unidades |
| **Snapshots** | Pré-calculados | Minimalista, rápido, integra com fechamento mensal |
| **Stack** | AdvPL/TLPP (dados) + UI decidir depois | Foco em estrutura, UI é Phase 3 |

---

## Estrutura de Dados

### Tabelas Novas

#### `AVISOS` (Quadro de avisos gerais)

```
├── AVI_ID           (NUMERIC, PK, autoincrement)
├── AVI_TITULO       (TEXT: "Assembleia 15/08")
├── AVI_CORPO        (TEXT: corpo do aviso)
├── AVI_DATA_CRIACAO (DATETIME: quando foi criado)
├── AVI_ATIVO        (NUMERIC: 1=visible, 0=archived)
├── R_E_C_N_O_       (NUMERIC, autoincrement)
├── D_E_L_E_T_       (TEXT, soft-delete)
└── R_E_C_D_E_L_     (NUMERIC, timestamp soft-delete)
```

**Constraints:**
- PK: AVI_ID
- AVI_ATIVO: 0 or 1
- Soft-delete pattern (D_E_L_E_T_, R_E_C_D_E_L_)

#### `RPT_PORTAL_EXTRATOS` (Snapshot de cobranças por unidade)

```
├── REX_ID           (NUMERIC, PK, autoincrement)
├── REX_COMPETENCIA  (TEXT: "2025-01", FK → EXE_CODIGO)
├── REX_UNIDADE      (TEXT: "T01", FK → UNI_CODIGO)
├── REX_VALOR        (NUMERIC: valor da cobrança)
├── REX_VENCIMENTO   (DATE: data vencimento)
├── REX_STATUS       (TEXT: "PENDENTE" | "PAGO")
├── REX_DATA_PAGAMENTO (DATE: se pago, NULL senão)
├── R_E_C_N_O_       (NUMERIC)
├── D_E_L_E_T_       (TEXT, soft-delete)
└── R_E_C_D_E_L_     (NUMERIC)
```

**Constraints:**
- PK: REX_ID
- REX_STATUS: "PENDENTE" or "PAGO"
- FK: REX_UNIDADE → UNI_CODIGO
- UNIQUE(REX_COMPETENCIA, REX_UNIDADE, D_E_L_E_T_) — one record per unit per month
- Recalculado 100% no fechamento (DELETE + INSERT)

#### `RPT_PORTAL_AGENDA` (Próximos vencimentos por unidade)

```
├── REA_ID           (NUMERIC, PK, autoincrement)
├── REA_UNIDADE      (TEXT: "T01", FK → UNI_CODIGO)
├── REA_COMPETENCIA  (TEXT: "2025-02")
├── REA_VENCIMENTO   (DATE: data vencimento)
├── REA_VALOR        (NUMERIC: valor esperado)
├── R_E_C_N_O_       (NUMERIC)
├── D_E_L_E_T_       (TEXT, soft-delete)
└── R_E_C_D_E_L_     (NUMERIC)
```

**Constraints:**
- PK: REA_ID
- FK: REA_UNIDADE → UNI_CODIGO
- Próximos 12 meses (máximo)
- Recalculado 100% no fechamento

---

## Fluxo de Dados

### Quando Admin Fecha Período

```
GcFecharPeriodo("2025-01") executa:
  ↓
  1. Valida integridade (já existe, v2)
  2. Marca EXERCICIO.EXE_FECHADO = 1
  3. Cria próximo período (já existe, v2)
  4. Gera RPT_BALANCETE (já existe, v2)
  ↓ NOVO:
  5. Chama GcGerarPortalExtratos("2025-01")
     └─ DELETE RPT_PORTAL_EXTRATOS where competencia = "2025-01"
     └─ SELECT * FROM COB where COB_COMPET = "2025-01"
     └─ INSERT into RPT_PORTAL_EXTRATOS (unidade, valor, vencimento, status)
  ↓ NOVO:
  6. Chama GcGerarPortalAgenda("2025-01")
     └─ DELETE RPT_PORTAL_AGENDA where unidade in (...)
     └─ SELECT próximos 12 vencimentos de COB por unidade
     └─ INSERT into RPT_PORTAL_AGENDA (unidade, competencia, vencimento, valor)
```

### Quando Condômino Acessa Portal via Token

```
Portal recebe token: "uuid-xxx-yyy-zzz"
  ↓
  1. Valida token em GCT_TOKEN
     └─ Verificar: válido? (< 48h)
     └─ Verificar: ativo? (VALIDO_ATE >= now(), USADO = 1 ou 0)
  ↓
  2. Extrai: cUnidade = GCT_TOKEN.UNI_CODIGO
  ↓
  3. Carrega dados filtrados:
     ├─ AVISOS: SELECT * where AVI_ATIVO = 1, D_E_L_E_T_ = ' '
     ├─ EXTRATOS: SELECT * where REX_UNIDADE = cUnidade, D_E_L_E_T_ = ' '
     └─ AGENDA: SELECT * where REA_UNIDADE = cUnidade, D_E_L_E_T_ = ' '
  ↓
  4. Marca token como USADO = 1 (se não estava)
  ↓
  5. Retorna dados para exibição (UI, Phase 3)
```

---

## Funções Principais (AdvPL/TLPP)

### Snapshot Generation (Chamadas pelo Fechamento)

```tlpp
/*{Protheus.doc}
Generate portal extracts snapshot for a period
@type Function
@author Claude
@since 2026-07-30
@param cCompetencia Character period code (e.g., "2025-01")
@return Numeric number of extracts inserted
/*/
User Function GcGerarPortalExtratos(cCompetencia as character) as numeric
  // 1. Delete old extracts for this competence
  // 2. Query COB where COB_COMPET = cCompetencia
  // 3. For each record: insert into RPT_PORTAL_EXTRATOS
  //    (competencia, unidade, valor, vencimento, status, data_pagamento)
  // 4. Return row count
End Function

/*{Protheus.doc}
Generate portal agenda snapshot (upcoming due dates)
@type Function
@author Claude
@since 2026-07-30
@param cCompetencia Character current period code
@return Numeric number of agenda items inserted
/*/
User Function GcGerarPortalAgenda(cCompetencia as character) as numeric
  // 1. Delete old agenda
  // 2. Query: next 12 months of COB by unit
  // 3. For each: insert into RPT_PORTAL_AGENDA
  //    (unidade, competencia, vencimento, valor)
  // 4. Return row count
End Function
```

### Avisos Management

```tlpp
/*{Protheus.doc}
Create new notice in bulletin board
@type Function
@author Claude
@since 2026-07-30
@param cTitulo Character notice title
@param cCorpo Character notice body
@return Logical .T. on success
/*/
User Function GcCriarAviso(cTitulo as character, cCorpo as character) as logical
  // 1. Validate inputs
  // 2. INSERT into AVISOS (titulo, corpo, data_criacao, ativo)
  // 3. Return .T. on success
End Function

/*{Protheus.doc}
Archive notice (soft-delete / deactivate)
@type Function
@author Claude
@since 2026-07-30
@param nAvisoId Numeric AVISOS.AVI_ID to archive
@return Logical .T. on success
/*/
User Function GcArquivarAviso(nAvisoId as numeric) as logical
  // 1. UPDATE AVISOS SET AVI_ATIVO = 0 where AVI_ID = nAvisoId
  // 2. Return .T. on success
End Function
```

### Portal Access (Reutiliza v1 + Filtra)

```tlpp
/*{Protheus.doc}
Portal entry point: authenticate token and return condômino data
@type Function
@author Claude
@since 2026-07-30
@param cToken Character auth token
@return Logical .T. on success (data prepared for UI)
/*/
User Function GcPortalCondominoV2(cToken as character) as logical
  // 1. Validate token via GcAuthPortalToken (reutiliza v1)
  // 2. Extract UNI_CODIGO from token
  // 3. Query and filter:
  //    - Avisos (all, where AVI_ATIVO = 1)
  //    - Extratos (only this unit)
  //    - Agenda (only this unit)
  // 4. Prepare data structure for UI
  // 5. Return .T.
End Function
```

---

## Restrições & Validações

1. **Autenticação:** Token-based, reutiliza v1 (`GCT_TOKEN`, 48h válido)
2. **Privacidade:** Cada condômino vê apenas suas unidades
3. **Avisos:** Apenas admin posta (via menu)
4. **Snapshots:** Gerados 100% no fechamento (sem cache intermediário)
5. **Soft-delete:** Todas as tabelas seguem padrão Protheus (D_E_L_E_T_, R_E_C_D_E_L_)

---

## Testes Esperados

- ✅ Snapshot geração (extratos + agenda no fechamento)
- ✅ Criação e arquivamento de avisos
- ✅ Filtro por unidade (token autoriza apenas suas unidades)
- ✅ E2E: fechar mês → dados aparecem no portal

---

## Integração com Sistema Contábil v2

- **Entrada de dados:** `GcFecharPeriodo()` chama `GcGerarPortalExtratos()` e `GcGerarPortalAgenda()`
- **Reutiliza:** Sistema Contábil v2 (LANCAMENTOS, COB, RATEIO_DETALHE já estão lá)
- **Dados:** Extratos vêm de COB; agenda vem de COB (próximos vencimentos)

---

## Próximas Fases

**Phase 3 (Portal UI):** Decidir entre AdvPL/TLPP web ou React/Vue + REST API

**Phase 4 (Auditoria Dashboard):** Visualizar anomalias contábeis + compliance

---

## Referências

- Spec Sistema Contábil v2: `docs/superpowers/specs/2026-07-30-sistema-contabil-design.md`
- Portal v1 (authentication): `src/portal.prw` (reutilizar `GcAuthPortalToken`, `GCT_TOKEN`)
- KondoManager (inspiração): https://github.com/vince844/kondomanager-free
