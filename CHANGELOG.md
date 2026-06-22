# Changelog

All notable changes to this project are documented here. See the
[README](README.md) for current features and usage.

### v1.0.6
- fix: **3 images still used `:latest` while every other image across all 5 stacks was carefully
  pinned to an exact version** (down to specific patch releases like `v0.50.0`, `v1.6.3`) —
  inconsistent with the rest of the project's demonstrated standard, and a real reproducibility
  risk (a `docker compose pull && up` done today vs. next month could pull a materially different
  image). Verified each image's actual current release before pinning, rather than guessing:
  - `certbot/certbot` → `v5.6.0` (current stable per the project's official GitHub releases)
  - `crazymax/fail2ban` → `1.1.0-r0` (current stable per the official GitHub releases)
  - `crowdsecurity/nginx-bouncer` → **left as `:latest`, deliberately, with a prominent comment**.
    Could not confirm this image is currently published under this exact name on Docker Hub — the
    `crowdsecurity` organisation's current repositories include `crowdsecurity/openresty` (a
    combined nginx+bouncer image) and `crowdsecurity/lua-bouncer-plugin`, but nothing matching
    `nginx-bouncer` was found. Pinning a guessed version number for an image whose current
    existence isn't confirmed would be worse than flagging it honestly — operators relying on the
    `security` stack should verify `docker pull crowdsecurity/nginx-bouncer` works before deploying,
    and consider `crowdsecurity/openresty` as the likely modern equivalent if it doesn't.
- chore: removed leftover empty junk directories from an early shell command that didn't expand
  brace patterns as intended — never tracked in git, purely local clutter.
- noted (not yet fixed): `stacks/security/docker-compose.yml` has zero `healthcheck:` blocks across
  all of its services, while every other stack has at least some — worth a follow-up pass.

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
