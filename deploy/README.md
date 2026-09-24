# Deploy GesCon — Homelab Proxmox + Cloudflare Tunnel

## Visão Geral

Deploy do GesCon como aplicação web (AdvPP `serve`) em LXC dedicada no
homelab Proxmox, com acesso externo via Cloudflare Tunnel em
`gescon.itmix.com.br`.

## Dimensionamento

| Recurso | Valor | Justificativa |
|---------|-------|---------------|
| vCPUs | 2 | AdvPP web + SQLite (single-thread) |
| RAM | 2GB | AdvPP é leve, SQLite local |
| Disco | 20GB | Código + SQLite + backups 30 dias |
| OS | Debian 12 | Padrão do homelab |
| Rede | 192.168.2.105/24 | Subnet do homelab |
| Privilegiado | Não (unprivileged) | Padrão segurança |

**Comparação com outras LXCs:**
- LXC 101 (ernesto): 4 cores, 8GB — serve RAG + Ollama (muito mais pesado)
- LXC 103 (justatistic): 2 cores, 16GB — PostgreSQL + sync pesado
- LXC 104 (blu): 2 cores, 4GB — Streamlit + sync + 4GB SQLite
- **LXC 105 (gescon): 2 cores, 2GB — AdvPP web + SQLite leve**

## Fluxo de Deploy

### Pré-requisitos

1. **Proxmox VE 8+** acessível via SSH (`homelab-lan`)
2. **Cloudflare** com zona `itmix.com.br` ativa
3. **Template Debian 12** disponível no Proxmox

### Passo a passo

#### 1. Criar LXC no Proxmox

```bash
# No host Proxmox
cd ~/Projetos/GesCon/deploy
bash 01-criar-lxc.sh
```

Isso cria LXC 105 (gescon) com Debian 12, 2 cores, 2GB RAM, 20GB disco.

#### 2. Configurar SSH no laptop

```bash
# No laptop-peder
bash 04-ssh-config.sh
```

Adiciona alias `lxc105` em `~/.ssh/config` com ProxyJump homelab-lan.

#### 3. Setup do AdvPP + GesCon

```bash
# Na LXC 105
ssh lxc105
bash -s < 02-setup-advpp.sh
```

Instala AdvPP v3.0.0, clona GesCon, aplica schema, cria systemd service.

#### 4. Criar túnel Cloudflare

1. Acesse https://one.dash-cloudflare.com → **Networks** → **Tunnels**
2. Clique **Create a tunnel**
3. Nome: `gescon`
4. Copie o **TOKEN** (string longa base64)
5. No passo **Public hostname**, adicione:
   - Subdomain: `gescon`
   - Domain: `itmix.com.br`
   - Service: `http://localhost:8080`
6. Salve

#### 5. Configurar cloudflared na LXC

```bash
# Na LXC 105
export TUNNEL_TOKEN="eyJ..."
bash 03-setup-cloudflared.sh
systemctl start gescon
systemctl start cloudflared
```

#### 6. Verificar

```bash
# Teste local
ssh lxc105 'curl -s http://localhost:8080 | head -5'

# Teste externo
curl -s https://gescon.itmix.com.br | head -5
```

## Arquitetura

```
Internet
  │
  ├── Cloudflare (HTTPS, WAF, DDoS)
  │     │
  │     └── Cloudflare Tunnel (zero-trust, sem portas abertas)
  │           │
  │           └── LXC 105 (192.168.2.105)
  │                 │
  │                 ├── cloudflared (tunnel → Cloudflare)
  │                 ├── advplc serve (porta 8080)
  │                 └── SQLite (~/.advpp/ADVPP.db)
  │
  └── Backup diário (03:00, retenção 30 dias)
```

## Segurança

| Camada | Medida |
|--------|--------|
| Rede | Cloudflare Tunnel (zero-trust, sem portas abertas no host) |
| TLS | Automático via Cloudflare (certificado gerenciado) |
| WAF | Cloudflare WAF ativo (bloqueia SQLi, XSS, etc.) |
| Auth | Login de administrador no GesCon (hash SHA-256) |
| Credenciais | Token cloudflared em arquivo 600 root:root |
| Filesystem | LXC unprivileged, ProtectSystem=strict |
| Backup | Diário com retenção 30 dias |

## Comandos Úteis

```bash
# Status
ssh lxc105 'systemctl status gescon cloudflared'

# Logs
ssh lxc105 'journalctl -u gescon -f'
ssh lxc105 'journalctl -u cloudflared -f'

# Reiniciar
ssh lxc105 'systemctl restart gescon'

# Backup manual
ssh lxc105 '/usr/local/bin/gescon-backup.sh'

# Acessar LXC
ssh lxc105

# Acessar Proxmox
ssh homelab-lan
pct enter 105
```

## Atualização

```bash
# Atualizar GesCon
ssh lxc105
cd /opt/gescon
git pull
systemctl restart gescon

# Atualizar AdvPP
# (baixar novo release e reinstalar em /opt/advpp)
```

## Troubleshooting

### GesCon não inicia

```bash
ssh lxc105
journalctl -u gescon -n 50
advplc serve gescon.prw --port 8080  # teste manual
```

### Cloudflare Tunnel não conecta

```bash
ssh lxc105
systemctl status cloudflared
journalctl -u cloudflared -n 50
cloudflared tunnel info  # verifica status
```

### Acesso externo retorna 502

1. Verificar se o GesCon está rodando: `systemctl status gescon`
2. Verificar se a porta 8080 responde: `curl http://localhost:8080`
3. Verificar logs do tunnel: `journalctl -u cloudflared -f`
4. Verificar no dashboard Cloudflare se o túnel está "HEALTHY"

## IP e Rede

| Host | IP | Acesso |
|------|-----|--------|
| Proxmox (host) | 192.168.1.14 | `ssh homelab-lan` |
| LXC 101 (ernesto) | 192.168.2.81 | `ssh lxc101` |
| LXC 102 (meugerente) | 192.168.2.102 | `ssh lxc102` |
| LXC 103 (justatistic) | 192.168.2.103 | `ssh lxc103` |
| LXC 104 (blu) | 192.168.2.104 | `ssh lxc104` |
| **LXC 105 (gescon)** | **192.168.2.105** | `ssh lxc105` |

## URLs de Acesso

| Serviço | URL |
|---------|-----|
| GesCon (web) | https://gescon.itmix.com.br |
| Ernesto | https://ernesto.itmix.com.br |
| Justatistic | https://justatistic.itmix.com.br |
| BLU | https://conciliador.itmix.com.br |
