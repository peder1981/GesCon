# GesCon — Guia Homelab Proxmox

> **Para qualquer agente/modelo:** este é o ponto de entrada único para
> entender onde está o GesCon rodando, como analisar problemas, fazer
> deploy, backups e qualquer operação de infraestrutura.

---

## 📍 Onde Roda

| Item | Valor |
|------|-------|
| **Projeto** | `/home/peder/Projetos/GesCon` (laptop-peder) |
| **Produção** | LXC 105 no homelab Proxmox |
| **IP** | `192.168.2.105/24` |
| **Hostname** | `gescon` |
| **URL externa** | `https://gescon.itmix.com.br` |
| **Stack** | AdvPP v3.0.6 + SQLite + Cloudflare Tunnel |

---

## 🗺️ Mapa do Homelab

```
homelab-lan (192.168.1.14) — Proxmox VE 8
├── LXC 101 (ernesto)     — Ollama, RAG, Mem0, MCP, ChromaDB
├── LXC 102 (meugerente)  — Bot Telegram + painel web
├── LXC 103 (justatistic) — PostgreSQL, Streamlit, Ollama
├── LXC 104 (blu)         — Conciliação, Streamlit, SQLite
└── LXC 105 (gescon)      — GesCon (AdvPP web + SQLite)
```

---

## 🔑 Como Acessar

```bash
# SSH direto para a LXC do GesCon
ssh lxc105

# Via Proxmox (host)
ssh homelab-lan
pct enter 105

# Acesso externo (web)
https://gescon.itmix.com.br
```

**ProxyJump:** todas as LXCs usam `ProxyJump homelab-lan` no `~/.ssh/config`.

---

## 📁 Estrutura em Produção

```
LXC 105 (gescon)
├── /opt/gescon/                    ← Código-fonte (clone do git)
│   ├── gescon.prw                  ← Entry point
│   ├── schema.sql                  ← DDL do banco
│   └── ...
├── /usr/local/bin/advplc           ← Binário AdvPP v3.0.6
├── ~/.advpp/ADVPP.db               ← Banco SQLite (dados)
├── /etc/systemd/system/
│   ├── gescon.service              ← Systemd unit do GesCon
│   └── cloudflared.service         ← Systemd unit do tunnel
├── /etc/cloudflared/
│   ├── config.yml                  ← Config do tunnel
│   └── <uuid>.json                 ← Credenciais (600 root:root)
├── /usr/local/bin/gescon-backup.sh ← Script de backup
├── /opt/gescon/healthcheck.sh      ← Healthcheck (cron */3)
└── /opt/gescon/backups/            ← Backups diários (30 dias)
```

---

## 🚀 Comandos de Deploy

### Deploy do zero

```bash
# 1. Criar LXC
cd ~/Projetos/GesCon/deploy
bash 01-criar-lxc.sh

# 2. Configurar SSH
bash 04-ssh-config.sh

# 3. Setup AdvPP + GesCon (na LXC)
ssh lxc105
bash -s < 02-setup-advpp.sh

# 4. Criar tunnel Cloudflare (dashboard)
# https://one.dash-cloudflare.com → Networks → Tunnels → Create

# 5. Configurar cloudflared
export TUNNEL_TOKEN="eyJ..."
bash 03-setup-cloudflared.sh

# 6. Validar
bash 06-validar-deploy.sh
```

### Atualizar código

```bash
ssh lxc105
cd /opt/gescon
git pull
systemctl restart gescon
```

### Atualizar AdvPP

```bash
# Baixar novo release em https://github.com/peder1981/AdvPP/releases
# Copiar binário para /usr/local/bin/advplc
# Reiniciar
systemctl restart gescon
```

---

## 🔍 Diagnosticar Problemas

### GesCon não responde

```bash
# 1. Verificar serviço
ssh lxc105 'systemctl status gescon'

# 2. Ver logs
ssh lxc105 'journalctl -u gescon -n 50 --no-pager'

# 3. Teste manual
ssh lxc105 'advplc serve gescon.prw --port 8080'

# 4. Verificar porta
ssh lxc105 'ss -tlnp | grep 8080'
```

### Acesso externo 502/503

```bash
# 1. GesCon rodando?
ssh lxc105 'systemctl status gescon'

# 2. Porta 8080 respondendo?
ssh lxc105 'curl -s http://localhost:8080 | head -5'

# 3. Tunnel conectado?
ssh lxc105 'systemctl status cloudflared'

# 4. Dashboard Cloudflare → Tunnels → verificar "HEALTHY"
```

