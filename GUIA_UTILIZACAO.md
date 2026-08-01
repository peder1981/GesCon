# Guia de Utilização — GesCon

Instalação, compilação e execução do GesCon.
Para o passo a passo de cada tela, veja [MANUAL_USUARIO.md](MANUAL_USUARIO.md).

---

## 1. O que é

Sistema de gestão condominial escrito em AdvPL, compilado pelo
[AdvPP](https://github.com/peder1981/AdvPP) e executado como **aplicação
desktop** em janela nativa.

Não há servidor, navegador ou banco externo: o executável é autocontido e os
dados ficam num arquivo SQLite.

---

## 2. Pré-requisitos

| Item | Para quê |
|---|---|
| `advplc` (AdvPP) | compilar os fontes |
| Go 1.24+ | `advplc build` gera um binário Go com o bytecode embutido |
| `sqlite3` | criar o banco a partir de `schema.sql` |
| Checkout do AdvPP | o stub gerado importa o módulo; aponte `ADVPP_SRC` |

---

## 3. Instalação

```bash
# 1. Banco de dados (cria as tabelas e semeia plano de contas,
#    exercício, tipos de repartição e 20 unidades de exemplo)
scripts/bootstrap-db.sh

# 2. Executável
export ADVPP_SRC=~/Projetos/AdvPP
scripts/build.sh                    # gera ./GesConApp

# 3. Primeiro administrador
#    O login inicial é criado pela própria tela de login na primeira
#    execução, quando ainda não existe nenhum usuário.
```

O banco padrão é `~/.advpp/ADVPP.db`. Para usar outro, defina `ADVPP_DB`.

---

## 4. Execução

```bash
./gescon
```

**Use sempre `./gescon`, nunca `./GesConApp` direto.** O launcher exporta
`ADVPP_FORCE_GUI=1`, que é obrigatório: sem ele, o executável lançado de um
terminal detecta o TTY e escolhe a interface de terminal, que não implementa
formulários — os menus funcionam e as telas de cadastro quebram. O porquê
está em [docs/PADRAO_GUI.md](docs/PADRAO_GUI.md), seção 4.

---

## 5. Verificação

```bash
scripts/check.sh    # encoding, sintaxe de todos os fontes, alcance dos menus
scripts/test.sh     # 13 suítes de teste, em banco descartável
scripts/build.sh    # executável
```

`check.sh` recusa fonte que não seja UTF-8 e acusa qualquer função de negócio
que tenha ficado sem caminho de menu. `test.sh` monta um banco novo a cada
execução, então não depende do estado do seu banco de desenvolvimento.

---

## 6. Estrutura

```
gescon.prw          ponto de entrada: login e menus
src/                módulos por área (contábil, boleto, portal, auditoria…)
tests/              13 suítes, uma por área
schema.sql          tabelas, índices e dicionário SX3
scripts/            check, test, build, bootstrap do banco
docs/PADRAO_GUI.md  como escrever tela neste projeto
```

Regra de módulo: **nenhum arquivo de `src/` inclui outro**. O AdvPP não tem
include guard, então incluir em cadeia cola o mesmo arquivo várias vezes no
compilado. Quem lista os módulos é `gescon.prw` (ou o arquivo de teste), uma
vez cada.

---

## 7. Problemas comuns

**"MSDIALOG: requer o modo web"** — o app foi executado sem
`ADVPP_FORCE_GUI=1`. Use `./gescon`.

**Acentos aparecem trocados** — algum fonte voltou a CP-1252.
`scripts/check.sh` acusa qual. Os fontes deste projeto são UTF-8; a
convenção CP-1252 do Protheus real não se aplica ao AdvPP.

**"Nenhum exercício ativo"** — abra um em *Contabilidade > Abrir Exercício*.
Lançamentos, rateio e fechamento dependem de um exercício aberto.

**Uma tela abre sem colunas** — falta metadado SX3 da tabela em
`schema.sql`. O `FWMBrowse` monta as colunas a partir do dicionário.

**`advplc build` falha** — confira `ADVPP_SRC` e se o Go está instalado.

---

## 8. Fora do escopo por enquanto

O **portal do condômino** — acesso externo por token, extratos e agenda pela
web — está adiado. O código de autenticação já existe em
`src/auth-primitives.prw`, compilado e testado, mas sem tela: é a base de
quando a fase for retomada. Dentro do app, o condômino já acessa suas
cobranças pela opção *Sou condômino* na tela inicial.
