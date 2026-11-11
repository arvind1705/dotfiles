#!/usr/bin/env bash
# =============================================================================
# Stacks CLI: Manage all Docker Compose services
# =============================================================================
set -euo pipefail

STACKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_STACKS=("devdeps" "langfuse" "9router" "media-server")

usage() {
  cat <<EOF
Usage: $0 <command> [stack-name]

Commands:
  up        Start stack(s)
  down      Stop stack(s)
  restart   Restart stack(s)
  status    Show status of all containers
  health    Probe HTTP and TCP service endpoints
  logs      Tail logs for stack(s)

Available stacks:
  ${ALL_STACKS[*]}

Examples:
  $0 status
  $0 up devdeps
  $0 up
  $0 logs 9router
EOF
  exit 1
}

CMD="${1:-}"
TARGET="${2:-}"

[[ -z "$CMD" ]] && usage

run_cmd() {
  local stack="$1"
  local action="$2"
  local dir="$STACKS_DIR/$stack"

  if [[ ! -d "$dir" ]]; then
    echo "✗ Unknown stack: $stack"
    return 1
  fi

  echo "==> [$stack] Running: docker compose $action"
  (
    cd "$dir"
    case "$action" in
      up)
        docker compose up -d --remove-orphans
        ;;
      down)
        docker compose down
        ;;
      restart)
        docker compose restart
        ;;
      status)
        docker compose ps
        ;;
      logs)
        docker compose logs -f --tail=100
        ;;
      *)
        docker compose "$action"
        ;;
    esac
  )
}

check_health() {
  local lan_ip
  lan_ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' || true)"
  lan_ip="${lan_ip:-127.0.0.1}"

  echo "========================================================================"
  echo " DEVBOX INFRASTRUCTURE HEALTH PROBE"
  echo "========================================================================"
  printf "%-22s %-34s %s\n" "SERVICE" "ENDPOINT" "STATUS"
  echo "------------------------------------------------------------------------"

  # TCP Checks
  local tcp_endpoints=(
    "PostgreSQL:$lan_ip:5432"
    "Redis:$lan_ip:6380"
    "Dgraph gRPC:$lan_ip:9080"
    "ClickHouse native:$lan_ip:9002"
    "9router direct:$lan_ip:20128"
    "Langfuse direct:$lan_ip:3005"
  )
  for item in "${tcp_endpoints[@]}"; do
    local name="${item%%:*}"
    local addr="${item#*:}"
    local host="${addr%:*}"
    local port="${addr##*:}"
    if (timeout 2 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null); then
      printf "%-22s %-34s \033[32mONLINE\033[0m\n" "$name" "$addr"
    else
      printf "%-22s %-34s \033[31mOFFLINE\033[0m\n" "$name" "$addr"
    fi
  done

  # HTTP Checks (via Caddy :80)
  local http_endpoints=(
    "Devbox Dashboard:http://devbox.local/health"
    "Langfuse:http://langfuse.local/health"
    "9router:http://9router.local/health"
    "ClickHouse HTTP:http://clickhouse.local"
    "Dgraph HTTP:http://dgraph.local"
    "MinIO S3:http://minio.local"
    "MinIO console:http://minio-console.local"
    "Jellyfin:http://jellyfin.local"
    "qBittorrent:http://qbittorrent.local"
    "Cube:http://cube.local/health"
    "T3 Code:http://t3.local/health"
  )
  for item in "${http_endpoints[@]}"; do
    local name="${item%%:*}"
    local url="${item#*:}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -m 3 -L "$url" 2>/dev/null || echo "000")
    if [[ "$code" =~ ^(200|204|301|302|307|308|403)$ ]]; then
      printf "%-22s %-34s \033[32mONLINE\033[0m (HTTP %s)\n" "$name" "$url" "$code"
    else
      printf "%-22s %-34s \033[31mOFFLINE\033[0m (HTTP %s)\n" "$name" "$url" "$code"
    fi
  done
  echo "========================================================================"
}

case "$CMD" in
  up|down|restart)
    if [[ -n "$TARGET" ]]; then
      run_cmd "$TARGET" "$CMD"
    else
      for s in "${ALL_STACKS[@]}"; do
        run_cmd "$s" "$CMD"
      done
    fi
    ;;
  status)
    echo "========================================================================"
    echo " DEVBOX CONTAINER STATUS"
    echo "========================================================================"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ;;
  health)
    check_health
    ;;
  logs)
    if [[ -n "$TARGET" ]]; then
      run_cmd "$TARGET" "logs"
    else
      echo "Please specify a stack to tail logs for: ${ALL_STACKS[*]}"
    fi
    ;;
  *)
    usage
    ;;
esac
