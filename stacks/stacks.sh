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
