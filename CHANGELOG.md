# Changelog

All notable changes to this project are documented here. See the
[README](README.md) for current features and usage.

### v1.3.0
- fix: **`full-stack`'s nginx logs now actually reach Loki** — closes #16. The Docker `loki` logging
  driver runs on the host daemon, not inside any container's network namespace, so its
  `http://localhost:3100/...` URL could never reach the `loki` container (which doesn't even publish
  port 3100 to the host). Reverted nginx to `json-file` (matching every other stack) — the standard
  nginx image's `access_log`/`error_log` already point at its own `/dev/stdout`/`/dev/stderr`, so once
  `json-file` is capturing that output again, Promtail's existing `docker_sd_configs` job already
  ships it, the same way it already does for every other container in the stack. No further wiring
  needed once the driver itself was fixed.
- fix: **`ssl_alerts.yml`'s alert rules were permanently inert** — closes #15. Both rules queried
  `probe_ssl_earliest_cert_expiry`, a metric only `blackbox_exporter` produces, and no stack shipped
  that exporter. Added a real `blackbox-exporter` service (`monitoring` and `full-stack`) probing a
  configurable HTTPS target, wired into `prometheus.yml`'s scrape config, and re-added the
  `ssl_alerts.yml` rule_files reference to `full-stack` (previously dropped specifically because
  nothing produced the metric there either — now it does). Verified for real on CI: probes a real
  HTTPS domain and confirms `probe_ssl_earliest_cert_expiry` comes back as a real, positive value,
  both directly from the exporter and via Prometheus's own scrape.
- fix: **`loki` couldn't actually start in either `logging` or `full-stack`** — found by the new
  CI job for #16 actually booting it for real, rather than just `config --quiet`. Loki 3.x rejects
  `compactor.retention_enabled: true` unless `compactor.delete_request_store` is also set; both
  stacks' `loki.yml` had the former without the latter, so the container has never come up as
  committed. Added `delete_request_store: filesystem`, matching the `filesystem` object store
  already configured under `common.storage`.

### v1.2.0
- fix: **`security` and `full-stack` stacks' missing `./config/` files** — both stacks'
  `docker-compose.yml` referenced config files that didn't exist anywhere in the repo, making both
  undeployable as committed. Built `security/config/` (nginx, fail2ban jails using fail2ban's own
  bundled filters) from scratch, and `full-stack/config/` mostly by reusing and adapting what
  `monitoring/` and `logging/` already had (fixed a broken `localhost` alertmanager URL and a
  datasource `isDefault` conflict along the way) — closes #12.
- fix: found and fixed a **real, separate, pre-existing gap in the already-shipping `monitoring`
  stack** while investigating #12 — its `docker-compose.yml` bind-mounted
  `./config/grafana/dashboards`, but that directory never existed either. Added a real, functional
  dashboard (host CPU/memory/disk, container count/CPU) rather than an empty placeholder.
- feat: **new CI check** — `validate.yml` now confirms every repo-relative bind-mount source path
  in every stack's `docker-compose.yml` actually exists on disk, catching the exact class of gap
  above before it can recur. `docker compose config --quiet` alone never caught this, since Compose
  only needs bind-mount sources to exist at real `up` time. Verified on real CI: deliberately
  removed `security/config/` and confirmed the new check fails with a clear message, then restored
  it and confirmed green.
- Two further, unrelated findings from this investigation (an inert Prometheus alert rule in
  `monitoring` with no producing exporter, and a Docker `loki` logging driver in `full-stack` that
  can't actually reach Loki due to a host/container networking mismatch) are filed as separate
  follow-up issues rather than folded into this fix.

### v1.1.0
- feat: **CI actually boots `web-basic` for real**, not just `docker compose config --quiet` —
  a new `smoke-test-web-basic` job generates real secrets, boots postgres + redis for real, polls
  until both report healthy, then verifies each is actually accepting real connections (a real
  `psql -c "SELECT 1"`, a real Redis `SET`+`GET` round trip using the same secret-file-based auth
  the real stack uses). `app`/nginx are deliberately out of scope for this pass — see below for
  why. Found two real, non-obvious things while building this, entirely through reproduction on a
  throwaway test branch (Docker isn't available in the dev sandbox, and this sandbox's network
  egress additionally blocks GitHub's log/artifact storage backend entirely, so every diagnostic
  had to come from job/step pass-fail patterns and local reproduction, not actual log text):
  `docker compose ps --format json`'s output shape changed between Compose versions (handled in
  `ci/wait_healthy.py`), and — the bigger one — `app` only joins the `backend` network, which is
  `internal: true` by design, so Docker never wires up host→container port publishing for it no
  matter what a CI override does; reachability has to be verified via `docker compose exec` from
  inside the network instead, the same way nginx actually reaches it in production. This is good
  security design in the original file, not a bug.
- feat: **`crowdsec` healthcheck** added to the `security` stack (`cscli lapi status`, CrowdSec's
  own current recommended pattern). `fail2ban` already had one baked into its own image
  (confirmed against its published Dockerfile) — documented explicitly so that isn't mistaken for
  an oversight. `certbot` gets a genuinely missing `restart: unless-stopped` (found while writing
  its no-healthcheck explanation — `web-basic`'s identical certbot service already had this).
- fix: **filed #12** for a much bigger thing found while trying to write `nginx`'s healthcheck for
  the `security` stack: `security/docker-compose.yml` and `full-stack/docker-compose.yml` both
  reference `./config/...` files that don't exist anywhere in this repository (confirmed against a
  fresh clone) — both stacks are currently non-deployable as committed, and `config --quiet`
  doesn't catch it since Compose doesn't require bind-mount sources to exist until actual `up`
  time. Scoped out of this round rather than rushed.
- feat: **new `web-traefik` stack** — same scope as `web-basic` (app + postgres + redis), Traefik
  instead of nginx + certbot. Automatic Let's Encrypt with no renewal cron to maintain, routing
  configured via `traefik.*` labels on each service instead of a separate nginx config file.
  Pinned to the actual current release (`v3.7.5`, checked before pinning). Found one thing before
  it became a blind-debugging problem: `traefik healthcheck --ping` requires the ping endpoint to
  be explicitly enabled via a separate `--ping=true` flag, confirmed against Traefik's own docs
  and real-world bug reports of people hitting exactly this. Added to `scripts/setup.sh`'s stack
  picker, which was a hardcoded menu with no dynamic discovery.
- chore: all of the above verified against real `docker compose config --quiet` runs on actual CI
  via throwaway test branches/PRs, cleaned up after confirming green — not just YAML syntax
  checked locally.

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
