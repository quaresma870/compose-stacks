# 🐳 Compose Stacks

[![Validate Stacks](https://github.com/quaresma870/compose-stacks/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/quaresma870/compose-stacks/actions/workflows/validate.yml)
![Docker](https://img.shields.io/badge/Docker%20Compose-v2.20%2B-2496ED?logo=docker&logoColor=white)
![Node.js](https://img.shields.io/badge/GitHub%20Actions-Node.js%2024-brightgreen?logo=nodedotjs&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

Production-ready Docker Compose stacks. Pick one, copy it, fill in your `.env` and run.

---

## Stacks

| Stack | Services | Use case |
|-------|----------|----------|
| [`web-basic`](stacks/web-basic/) | nginx + app + postgres + redis + certbot | Any web app |
| [`monitoring`](stacks/monitoring/) | prometheus + grafana + alertmanager + node-exporter + cadvisor | Metrics & dashboards |
| [`security`](stacks/security/) | nginx + crowdsec + fail2ban + certbot | Hardened reverse proxy |
| [`logging`](stacks/logging/) | loki + promtail + grafana | Centralised log aggregation |
| [`full-stack`](stacks/full-stack/) | All of the above combined | Complete production setup |

---

## Quick start

### Option A — Setup wizard

```bash
git clone https://github.com/quaresma870/compose-stacks.git
cd compose-stacks
./scripts/setup.sh
```

The wizard will ask which stack you want, copy it to `/opt/stacks/<name>`, and generate strong passwords.

### Option B — Manual

```bash
# Clone
git clone https://github.com/quaresma870/compose-stacks.git
cd compose-stacks/stacks/web-basic

# Configure
cp .env.example .env
vim .env   # fill in passwords and domain

# Start
docker compose up -d

# Check
docker compose ps
docker compose logs -f
```

---

## Stack details

### web-basic
Minimal production-ready web stack:
- **nginx** — reverse proxy with rate limiting and security headers
- **app** — your application (replace `APP_IMAGE` in `.env`)
- **postgres 16** — database with health checks
- **redis 7** — cache with password and memory limits
- **certbot** — automatic SSL certificate renewal

### monitoring
Full observability stack:
- **Prometheus** — metrics collection with 15-day retention
- **Grafana** — dashboards (pre-provisioned with Prometheus datasource)
- **Alertmanager** — alert routing (Slack/email ready, just add credentials)
- **Node Exporter** — host CPU, memory, disk, network metrics
- **cAdvisor** — per-container CPU/memory/network metrics

Access Grafana at `http://your-server:3000` (default: admin/change-me).

### security
Hardened reverse proxy layer:
- **nginx** — with request logging to shared volume
- **CrowdSec** — community-driven IDS/IPS with nginx, linux and sshd collections
- **CrowdSec nginx bouncer** — blocks malicious IPs at nginx level
- **Fail2ban** — bans IPs after repeated failures
- **Certbot** — automatic SSL with auto-renewal

### logging
Lightweight log aggregation (Grafana LGTM stack without Mimir):
- **Loki** — log storage with 31-day retention
- **Promtail** — ships syslog, auth.log and all Docker container logs to Loki
- **Grafana** — log exploration and dashboards (pre-provisioned with Loki datasource)

### full-stack
Combines all four stacks into a single `docker-compose.yml`. Includes the Loki Docker log driver so nginx logs flow automatically into Grafana.

---

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/setup.sh` | Interactive wizard — copy and configure a stack |
| `scripts/backup.sh` | Backup postgres, redis and volumes |
| `scripts/restore.sh` | Restore from a backup created by backup.sh |

```bash
# Backup
./scripts/backup.sh /opt/stacks/web-basic ~/backups

# Restore
./scripts/restore.sh ~/backups/20241010_143000 /opt/stacks/web-basic
```

---

## Project structure

```
compose-stacks/
├── stacks/
│   ├── web-basic/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── config/
│   │       ├── nginx.conf
│   │       ├── conf.d/app.conf
│   │       └── postgres/init.sql
│   ├── monitoring/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── config/
│   │       ├── prometheus.yml
│   │       ├── alerts.yml
│   │       ├── alertmanager.yml
│   │       └── grafana/provisioning/
│   ├── security/
│   │   ├── docker-compose.yml
│   │   └── .env.example
│   ├── logging/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── config/
│   │       ├── loki.yml
│   │       ├── promtail.yml
│   │       └── grafana/provisioning/
│   └── full-stack/
│       ├── docker-compose.yml
│       └── .env.example
├── scripts/
│   ├── setup.sh          # interactive setup wizard
│   ├── backup.sh         # backup postgres + redis + volumes
│   └── restore.sh        # restore from backup
└── .github/workflows/
    └── validate.yml      # validates all compose files on push
```

---

## Requirements

- Docker Engine 24+
- Docker Compose plugin v2.20+
- Linux (Ubuntu 22.04+ recommended)

---

## Changelog

### v1.0.4
- feat: Docker Secrets for `postgres_password` and `redis_password` in `web-basic` — closes #2
  (file-based secrets via `/opt/secrets/`; no passwords in `docker inspect` output)
- docs: `docs/docker-secrets.md` — full guide for file-based and Swarm secrets

### v1.0.4
- feat: Docker Secrets in `web-basic` stack — closes #2
  - `POSTGRES_PASSWORD_FILE` and `REDIS_PASSWORD_FILE` — not visible in `docker inspect`
  - `secrets/` directory with `.gitignore` and generation guide
  - `scripts/setup.sh` auto-generates secret files via `openssl rand`
  - `docs/docker-secrets.md` — security comparison and setup guide

### v1.0.3
- feat: nginx connection limits + slow-loris protection — closes #3
  (`limit_conn perip 20`, body/header/send timeouts 10s)
- feat: SSL certificate expiry Prometheus alerts — closes #4
  (`SSLCertExpiringSoon` < 14 days warning, `SSLCertExpired` critical)

### v1.0.2
- feat: `deploy.resources` (memory + CPU limits + reservations) on all services — closes #1

### v1.0.1
- fix: CI — `.env` files created from `.env.example` before `docker compose config`
- fix: `env_file: required: false` in `full-stack` and `web-basic`

---

## License

MIT
