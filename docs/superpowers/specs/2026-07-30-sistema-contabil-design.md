# Design: Sistema Contábil em Partida Dupla — GesCon v2

**Data:** 2026-07-30  
**Escopo:** Essencial e minimalista  
**Status:** Design aprovado, pronto para implementação  

---

## Visão Geral

Implementar um **sistema contábil em partida dupla** para o GesCon, permitindo registrar lançamentos contábeis com integridade garantida (débito sempre igual a crédito). O sistema suporta:

- **Lançamentos manuais**: admin cria débito + crédito explícitos na mesma tela
- **Lançamentos automáticos**: via rateio de despesas com tabelas milesinares customizáveis
- **Plano de contas**: predefinido, simples (~20 contas)
- **Rateio flexível**: fração ideal OU tabelas milesinais (metragem, valor fixo, etc.)
- **Um exercício por vez**: período ativo linear (Jan → Feb → Mar), sem paralelos
- **Fechamento com validação**: débito == crédito obrigatoriamente antes de fechar

---

## Decisões de Design

| Aspecto | Decisão | Motivo |
|---|---|---|
| **Dupla entrada** | Explícita na tela (débito + crédito obrigatórios) | Força integridade, educativo, minimalista |
| **Rateio** | Fração ideal OU tabelas milesinais customizáveis | Flexibilidade sem complexidade excessiva |
| **Plano de contas** | Simples (~20 contas), sem hierarquia | Minimalista, atende condomínio pequeno-médio |
| **Período contábil** | Um exercício por vez (linear) | Simples, não requer múltiplos períodos abertos |
| **Lançamentos** | Manual + Automático (via rateio) | Controle manual + automação de roteinas |
| **Validação** | D/C obrigatoriamente iguais ao fechar | Garante integridade contábil |

---

## Estrutura de Dados

### Tabelas Essenciais

#### `PLANO_CONTAS`
Plano de contas predefinido (~20 linhas).

```
├── PLA_CODIGO        (TEXT, PK: "1000", "2000", "3100", etc.)
├── PLA_NOME          (TEXT: "Caixa", "Receita Condominial", "Despesa Comum")
├── PLA_TIPO          (TEXT: "ATIVO" | "PASSIVO" | "RECEITA" | "DESPESA")
├── PLA_ATIVO         (NUMERIC: 1=ativo, 0=inativo)
├── R_E_C_N_O_        (NUMERIC, auto-increment)
├── D_E_L_E_T_        (TEXT, soft-delete)
└── R_E_C_D_E_L_      (NUMERIC, timestamp soft-delete)
```

**Dados iniciais (seed):**
- Ativo: Caixa (1000)
- Passivo: Receita Condominial (2000), Débitos Anteriores (2100)
- Receita: Receita Condominial (3000)
- Despesa: Despesa Comum (4000), Despesa Extraordinária (4100), Ajustes (4900)

#### `REPARTICAO`
Tipos de rateio customizáveis (fração ideal, metragem, valor fixo, etc.).

```
├── REP_CODIGO        (TEXT, PK: "FRACAO", "METRAGEM", "FIXO")
├── REP_NOME          (TEXT: "Fração Ideal", "Por Metragem", "Valor Fixo")
├── REP_ATIVO         (NUMERIC: 1=ativo, 0=inativo)
├── REP_DETALHE       (TEXT/JSON: array de {unidade, percentual_ou_valor})
├── R_E_C_N_O_        (NUMERIC)
├── D_E_L_E_T_        (TEXT, soft-delete)
└── R_E_C_D_E_L_      (NUMERIC)
```

**Dados iniciais (seed):**
- "FRACAO": Usa fração ideal de cada unidade (UNI_FRACAO)
- "METRAGEM": Customizável por admin (requer input)
- "FIXO": Valor fixo por unidade (requer input)

#### `EXERCICIO`
Período contábil ativo (um por vez).

```
├── EXE_CODIGO        (TEXT, PK: "2025-01", "2025-02")
├── EXE_INICIO        (DATE: primeira data do mês)
├── EXE_FIM           (DATE: última data do mês)
├── EXE_ATIVO         (NUMERIC: 1=ativo, 0=inativo, apenas 1 ativo)
├── EXE_FECHADO       (NUMERIC: 1=fechado, 0=aberto)
├── R_E_C_N_O_        (NUMERIC)
├── D_E_L_E_T_        (TEXT, soft-delete)
└── R_E_C_D_E_L_      (NUMERIC)
```

#### `LANCAMENTOS`
Core da dupla entrada (débito sempre == crédito).

