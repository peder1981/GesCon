# Portal v3 + Auditoria Dashboard — Manual do Usuário

**Para:** Condôminos e Administradores  
**Versão:** 1.0  
**Data:** 2026-07-31  

---

## Parte 1: Para Condôminos

### 1.1 Introdução

Bem-vindo ao **Portal do Condômino v3!** Este guia o ajudará a acompanhar sua conta, consultar avisos importantes e ver quando suas cobranças vencem.

**O que você pode fazer:**
- ✅ Ver seu extrato mensal (débitos e créditos)
- ✅ Consultar suas próximas cobranças e prazos
- ✅ Ler avisos importantes do condomínio
- ❌ Editar ou deletar dados (somente leitura)

### 1.2 Acesso ao Portal

#### Passo 1: Abrir o Portal

Acesse no navegador:
```
http://[seu-condominio].local:3000
```

ou peça o endereço ao seu administrador.

#### Passo 2: Fazer Login

```
Tela de login
├─ Campo "Usuário": Digite seu CPF ou email
├─ Campo "Senha": Digite sua senha (caracteres não aparecem, é normal)
└─ Botão "Entrar": Clique aqui
```

**Primeira vez?**
- Peça seu usuário e senha ao administrador do condomínio
- Senhas são criptografadas (impossível recuperar no banco)
- Se esquecer a senha, solicite ao admin um reset

#### Passo 3: Visualizar Menu Principal

Após login, você vê três abas:

| Aba | O que vê | Descrição |
|-----|----------|-----------|
| **Extratos** | Seu saldo | Débitos (despesas) e créditos (pagamentos) do mês |
| **Agenda** | Próximos vencimentos | Próximas 12 cobranças e datas de vencimento |
| **Avisos** | Notificações gerais | Avisos do condomínio (reuniões, mudanças de regra, etc.) |

### 1.3 Consultando Seu Extrato

```
Menu → Extratos
├─ Período: Julho/2026
├─ Saldo inicial: R$ 1.500,00
├─ Movimentação:
│  ├─ Despesa Comum: -R$ 300,00 (01/07)
│  ├─ Despesa Extraordinária: -R$ 150,00 (05/07)
│  └─ Pagamento recebido: +R$ 300,00 (15/07)
├─ Saldo final: R$ 1.350,00
└─ Data de atualização: 31/07/2026 23:59
```

**Interpretando:**
- **Valores negativos** (-) = você deve ao condomínio
- **Valores positivos** (+) = crédito a seu favor
- **Saldo negativo final** = você tem débito

### 1.4 Consultando Sua Agenda

```
Menu → Agenda
├─ Próximas 12 cobranças:
│  ├─ Cobrança #001 (Julho) - Vence em 05/08/2026 - R$ 300,00
│  ├─ Cobrança #002 (Agosto) - Vence em 05/09/2026 - R$ 320,00
│  └─ Cobrança #003 (Setembro) - Vence em 05/10/2026 - R$ 320,00
└─ Legenda:
   ├─ 🟢 Verde = prazo normal
   ├─ 🟡 Amarelo = próximo de vencer (< 7 dias)
   └─ 🔴 Vermelho = vencido (débito)
```

**Dicas:**
- Anote as datas de vencimento
- Pague antes de vencer para evitar juros
- Guarde comprovante de pagamento

### 1.5 Lendo Avisos do Condomínio

```
Menu → Avisos
├─ [01/07/2026] Reunião Extraordinária
│  "Assembléia de condôminos em 10/08. Compareça!"
├─ [15/07/2026] Mudança de Regra
│  "A partir de agosto, multa por atraso é 2% ao mês"
└─ [20/07/2026] Manutenção Programada
   "Elevador 1 em manutenção de 01/08 a 05/08"
```

Avisos antigos ficam visíveis por 90 dias e desaparecem automaticamente.

### 1.6 Gerenciando Sua Senha

**Trocar senha:**
```
Menu → Configurações → Minha Conta
├─ Senha atual: [___________]
├─ Nova senha: [___________]
├─ Confirmar: [___________]
└─ Botão "Salvar"
```

