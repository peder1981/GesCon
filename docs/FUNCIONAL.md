# Documentação funcional — GesCon

O que o GesCon faz, do ponto de vista de quem administra um condomínio.
Para como o sistema é construído por dentro, ver
[`ARQUITETURA.md`](ARQUITETURA.md).

## Visão geral

GesCon é um sistema de gestão condominial: cadastro de unidades e
condôminos, lançamento de despesas, rateio mensal por fração ideal,
cobrança e registro de pagamento, mala direta por e-mail, relatórios,
e login de administrador. Um condomínio por instância — se precisar
administrar mais de um, sobe-se outra instância do sistema.

## Login

Gate de acesso antes de qualquer tela — administrador único, sem
papéis/permissões. No primeiro acesso (nenhum usuário cadastrado
ainda), o sistema pede pra escolher login e senha e cria o
administrador na hora. Nos acessos seguintes, pede login e senha e
confere contra o que foi cadastrado (até 3 tentativas). A senha nunca
é gravada em texto puro — sempre em hash SHA-256 (`FWHash`, AdvPP
v1.23.5+).

**Limitação conhecida**: não existe campo de senha mascarado no AdvPP
hoje (`FWGetText` é um campo de texto comum) — a senha fica visível
enquanto é digitada, tanto na criação quanto no login.

## Menu e navegação

`advplc serve gescon.prw` (sobe em `http://localhost:8080` por padrão)
mostra a tela de login e, depois, um **menu real** — clique numa opção
pra abrir a tela, feche a tela (botão "Fechar browse") pra voltar ao
menu. Nenhum reinício de processo, nenhuma troca de porta/aba:

1. Unidades
2. Condôminos
3. Despesas
4. Cobranças
5. Fechamento Mensal (pede a competência e o dia de vencimento, mostra o resultado)
6. Mala Direta (pede a competência, mostra quantos e-mails foram enviados)
7. Relatórios (abre um submenu — ver seção própria abaixo)
8. Sair

## Telas

As quatro primeiras dão CRUD completo (Incluir, Alterar, Excluir,
Consultar) automaticamente:

- **Condôminos** — nome, CPF, e-mail, telefone.
- **Unidades** — código, bloco, fração ideal, e o código do condômino
  responsável (digitado como texto — não há um seletor vinculado).
- **Despesas** — descrição, categoria, valor, competência (mês/ano no
  formato `YYYY-MM`), data de lançamento.
- **Cobranças** — consulta das cobranças geradas pelo Fechamento
  Mensal (unidade, competência, valor, vencimento, status, data de
  pagamento). Tecnicamente editável pela mesma tela de CRUD — ver
  "Limitações" abaixo.

Fechamento Mensal e Mala Direta não são telas de cadastro — são ações:
o menu pede a competência (`FWMenuSelect`/`FWGetText`, capacidades do
AdvPP v1.23.0+) e mostra o resultado num diálogo, sem sair do menu.
Relatórios (abaixo) usam o mesmo mecanismo de submenu.

## Fechamento Mensal

A ação central do sistema. Dado um mês/ano (competência), soma todas as
despesas lançadas naquela competência e gera uma Cobrança por unidade
ativa, proporcional à fração ideal de cada uma:

```
valor da cobrança da unidade = total de despesas da competência × fração ideal da unidade
```

Regras:

- **Só pode ser feito uma vez por competência.** Tentar fechar uma
  competência que já tem Cobrança gerada é bloqueado — não recalcula,
  não duplica.
- **O valor gerado fica travado.** Mesmo que a fração ideal de uma
  unidade mude depois, as Cobranças já geradas não são recalculadas
  retroativamente — reflete como fechamento contábil real funciona, e
  evita que uma correção cadastral reescreva cobranças já pagas.
- **Avisa, mas não bloqueia**, em dois casos: se a soma das frações
  ideais das unidades ativas não bate com 100%, ou se a competência não
  tem nenhuma despesa lançada (nesse caso, gera Cobranças de valor
  zero — fecha mesmo assim).
