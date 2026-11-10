# Devbox: Dotfiles, System Hardening & Infrastructure Stacks

The consolidated, single source of truth for:
- **Personal Shell & Editor Dotfiles** (`home/`: zsh, starship, ghostty, git, vscode)
- **Host OS Configuration & Hardening** (`system/`: headless power, ssh key-only, wifi powersave, firewall, unattended upgrades)
- **Network Ingress & Local Discovery** (`network/`: Caddy reverse proxy, native Avahi mDNS for `*.local` domains, dashboard)
- **Container Infrastructure Stacks** (`stacks/`: PostgreSQL, Redis, Dgraph, ClickHouse, MinIO, Langfuse, 9router, Jellyfin + qBittorrent)
- **Automated Boot Convergence** (`stack@.service`: reliable systemd multi-stack startup on boot)

---

## Quickstart (New Machine Replication)

To bootstrap an entire machine from scratch:

```bash
# 1. Clone repository
git clone https://github.com/arvind1705/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles

# 2. Run automated installer
./install.sh --all
```

Or install specific components selectively:

```bash
./install.sh --dotfiles   # Shell, git, and editor configs
./install.sh --system     # OS hardening & systemd tweaks
./install.sh --network    # Caddy reverse proxy & mDNS resolution
./install.sh --stacks     # Docker Compose datastores & media stack
```

---

## Local Endpoints & Discovery

All services are accessible on your local LAN via mDNS (`.local` domain names) reverse-proxied by Caddy:

| Service | Local URL | Direct Port | Stack | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Devbox Dashboard** | `http://devbox.local` | `80` (Caddy) | `network` | Unified portal & live hardware telemetry |
| **Jellyfin** | `http://jellyfin.local` | `8096` | `media-server` | Media streaming server with Intel QSV transcoding |
| **qBittorrent** | `http://qbittorrent.local` | `8081` | `media-server` | Torrent downloader with automated queue |
| **Langfuse** | `http://langfuse.local` | `3005` | `langfuse` | LLM observability & prompt management platform |
| **9router** | `http://9router.local` | `20128` | `9router` | AI gateway, dynamic model router & rate limiter |
| **MinIO Console** | `http://minio-console.local`| `9094` | `devdeps` | Object storage admin UI |
| **MinIO API** | `http://minio.local` | `9092` | `devdeps` | S3-compatible object storage HTTP API |
| **ClickHouse HTTP** | `http://clickhouse.local` | `8124` | `devdeps` | Columnar database HTTP ping & query endpoint |
| **ClickHouse Native** | `clickhouse.local:9002` | `9002` | `devdeps` | High-performance binary ingestion protocol |
| **Dgraph HTTP** | `http://dgraph.local` | `8080` | `devdeps` | Distributed graph database HTTP & GraphQL API |
| **Dgraph gRPC** | `dgraph.local:9080` | `9080` | `devdeps` | Distributed graph database binary gRPC endpoint |
| **PostgreSQL** | `postgres.local:5432` | `5432` | `devdeps` | Primary relational database (backing Langfuse) |
| **Redis** | `redis.local:6380` | `6380` | `devdeps` | High-throughput in-memory cache & pub/sub broker |

---

## Devbox Portal & Telemetry (`http://devbox.local`)

The Devbox portal serves as the single pane of glass for all LAN services:

- **Live System Telemetry**: Minimal real-time telemetry strip monitoring CPU load & temperature, RAM & Swap utilization, NVMe storage, and network I/O.
- **Telemetry Daemon (`devbox-metrics.py`)**: Runs as a lightweight systemd service (`devbox-metrics.service`) listening on `127.0.0.1:9108`, proxied by Caddy under `/api/system`.
- **Direct TCP Probing**: Raw database ports (Postgres, Redis, ClickHouse Native, Dgraph gRPC) are probed directly on the server via TCP socket connections rather than false frontend correlations.
- **Anti-Flapping Hysteresis**: Frontend health checks include a 4-second timeout and 1-cycle grace period to prevent transient network jitter or CPU spikes from causing visual status flapping.
- **Collapsible CLI Drawer**: Includes copyable one-click connection commands for all CLI tools (`psql`, `redis-cli`, `clickhouse-client`, `grpcurl`, etc.).

---

## Managing Stacks (`stacks.sh`)

Everyday operations are controlled via the `./stacks/stacks.sh` management CLI:

```bash
# Check status of all containers (status, uptime, ports)
./stacks/stacks.sh status

# Probe real-time HTTP and TCP health of all 15 endpoints
./stacks/stacks.sh health

# Start, stop, or restart all stacks
./stacks/stacks.sh up
./stacks/stacks.sh down
./stacks/stacks.sh restart

# Target an individual stack (devdeps, langfuse, 9router, media-server)
./stacks/stacks.sh up 9router
./stacks/stacks.sh logs langfuse
./stacks/stacks.sh restart media-server
```

---

## Resource Tuning & Stability Guide

All container resource limits are carefully budgeted for host stability on a 2-core / 4-thread CPU with 8GB RAM:

