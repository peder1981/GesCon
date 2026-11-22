# Refatoração GesCon sobre o AdvPP 4.8.5: achados e divisão do trabalho

Data: 2026-11-21. Objetivo do operador: GesCon como **produto para vender**.
Ordem acordada: (1) AdvPP 4.8.5 + bugs e segurança; (2) login; (3) interface
nova (PO-UI, web, com pacote Windows no lugar da janela Fyne); (4) reforma
tributária (IBS/CBS, NFS-e de condomínio).

Ponto de partida: branch `master` em `cd7220d`, AdvPP fixado em 4.4.6.
Com o advplc 4.8.5 a suíte já passa sem mudança (15 suítes, `check`,
`alcance`, `check-filial`, `check-migracao-filial`).

## Projeto 1 — corrigido nesta etapa (branch `refactor/advpp-485`)

Estado: B1 a B9 concluídos, cada um com teste. Suíte: 18 suítes, 0 falha
(eram 15); `check.sh` 40 fontes, 0 erro; `check-migracao-filial` ok;
executável desktop gerado com o 4.8.5; `advplc serve gescon.prw` sobe e o
boot cria o índice único.

| # | Onde | Achado | Correção |
|---|------|---------|----------|
| B1 | `src/boleto.prw` | Boleto não pagável. Fator de vencimento com base 07/09/1997 (correto: 07/10/1997) e travado em 9999 (desde 22/02/2025 o fator volta a 1000, então todo boleto de hoje sai com vencimento 21/02/2025). Valor com 8 dígitos e `Ceiling` (correto: 10 dígitos, arredondado). Código de barras de 43 posições com DVs a mais e módulo 11 com pesos 2-7 (correto: 44 posições, pesos 2-9). Campo livre fora do layout do Itaú e do Bradesco. | Reescrito pelo manual Itaú CNAB 400 (jan/2017, itens 7.3, 7.4 e anexos 2, 3, 4 e 6) e pelo manual Bradesco CNAB 400 (abr/2022, "Montagem dos Dados do Código de Barras"). Testes com os exemplos numéricos dos dois manuais. |
| B2 | `src/fechamento.prw` | Frações ideais fora de 100% só geram aviso no log: com 120% cobra 20% a mais, com 50% arrecada a metade. Competência não validada ("abc" vira vencimento 0000-01-10). Cobranças gravadas uma a uma, fora de transação. Nada impede cobrança duplicada da mesma unidade na mesma competência. | Recusa competência fora de `AAAA-MM` e soma de frações fora de 0,999 a 1,001. Grava todas as cobranças num único `BEGIN;...COMMIT;`. Índice único parcial em `COB (FILIAL, COB_COMPET, COB_UNIDADE)` para registros ativos. |
| B3 | `src/usuarios.prw`, `src/portal.prw` | Token previsível (data + hora + `Random()` + SHA-256). Consumo do token em duas operações (`SELECT` e depois `UPDATE`): dois acessos simultâneos passam com o mesmo token. | Token = 2 × `UUIDRandom()` (aleatório criptográfico, 64 hex). Consumo atômico: `UPDATE ... WHERE USADO = 0` e só então a leitura. |
| B4 | `gescon.prw` | "Arquivar Aviso" lista avisos de todos os condomínios (consulta sem filial). | Filtro por filial. |
| B5 | `src/contabil.prw` | Lançamento manual grava `LAN_USUARIO = 'TEST_USER'`. Lançamentos automáticos (despesa/rateio) podem ser editados e excluídos. Valor sem arredondamento a 2 casas. | `GcUsuarioSessao()` (login da sessão). Edição e exclusão só de `LAN_TIPO = 'MANUAL'`. `Round(nValor, 2)`. |
| B6 | `gescon.prw`, `src/cobrancas.prw` | Data de pagamento não validada (`20261399` vira data vazia; data futura aceita). `GcRegistrarPagamento` devolvia o sucesso do comando: `.T.` mesmo sem alterar linha (cobrança inexistente ou de outro condomínio), e a tela dizia "Pagamento registrado"; regravava a data de cobrança já paga. | Recusa na tela e na função; `UPDATE ... RETURNING`: `.T.` só se a cobrança passou a constar como paga. |
| B7 | `src/malas.prw` | Valor sai cru ("350.5") e vencimento em ISO. E-mail do condômino não validado antes de ir ao cabeçalho. | `Transform("@E 999,999,999.99")`, vencimento DD/MM/AAAA, e-mail validado (sem CR/LF, formato `x@y.z`). |
| B8 | `scripts/check-filial.sh` | Checa por arquivo (basta a palavra FILIAL aparecer uma vez) e ignora `gescon.prw`. Por isso B4 passou. | Checagem por comando SQL, incluindo `gescon.prw`, com lista de exceções justificadas (tabelas globais e migrações). |
| B9 | `ADVPP_VERSION`, CI, deploy | Fixado em 4.4.6. A CI de testes compila o AdvPP da branch principal, sem versão. O `deploy/02-setup-advpp.sh` instala o 3.0.0 do pacote completo (GLIBC 2.38; o servidor é Debian 12, GLIBC 2.36). | 4.8.5 em todos, lido do `ADVPP_VERSION`; deploy com o pacote `advpp-cli`. |

