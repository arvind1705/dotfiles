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
│   ├── metrics/                # Lightweight btop-style system telemetry daemon
│   └── portal/index.html       # Landing page dashboard at http://devbox.local
│
└── stacks/                     # Docker Compose infrastructure
    ├── stacks.sh               # CLI: up, down, restart, status, logs
    ├── setup-stacks.sh         # Generates .env files & sets up boot systemd units
    ├── devdeps/                # Postgres, Redis, Dgraph, ClickHouse, MinIO
    ├── langfuse/               # Observability Web UI & Background Worker
    ├── 9router/                # AI Gateway (LiteLLM/9router)
    ├── media-server/           # Streaming & Torrent Stack (Jellyfin + qBittorrent)
    └── systemd/stack@.service  # Templated systemd boot service
```

---

## Local Endpoints & Discovery

All services are accessible on your local LAN via mDNS (`.local` domain names):

| Service | Local URL | Direct Port | Description |
| :--- | :--- | :--- | :--- |
| **Devbox Dashboard** | `http://devbox.local` | `80` (Caddy) | Central landing dashboard |
| **Jellyfin** | `http://jellyfin.local` | `8096` | Media streaming server |
| **qBittorrent** | `http://qbittorrent.local` | `8081` | Torrent downloader |
| **Langfuse** | `http://langfuse.local` | `3005` | LLM observability platform |
| **9router** | `http://9router.local` | `20128` | AI gateway & model router |
| **MinIO Console** | `http://minio-console.local`| `9094` | Object storage admin UI |
| **MinIO API** | `http://minio.local` | `9092` | S3-compatible API |
| **ClickHouse HTTP** | `http://clickhouse.local` | `8124` | Analytical database HTTP |
| **Dgraph HTTP** | `http://dgraph.local` | `8080` | Graph database HTTP |
| **PostgreSQL** | `postgres.local:5432` | `5432` | Relational database (TCP) |
| **Redis** | `redis.local:6380` | `6380` | In-memory cache/store (TCP) |

---

## Managing Stacks

Use the `stacks.sh` CLI for everyday management:

```bash
# Check status of all containers
./stacks/stacks.sh status

# Probe real-time HTTP and TCP health of all endpoints
./stacks/stacks.sh health

# Start, stop, or restart all stacks
./stacks/stacks.sh up
./stacks/stacks.sh down
./stacks/stacks.sh restart

# Target an individual stack
./stacks/stacks.sh up 9router
./stacks/stacks.sh logs langfuse
./stacks/stacks.sh restart devdeps
```

---

## Boot Auto-Start Convergence

All stacks are governed by a templated systemd unit: `/etc/systemd/system/stack@.service`.

On machine reboot:
1. `systemd` waits for network initialization (`network-online.target`) and `docker.service`.
2. Automatically triggers:
   - `stack@devdeps`
   - `stack@langfuse`
   - `stack@9router`
   - `stack@media-server`
3. Each stack runs `docker compose up -d --remove-orphans`, ensuring that any stopped, missing, or updated containers converge automatically to their desired state.

---

## Secrets & Security Policy

- **Zero Secrets in Git**: No API keys, passwords, database dumps, or private keys are ever committed.
- All live environment files (`.env`, `langfuse.env`) are strictly excluded by `.gitignore`.
- Sanitize and review before committing: `.env.example` templates document every configuration variable with placeholder values.
- 9router persistent storage (`/home/aravind/data/9router`) containing runtime databases and provider keys is held outside version control.