**Requisitos de senha:**
- Mínimo 8 caracteres
- Pelo menos 1 letra maiúscula (A-Z)
- Pelo menos 1 número (0-9)
- Pelo menos 1 caractere especial (!@#$%^&*)

**Boas práticas:**
- ❌ Não use seu CPF como senha
- ❌ Não repita senhas antigas
- ❌ Não compartilhe sua senha
- ✅ Use uma senha única para o Portal

### 1.7 Fazer Logout

```
Menu → [Seu nome] → Logout
```

Clique em "Logout" quando terminar. Sua sessão encerra e você é desconectado.

**Importante:** Sempre faça logout em computadores compartilhados!

### 1.8 Dúvidas Frequentes

**P: Posso pagar pelo Portal?**  
R: Não na v1. Pagamentos são feitos por boleto, TED ou dinheiro. Seu saldo é atualizado 24h após confirmação.

**P: Posso editar meus dados?**  
R: Não. Apenas leitura. Mudanças de endereço/telefone solicite ao admin.

**P: Meu extrato está errado!**  
R: Contate o administrador imediatamente. Nós auditamos todos os lançamentos.

**P: Posso ver extratos de meses anteriores?**  
R: Sim na v2. Por enquanto só mostra mês atual.

**P: Esqueci minha senha, o que faço?**  
R: Solicite um reset ao administrador. Você receberá uma senha temporária.

---

## Parte 2: Para Administradores

### 2.1 Introdução para Admins

Você tem acesso total ao sistema:
- ✅ Gerenciar usuários e permissões
- ✅ Visualizar e resolver anomalias contábeis
- ✅ Monitorar Dashboard de Auditoria
- ✅ Fazer fechamento de período
- ✅ Gerar relatórios

### 2.2 Dashboard de Auditoria — Visão Geral

Após login como admin:

```
Menu Principal
├─ Portal
│  ├─ Extratos (todas as unidades)
│  ├─ Agenda (todas as unidades)
│  └─ Avisos
├─ Auditoria
│  ├─ Dashboard (snapshots diários)
│  ├─ Anomalias (lista completa)
│  └─ Alertas (notificações críticas)
├─ Cadastros
│  ├─ Unidades
│  ├─ Condôminos
│  ├─ Usuários
│  └─ Despesas
├─ Operações
│  ├─ Fechamento de Período
│  ├─ Rateios
│  ├─ Cobranças
│  └─ Pagamentos
└─ Relatórios
   ├─ Balancete
   ├─ Inadimplência
   ├─ Extratos por Unidade
   └─ Despesas por Categoria
```

### 2.3 Dashboard de Auditoria Explicado

O Dashboard mostra um "snapshot" diário de anomalias contábeis detectadas automaticamente.

#### Acessar Dashboard

```
Menu Auditoria → Dashboard
├─ Seletor de período: Julho/2026 ▼
├─ Botão "Atualizar": Força recálculo
└─ Resultado:
   │
   ├─ 📊 RESUMO DO PERÍODO
   │  ├─ Data do snapshot: 31/07/2026 às 23:59
   │  ├─ Total de anomalias: 8
   │  └─ Status: ⚠️ CRÍTICAS ENCONTRADAS
   │
   ├─ 📋 DETALHAMENTO
   │  ├─ Desequilíbrio Contábil: 2
   │  ├─ Lançamentos Órfãos: 3
   │  ├─ Cobranças Órfãs: 1
   │  ├─ Rateio Inválido: 1
   │  ├─ Timing de Lançamentos: 1
   │  └─ Alterações em Período Fechado: 0
   │
   └─ 🔴 ANOMALIAS CRÍTICAS
      └─ Ver lista completa →
```

#### Interpretando Cada Anomalia

**1. Desequilíbrio Contábil (2 encontradas)**

```
Significado:
  Débito total ≠ Crédito total no período

Exemplo:
  ├─ Total débito lançado: R$ 10.000,00
  ├─ Total crédito lançado: R$ 9.800,00
  └─ Diferença: R$ 200,00 ❌

Ação recomendada:
  1. Verificar lançamentos de julho manualmente
  2. Procurar por:
     ├─ Lançamento duplicado
     ├─ Erro de digitação em valor
     └─ Crédito não contabilizado
  3. Corrigir no sistema
  4. Marcar anomalia como RESOLVIDA
```

**2. Lançamentos Órfãos (3 encontradas)**

```
Significado:
  Lançamento de débito sem cobrança relacionada

Exemplo:
  ├─ Lançamento: Despesa Extraordinária - R$ 1.500,00 (01/07)
  ├─ Unidade: 101
  ├─ Problema: Nenhuma cobrança para esta despesa
  └─ Criado há: 30 dias ❌

Ação recomendada:
  1. Verificar se foi erro de lançamento
  2. Se sim:
     ├─ Deletar lançamento
     └─ Refazer se necessário
  3. Se não:
     ├─ Criar cobrança manualmente
     └─ Vincular ao lançamento
  4. Marcar anomalia como RESOLVIDA
```

**3. Cobranças Órfãs (1 encontrada)**

```
Significado:
  Cobrança sem lançamento/despesa relacionada

Exemplo:
  ├─ Cobrança #042 - R$ 500,00 (Unidade 105)
  ├─ Período: Julho/2026
  ├─ Problema: Nenhum lançamento vinculado
  └─ Status: ABERTA ❌

Ação recomendada:
  1. Verificar se foi erro de criação
  2. Se sim:
     ├─ Deletar cobrança
     └─ Recrear se necessário
  3. Se não:
     ├─ Criar lançamento de despesa
     └─ Vincular à cobrança
  4. Marcar anomalia como RESOLVIDA
```

**4. Rateio Inválido (1 encontrada)**

```
Significado:
  Fração ideal das unidades ≠ 100%

Exemplo:
  ├─ Unidade 101: 20%
  ├─ Unidade 102: 20%
  ├─ Unidade 103: 20%
  ├─ Unidade 104: 20%
  ├─ Unidade 105: 18%
  └─ Total: 98% ❌ (Deveria ser 100%)

Ação recomendada:
  1. Editar Cadastro de Unidades
  2. Corrigir percentuais (ex: Unidade 105 → 22%)
  3. Verificar: Total deve ser 100%
  4. Salvar
  5. Marcar anomalia como RESOLVIDA
```

**5. Timing de Lançamentos (1 encontrada)**

```
Significado:
  Lançamento feito APÓS a data de vencimento da cobrança

Exemplo:
  ├─ Cobrança: Vencimento 05/07/2026
  ├─ Lançamento: Lançado em 20/07/2026
  ├─ Atraso: 15 dias ❌
  └─ Problema: Crédito contabilizado fora da competência

Ação recomendada:
  1. Editar lançamento
  2. Alterar data para o período correto
  3. Gerar novo rateio se necessário
  4. Marcar anomalia como RESOLVIDA
```

**6. Alterações em Período Fechado (0 encontradas)**

```
Significado:
  Alguém editou ou deletou registros APÓS período ser fechado

Exemplo:
  ├─ Período Junho/2026: Fechado em 30/06
  ├─ Edição: Lançamento deletado em 15/07
  ├─ Problema: Auditoria comprometida ❌
  └─ Culprit: Usuário admin (21:30:15)

Ação recomendada:
  1. Revisar alterações no período fechado
  2. Considerar:
     ├─ Reverter alterações (Reabrir período)
     ├─ Gerar novo snapshot de auditoria
     └─ Documentar motivo da reversão
  3. Estabelecer regra: não editar períodos fechados
  4. Marcar anomalia como RESOLVIDA
```

### 2.4 Gerenciando Anomalias

#### Visualizar Anomalias em Detalhe

```
Menu Auditoria → Anomalias
├─ Filtro por período: Julho/2026 ▼
├─ Filtro por tipo: [Todos] ▼
└─ Resultado: 8 anomalias encontradas
   │
   ├─ [001] Desequilíbrio Contábil (ABERTA)
   │  ├─ Período: 202407
   │  ├─ Valor: R$ 200,00
   │  ├─ Descrição: Débito ≠ Crédito
   │  ├─ Detectada: 31/07/2026 23:55
   │  ├─ Botão "Ver detalhes →"
   │  └─ Status: ⚫ ABERTA | 🟢 RESOLVIDA | 🟠 IGNORADA
   │
   ├─ [002] Lançamento Órfão - Unidade 101 (ABERTA)
   │  ├─ Valor: R$ 1.500,00
   │  └─ ... (mais detalhes)
   │
   └─ [... mais anomalias]
```

#### Resolver uma Anomalia

```
Passo 1: Clique em "Ver detalhes →" de uma anomalia
Passo 2: Painel aberto com:
         ├─ Descrição completa
         ├─ Lançamentos/cobranças relacionadas
         ├─ Data de criação
         └─ Histórico de alterações

Passo 3: Você corrige o problema no sistema:
         ├─ Edita lançamento
         ├─ Cria cobrança ausente
         ├─ Ajusta percentuais
         └─ etc...

Passo 4: Volta ao painel da anomalia
Passo 5: Clica "Marcar como Resolvida" ou "Ignorar"
         ├─ Resolvida: Problema foi corrigido
         └─ Ignorada: Problema é conhecido e aceito

Passo 6: Status muda para 🟢 RESOLVIDA
         └─ Data de resolução é registrada
```

### 2.5 Monitorando Alertas Críticos

Alertas aparecem em tempo real quando anomalias críticas são detectadas.

#### Acessar Alertas

```
Menu Auditoria → Alertas
└─ Lista de até 20 alertas não-lidos
   │
   ├─ [🔴 CRITICO] Desequilíbrio de R$ 200 detectado (01 não lido)
   │  └─ Clique para marcar como lido ✓
   │
   ├─ [🟠 AVISO] Lançamento órfão em unidade 101 (02 não lidos)
   │  └─ Valor: R$ 1.500,00
   │
   └─ [ℹ️ INFO] Período julho auditado com sucesso (0 não lidos)
      └─ Lido em: 31/07/2026 22:15
```

#### Tipos de Alerta

| Tipo | Cor | Ação | Exemplo |
|------|-----|------|---------|
| **CRITICO** | 🔴 Vermelho | Revisar imediatamente | Desequilíbrio detectado |
| **AVISO** | 🟠 Amarelo | Investigar em breve | Lançamento órfão |
| **INFO** | ℹ️ Azul | Para conhecimento | Auditoria completada |

### 2.6 Fazendo Fechamento de Período

O fechamento automático roda auditoria completa.

#### Fluxo de Fechamento

```
Menu Operações → Fechamento de Período
├─ Período aberto: Julho/2026 ▼
├─ Botão "Calcular Rateio"
│  └─ Exibe: Total de despesas, fração por unidade, valores
│
├─ Botão "Gerar Cobranças"
│  └─ Cria registros em COB (tabela de cobranças)
│
└─ Botão "Confirmar Fechamento"
   └─ Executa:
      1. Marca período como FECHADO
      2. Cria snapshot em DASHBOARD_CACHE
      3. EXECUTA auditoria completa (GcAuditarPeriodoCompleto)
         ├─ Detecta 6 tipos de anomalias
         ├─ Insere em ANOMALIA_LOG
         └─ Cria alertas críticos em ALERTA
      4. Exibe resultado: "X anomalias detectadas"
```

**Importante:** Não é possível editar período após fechamento sem reabrir!

#### Se Anomalias Forem Encontradas

```
Cenário 1: Anomalias Críticas (Desequilíbrio, Alterações Fechadas)
  ├─ Sistema PERGUNTA: "Deseja reabrir para corrigir?"
  ├─ SIM: Período volta a ABERTO, você corrige, refecha
  └─ NÃO: Período fica fechado, você marca anomalia como "IGNORADA"

Cenário 2: Anomalias Não-Críticas (Lançamentos órfãos, Rateio)
  ├─ Sistema AVISA: "X anomalias encontradas"
  └─ Você pode investigar depois (Auditoria → Anomalias)

Cenário 3: Nenhuma Anomalia
  ├─ Sucesso! ✓
  ├─ Período fechado e auditado
  └─ Dashboard limpo
```

### 2.7 Gerenciando Usuários

#### Criar Novo Usuário

```
Menu Cadastros → Usuários → Novo
├─ Nome: [___________________]
├─ Email: [___________________]
├─ CPF: [_______________]
├─ Perfil: [ADMIN / CONDOMINO / AUDITOR] ▼
├─ Unidades permitidas: [Selecione] (checkbox)
│  ├─ ☑ Unidade 101
│  ├─ ☑ Unidade 102
│  ├─ ☐ Unidade 103
│  └─ ...
└─ Botão "Criar"
   └─ Sistema gera senha temporária e exibe
```

**Senha temporária:**
- Exemplo: `TempPwd_2026_07_31_XyZ123!`
- Condômino usa para primeiro login
- Obrigado a trocar na primeira sessão

#### Editar Permissões

```
Menu Cadastros → Usuários → [Selecionar usuário]
├─ Nome: João Silva (não editável)
├─ Email: joao@email.com (editável)
├─ Perfil: CONDOMINO (editável)
├─ Unidades permitidas: (editável)
│  ├─ ☑ Unidade 101
│  ├─ ☑ Unidade 102
│  └─ Botão "Salvar"
└─ Novo token gerado automaticamente
   └─ Sessão ativa encerrada (usuario faz logout/login)
```

#### Revogar Acesso

```
Menu Cadastros → Usuários → [Selecionar usuário]
├─ Botão "Desativar Usuário"
└─ Confirmação: "Desativar [Nome]? Não poderá mais acessar."
   └─ SIM: Token revogado, login bloqueado
```

### 2.8 Dúvidas Frequentes (Admin)

**P: Como forço recalcular dashboard?**  
R: Menu Auditoria → Dashboard → Botão "Atualizar". Força execução imediata.

**P: Um período foi auditado errado. Como refaço?**  
R: Reabra o período, corrija os dados, refecha. Nova auditoria executada.

**P: Quem modificou isso e quando?**  
R: Cada anomalia registra usuário e timestamp (R_E_C_D_E_L_ em ANOMALIA_LOG).

**P: Posso restaurar um período deletado?**  
R: Não. Soft-delete marca como deletado mas não restaura dados. Backup regularmente.

**P: Quantos usuários posso criar?**  
R: Ilimitado. Mas cada um consome uma sessão (até 10 simultâneas recomendado).

---

## Parte 3: Contatos e Suporte

### 3.1 Reportar Problemas

Se encontrar um bug ou anomalia estranha:

```
1. Anote:
   ├─ Data e hora exata do problema
   ├─ O que você fez (passos)
   ├─ O que esperava
   ├─ O que aconteceu
   ├─ Período afetado
   └─ Usuário que estava usando

2. Contate:
   ├─ Admin do condomínio (se é usuário comum)
   └─ @peder1981 via GitHub Issues (se é admin)

3. Aguarde resposta:
   └─ Prioridade CRITICA: < 2h
   └─ Prioridade ALTA: < 24h
   └─ Prioridade NORMAL: < 3 dias
```

### 3.2 Escalação

```
Tipo de Problema          → Contato             → Tempo
─────────────────────────────────────────────────────────
Senha esquecida           → Admin do condomínio → 1h
Dados incorretos          → Admin do condomínio → 24h
Anomalia estranha         → @peder1981 GitHub   → 2h
Bug na auditoria          → @peder1981 GitHub   → ASAP
Feature request           → Discussions         → Próx Sprint
Treinamento de usuários   → Admin do condomínio → Agendado
```

### 3.3 Horários de Atendimento

```
Seg-Sex: 09:00-18:00 (respostas rápidas)
Fim de semana: Respostas na segunda-feira
Feriados: Respostas no próximo dia útil
```

---

## Apêndice: Glossário

| Termo | Significado |
|-------|-----------|
| **Anomalia** | Inconsistência contábil detectada automaticamente |
| **Alerta** | Notificação ao admin sobre anomalia crítica |
| **Dashboard** | Painel de controle com resumo de anomalias |
| **Snapshot** | Fotografia do estado em determinado momento |
| **Período Fechado** | Mês não pode ser editado, auditoria completa |
| **Rateio** | Divisão de despesas entre unidades por fração |
| **Token** | Identificador de sessão (válido por 24h) |
| **Desequilíbrio** | Débito ≠ Crédito em partida dupla |
| **Órfão** | Lançamento/cobrança sem relacionamento |
| **Soft-delete** | Marcar como deletado sem remover do banco |

---

## Apêndice: Checklists Rápidas

### Para Condôminos

```
☐ Acessei o portal com meu usuário?
☐ Visualizei meu extrato do mês?
☐ Anotei meus próximos vencimentos?
☐ Li os avisos importantes?
☐ Fiz logout ao terminar?
```

### Para Administradores

```
☐ Auditoria rodou após fechamento?
☐ Anomalias detectadas foram revisadas?
☐ Alertas críticos foram lidos?
☐ Perí­odos encerrados estão fechados?
☐ Usuários têm permissões corretas?
```

---

**Fim do Manual do Usuário**  
*Para perguntas, contate seu administrador ou abra uma issue no GitHub.*
