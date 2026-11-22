# Guia de Utilização — GesCon

Instalação, execução, servidor, cópia de segurança e problemas comuns. Para o
uso das telas, ver o [Manual do usuário](MANUAL_USUARIO.md).

## 1. O que é

Sistema de gestão condominial em AdvPL/TLPP, executado pelo
[AdvPP](https://github.com/peder1981/AdvPP). A interface é web (componentes
PO-UI) servida pelo `advplc serve`; o banco é SQLite. Vários condomínios numa
instalação, separados por condomínio (filial).

## 2. Computador do escritório (pacote)

| Sistema | Arquivo | Como |
|---|---|---|
| Windows 10/11 | `gescon-setup-<versão>.exe` | Instala por usuário em `%LOCALAPPDATA%\Programs\GesCon`, sem administrador; atalho **GesCon** na área de trabalho e no menu Iniciar |
| Windows (sem instalar) | `GesCon-<versão>-windows-amd64.zip` | Descompacte e abra `GesCon.exe` |
| Linux | `GesCon-<versão>-linux-amd64.tar.gz` | Descompacte e rode `./GesCon` |
| macOS (Apple Silicon) | `GesCon-<versão>-darwin-arm64.tar.gz` | Descompacte e rode `./GesCon` |

O programa **GesCon** (o iniciador):

1. cria a pasta de dados do usuário: `%LOCALAPPDATA%\GesCon` no Windows,
   `~/.local/share/gescon` no Linux e macOS;
2. na primeira vez, gera a senha inicial do `admin`, grava em `gescon.env`
   (só o usuário lê) e abre `PRIMEIRO-ACESSO.txt` com ela;
3. sobe o servidor em `http://127.0.0.1:8086` (só esta máquina acessa) e
   abre o navegador. Se o GesCon já estiver aberto, só abre o navegador.

No primeiro login o GesCon pede uma senha nova; depois apague o
`PRIMEIRO-ACESSO.txt`. Outra porta: `GESCON_PORTA=8090` no `gescon.env`.
Registro do servidor: `gescon.log` na pasta de dados.

O servidor continua no ar ao fechar o navegador; para pará-lo, rode
`GesCon --encerrar` (ou saia da sessão do Windows). Atualizar ou desinstalar
com o GesCon aberto funciona: o instalador encerra antes o servidor desta
instalação (e só ele).

## 3. Servidor (vários computadores, acesso pela internet)

`deploy/02-setup-advpp.sh` prepara uma máquina Debian 12: instala o `advplc`
da versão em `ADVPP_VERSION`, clona o GesCon, cria o banco, gera a senha
inicial em `/etc/gescon/gescon.env` (0600) e cria o serviço systemd
`gescon` (`advplc serve gescon.prw --port 8080`, mensagens internas só no
journal). Para publicar na internet, ponha um proxy com HTTPS na frente (o
exemplo do projeto usa Cloudflare Tunnel: `deploy/03-setup-cloudflared.sh`)
e defina `ADVPP_WEBUI_ALLOWED_HOSTS=<seu domínio>` no serviço — o `advplc`
recusa Host que não seja da própria máquina. Detalhes em
[`deploy/README.md`](deploy/README.md).

## 4. Variáveis de ambiente

| Variável | Para |
|---|---|
| `GESCON_ADMIN_SENHA` | Senha inicial do `admin`; só vale com a tabela de usuários vazia (mínimo 10 caracteres, maiúscula, minúscula, número e especial) |
| `GESCON_SMTP_HOST`, `_PORT`, `_USER`, `_PASS`, `_FROM` | Mala direta |
| `ADVPP_DB` | Banco SQLite (no pacote, o iniciador usa a pasta de dados) |
| `GESCON_PORTA` | Porta do pacote (padrão 8086) |
| `ADVPP_WEBUI_HIDE_LOG=1` | Mensagens internas fora do navegador (o pacote e o deploy já definem) |

Sem usuários e sem `GESCON_ADMIN_SENHA`, a tela de entrada explica o que
fazer: ninguém cria administrador pela tela.

## 5. Cópia de segurança

Tudo está num arquivo: `gescon.db` na pasta de dados (com `gescon.db-wal` e
`gescon.db-shm` enquanto o sistema está aberto). Com o GesCon fechado, copie
a pasta inteira; com ele aberto, use `sqlite3 gescon.db ".backup copia.db"`.
No servidor, `deploy/05-backup-setup.sh` agenda uma cópia diária.

## 6. Desenvolvimento

```bash
scripts/bootstrap-db.sh                        # banco em ~/.advpp/ADVPP.db
GESCON_ADMIN_SENHA='Uma#SenhaForte1' ./gescon   # http://127.0.0.1:8086
scripts/test.sh                                # exige o advplc de ADVPP_VERSION
scripts/check.sh                               # sintaxe, alcance, isolamento por condomínio
scripts/check-migracao-filial.sh               # banco antigo sobe limpo
packaging/build-package.sh <versão>            # pacotes e instalador
```

## 7. Problemas comuns

**A página não abre** — veja `gescon.log` na pasta de dados. Porta ocupada
por outro programa: defina `GESCON_PORTA` no `gescon.env`.

**"Nenhum usuário cadastrado"** — falta `GESCON_ADMIN_SENHA` (no pacote, ela é
gerada na primeira execução; se o `gescon.env` foi apagado, o iniciador gera
outro).

**"Usuário bloqueado por excesso de tentativas"** — 15 minutos, ou um
administrador desbloqueia em Usuários.

**"test: advplc vX no PATH, mas ADVPP_VERSION pede vY"** — instale o `advplc`
da versão fixada (a suíte recusa outra versão de propósito).

**Acentos trocados** — algum fonte voltou a CP-1252; os deste projeto são
UTF-8 (`scripts/check.sh` acusa).

**403 atrás de proxy** — defina `ADVPP_WEBUI_ALLOWED_HOSTS` com o domínio
público.