```
├── LAN_ID            (NUMERIC, PK, auto-increment)
├── LAN_DATA          (DATE: data do lançamento)
├── LAN_CONTA_DEB     (TEXT, FK → PLA_CODIGO: conta débito)
├── LAN_CONTA_CRED    (TEXT, FK → PLA_CODIGO: conta crédito)
├── LAN_VALOR         (NUMERIC, sempre positivo)
├── LAN_DESCR         (TEXT: "Pintura Comum", "Ajuste de caixa")
├── LAN_REFERENCIA    (NUMERIC, opcional FK: DES_ID, COB_RECNO, ou NULL)
├── LAN_TIPO          (TEXT: "MANUAL" | "AUTOMATICO_DESPESA" | "AUTOMATICO_RATEIO")
├── LAN_DATA_HORA     (DATETIME: auditoria)
├── LAN_USUARIO       (TEXT: auditoria)
├── LAN_EXERCICIO     (TEXT, FK → EXE_CODIGO)
├── R_E_C_N_O_        (NUMERIC)
├── D_E_L_E_T_        (TEXT, soft-delete)
└── R_E_C_D_E_L_      (NUMERIC)
```

#### `RATEIO_DETALHE`
Intermediário: quebra rateio por unidade (para auditoria e portal).

```
├── RAT_ID            (NUMERIC, PK, auto-increment)
├── RAT_LANCAMENTO    (NUMERIC, FK → LAN_ID: lançamento origem)
├── RAT_UNIDADE       (TEXT, FK → UNI_CODIGO)
├── RAT_VALOR         (NUMERIC: valor rateiado para essa unidade)
├── RAT_PERCENTUAL    (NUMERIC: percentual ou valor fixo usado)
├── R_E_C_N_O_        (NUMERIC)
├── D_E_L_E_T_        (TEXT, soft-delete)
└── R_E_C_D_E_L_      (NUMERIC)
```

---

## Fluxos de Negócio

### Fluxo 1: Lançamento Manual

**Ator:** Admin abre "Contabilidade" → "Novo Lançamento"

**Passos:**

1. Admin preenche formulário:
   - Data do lançamento
   - Descrição (ex: "Ajuste de caixa")
   - Conta Débito (combo PLANO_CONTAS)
   - Conta Crédito (combo PLANO_CONTAS)
   - Valor (sempre positivo)

2. Sistema valida:
   - Débito ≠ Crédito (não permite mesma conta dos dois lados)
   - Valor > 0
   - Exercício ativo e não fechado

3. Admin confirma (OK/Cancelar)

4. Sistema grava em LANCAMENTOS:
   - LAN_TIPO = "MANUAL"
   - Auditoria (data_hora, usuário)
   - Soft-delete = ' ' (ativo)

5. Feedback: "Lançamento #123 gravado"

---

### Fluxo 2: Lançar Despesa com Rateio Automático

**Ator:** Admin abre "Lançar Despesa" (interface adaptada do GesCon v1)

**Passos:**

1. Admin preenche:
   - Data
   - Descrição (ex: "Pintura Comum")
   - Valor total (ex: R$ 1000)
   - Categoria (ex: "Manutenção")
   - Tabela de repartição (combo: "Fração Ideal", "Metragem", "Fixo", etc.)

2. Sistema calcula rateio:
   - Busca REPARTICAO escolhida
   - Para cada unidade ativa: `valor_unidade = valor_total × percentual_unidade`
   - Armazena em RATEIO_DETALHE (intermediário)

3. Sistema cria lançamentos D/C automáticos:
   - **1º Lançamento:** Débito "Despesa Comum" / Crédito "Caixa"
     - Valor = total (R$ 1000)
     - LAN_TIPO = "AUTOMATICO_DESPESA"
   - **N Lançamentos de rateio:** um por unidade
     - Débito "Contas a Receber" / Crédito "Receita Condominial"
     - Valor = valor_unidade (R$ 100 cada, se 10 unidades)
     - LAN_TIPO = "AUTOMATICO_RATEIO"
     - LAN_REFERENCIA = DES_ID (da despesa original)

4. Sistema cria cobranças (tabela COB):
   - Para cada unidade: INSERT COB (unidade, valor_rateiado, vencimento, status)

5. Feedback: "Despesa de R$ 1000 lançada, 10 unidades cobradas"

---

### Fluxo 3: Fechar Período

**Ator:** Admin abre "Contabilidade" → "Fechar Período"

**Pré-requisitos:**
- Exercício ativo escolhido (ex: "2025-01")
- Todos os lançamentos já criados

**Passos:**

