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

**Revisão em 2026-07-24, depois do menu real (`FWMenuSelect`) ficar
pronto**: o usuário achou o visual web "precário" e pediu uma aplicação
executável direta. `advplc build` já existia no AdvPP (standalone Fyne,
v1.10.2) — GesCon passou a suportar **os dois modos** a partir do mesmo
`.prw`, sem código duplicado: `advplc serve gescon.prw` (web) e `advplc
build gescon.prw -o GesConApp` (desktop nativo). A frase acima
("escolhido em vez de... desktop Fyne") descreve a decisão original do
v1, não mais o estado atual — mantida aqui pelo valor histórico da
justificativa, não como descrição do que existe hoje. Ver
`docs/ARQUITETURA.md`, seção "Stack", para o estado atual.

**Banco de dados**: SQLite via a camada de DB já compartilhada do AdvPP.
Tabelas criadas por DDL simples na inicialização, seguindo a mesma convenção
de exclusão lógica estilo Protheus que o AdvEditor já usa (`R_E_C_N_O_`,
`D_E_L_E_T_`, `R_E_C_D_E_L_`) — o mesmo arquivo `.db` pode ser aberto no
AdvEditor para inspeção/administração manual se necessário.

**Autenticação**: tela de login simples gate na frente das demais telas,
usuário administrador único (v1). Sem sessões multi-usuário, sem papéis.
**Implementado** (`src/login.prw`, `GcLogin`) — ficou pendente durante
boa parte da implementação (nenhuma task do plano cobria explicitamente
essa operação apesar de listada aqui) até ser cobrado numa revisão de
completude e implementado com `FWHash` (AdvPP v1.23.5, hash SHA-256 —
não existia nenhuma função de hash no compilador antes disso).

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
- **Mala direta (geração + envio real)**: monta uma mensagem personalizada
  por condômino (nome, unidade, valor, vencimento, status) a partir das
  cobranças não pagas de uma competência, e envia via `TMailMessage`
  (`GcMalaDireta`, `src/malas.prw`). Balancete, inadimplência, extrato por
  unidade e despesas por categoria continuam no **Plano 2** (leitura
  read-only sobre o modelo existente, sem dependência de capacidade nova
  de compilador).

### Envio de e-mail

**Decisão revista em 2026-07-24, durante o planejamento**: o AdvPP não
implementava nenhuma native de envio de e-mail. A decisão original desta
spec era não implementar isso agora, respeitando a prioridade de
estabilizar o compilador antes de features novas — mas ao planejar o Task 1
(que já precisava mexer no compilador para viabilizar o Fechamento Mensal
via `TCSqlExec`/`TCSqlQuery`), o usuário pediu explicitamente para
adiantar `TMailMessage`/SMTP junto, já que o compilador estava sendo
tocado mesmo. `TMailMessage` (classe nativa, envio real via `net/smtp` da
stdlib) foi implementada no **Plano 1** (Task 3).

**Segunda revisão, ainda em 2026-07-24, após a implementação e revisão
final do branch**: como a única razão original para adiar a mala direta
pro Plano 2 era a ausência de `TMailMessage` — e essa ausência não existe
mais — o usuário pediu para trazer a mala direta pro Plano 1 também.
Implementada em `GcMalaDireta(cCompetencia)` (`src/malas.prw`): busca as
`Cobrança` não pagas da competência via `JOIN` com `Unidade`/`Condômino`,
monta o corpo da mensagem, e envia via `TMailMessage` para cada
condômino com e-mail cadastrado — condôminos sem e-mail são pulados,
falha de envio individual (`Begin Sequence/Recover`) não aborta o
restante do lote. Configuração SMTP via variáveis de ambiente
(`GESCON_SMTP_HOST/PORT/USER/PASS/FROM`), **não** via `GetMV()` — testado
e confirmado que `GetMV()` é um stub no AdvPP (sempre retorna o valor
padrão passado, nunca lê configuração real), então `GetEnv()` é o único
mecanismo real de configuração sem segredo hardcoded disponível hoje.
Sem `GESCON_SMTP_HOST` configurado, `GcMalaDireta` não tenta enviar nada
e retorna 0 (comportamento seguro por padrão). Testado de ponta a ponta
com um servidor SMTP de teste local — ver `tests/malas_test.prw`.

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
- Mala direta trazida pro Plano 1 (decisão revista pela 2ª vez, ver seção
  "Envio de e-mail") — implementada com envio real via `TMailMessage`,
  já que a única razão pra adiar era a ausência dessa capacidade, e ela
  deixou de existir assim que o Plano 1 a implementou. Balancete,
  inadimplência, extrato por unidade e despesas por categoria continuam
  no Plano 2.
- Login único de administrador — sem papéis/permissões nesta fase.
- Vínculo Unidade→Condômino (`UNI_CONDOMINO`) é o código digitado como
  texto, sem combo/lookup vinculado — `FWMBrowse` não expõe esse tipo de
  campo relacionado na v1 desta integração. Aceitável para o volume de
  dados de um condomínio (dezenas de unidades, não milhares).
- API de banco descoberta durante o planejamento: a API clássica de
  work-area do AdvPP (`DbAppend`/`RecLock`/`FieldPut`/`MsUnlock`) não
  persistia dados de verdade (confirmado por teste direto) — só `FWMBrowse`
  gravava, via código interno acionado por clique na UI. Corrigida no
  AdvPP v1.22.0 (persistência real), que também ganhou `TCSqlExec`/
  `TCSqlQuery` — o caminho que o GesCon usa de fato para o Fechamento
  Mensal (que precisa gravar
  a partir de lógica de negócio, não de clique de UI).
- **Limitação conhecida e aceita, registrada na revisão final do branch
  (Plano 1)**: a tela de Cobranças (`GcCobrancas`) usa o mesmo `FWMBrowse`
  editável dos demais cadastros — o que dá Incluir/Alterar/Excluir "de
  graça", inclusive sobre `COB_VALOR`. Isso significa que a garantia
  "valor travado no fechamento, nunca recalculado retroativamente" é
  imposta pela lógica de negócio (`GcFecharMes`/`GcRegistrarPagamento`),
  mas **não é imposta pela UI** — o mesmo administrador que fecha o mês
  também pode editar uma cobrança na mão pelo browse. Aceitável para a
  v1 (login único, sem papéis, uso pessoal/piloto). O AdvPP tem um campo
  `ReadOnly` em `FWFormBrowse` (`pkg/mvc/browse.go`), mas ele não está
  ligado a nada — nem ao dispatch de método nativo, nem ao renderer web
  — então hoje não há como tornar um `FWMBrowse` de fato somente-leitura.
  Tornar isso real exigiria trabalho novo no compilador AdvPP (fora do
  escopo deste plano) ou trocar a tela por algo customizado sem
  `FWMBrowse` no GesCon. Fica como candidato pro Plano 2 se o uso real
  mostrar que o risco importa.
