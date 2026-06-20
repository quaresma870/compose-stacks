# Changelog

All notable changes to this project are documented here. See the
[README](README.md) for current features and usage.

### v1.0.5
- feat: zero-downtime update script (`scripts/update.sh`) — closes #5
  - Pulls new images while old containers keep serving traffic
  - Rolling restart per service with health-check verification
  - Automatic rollback if a service fails to become healthy
  - Stateful services (postgres, redis, loki) restart last with confirmation prompt
- feat: Docker Secrets for Grafana password in `monitoring`, `logging`, `full-stack` — closes #6
  - `GF_SECURITY_ADMIN_PASSWORD__FILE` via `/run/secrets/grafana_password`
  - `setup.sh` generates `grafana_password.txt` automatically

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
