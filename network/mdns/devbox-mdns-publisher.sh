#!/usr/bin/env bash
# =============================================================================
# Unified mDNS Publisher for All Local Service Endpoints
# =============================================================================
set -euo pipefail

detect_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
}
detect_ipv6() {
  ip -6 addr show dev "${LAN_IFACE:-wlp3s0}" scope link 2>/dev/null \
    | awk '/inet6/ {print $2; exit}' | cut -d/ -f1
}

IPV4="${LAN_IP:-$(detect_ip)}"; IPV4="${IPV4:-127.0.0.1}"
IPV6="$(detect_ipv6 || true)"

HOSTNAMES=(
  "devbox.local"
  "jellyfin.local"
  "qbittorrent.local"
  "langfuse.local"
  "9router.local"
  "clickhouse.local"
  "minio.local"
  "minio-console.local"
  "dgraph.local"
  "cube.local"
  "postgres.local"
  "redis.local"
)

PIDS=()
cleanup() {
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

for h in "${HOSTNAMES[@]}"; do
  avahi-publish -a -R "$h" "$IPV4" &
  PIDS+=($!)
  if [[ -n "$IPV6" ]]; then
    avahi-publish -a -R "$h" "$IPV6" &
    PIDS+=($!)
  fi
done

wait
