#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Backup script — PostgreSQL dump + named Docker volumes
# Usage: ./backup.sh [stack-dir] [backup-dir]
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

STACK_DIR="${1:-$(pwd)}"
BACKUP_DIR="${2:-$HOME/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[$(date +%H:%M:%S)] $*${NC}"; }
success() { echo -e "${GREEN}✔  $*${NC}"; }
error()   { echo -e "${RED}✘  $*${NC}"; exit 1; }

cd "$STACK_DIR" || error "Stack dir not found: $STACK_DIR"
[ -f docker-compose.yml ] || error "No docker-compose.yml in $STACK_DIR"

mkdir -p "$BACKUP_PATH"
info "Backup destination: $BACKUP_PATH"

# ── PostgreSQL ────────────────────────────────────────────────────────────────
if docker compose ps postgres 2>/dev/null | grep -q "running"; then
  info "Dumping PostgreSQL..."
  # Source .env for credentials
  [ -f .env ] && export $(grep -v '^#' .env | grep POSTGRES | xargs) 2>/dev/null || true
  docker compose exec -T postgres pg_dumpall -U "${POSTGRES_USER:-app}" \
    | gzip > "$BACKUP_PATH/postgres_all.sql.gz"
  success "PostgreSQL dump saved"
else
  info "PostgreSQL not running — skipping"
fi

# ── Redis RDB ─────────────────────────────────────────────────────────────────
if docker compose ps redis 2>/dev/null | grep -q "running"; then
  info "Saving Redis RDB..."
  docker compose exec -T redis redis-cli -a "${REDIS_PASSWORD:-}" BGSAVE > /dev/null 2>&1 || true
  sleep 2
  REDIS_CONTAINER=$(docker compose ps -q redis 2>/dev/null || true)
  if [ -n "$REDIS_CONTAINER" ]; then
    docker cp "$REDIS_CONTAINER:/data/dump.rdb" "$BACKUP_PATH/redis_dump.rdb" 2>/dev/null || true
    success "Redis RDB saved"
  fi
else
  info "Redis not running — skipping"
fi

# ── Docker volumes ─────────────────────────────────────────────────────────────
info "Backing up Docker volumes..."
COMPOSE_PROJECT=$(basename "$STACK_DIR")
for VOLUME in $(docker volume ls --filter "name=${COMPOSE_PROJECT}" -q 2>/dev/null); do
  SHORT="${VOLUME#${COMPOSE_PROJECT}_}"
  # Skip postgres and redis — already handled above
  [[ "$SHORT" == "postgres_data" || "$SHORT" == "redis_data" ]] && continue
  info "  Volume: $VOLUME"
  docker run --rm \
    -v "$VOLUME:/data:ro" \
    -v "$BACKUP_PATH:/backup" \
    alpine:3.20 \
    tar czf "/backup/volume_${SHORT}.tar.gz" -C /data . 2>/dev/null || true
done
success "Volumes backed up"

# ── Config files ───────────────────────────────────────────────────────────────
info "Backing up config..."
tar czf "$BACKUP_PATH/config.tar.gz" \
  --exclude=".env" \
  docker-compose.yml config/ 2>/dev/null || \
tar czf "$BACKUP_PATH/config.tar.gz" docker-compose.yml 2>/dev/null || true
success "Config backed up (passwords excluded)"

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
echo ""
success "Backup complete — $TOTAL_SIZE saved to $BACKUP_PATH"
ls -lh "$BACKUP_PATH"
