# Devbox: Dotfiles, System Hardening & Infrastructure Stacks

The consolidated, single source of truth for:
- **Personal Shell & Editor Dotfiles** (`home/`: zsh, starship, ghostty, git, vscode)
- **Host OS Configuration & Hardening** (`system/`: headless power, ssh key-only, wifi powersave, firewall, unattended upgrades)
- **Network Ingress & Local Discovery** (`network/`: Caddy reverse proxy, native Avahi mDNS for `*.local` domains, dashboard)
- **Container Infrastructure Stacks** (`stacks/`: PostgreSQL, Redis, Dgraph, ClickHouse, MinIO, Cube, Langfuse, 9router, Jellyfin + qBittorrent)
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
| **Cube** | `http://cube.local` | `15432` (SQL) | `cube` | Semantic layer REST API and SQL endpoint |
| **T3 Code** | `http://t3.local` | `3773` | `host` | Autonomous agentic coding server & web interface |
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

# Probe real-time HTTP and TCP health of all service endpoints
./stacks/stacks.sh health

# Start, stop, or restart general dev infra stacks (default)
./stacks/stacks.sh up
./stacks/stacks.sh down
./stacks/stacks.sh restart

# Target an operating profile
./stacks/stacks.sh up general        # Always-on dev infra (devdeps, cube, langfuse, 9router)
./stacks/stacks.sh up media          # On-demand media server (jellyfin, qbittorrent)
./stacks/stacks.sh down media        # Stop media server

# Target an individual stack
./stacks/stacks.sh up cube
./stacks/stacks.sh logs 9router
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
- **Transcode Cache & Throttling**: Mounted `${MEDIA_ROOT}/cache:/cache` on disk with transcode throttling (`EnableThrottling: true`) and segment deletion enabled. Throttling ensures Jellyfin only transcodes 180s ahead during playback, eliminating HDD write thrashing without the fatal out-of-space errors that occur when bounding remuxes of full-length movies to a small tmpfs RAM disk.
- **Dual Path Mounts**: Both `${MEDIA_ROOT}/library` (`/home/aravind/data/media/library`) and `/home/aravind/entertainment/library` are mounted inside the container to maintain full backwards and forwards compatibility with Jellyfin's SQLite database index.
- **Hardware Transcoding**: Passed `/dev/dri` device and `render`/`video` groups for Intel Quick Sync Video (QSV) hardware-accelerated video transcode and remuxing.
- **qBittorrent WebUI Port**: Bound to port `8081` matching host and container to satisfy qBittorrent 5.x CSRF/Host-header validation.

### 3. Operating Profiles
- **General Dev Infra Profile (Always On)**:
  - Consists of all developer infrastructure: PostgreSQL, Redis, ClickHouse, MinIO, Dgraph, Cube, 9router, and Langfuse.
  - Automatically started and enabled at boot via templated systemd services (`stack@devdeps`, `stack@cube`, `stack@langfuse`, `stack@9router`).
- **Media Profile (On Demand & Web Toggleable)**:
  - Consists of Jellyfin and qBittorrent (`stacks/media-server`).
  - Toggleable on/off directly from the `http://devbox.local` dashboard with a single click, or via CLI (`./stacks/stacks.sh up media` / `./stacks/stacks.sh down media`).
  - Intentionally kept disabled at boot to conserve CPU and RAM on headless restarts until needed.

### 4. Devdeps Datastores (`stacks/devdeps/compose.yaml`)
- **PostgreSQL**: Tuned with `shared_buffers=256MB` (allowing 100% of the active database to live in RAM), `work_mem=16MB`, and `synchronous_commit=off` to eliminate mechanical disk `fsync` stalls.
- **Redis**: Tuned with `--maxmemory 192mb --maxmemory-policy allkeys-lru` to auto-evict expired cache keys without risking Docker OOM kills, with conservative RDB disk snapshot intervals.
- **ClickHouse**: Configured with `<async_insert>1</async_insert>` and `<wait_for_async_insert>0</wait_for_async_insert>` in `users-tuning.xml` to buffer incoming inserts in RAM and consolidate disk writes.
- **Dgraph**: Cache bounded to `size-mb=256` to lower background Raft consensus memory pressure on a 4-thread CPU.
- **MinIO**: Memory limited to `512M`, `cpus: '0.75'`.

### 5. Cube (`stacks/cube/compose.yaml`)
- HTTP API is bound to localhost and exposed through Caddy at `cube.local`.
- Cube SQL remains LAN-bound on port `15432`.
- The image is pinned by digest, with a 768M memory and 0.75 CPU ceiling.
- Development mode is disabled by default; enable it only for local Playground work.
- Uses the memory cache/queue driver and disables the refresh worker because no pre-aggregations are currently defined.

### 6. Kernel & Ingress Performance
- **Kernel Swap & Cache (`/etc/sysctl.d/99-devbox.conf`)**: `vm.swappiness = 10` (prevents premature memory eviction to disk) and `vm.vfs_cache_pressure = 50` (retains directory/inode cache longer in RAM).
- **zswap Compressed Swap Cache**: Enabled via `zswap-enable.service` with LZO compression to intercept swapped pages and compress them in RAM.
- **Filesystem `noatime`**: Root ext4 partition mounted with `noatime` to eliminate metadata write wear on disk reads.
- **Caddy Compression**: Enabled `encode zstd gzip` across all `.local` web vhosts for 70–80% payload transfer reduction over local Wi-Fi.
- **Docker Log Rotation (`/etc/docker/daemon.json`)**: Configured with `max-size: 10m` and `max-file: 3` to prevent unbounded log accumulation on disk.

---

## Boot Auto-Start Convergence

All stacks are governed by a templated systemd unit: `/etc/systemd/system/stack@.service`.

On machine boot:
1. `systemd` waits for network initialization (`network-online.target`) and `docker.service`.
2. Automatically triggers the always-on general dev infra services:
   - `stack@devdeps` (PostgreSQL, Redis, ClickHouse, MinIO, Dgraph)
   - `stack@cube`
   - `stack@langfuse`
   - `stack@9router`
3. Jellyfin and qBittorrent remain available through the `http://devbox.local` web toggle or `./stacks/stacks.sh up media`, and are not started automatically at boot.

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
    ├── devdeps/                # Postgres, Redis, ClickHouse, MinIO, Dgraph
    ├── cube/                   # Cube semantic layer and SQL endpoint
    ├── langfuse/               # Observability Web UI & Background Worker
    ├── 9router/                # AI Gateway (LiteLLM/9router)
    ├── media-server/           # On-demand streaming & torrent stack
    └── systemd/stack@.service  # Templated systemd boot service
```

---

## Secrets & Security Policy

- **Zero Secrets in Git**: No API keys, passwords, database dumps, or private keys are ever committed.
- All live environment files (`.env`, `langfuse.env`) are strictly excluded by `.gitignore`.
- Sanitize and review before committing: `.env.example` templates document every configuration variable with placeholder values.
- 9router persistent storage (`/home/aravind/data/9router`) containing runtime databases and provider keys is held outside version control.
