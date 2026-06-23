# Secrets

This directory holds secret files read by Docker Secrets (`/run/secrets/<name>`).

**Never commit these files.** They are in `.gitignore`.

## Generate secrets

```bash
# Generate strong random passwords
openssl rand -hex 32 > postgres_password.txt
openssl rand -hex 24 > redis_password.txt
chmod 600 *.txt
```

Or use the setup wizard:
```bash
../../scripts/setup.sh
```

## Why Docker Secrets instead of env vars?

Environment variables are visible via `docker inspect <container>` and in
`/proc/<pid>/environ`. Docker Secrets are:
- Mounted as files in `/run/secrets/` (tmpfs — never written to disk)
- Not visible in `docker inspect` output
- Readable only by the container process
