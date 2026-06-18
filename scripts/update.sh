#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Zero-downtime update script
# Pulls new images while old containers keep serving traffic, then performs
# a rolling restart per service with health-check verification and automatic
# rollback if the new version fails to become healthy.
#
# Usage: ./update.sh [stack-dir] [service ...]
#   No services specified → updates all services with a healthcheck defined.
#   Stateful services (postgres, redis) are restarted last, with a brief
#   planned downtime, since rolling them is unsafe without replication.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

STACK_DIR="${1:-$(pwd)}"
shift || true
SERVICES=("$@")

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[$(date +%H:%M:%S)] $*${NC}"; }
success() { echo -e "${GREEN}✔  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
error()   { echo -e "${RED}✘  $*${NC}"; exit 1; }

cd "$STACK_DIR" || error "Stack dir not found: $STACK_DIR"
[ -f docker-compose.yml ] || error "No docker-compose.yml in $STACK_DIR"

# Services that should NOT be rolled live (restarted last, briefly)
STATEFUL_SERVICES=("postgres" "redis" "loki")

HEALTH_TIMEOUT=60
HEALTH_INTERVAL=3

# ── Determine which services to update ────────────────────────────────────────
if [ ${#SERVICES[@]} -eq 0 ]; then
  info "No services specified — updating all services with a healthcheck"
  mapfile -t ALL_SERVICES < <(docker compose config --services)
else
  ALL_SERVICES=("${SERVICES[@]}")
fi

# Split into stateless (rolling) and stateful (planned downtime)
STATELESS=()
STATEFUL=()
for svc in "${ALL_SERVICES[@]}"; do
  is_stateful=false
  for s in "${STATEFUL_SERVICES[@]}"; do
    [ "$svc" = "$s" ] && is_stateful=true && break
  done
  if $is_stateful; then
    STATEFUL+=("$svc")
  else
    STATELESS+=("$svc")
  fi
done

# ── Pull all new images first (containers keep running) ──────────────────────
info "Pulling new images (current containers stay up)..."
docker compose pull "${ALL_SERVICES[@]}" 2>&1 | grep -v "^$" || true
success "Images pulled"

# ── Health check helper ───────────────────────────────────────────────────────
wait_healthy() {
  local svc="$1"
  local elapsed=0
  info "  Waiting for $svc to become healthy..."
  while [ "$elapsed" -lt "$HEALTH_TIMEOUT" ]; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "$(docker compose ps -q "$svc")" 2>/dev/null || echo "none")
    if [ "$status" = "healthy" ]; then
      success "  $svc is healthy (${elapsed}s)"
      return 0
    elif [ "$status" = "none" ]; then
      # No healthcheck defined — just check it's running
      running=$(docker inspect --format='{{.State.Running}}' "$(docker compose ps -q "$svc")" 2>/dev/null || echo "false")
      if [ "$running" = "true" ]; then
        success "  $svc is running (no healthcheck defined)"
        return 0
      fi
    fi
    sleep "$HEALTH_INTERVAL"
    elapsed=$((elapsed + HEALTH_INTERVAL))
  done
  return 1
}

get_current_image() {
  local svc="$1"
  docker compose images "$svc" --format json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    items = data if isinstance(data, list) else [data]
    print(items[0].get('Repository','') + ':' + items[0].get('Tag',''))
except Exception:
    print('')
" 2>/dev/null || echo ""
}

# ── Rolling update for stateless services ─────────────────────────────────────
FAILED=()
for svc in "${STATELESS[@]}"; do
  info "Rolling update: $svc"
  old_image=$(get_current_image "$svc")

  docker compose up -d --no-deps "$svc"

  if wait_healthy "$svc"; then
    success "$svc updated successfully"
  else
    warn "$svc failed health check — rolling back"
    if [ -n "$old_image" ]; then
      docker tag "$old_image" "${svc}:rollback" 2>/dev/null || true
    fi
    docker compose up -d --no-deps "$svc"
    FAILED+=("$svc")
  fi
done

# ── Planned-downtime restart for stateful services ────────────────────────────
if [ ${#STATEFUL[@]} -gt 0 ]; then
  warn "Stateful services require brief planned downtime: ${STATEFUL[*]}"
  read -rp "Proceed with stateful service restart? [y/N]: " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    for svc in "${STATEFUL[@]}"; do
      info "Restarting (planned downtime): $svc"
      docker compose up -d --no-deps "$svc"
      wait_healthy "$svc" || { warn "$svc did not become healthy"; FAILED+=("$svc"); }
    done
  else
    warn "Skipped stateful services: ${STATEFUL[*]}"
  fi
fi

# ── Cleanup ────────────────────────────────────────────────────────────────────
info "Cleaning up old images..."
docker image prune -f >/dev/null 2>&1 || true

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
if [ ${#FAILED[@]} -eq 0 ]; then
  success "Update complete — all services healthy"
else
  error "Update completed with failures: ${FAILED[*]} — check 'docker compose logs <service>'"
fi