Achados no caminho, corrigidos junto: `GcBoletoGera` lia o vencimento
`AAAA-MM-DD` (formato que o Fechamento grava) com `SToD`, que espera
`AAAAMMDD` -- a data saía vazia; `GcGerarToken` gravava como emissor
`GetEnv("USER")` (usuário do sistema operacional do servidor), por um
`Local` que encobria `cLoginAtual`; o teste antigo do boleto reimplementava
a fórmula e comparava cópia com cópia; o de pagamento só imprimia.

Itens retirados depois de conferidos: `R_E_C_N_O_` repetido em
`LANCAMENTOS` por `MAX+1` concorrente -- é um único comando e o SQLite
serializa as escritas (numa disputa, o segundo recebe "banco ocupado"),
sem evidência de duplicata. `Return` dentro de `Begin Transaction`
não deixa transação aberta, porque no AdvPP (inclusive no 4.8.5)
`Begin/End Transaction` é só marcador (`pkg/parser/expressions.go`,
`parseBeginEndBlock`). As grades `FWMBrowse` já filtram por filial
(`pkg/vm/browse.go`).

## AdvPP — divergência do Protheus achada nesta etapa (corrigir no AdvPP)

`TCSqlExec`/`TCSqlQuery` com erro de SQL (violação de NOT NULL, de índice
único, `RAISE(ABORT)` de gatilho) **encerram o programa**: o erro sai da
função nativa e nem `Try/Catch` nem `ErrorBlock` + `Begin Sequence` o
capturam (testado no 4.8.5). No Protheus, `TCSqlExec` devolve número
negativo e a mensagem fica em `TCSqlError()`. Consequências no GesCon: as
travas por gatilho da tabela de cobranças derrubam a operação em vez de
voltar uma mensagem, e `BEGIN;...COMMIT;` num `TCSqlExec` deixa a
transação aberta se um comando do meio falha. Contorno usado aqui:
gravação em um único comando (atômico no SQLite). Correção proposta no
AdvPP (`pkg/vm/natives.go`, `TCSQLEXEC`): devolver negativo e expor
`TCSqlError()`, como o Protheus.

## Projeto 2 — login (próxima etapa)

- Senha em SHA-256 **sem salt** (`FWHash`): trocar por Argon2id com salt por usuário (`Argon2id` + `UUIDRandom`, nativos do runtime, como no GEBAN), migrando o hash no próximo login bem-sucedido.
- Primeiro acesso: com `USR` vazia, **qualquer visitante** cria o super administrador pela web. Trocar por credencial de primeiro acesso gerada no servidor, como o `GEBSECBOOT` do GEBAN.
- Sem bloqueio por tentativas além do limite de 3 por sessão: basta recarregar a página. Contador e bloqueio por usuário no banco.
- Sem expiração de sessão e sem política de senha.
- Perfis (SUPERADMIN, SÍNDICO, condômino) não aplicados no menu: o síndico vê as mesmas opções do super administrador.

## Projeto 3 — interface (depende do 2)

- Tabelas de rascunho compartilhadas por condomínio (`RPT_COND_COBRANCAS`, `RPT_INADIM`, `RPT_EXTRATO`, `RPT_DESCAT`, `RPT_BALANCETE`...). Na web, sessões simultâneas sobrescrevem umas às outras. **No portal do condômino, um condômino pode ver as cobranças da unidade de outro.** A interface nova lê as linhas direto da consulta, sem tabela de rascunho.
- Grades `FWMBrowse` deixam Incluir/Alterar/Excluir livres. O portal "somente leitura" deixa o condômino editar a própria grade.
- Texto `"\n"` literal na lista de condomínios (`src/login.prw`).

## Projeto 4 — reforma tributária

Pendente de fontes primárias: LC 214/2025 (artigos sobre condomínio
edilício), ato que obriga a NFS-e de condomínio a partir de 01/12/2026
(o artigo de referência não cita norma; o "Ato Conjunto RFB/CGIBS nº 4/2026"
ainda não foi confirmado) e as regras do critério dos 80% (período de
apuração, base de cálculo) e da opção pelo regime regular.
