# Manual do Usuário — GesCon

Como operar o sistema, tela por tela.
Para instalar e compilar, veja [GUIA_UTILIZACAO.md](GUIA_UTILIZACAO.md).

---

## Entrando

Abra com `./gescon`. A primeira tela pergunta como você quer acessar:

- **Administrador** — login e senha, dá acesso a todo o sistema
- **Sou condômino** — token temporário, mostra só as cobranças da sua unidade

Navegue com as setas e Enter, ou com o mouse. Em qualquer menu, **Voltar**
retorna ao anterior.

---

## Menu principal

| Opção | O que faz |
|---|---|
| Unidades | cadastro das unidades e suas frações ideais |
| Condôminos | cadastro dos condôminos |
| Despesas | lançamento avulso de despesas |
| Cobranças | consulta e registro de pagamento |
| Fechamento Mensal | fecha a competência e gera as cobranças |
| Mala Direta | envia cobranças por e-mail |
| Relatórios | balancete, inadimplência, extrato, despesas por categoria |
| Contabilidade | lançamentos, validações, balancete, cadastros contábeis |
| Auditoria | detecção de anomalias e alertas |
| Boletos | configuração bancária e emissão |
| Avisos | comunicados do condomínio |
| Usuários | tokens de acesso e criação de usuários |
| Trocar Senha | troca a senha do próprio usuário |

---

## Cadastros

**Unidades, Condôminos, Despesas** abrem uma grade com **Novo**, **Editar** e
**Excluir**. A fração ideal da unidade é o que determina o rateio: a soma das
frações de todas as unidades ativas deve fechar em 1,0 (100%).

---

## Contabilidade

A contabilidade é em partida dobrada: todo lançamento tem uma conta de débito
e uma de crédito, e o total de débitos precisa igualar o de créditos.

### Antes de começar

1. **Abrir Exercício** — informe o código (AAAA-MM), a data de início e a de
   fim. O novo exercício passa a ser o ativo e o anterior é desativado; só
   existe um ativo por vez.
2. **Plano de Contas** — o sistema já vem com 20 contas. Só as contas
   cadastradas e ativas podem ser usadas em lançamento.
3. **Tipos de Repartição** — como a despesa se divide entre as unidades.

### Lançamentos

| Opção | Quando usar |
|---|---|
| Novo Lançamento | lançamento manual, você informa as duas contas |
| Lançar Despesa com Rateio | despesa que se divide entre as unidades e vira cobrança |
| Editar Histórico | corrige a descrição de um lançamento |
| Excluir Lançamento | remove um lançamento |
| Consultar Lançamentos | grade com tudo do exercício |

**Novo Lançamento** pede data (AAAAMMDD), conta de débito, conta de crédito,
valor e histórico. O valor aceita vírgula decimal (`1500,50`).

**Lançar Despesa com Rateio** primeiro pergunta o tipo de rateio, depois a
data, descrição, valor total e o dia de vencimento. O sistema divide o valor
entre as unidades conforme a fração ideal e gera as cobranças.

Lançamentos automáticos (gerados por rateio ou fechamento) não podem ser
editados nem excluídos, e nada é aceito em exercício já fechado.

### Validações e fechamento

- **Validar Integridade** — confere se débitos igualam créditos
- **Gerar Balancete** — consolida receitas, despesas e saldo do período
- **Auditar Período** — roda a auditoria do fechamento
- **Fechar Período** — encerra o exercício e abre o seguinte

Feche o período só depois que a integridade estiver validada. Depois de
fechado, o exercício não aceita mais lançamento.

---

## Auditoria

Procura inconsistências que o uso normal não revela.

| Opção | O que mostra |
|---|---|
| Auditar Período Completo | roda os seis validadores de uma vez |
| Rodar Validador Individual | roda um só, para investigar um tipo |
| Anomalias Detectadas | grade com tudo que foi encontrado |
| Alertas | avisos críticos; dá para marcar como visto |
| Painel do Período | contadores por tipo de anomalia |

Os seis validadores:

1. **Desequilíbrio contábil** — débitos diferentes de créditos. É o mais
   grave: invalida o balancete do período, e gera alerta crítico.
2. **Lançamentos órfãos** — lançamento sem exercício válido
3. **Cobranças órfãs** — cobrança sem unidade correspondente
4. **Rateio inválido** — soma do rateio diferente do valor da despesa
5. **Timing de lançamentos** — lançamento com data fora do período
6. **Alteração em período fechado** — mexeram em exercício já encerrado

O painel só existe depois de rodar *Auditar Período Completo* ao menos uma
vez para aquele período.

---

## Cobranças e boletos

**Cobranças > Registrar Pagamento** lista as cobranças pendentes; escolha uma
e informe a data do pagamento (AAAAMMDD). Só o status e a data de pagamento
mudam — o valor nunca é alterado.

**Boletos > Configurar Dados Bancários** guarda banco, agência, conta,
cedente e carteira. Há fórmula implementada para **Itaú (341)** e
**Bradesco (237)**.

**Boletos > Gerar Boleto** escolhe a cobrança e mostra a linha digitável e o
código de barras. Configure os dados bancários antes.

---

## Avisos

Comunicados do condomínio. **Criar Aviso** pede título e texto;
**Arquivar Aviso** tira um aviso de circulação sem apagá-lo.

---

## Usuários

**Gerar Token** cria um acesso temporário para um condômino usar a opção
*Sou condômino*. O token vale 48 horas e serve uma vez só.
**Revogar Token** cancela um token antes do prazo.
**Criar Usuário** cadastra um novo administrador.

---

## Perguntas frequentes

**"Nenhum exercício ativo"** — abra um em *Contabilidade > Abrir Exercício*.

**"Exercício está fechado"** — período encerrado não aceita lançamento. Abra
o exercício seguinte.

**"Conta não existe no plano de contas"** — cadastre-a em *Contabilidade >
Plano de Contas*, ou confira o código digitado.

**O rateio não fecha** — a soma das frações ideais das unidades ativas
precisa dar 1,0. Confira em *Unidades*.

**Cancelei o formulário e quero ter certeza de que nada foi gravado** — nada
é gravado quando você cancela. O sistema só grava depois de **Confirmar**.

---

## Glossário

| Termo | Significado |
|---|---|
| Competência | mês de referência, no formato AAAA-MM |
| Exercício | período contábil aberto; só um fica ativo por vez |
| Fração ideal | participação da unidade no condomínio; base do rateio |
| Rateio | divisão de uma despesa entre as unidades |
| Partida dobrada | todo lançamento tem débito e crédito de igual valor |
| Balancete | consolidação de receitas, despesas e saldo do período |
| Anomalia | inconsistência encontrada pela auditoria |
| Linha digitável | numeração do boleto para pagamento manual |