- O vencimento de cada Cobrança é no mês seguinte à competência, num
  dia configurável (o menu pergunta; padrão dia 10). Dias fora da faixa
  1-28 caem no padrão (evita datas inválidas em fevereiro).

## Registrar Pagamento

Marca uma Cobrança específica como paga, com a data informada. Só altera
o status e a data de pagamento — nunca o valor da cobrança.

## Mala direta

Envia um e-mail individual para cada condômino com Cobrança pendente
(não paga) numa competência — nome, unidade, valor, vencimento e
situação. Só envia para condôminos com e-mail cadastrado; quem não tem,
é pulado silenciosamente (registrado no log). Se o envio falhar para um
condômino específico (servidor fora do ar, e-mail inválido), os demais
ainda recebem — uma falha isolada não interrompe o lote.

Para funcionar, o servidor SMTP precisa estar configurado (ver
[`README.md`](../README.md), seção "Mala direta"). Sem essa
configuração, a mala direta simplesmente não envia nada (sem erro).

## Relatórios

Acessados via "Relatórios" no menu principal (abre um submenu com as 4
opções abaixo + "Voltar"). Todos são leitura sobre os dados já
cadastrados — nenhum muda Cobrança, Despesa, Unidade ou Condômino.

- **Balancete Mensal** — pede a competência, mostra num diálogo:
  receitas (soma de Cobrança com status `pago`), despesas (soma de
  Despesa lançada), saldo (receitas − despesas).
- **Inadimplência** — lista, sem precisar de nenhum parâmetro, toda
  Cobrança em status `atrasado`: unidade, competência, valor,
  vencimento, dias de atraso. Antes de listar, promove pra `atrasado`
  toda Cobrança `pendente` com vencimento já passado (`GcAtualizarInadimplentes`
  — também roda automaticamente logo após o login, então o status
  gravado na Cobrança em si — visível também na tela de Cobranças e na
  Mala Direta — nunca fica desatualizado por mais que a duração de uma
  sessão).
- **Extrato por Unidade** — pede o código da unidade, lista todo o
  histórico de Cobrança dela (competência, valor, vencimento, status,
  data de pagamento).
- **Despesas por Categoria** — pede a competência (vazio = todas),
  soma as despesas agrupadas por categoria, maior valor primeiro.

Cada relatório recalcula seu conteúdo do zero toda vez que é aberto —
sempre reflete os dados mais recentes, não fica desatualizado entre
uma abertura e outra.

## O que ainda não existe (Plano 2)

- **Papéis de usuário** — administrador único, sem porteiro nem portal
  do condômino (login existe, mas sem controle de permissões).
- **Campo de senha mascarado** — depende de uma capacidade que não
  existe no AdvPP hoje (ver "Login" acima).
- **Boleto bancário real** — Cobrança é um registro de débito interno
  (valor, vencimento, status), não um boleto FEBRABAN com código de
  barras/linha digitável.

## Limitações conhecidas (v1)

- **A tela de Cobranças permite editar/excluir registros livremente.**
  A garantia de "valor travado no fechamento" é imposta pela lógica de
  negócio (só o Fechamento Mensal cria Cobrança, só Registrar Pagamento
  altera status/data), não pela interface — nada tecnicamente impede
  alguém com acesso à tela de editar o valor na mão. Aceitável para uso
  com um único administrador de confiança; ver `ARQUITETURA.md` para o
  motivo técnico.
- **Vínculo unidade→condômino é texto livre**, sem validação de que o
  código digitado existe de fato em Condôminos.
- **Os relatórios também são telas de `FWMBrowse`**, então tecnicamente
  dá pra clicar Incluir/Alterar/Excluir neles — não faz sentido editar
  um relatório (o conteúdo é recalculado do zero na próxima abertura,
  então a edição não sobrevive), mas nada impede clicar. Mesma
  limitação técnica da tela de Cobranças.
- Multi-condomínio, multi-usuário e boleto bancário real estão fora do
  escopo desta fase — ver "O que ainda não existe" acima.
