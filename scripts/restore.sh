#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Restore script — restores a backup created by backup.sh
# Usage: ./restore.sh [backup-dir] [stack-dir]
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BACKUP_PATH="${1:-}"
STACK_DIR="${2:-$(pwd)}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[$(date +%H:%M:%S)] $*${NC}"; }
success() { echo -e "${GREEN}✔  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
error()   { echo -e "${RED}✘  $*${NC}"; exit 1; }

[ -n "$BACKUP_PATH" ] || error "Usage: $0 <backup-dir> [stack-dir]"
[ -d "$BACKUP_PATH" ] || error "Backup dir not found: $BACKUP_PATH"

cd "$STACK_DIR" || error "Stack dir not found: $STACK_DIR"

warn "This will overwrite existing data. Are you sure? [y/N]"
read -r CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || error "Aborted."

info "Restoring from: $BACKUP_PATH"

# ── Stop services ─────────────────────────────────────────────────────────────
info "Stopping services..."
docker compose down 2>/dev/null || true

# ── PostgreSQL ────────────────────────────────────────────────────────────────
if [ -f "$BACKUP_PATH/postgres_all.sql.gz" ]; then
  info "Restoring PostgreSQL..."
  [ -f .env ] && export $(grep -v '^#' .env | grep POSTGRES | xargs) 2>/dev/null || true
  docker compose up -d postgres
  sleep 5
  gunzip -c "$BACKUP_PATH/postgres_all.sql.gz" | \
    docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" postgres
  success "PostgreSQL restored"
fi

# ── Redis ─────────────────────────────────────────────────────────────────────
if [ -f "$BACKUP_PATH/redis_dump.rdb" ]; then
  info "Restoring Redis..."
  REDIS_VOLUME=$(docker volume ls --filter "name=redis_data" -q | head -1)
  if [ -n "$REDIS_VOLUME" ]; then
    docker run --rm \
      -v "$REDIS_VOLUME:/data" \
      -v "$BACKUP_PATH:/backup:ro" \
      alpine:3.20 \
      cp /backup/redis_dump.rdb /data/dump.rdb
    success "Redis RDB restored"
  fi
fi

# ── Docker volumes ─────────────────────────────────────────────────────────────
for ARCHIVE in "$BACKUP_PATH"/volume_*.tar.gz; do
  [ -f "$ARCHIVE" ] || continue
  VOLUME_SHORT=$(basename "$ARCHIVE" .tar.gz | sed 's/^volume_//')
  COMPOSE_PROJECT=$(basename "$STACK_DIR")
  VOLUME="${COMPOSE_PROJECT}_${VOLUME_SHORT}"
  info "Restoring volume: $VOLUME"
  docker volume create "$VOLUME" 2>/dev/null || true
  docker run --rm \
    -v "$VOLUME:/data" \
    -v "$BACKUP_PATH:/backup:ro" \
    alpine:3.20 \
    sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$ARCHIVE") -C /data"
  success "Volume $VOLUME_SHORT restored"
done

# ── Start all services ────────────────────────────────────────────────────────
info "Starting all services..."
docker compose up -d
success "All services started"

echo ""
info "Check status: docker compose ps"
info "View logs:    docker compose logs -f"
