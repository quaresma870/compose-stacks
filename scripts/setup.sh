#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# compose-stacks setup wizard
# Interactive script to copy and configure a stack.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

STACKS_DIR="$(cd "$(dirname "$0")/../stacks" && pwd)"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/stacks}"

info()    { echo -e "${CYAN}ℹ  $*${NC}"; }
success() { echo -e "${GREEN}✔  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
error()   { echo -e "${RED}✘  $*${NC}"; exit 1; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════╗"
echo "║   compose-stacks setup wizard    ║"
echo "╚══════════════════════════════════╝"
echo -e "${NC}"

# ── Select stack ──────────────────────────────────────────────────────────────
info "Available stacks:"
echo ""
echo "  1) web-basic    — nginx + app + postgres + redis"
echo "  2) monitoring   — prometheus + grafana + alertmanager + node-exporter"
echo "  3) security     — nginx + crowdsec + fail2ban + certbot"
echo "  4) logging      — loki + promtail + grafana"
echo "  5) full-stack   — everything combined"
echo ""

read -rp "Select stack [1-5]: " CHOICE
case $CHOICE in
  1) STACK="web-basic"   ;;
  2) STACK="monitoring"  ;;
  3) STACK="security"    ;;
  4) STACK="logging"     ;;
  5) STACK="full-stack"  ;;
  *) error "Invalid choice" ;;
esac

STACK_SRC="$STACKS_DIR/$STACK"
STACK_DEST="$DEPLOY_DIR/$STACK"

# ── Check prerequisites ───────────────────────────────────────────────────────
info "Checking prerequisites..."
command -v docker  >/dev/null 2>&1 || error "Docker not found. Install from https://get.docker.com"
docker compose version >/dev/null 2>&1 || error "Docker Compose plugin not found"
success "Docker and Compose are available"

# ── Copy stack ────────────────────────────────────────────────────────────────
if [ -d "$STACK_DEST" ]; then
  warn "Destination exists: $STACK_DEST"
  read -rp "Overwrite? [y/N]: " OVERWRITE
  [[ "$OVERWRITE" =~ ^[Yy]$ ]] || error "Aborted."
fi

mkdir -p "$STACK_DEST"
cp -r "$STACK_SRC/." "$STACK_DEST/"
success "Stack copied to $STACK_DEST"

# ── Configure .env ────────────────────────────────────────────────────────────
ENV_FILE="$STACK_DEST/.env"
if [ ! -f "$ENV_FILE" ]; then
  cp "$STACK_DEST/.env.example" "$ENV_FILE"
  info "Created .env from .env.example"
fi

warn "Please edit $ENV_FILE and set your passwords and domain before starting."
echo ""

# ── Generate strong passwords ─────────────────────────────────────────────────
if command -v openssl >/dev/null 2>&1; then
  info "Generated strong passwords (copy these into your .env):"
  echo ""
  echo "  POSTGRES_PASSWORD=$(openssl rand -hex 24)"
  echo "  REDIS_PASSWORD=$(openssl rand -hex 20)"
  echo "  GRAFANA_PASSWORD=$(openssl rand -hex 16)"
  echo ""
fi


  # ── Generate secret files ──────────────────────────────────────────────────
  SECRETS_DIR="$STACK_DEST/secrets"
  mkdir -p "$SECRETS_DIR"

  if [ "$STACK" = "web-basic" ] || [ "$STACK" = "full-stack" ]; then
    if command -v openssl >/dev/null 2>&1; then
      info "Generating secret files in $SECRETS_DIR ..."
      openssl rand -hex 32 > "$SECRETS_DIR/postgres_password.txt"
      openssl rand -hex 24 > "$SECRETS_DIR/redis_password.txt"
      chmod 600 "$SECRETS_DIR/"*.txt
      success "Secret files generated (postgres_password.txt, redis_password.txt)"
    else
      warn "openssl not found — create secret files manually:"
      echo "  echo 'your-password' > $SECRETS_DIR/postgres_password.txt"
      echo "  echo 'your-password' > $SECRETS_DIR/redis_password.txt"
      echo "  chmod 600 $SECRETS_DIR/*.txt"
    fi
  fi

  if [ "$STACK" = "monitoring" ] || [ "$STACK" = "logging" ] || [ "$STACK" = "full-stack" ]; then
    if command -v openssl >/dev/null 2>&1; then
      info "Generating Grafana secret in $SECRETS_DIR ..."
      openssl rand -hex 16 > "$SECRETS_DIR/grafana_password.txt"
      chmod 600 "$SECRETS_DIR/grafana_password.txt"
      success "Secret file generated (grafana_password.txt)"
    else
      warn "openssl not found — create secret file manually:"
      echo "  echo 'your-password' > $SECRETS_DIR/grafana_password.txt"
      echo "  chmod 600 $SECRETS_DIR/grafana_password.txt"
    fi
  fi

# ── Summary ───────────────────────────────────────────────────────────────────
success "Setup complete!"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "  1. Edit:  $ENV_FILE"
echo "  2. Start: cd $STACK_DEST && docker compose up -d"
echo "  3. Logs:  docker compose logs -f"
echo ""