1. Admin clica "Fechar Período"
   - Sistema exibe preview:
     - Total Débitos: R$ X.XXX
     - Total Créditos: R$ X.XXX
     - Diferença: R$ 0.00 (ou erro se ≠ 0)
     - Resumo: N lançamentos, N cobranças geradas

2. Sistema valida integridade:
   - Débito total == Crédito total? (SIM/NÃO)
   - Se NÃO → Exibe erro: "Desequilíbrio de R$ XXX, revise lançamentos"
     - Aborta fechamento
   - Se SIM → Continua
   - Verifica cobranças órfãs: há COB sem LAN_REFERENCIA? (aviso, não fatal)

3. Admin confirma fechamento

4. Sistema executa:
   - Marca EXERCICIO.EXE_FECHADO = 1
   - Bloqueia edição/exclusão de lançamentos nesse período
   - Gera relatório contábil (snapshot em RPT_BALANCETE):
     - Soma Receitas
     - Soma Despesas
     - Calcula Saldo = Receitas - Despesas
   - Cria EXERCICIO novo para próximo período (ex: "2025-02")
     - Automático (data_inicio = fim do anterior + 1 dia)
     - Marcado como EXE_ATIVO = 1

5. Feedback: "Período 2025-01 fechado com sucesso. Próximo período: 2025-02"

---

## Funções Principais (AdvPL/TLPP)

### Lançamentos Manuais

```tlpp
// Criar lançamento manual (débito + crédito explícitos)
User Function GcNovoLancamento() as logical
  // Abre diálogo
  // Valida: débito ≠ crédito, valor > 0, exercício não fechado
  // Grava em LANCAMENTOS
  Return .T.
End Function

// Editar lançamento (data, descrição, valor apenas)
User Function GcEditarLancamento(nRecno as numeric) as logical
  // Permite edição de: LAN_DATA, LAN_DESCR, LAN_VALOR
  // NÃO permite mudar contas (preserva dupla entrada)
  // Apenas se exercício não fechado
  Return .T.
End Function

// Deletar lançamento (soft-delete)
User Function GcDeletarLancamento(nRecno as numeric) as logical
  // Marca D_E_L_E_T_ = '*'
  // Apenas se exercício não fechado
  Return .T.
End Function

// Browse de lançamentos
User Function GcLancamentosConsulta()
  // FWMBrowse sobre LANCAMENTOS
  // Permite filtrar por: data, conta, tipo (manual/automático)
  // Ações: editar, deletar (se não fechado)
  Return
End Function
```

### Lançamentos Automáticos (Rateio)

```tlpp
// Lançar despesa com rateio automático
User Function GcLancarDespesaContabil(cDescricao as character, nValor as numeric, cReparticao as character) as logical
  // 1. Valida exercício ativo e não fechado
  // 2. Calcula rateio (busca REPARTICAO e percentuais)
  // 3. Cria lançamento D/C principal (AUTOMATICO_DESPESA)
  // 4. Cria N lançamentos de rateio (AUTOMATICO_RATEIO)
  // 5. Cria cobranças (COB) por unidade
  // Retorna .T. se sucesso
  Return .T.
End Function

// Calcular rateio para preview (antes de confirmar)
User Function GcCalcularRateio(cReparticao as character, nValor as numeric) as array
  // Retorna array com: {unidade, percentual, valor_rateiado, ...}
  // Permite admin revisar antes de confirmar
  Return aResultado
End Function

// Consultar lançamentos de uma despesa
User Function GcLancamentosPorDespesa(nRecnoDespesa as numeric) as numeric
  // Busca LANCAMENTOS linkados (LAN_REFERENCIA = DES_ID)
  // Mostra preview
  Return nQtdLancamentos
End Function
```

### Fechamento e Validação

```tlpp
// Validar integridade contábil (débito == crédito)
User Function GcValidarIntegridade(cExercicio as character) as logical
  // Soma LAN_VALOR onde LAN_CONTA é débito
  // Soma LAN_VALOR onde LAN_CONTA é crédito
  // Retorna .T. se iguais (com tolerância de centavos)
  Return lIntegro
End Function

// Fechar período
User Function GcFecharPeriodo(cExercicio as character) as logical
  // 1. Valida integridade
  // 2. Marca EXERCICIO.EXE_FECHADO = 1
  // 3. Gera snapshot contábil (relatório)
  // 4. Cria próximo exercício
  // Retorna .T. se sucesso
  Return .T.
End Function

// Gerar balancete (relatório de fechamento)
User Function GcGerarBalancetePeriodo(cExercicio as character) as numeric
  // Calcula:
  //   - Total Receitas (LANCAMENTOS onde conta_tipo = RECEITA)
  //   - Total Despesas (LANCAMENTOS onde conta_tipo = DESPESA)
  //   - Saldo = Receitas - Despesas
  // Grava em RPT_BALANCETE para portal
  // Retorna nSaldo (numeric)
  Return nSaldo
End Function

// Bloquear edição em período fechado
User Function GcPeriodoFechado(cExercicio as character) as logical
  // Verifica se EXERCICIO.EXE_FECHADO = 1
  // Impede GcNovoLancamento, GcEditarLancamento, GcDeletarLancamento
  Return lFechado
End Function

// Obter exercício ativo
User Function GcExercicioAtivo() as character
  // Retorna EXE_CODIGO do exercício com EXE_ATIVO = 1
  // Retorna "" se nenhum
  Return cExercicio
End Function
```