### 1. Langfuse (`stacks/langfuse/compose.yaml`)
- **Web App**:
  - `memory: 1536M`
  - `NODE_OPTIONS: "--max-old-space-size=1024"`
  - `cpus: '1.25'`
  - *Why*: Langfuse v4 (Next.js 16 + Prisma) allocates ~700MB during startup and telemetry processing. Capping V8 heap at 512MB causes fatal JavaScript heap out-of-memory loops. Setting `max-old-space-size=1024` eliminates OOM crashes while CPU limits prevent startup spikes from starving the host.
- **Worker**:
  - `memory: 896M`
  - `NODE_OPTIONS: "--max-old-space-size=640"`
  - `cpus: '0.75'`

### 2. Media Server (`stacks/media-server/compose.yaml`)
- **Dual Path Mounts**: Both `${MEDIA_ROOT}/library` (`/home/aravind/data/media/library`) and `/home/aravind/entertainment/library` are mounted inside the container to maintain full backwards and forwards compatibility with Jellyfin's SQLite database index.
- **Hardware Transcoding**: Passed `/dev/dri` device and `render`/`video` groups for Intel Quick Sync Video (QSV) hardware-accelerated video transcode and remuxing.
- **qBittorrent WebUI Port**: Bound to port `8081` matching host and container to satisfy qBittorrent 5.x CSRF/Host-header validation.

### 3. Devdeps Datastores (`stacks/devdeps/compose.yaml`)
- **ClickHouse**: Memory limited to `1.5G`, configured with `tuning.xml` for max concurrency thread limits suited to a 4-thread host.
- **PostgreSQL**: Memory limited to `512M`, `cpus: '1.0'`.
- **Redis**: Memory limited to `256M`, `cpus: '0.5'`.
- **Dgraph**: Memory limited to `768M`, cache bounded to `512M`.
- **MinIO**: Memory limited to `512M`, `cpus: '0.75'`.

---

## Boot Auto-Start Convergence

All stacks are governed by a templated systemd unit: `/etc/systemd/system/stack@.service`.

On machine boot:
1. `systemd` waits for network initialization (`network-online.target`) and `docker.service`.
2. Automatically triggers:
   - `stack@devdeps`
   - `stack@langfuse`
   - `stack@9router`
   - `stack@media-server`
3. Each stack runs `docker compose up -d --remove-orphans`, ensuring that any stopped, missing, or updated containers converge automatically to their desired state.

---

## Troubleshooting & Diagnostics

```bash
# 1. Quick full-stack health probe
./stacks/stacks.sh health

# 2. Check running processes, memory and load
uptime && free -h
docker stats --no-stream

# 3. Check container restart counts and exit codes
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"

# 4. View telemetry service status
systemctl status devbox-metrics.service

# 5. Restart telemetry daemon after config changes
sudo systemctl restart devbox-metrics.service
```

---

## Repository Layout

```
.
├── install.sh                  # Master orchestrator for system setup
├── home/                       # User-level dotfiles (cleanly linkable to ~)
│   ├── zsh/                    # .zshenv, .zprofile, .zshrc, modules in .zsh/
│   ├── bin/dev                 # Development environment and Devbox status CLI
│   ├── config/                 # starship.toml, ghostty, opencode, git ignore
│   ├── git/                    # ignore-global, sanitized config templates
│   ├── vscode/                 # settings.json, keybindings.json
│   └── Brewfile                # Homebrew bundle package list
│
├── system/                     # Host OS configs applied to /etc
│   ├── setup-system.sh         # Idempotent system configuration script
│   ├── logind/headless.conf    # Ignore lid switch & idle actions on headless box
│   ├── ssh/01-key-only.conf    # Enforce key-only authentication
│   ├── wifi/wifi-powersave-off # Systemd unit disabling Wi-Fi power saving
│   ├── apt/20auto-upgrades     # Unattended security update configuration
│   └── firewall/               # LAN-restricted iptables filter for dev services
│
├── network/                    # Ingress, Discovery & Dashboard
│   ├── setup-network.sh        # Ingress installer & legacy mDNS cleanup
│   ├── caddy/Caddyfile.template# Reverse proxy for all *.local endpoints
│   ├── mdns/update-mdns.sh     # Dynamic IP detection & /etc/avahi/hosts updater
│   ├── metrics/devbox-metrics.py# Lightweight system telemetry & TCP probe daemon
│   └── portal/index.html       # Landing page dashboard at http://devbox.local
│
└── stacks/                     # Docker Compose infrastructure
    ├── stacks.sh               # CLI: up, down, restart, status, health, logs
    ├── setup-stacks.sh         # Generates .env files & sets up boot systemd units
    ├── devdeps/                # Postgres, Redis, Dgraph, ClickHouse, MinIO
    ├── langfuse/               # Observability Web UI & Background Worker
    ├── 9router/                # AI Gateway (LiteLLM/9router)
    ├── media-server/           # Streaming & Torrent Stack (Jellyfin + qBittorrent)
    └── systemd/stack@.service  # Templated systemd boot service
```

---

## Secrets & Security Policy

- **Zero Secrets in Git**: No API keys, passwords, database dumps, or private keys are ever committed.
- All live environment files (`.env`, `langfuse.env`) are strictly excluded by `.gitignore`.
- Sanitize and review before committing: `.env.example` templates document every configuration variable with placeholder values.
- 9router persistent storage (`/home/aravind/data/9router`) containing runtime databases and provider keys is held outside version control.
