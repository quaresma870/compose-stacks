# Secrets

Holds secret files read by Docker Secrets (`/run/secrets/<name>`).
**Never commit these files** — see `.gitignore`.

## Generate

```bash
openssl rand -hex 16 > grafana_password.txt
chmod 600 *.txt
```

Or use `../../scripts/setup.sh` which generates this automatically.
