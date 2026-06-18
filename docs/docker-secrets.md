# Docker Secrets

How secrets are managed in the `web-basic` and `full-stack` stacks.

## Why Docker Secrets instead of env vars?

| Method | `docker inspect` | `/proc/environ` | Disk |
|--------|-----------------|-----------------|------|
| Environment variable | ⚠️  Visible | ⚠️  Visible | ⚠️  In compose/env file |
| Docker Secret | ✅ Hidden | ✅ Hidden | ✅ tmpfs only |

Environment variables are visible in `docker inspect <container>` output and
in `/proc/<pid>/environ`. Docker Secrets are mounted as files in `/run/secrets/`
using tmpfs — they are never written to disk and not visible in inspect output.

## Setup

```bash
cd stacks/web-basic
mkdir -p secrets
openssl rand -hex 32 > secrets/postgres_password.txt
openssl rand -hex 24 > secrets/redis_password.txt
chmod 600 secrets/*.txt
```

Or use the setup wizard which does this automatically:
```bash
./scripts/setup.sh
```

## How it works

```yaml
# docker-compose.yml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt   # local file → /run/secrets/postgres_password

services:
  postgres:
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    secrets:
      - postgres_password
```

PostgreSQL reads `POSTGRES_PASSWORD_FILE` natively.
Redis uses `$(cat /run/secrets/redis_password)` in its startup command.

## Secret files are gitignored

The `secrets/` directory contains a `.gitignore` that excludes `*.txt` files.
Only the `README.md` and `.gitignore` inside are committed — never the passwords.