### Auditoria Contábil

```tlpp
// Executado ao fechar período
User Function GcAuditoriaFecharPeriodo(cExercicio as character) as numeric
  // Anomalia 1: Desequilíbrio D/C
  If GcValidarIntegridade(cExercicio) == .F.
    GcRegistrarAnomalia("DESEQUILIBRIO_CONTABIL", "Débito ≠ Crédito", "CRITICA")
  EndIf

  // Anomalia 2: Cobrança sem lançamento
  // For Each COB where COB_COMPET = cExercicio
  //   If NOT EXISTS LANCAMENTOS where LAN_REFERENCIA = COB.RECNO
  //     GcRegistrarAnomalia("COB_ORFAO", "Cobrança sem lançamento", "AVISO")

  // Anomalia 3: Lançamento sem cobrança (rateio incompleto)
  // For Each LANCAMENTOS where LAN_TIPO = "AUTOMATICO_RATEIO"
  //   If NOT EXISTS COB where COB.RECNO = LAN_REFERENCIA
  //     GcRegistrarAnomalia("LAN_ORFAO", "Lançamento sem cobrança", "AVISO")

  Return nQtdAnomalias
End Function

// Registrar anomalia
User Function GcRegistrarAnomalia(cTipo as character, cDescricao as character, cSeveridade as character) as logical
  // Grava em tabela AUDITORIA
  // cSeveridade: "CRITICA" | "AVISO" | "INFO"
  Return .T.
End Function
```

---

## Integração com Outros Subsistemas

### Integração com Auditoria Contábil (Subsistema 3)

- **Contábil → Auditoria:** Ao fechar período, `GcAuditoriaFecharPeriodo()` valida integridade e detecta anomalias
- **Auditoria valida:** débito == crédito, cobranças órfãs, lançamentos órfãos
- **Resultado:** Alertas antes de fechar ou relatório pós-fechamento

### Integração com Portal do Condômino (Subsistema 2)

- **Contábil → Portal:** Após fechar, `GcGerarBalancetePeriodo()` gera snapshot em RPT_BALANCETE
- **Portal consome:** LANCAMENTOS, AUDITORIA, COB para gerar extratos por unidade
- **Resultado:** Condômino via REST vê seu extrato, cobranças, saldo (via tabelas RPT_*)

---

## Restrições & Validações

1. **Débito sempre igual a crédito:** Validado na tela (lançamento manual) e ao fechar (período)
2. **Exercício ativo:** Apenas um por vez (EXE_ATIVO = 1)
3. **Período fechado:** Bloqueia edição/exclusão de lançamentos
4. **Rateio:** Deve somar 100% ou valor total (validação no cálculo)
5. **Tabela de repartição:** Admin escolhe tipo; sistema calcula percentuais por unidade
6. **Valores:** Sempre positivos (débito/crédito), nunca negativos na entrada

---

## Testes Esperados

- ✅ Criar lançamento manual (débito ≠ crédito)
- ✅ Editar lançamento (data, descrição, valor)
- ✅ Deletar lançamento (soft-delete)
- ✅ Lançar despesa com rateio (fração ideal, metragem, fixo)
- ✅ Validar integridade (débito == crédito)
- ✅ Fechar período (se integro)
- ✅ Bloquear edição pós-fechamento
- ✅ Detectar anomalias (cob órfã, lançamento órfão)
- ✅ Gerar balancete (receitas, despesas, saldo)

---

## Próximas Fases

**Fase 2:** Portal do Condômino (avisos, documentos, agenda)  
**Fase 3:** Auditoria Contábil (detecção de anomalias, dashboard)  
**Fase 4:** REST API (integração com portal web/mobile)

---

## Referências

- Visão de alto nível: `docs/superpowers/specs/2026-07-30-sistema-contabil-design.md`
- KondoManager (inspiração): https://github.com/vince844/kondomanager-free
- GesCon v1 (base): `README.md`, `ARQUITETURA.md`
