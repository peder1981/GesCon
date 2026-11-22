# Etapa 3 — interface nova (PO-UI, web) — desenho

Data: 2026-11-21. Parte da refatoração "GesCon produto para vender"
(`2026-11-21-refatoracao-advpp485-achados.md`).

## Decisões

- **Uma aplicação web `PoApp`** servida por `advplc serve gescon.prw`, no
  lugar do menu de diálogos (`FWMenuSelect`/`FWGetText`) e das grades
  `FWMBrowse`. A janela nativa Fyne sai: `PoApp` só existe no modo web. No
  Windows, um pacote instala e abre no navegador (etapa 3f, como o GEBAN).
- **Três camadas**, para testar sem navegador:
  - `src/cadastros.prw`: gravação de unidade, condômino, despesa e
    condomínio, com validação (as grades genéricas gravavam qualquer coisa;
    só os gatilhos do banco seguravam algo).
  - `src/consultas.prw`: cada tabela e relatório é uma função que devolve
    `{colunas, linhas}` lidas direto da consulta. Some o uso das tabelas de
    rascunho `RPT_*` compartilhadas por condomínio, que vazavam dados entre
    sessões (no portal, entre unidades).
  - `src/ui.prw`: só montagem de tela e repasse para as duas camadas acima.
- **Permissão por perfil** (`GcPode(cAcao)` em `src/seguranca.prw`):
  SUPERADMIN tudo; SÍNDICO tudo do próprio condomínio, menos cadastro de
  condomínios e criação de super administrador. O menu só mostra o que o
  perfil pode; cada ação confere de novo.
- **Sessão expira** após 30 min sem ação (cronômetro do `PoApp`): a tela
  volta ao login.
- **Portal do condômino** na mesma tela de entrada (campo do token): só
  leitura, consultas filtradas pela unidade do token.

## Páginas (administração)

Início (indicadores e despesas por categoria) · Unidades · Condôminos ·
Despesas · Fechamento · Cobranças (pagamento, boleto) · Comunicação (mala
direta, avisos, tokens do portal) · Relatórios (balancete, inadimplência,
extrato da unidade, despesas por categoria) · Contabilidade (lançamentos,
plano de contas, exercícios, validação, balancete, fechar período) ·
Auditoria · Usuários · Condomínios (só super) · Minha senha · Trocar
condomínio · Sair.

## Fases (cada uma com commit e testes)

3a casca (login, troca obrigatória, condomínio, menu, permissões, sessão,
portal) · 3b cadastros · 3c operações · 3d relatórios e início · 3e remoção
da interface antiga, documentação e capturas · 3f pacote Windows.

## Estado (2026-11-22)

Fases 3a a 3f concluídas. Conferido no navegador (Playwright) a cada fase e
no Windows 10 (VM QEMU com disco em snapshot): instalação por usuário,
primeiro acesso com a senha gerada, troca obrigatória, atualização com o
GesCon aberto e desinstalação que preserva os dados.

Achados no AdvPP 4.8.6 (para uma próxima versão dele): `PoSelect` não troca
as opções depois de montado (`poToJSON` não converte `JsonObject`, então
`Set("options", ...)` não serve); `PoNumber` é `type=number` de passo
inteiro (sem vírgula nem decimais).

Achado no instalador: o NSIS é 32 bits e, num Windows de 64 bits, o
PowerShell que ele chama não lê o caminho de processos de 64 bits; o
encerramento do servidor passou para o próprio iniciador
(`GesCon --encerrar`, PIDs em `gescon.pid`).