### Banco corrompido

```bash
# 1. Verificar integridade
ssh lxc105 'sqlite3 ~/.advpp/ADVPP.db "PRAGMA integrity_check;"'

# 2. Restaurar backup mais recente
ssh lxc105
ls -lt /opt/gescon/backups/
cp /opt/gescon/backups/gescon_YYYY-MM-DD_HHMMSS.db ~/.advpp/ADVPP.db
systemctl restart gescon
```

---

## 💾 Backups

| Configuração | Valor |
|--------------|-------|
| **Script** | `/usr/local/bin/gescon-backup.sh` |
| **Cron** | `0 3 * * *` (todo dia às 03:00) |
| **Destino** | `/opt/gescon/backups/` |
| **Retenção** | 30 dias |
| **Log** | `/var/log/gescon-backup.log` |

### Backup manual

```bash
ssh lxc105 '/usr/local/bin/gescon-backup.sh'
```

### Restaurar backup

```bash
ssh lxc105
systemctl stop gescon
cp /opt/gescon/backups/gescon_<data>.db ~/.advpp/ADVPP.db
systemctl start gescon
```

---

## 🛡️ Segurança

| Camada | Status |
|--------|--------|
| SSH root | `prohibit-password` ✅ |
| Firewall | `ufw` ativo (apenas porta 22) ✅ |
| Cloudflare Tunnel | Zero-trust, sem portas abertas ✅ |
| TLS | Automático via Cloudflare ✅ |
| WAF | Cloudflare WAF ativo ✅ |
| DB perms | `600` (root:root apenas) ✅ |
| Credenciais | Arquivo `600` root:root ✅ |

**Auditoria completa:** `deploy/AUDITORIA_CYBERSECURITY.md`

---

## 📊 Monitoramento

| Componente | Localização |
|------------|-------------|
| Healthcheck | `/opt/gescon/healthcheck.sh` (cron */3) |
| Log healthcheck | `/var/log/gescon-healthcheck.log` |
| Monitor host | `/usr/local/bin/monitor-proxmox.sh` (cron */5) |
| Monitor Ernesto | `/usr/local/bin/monitor-ernesto.sh` |

### Verificar saúde

```bash
# Healthcheck manual
ssh lxc105 '/opt/gescon/healthcheck.sh'

# Status do host
ssh homelab-lan '/usr/local/bin/monitor-proxmox.sh'
```

---

## 🌐 URLs de Acesso

| Serviço | URL | LXC |
|---------|-----|-----|
| **GesCon** | https://gescon.itmix.com.br | 105 |
| Ernesto | https://ernesto.itmix.com.br | 101 |
| Justatistic | https://justatistic.itmix.com.br | 103 |
| BLU | https://conciliador.itmix.com.br | 104 |

---

## 📋 Checklist para Qualquer Agente

Antes de fazer qualquer operação no GesCon:

- [ ] **Ler este arquivo** (HOMELAB.md)
- [ ] **Ler `deploy/README.md`** para detalhes do deploy
- [ ] **Verificar memória** `mem0_search` antes de qualquer ação externa
- [ ] **Confirmar acesso** `ssh lxc105` funciona
- [ ] **Verificar serviço** `systemctl status gescon`
- [ ] **Não alterar** `/root/.cloudflared/` (credenciais do tunnel)
- [ ] **Não alterar** `/etc/cloudflared/config.yml` sem necessidade
- [ ] **Backup antes** de qualquer mudança estrutural

---

## 📚 Documentação Adicional

| Arquivo | Descrição |
|---------|-----------|
| `README.md` | Visão geral do projeto |
| `deploy/README.md` | Guia completo de deploy |
| `deploy/AUDITORIA_CYBERSECURITY.md` | Auditoria de segurança |
| `GUIA_UTILIZACAO.md` | Instalação e compilação |
| `MANUAL_USUARIO.md` | Passo a passo das telas |
| `docs/ARQUITETURA.md` | Arquitetura técnica |
| `docs/FUNCIONAL.md` | Documentação funcional |
| `schema.sql` | DDL do banco de dados |

---

**Última atualização:** 2026-09-15  
**Mantido por:** Peder Munksgaard  
