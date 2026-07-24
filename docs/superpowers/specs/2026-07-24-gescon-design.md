# GesCon — Sistema de Gestão Condominial (design v1)

**Data**: 2026-07-24
**Status**: aprovado pelo usuário, pronto para plano de implementação

## Propósito

GesCon é um sistema de gestão condominial escrito inteiramente em AdvPL/TLPP,
compilado e executado pelo [AdvPP](https://github.com/peder1981/AdvPP). Serve
dois objetivos simultâneos, ambos igualmente reais:

1. **Case de validação técnica**: dogfooding do compilador/VM AdvPP contra uma
   aplicação de negócio completa — não só compatibilidade sintática com fontes
   Protheus de terceiros (já validada via corpus real), mas correção de
   runtime numa aplicação escrita do zero: banco de dados, regras de negócio
   financeiras, cálculo, geração de relatórios, interface web.
2. **Uso real**: o sistema deve ser bom o suficiente para administrar um
   condomínio de verdade, não só compilar e rodar.

## Escopo desta fase (v1)

Fora do escopo desta primeira fatia, deliberadamente:

- **Multi-tenant** — uma instância administra um único condomínio. Se
  necessário para outro condomínio, sobe-se outra instância.
- **Boleto bancário real** — sem código de barras/linha digitável válidos,
  sem integração com banco. `Cobrança` é um registro de débito interno
  (valor, vencimento, status), não um boleto FEBRABAN.
- **Múltiplos papéis de usuário** — login único de administrador (síndico).
  Sem porteiro, sem portal do condômino, sem controle de permissões.
- **Envio real de mala direta** — o sistema gera o conteúdo (texto
  personalizado por condômino), mas não envia e-mail. Ver seção "Envio de
  e-mail" abaixo.

## Arquitetura

Repositório próprio (`~/Projetos/GesCon`), fonte AdvPL/TLPP puro, sem
dependência de código do AdvPP além do próprio compilador/runtime (`advplc`)
como ferramenta externa — o mesmo binário que qualquer outra fonte AdvPL usa.

**Interface**: web, via `advplc serve gescon.prw`. Telas construídas com
`FWMBrowse`/`FWFormModel`/`FWFormView`, renderizadas como PO-UI no navegador
— mesmo padrão já validado em `tests/mvc_browse_test.prw` do AdvPP. Escolhido
em vez de REST puro ou desktop Fyne porque entrega uma UI usável desde o dia
1, acessível de qualquer dispositivo sem instalação.

**Banco de dados**: SQLite via a camada de DB já compartilhada do AdvPP.
Tabelas criadas por DDL simples na inicialização, seguindo a mesma convenção
de exclusão lógica estilo Protheus que o AdvEditor já usa (`R_E_C_N_O_`,
`D_E_L_E_T_`, `R_E_C_D_E_L_`) — o mesmo arquivo `.db` pode ser aberto no
AdvEditor para inspeção/administração manual se necessário.

**Autenticação**: tela de login simples gate na frente das demais telas,
usuário administrador único (v1). Sem sessões multi-usuário, sem papéis.

## Modelo de dados

| Entidade | Campos principais |
|---|---|
| **Unidade** | código, bloco, fração ideal, condômino responsável (FK) |
| **Condômino** | nome, CPF, e-mail, telefone |
| **Despesa** | descrição, categoria, valor, competência (mês/ano), data de lançamento |
| **Cobrança** | unidade (FK), competência, valor (travado no fechamento), vencimento, status (pendente/pago/atrasado), data de pagamento |
| **Usuário** | login, senha (hash) — linha única para o admin |

`Cobrança` é gerada apenas pela ação de Fechamento Mensal (ver abaixo) e
nunca recalculada retroativamente — uma vez fechado, o valor de um mês fica
travado mesmo que a fração ideal de uma unidade mude depois. Isso é
deliberado: reflete como fechamento contábil real de condomínio funciona, e
evita que correções cadastrais futuras reescrevam cobranças já geradas ou
pagas.

## Fluxo de dados e operações principais

1. **Cadastro de Unidades / Condôminos** — CRUD padrão via `FWMBrowse`.
2. **Lançamento de Despesas** — CRUD com competência obrigatória.
3. **Fechamento Mensal** (ação central do sistema): dado um mês/ano, soma as
   despesas da competência, calcula `valor = total_despesas × fração_ideal`
   por unidade ativa, grava uma `Cobrança` por unidade com vencimento (dia
   configurável do mês seguinte) e status `pendente`.
   - **Trava**: bloqueia fechar a mesma competência duas vezes (checagem de
     `Cobrança` existente antes de gerar).
   - **Aviso, não bloqueio**: soma de frações ideais ≠ 100% (comum na
     prática real, por causa de áreas comuns/ajustes históricos).
   - **Aviso, não bloqueio**: fechar competência sem nenhuma despesa
     lançada — pede confirmação antes de prosseguir.
4. **Registrar Pagamento** — marca uma `Cobrança` como paga (status + data).
5. **Login** — tela de acesso antes de qualquer outra tela.

## Relatórios e comunicação

Nenhum exige mudança no modelo de dados acima — são leitura sobre o que já
existe:

- **Balancete mensal**: receitas (soma de `Cobrança` pagas) × despesas (soma
  de `Despesa` da competência) × saldo, por mês/ano.
- **Relatório de inadimplência**: unidades com `Cobrança` em status
  `atrasado` (vencimento passado e não paga), valor e dias de atraso.
- **Extrato por unidade**: histórico de cobranças/pagamentos de uma unidade.
- **Relatório de despesas por categoria**: soma agrupada por `categoria` no
  período.
- **Mala direta (geração, não envio)**: monta uma mensagem personalizada por
  condômino (nome, unidade, situação/saldo) a partir dos dados já
  cadastrados, exportada como texto pronto para uso manual (copiar/colar,
  anexar a um e-mail).

### Envio de e-mail (fora do escopo desta fase)

O AdvPP não implementa hoje nenhuma native de envio de e-mail (`TMailMessage`/
SMTP). Decisão explícita: **não** implementar isso agora, para respeitar a
prioridade já definida de estabilizar o compilador antes de adicionar
features novas. GesCon v1 gera o conteúdo da mala direta mas não envia.

**Item de roadmap registrado**: implementar `TMailMessage`/SMTP real no
AdvPP como uma fase futura, após o GesCon estar funcional — nesse ponto vira
a próxima feature natural do compilador (uso real já demonstrado pela
necessidade do GesCon), não uma feature especulativa.

## Testes

Estratégia de teste dupla, aproveitando que isto é dogfooding do compilador:

- Todo fonte roda por `advplc check` continuamente durante o desenvolvimento
  (equivalente a um gate de lint/CI).
- O fluxo de negócio central — cadastrar unidade → lançar despesa → fechar
  mês → conferir valores calculados por fração ideal → registrar pagamento →
  conferir status — vira um fixture de teste end-to-end via `advplc run`, no
  mesmo espírito dos fixtures de regressão já usados no próprio AdvPP. Serve
  dois propósitos ao mesmo tempo: valida a regra de negócio do GesCon E
  funciona como mais uma fonte de detecção de gaps de linguagem reais, sem
  depender de corpus de terceiros.

## Decisões explícitas registradas (para não reabrir sem necessidade)

- Fechamento mensal é a única forma de gerar `Cobrança` — nunca cálculo
  on-the-fly. Justificativa: correção contábil/auditoria.
- Fração ideal por unidade, não divisão igual nem regra configurável por
  tipo de despesa — mais simples que "configurável por despesa" e mais
  correto que "divisão igual" para uso real.
- Mala direta gera conteúdo, não envia — SMTP fica para depois.
- Login único de administrador — sem papéis/permissões nesta fase.
- Vínculo Unidade→Condômino (`UNI_CONDOMINO`) é o código digitado como
  texto, sem combo/lookup vinculado — `FWMBrowse` não expõe esse tipo de
  campo relacionado na v1 desta integração. Aceitável para o volume de
  dados de um condomínio (dezenas de unidades, não milhares).
- API de banco descoberta durante o planejamento: a API clássica de
  work-area do AdvPP (`DbAppend`/`RecLock`/`FieldPut`/`MsUnlock`) não
  persiste dados de verdade (confirmado por teste direto) — só `FWMBrowse`
  grava, via código interno acionado por clique na UI. GesCon depende de
  `TCSqlExec`/`TCSqlQuery`, duas natives novas expostas no AdvPP v1.22.0
  especificamente para viabilizar o Fechamento Mensal (que precisa gravar
  a partir de lógica de negócio, não de clique de UI).
