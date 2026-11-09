# Home media server (Jellyfin + qBittorrent)

Headless Ubuntu box, Docker Compose, LAN-only access. Streams to your Google
Android TV, laptop browser, and phone via Jellyfin. qBittorrent downloads
straight into that library folder, so files show up in Jellyfin as soon as
they finish. No hardlinks, no helper scripts.

**This machine's detected values**

| | |
|---|---|
| LAN IP | `192.168.0.172` |
| Jellyfin | `http://192.168.0.172:8096` |
| qBittorrent Web UI | `http://192.168.0.172:8081` |
| BitTorrent listen | `6881` TCP+UDP |
| Media root | `/home/aravind/entertainment` |
| CPU / iGPU | i7-6500U / Skylake HD 520 (Quick Sync) |
| Free disk | ~842 GB |

> **Why 8081 and not 8080?** Port 8080 on this host is already used by the
> Dgraph dev container. `QBT_WEBUI_PORT=8081` is used for **both** the host
> side and the container side — this is required, because qBittorrent 5.x
> rejects requests when the `Host` header's port differs from its own WebUI
> port (`Invalid Host header, port mismatch`). If you change `QBT_WEBUI_PORT`
> in `.env`, both sides change together, so it stays consistent.
>
> The existing Langfuse/dev stack binds to the LAN IP too, so this stack does
> the same: nothing is published on `0.0.0.0`. There is **no UFW** on this box,
> so port binding + no router port-forwarding is the whole security model.
> Don't port-forward 8096 / 8081 on your router. (`6881` is the exception —
> that one is torrent traffic, see the checklist.)

## Files

```
docker-compose.yml   Jellyfin + qBittorrent
.env.example         documented settings (template)
.env                 real values (committed -- private repo, holds secrets)
setup.sh             creates dirs, writes .env, validates, starts the stack
set-credentials.sh   sets Web UI credentials for both apps
media-stack.service  systemd unit: converge the stack on every boot
.gitignore           excludes generated library/ and config/
LICENSE              license from the GitHub repo
```

`config/` and `library/` are **created locally** by `setup.sh` and the
containers, and are deliberately not in git. Only the files above are needed
to rebuild the system on another machine.

## Start it

```bash
cd /home/aravind/entertainment
chmod +x setup.sh
./setup.sh --up          # dirs, .env, containers, Web UI credentials
docker compose ps        # both should be "Up"
docker compose logs -f   # Ctrl-C to detach
```

Other useful commands:

```bash
docker compose pull && docker compose up -d   # update images
docker compose restart qbittorrent
docker compose down                          # stop (config/media survive)
```

## Auto-start on boot

Yes — the stack comes back after a reboot, through two layers:

1. `docker.service` is enabled at boot and waits for `network-online.target`.
   The **DHCP reservation for `192.168.0.172` on the router** guarantees the
   LAN IP exists before the daemon tries to bind ports to it.
2. Every service has `restart: unless-stopped`, so Docker restarts the
   containers that were running.

That covers a plain reboot, but `unless-stopped` can't recreate a container
removed with `docker compose down`, and a reboot alone never re-applies edits
to `docker-compose.yml` or `.env`. `media-stack.service` closes that gap: it
runs `docker compose up -d --remove-orphans` on every boot, so the running
stack always converges to what's in this folder (and any leftover container
from a removed service is cleaned up). It's idempotent — containers already
up with a matching config are left alone, so it's safe alongside Docker's own
restart policy.

Install it once (or again after editing the unit file):

```bash
cd /home/aravind/entertainment
sudo cp media-stack.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now media-stack.service
```

Useful checks:

```bash
systemctl status media-stack.service
journalctl -u media-stack.service -b          # what it did on this boot
sudo systemctl restart media-stack.service   # re-apply compose/.env changes now
```

> Boot never runs `docker compose pull` — updating the upstream images stays a
> manual step (see above), so startup doesn't depend on a registry being
> reachable.

## Web UI credentials

Both apps use the same account, applied once by `set-credentials.sh` (also run
automatically by `./setup.sh --up`):

| | |
|---|---|
| Username | `aravind` |
| Password | `change_this_password` |

The values live in `.env` as `MEDIA_USER` / `MEDIA_PASSWORD` and the file is
`chmod 600`. To change them, edit `.env` and re-run:

```bash
./set-credentials.sh
```

The script works on an existing install (it renames the Jellyfin admin and
resets both passwords) and on a fresh one (it completes Jellyfin's startup
wizard via API and seeds qBittorrent's config — no wizard, no temporary
password). It verifies both logins afterwards. Libraries and watch history are
kept, but changing the credentials signs out existing Jellyfin devices (TV,
phone) and qBittorrent sessions.

> ⚠️ **Security:** `change_this_password` is a short, date-like password and is weak. It is
> stored in **plain text** in `.env` and in the container config files, there is
> **no UFW** on this box, and the Web UIs are plain HTTP on the LAN (no TLS), so
> anyone on the network can sniff or guess it. Prefer a long random password
> from a password manager, and keep the LAN-only binding + no router
> port-forwards. Run `./set-credentials.sh` again after changing it.

## Replicate on a new machine

The repo holds **only the files that define the system**. `library/` (media)
and `config/` (live databases, logs, metadata images, torrent state) are
generated locally and are **not** in git — see `.gitignore`. A fresh clone
starts with empty config, and the scripts rebuild it.

### Prerequisites

- Linux host with **Docker Engine + the Compose plugin**
  (`docker compose version`), plus `python3`, `curl` and `sudo`.
- A **DHCP reservation** for the server's LAN IP. Every published port is
  bound to that single address in `.env`; if it changes, edit `.env` and
  re-run `./setup.sh` + `docker compose up -d`.
- Intel iGPU with `/dev/dri` for QuickSync. Without one, remove the `devices:`
  and `group_add:` blocks from `jellyfin` in `docker-compose.yml`.
- Free ports `8096`, `8081`, `6881` (TCP+UDP) and UDP `7359`; forward `6881`
  TCP+UDP on the router for better peers.
- **This repo is private.** `.env` is committed with the Web UI password in
  plain text. Keep it private, or delete `.env` and use `.env.example` as a
  template instead.

### Steps

```bash
# 1. Clone. Prefer the SAME path as MEDIA_ROOT in .env: this stack deliberately
#    uses identical host and container paths for the library.
git clone https://github.com/arvind1705/media-server.git /home/aravind/entertainment
cd /home/aravind/entertainment

# 2. Adjust .env for the new machine (or delete it and let setup.sh regenerate):
#    LAN_IP, MEDIA_ROOT (if path/username differs), PUID/PGID, TZ,
#    RENDER_GID / VIDEO_GID (getent group render; getent group video),
#    and MEDIA_USER / MEDIA_PASSWORD -- change the default password!
${EDITOR:-nano} .env

# 3. If the folder path or username differs, also fix the absolute paths and
#    User= / Group= in media-stack.service (WorkingDirectory, Documentation).
#    setup.sh and set-credentials.sh derive everything else from .env.

# 4. Create dirs, validate config, start containers, set Web UI credentials.
#    On a fresh config, set-credentials.sh also completes Jellyfin's startup
#    wizard via the API -- no manual first user, no temporary qBittorrent pwd.
chmod +x setup.sh set-credentials.sh
./setup.sh --up

# 5. Boot persistence (recommended).
sudo cp media-stack.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now media-stack.service

# 6. Verify.
docker compose ps
systemctl status media-stack.service
```

Then work through the **First-run checklist** below. It quotes this machine's
absolute paths (`/home/aravind/entertainment/...`) — substitute your
`MEDIA_ROOT` when adding Jellyfin libraries.

> To carry over users / watch history from the old box, back up `config/` there
> (`tar czf media-config.tgz -C /home/aravind/entertainment config`), restore
> it into this folder **before** `./setup.sh --up`, and keep the `.env`
> credentials consistent. `config/` is not in git, so it is otherwise lost on
> a fresh clone. Media in `library/` is replaceable and is not backed up here.

## First-run checklist

### 1. qBittorrent — check the downloads settings

Open `http://192.168.0.172:8081` and sign in with `aravind` / `change_this_password`
(set by `set-credentials.sh` — there is no temporary password to look up,
and the Web UI port already reads `8081`).

1. Tools → Options → Downloads:
   - Default Save Path: `/downloads/movies` (already set — that's
     `/home/aravind/entertainment/library/movies` on the host)
   - For TV, set the save path to `/downloads/tv` when adding a torrent, or add
     categories `movies` → `/downloads/movies`, `tv` → `/downloads/tv`.
   - "Keep incomplete torrents in:" → `/downloads/incomplete`
2. Tools → Options → Connection → Listening Port: `6881`, and turn **off**
   "Use UPnP / NAT-PMP" if you'd rather forward manually.
3. On your **router**, forward `6881` TCP+UDP to `192.168.0.172`. Without it
   downloads still work (outbound connections only) but you'll get fewer peers
   and worse seeding. This is torrent traffic, not remote UI access — "LAN
   only" refers to the admin/streaming interfaces.

### 2. Jellyfin — set up libraries

1. Open `http://192.168.0.172:8096` from your laptop.
2. Sign in with `aravind` / `change_this_password`. The admin account and the startup
   wizard are handled by `set-credentials.sh`, so there's no user to create.
3. Dashboard → Libraries → Add Media Library:
   - **Movies** → folder `/home/aravind/entertainment/library/movies` → content type *Movies*
   - **Shows** → folder `/home/aravind/entertainment/library/tv` → content type *Shows*
   - Enable "Automatically add to library" / real-time monitoring if offered.
4. Dashboard → Playback → **Transcoding**:
   - Hardware acceleration: **Intel QuickSync (QSV)**
   - Enable HW decoding for: H.264, HEVC, VP8 (MPEG-2/VC-1 optional)
   - **Leave unchecked**: HEVC 10-bit, VP9 10-bit, AV1 — Skylake can't do them.
   - Verify the driver loaded:
     ```bash
     docker exec jellyfin /usr/lib/jellyfin-ffmpeg/vainfo 2>&1 | head -20
     ```
     If QSV isn't offered, try `image: linuxserver/jellyfin:latest` instead.

> ⚠️ **Skylake limitation:** this iGPU handles H.264 and HEVC **8-bit** fine
> (1–2 simultaneous 1080p transcodes), but not 4K HDR / HEVC 10-bit. A 4K HDR
> remux will fall back to software decoding + CPU tone-mapping on 2 CPU cores
> and stutter *when Jellyfin has to transcode*. Keep Jellyfin clients to
> **1080p H.264 / HEVC 8-bit**, or force **Direct Play** so the server only
> sends bytes and never has to decode at all.

### 3. Android TV / Google TV

1. On the TV, install **"Jellyfin for Android TV"** from the Play Store
   (it's also on Chromecast with Google TV).
2. It should auto-discover the server on LAN (that's what UDP 7359 is for).
   If not, choose "Enter server address" and type `http://192.168.0.172:8096`.
3. Log in with the Jellyfin user you created.
4. In the app settings, prefer **Direct play**; set max bitrate to ~20–40 Mbps
   for local network.
5. Laptop: just browse to the same URL. Phone: Jellyfin app, or cast to the TV.

## Daily workflow

```
paste magnet into qBittorrent Web UI
         ↓  downloads straight into library/movies/ (its Default Save Path)
    Jellyfin scans it immediately
         play on Android TV, browser, or phone
```

That's it — no moving, linking or copying. qBittorrent's save path is already
`/downloads/movies`, which is `library/movies` on the host, so finished files
land exactly where Jellyfin looks, and seeding continues in place.

For TV shows, set the save path to `/downloads/tv` (`library/tv`) when adding
the torrent, or add a `tv` category in qBittorrent.

Files keep their release names; Jellyfin identifies them by filename. If you
want the Jellyfin-friendly `Name (Year)/Name (Year).mkv` layout, just `mkdir`
the folder and `mv` the file into it on the server.

Then in Jellyfin: **Dashboard → Libraries → Scan All Libraries** (or wait for
the automatic scan).

## Folder layout

```
/home/aravind/entertainment/
├── config/              <- Jellyfin + qBittorrent settings
│   ├── jellyfin/
│   └── qbittorrent/
└── library/             <- the ONE media folder: downloads + Jellyfin
    ├── movies/          <- qBittorrent saves here; Jellyfin Movies library
    ├── tv/              <- optional TV library
    └── incomplete/      <- in-progress torrents (not scanned by Jellyfin)
```

Everything lives in this **one** folder — the Compose project files
(`docker-compose.yml`, `.env`, `setup.sh`, `media-stack.service`, `README.md`)
sit right next to the media tree, and `MEDIA_ROOT` in `.env` points at this
same directory. There is no separate `/srv/media` and no separate torrents
folder.

qBittorrent and Jellyfin read the same `library/` directory. Container paths
match host paths exactly, which keeps paths predictable.

## Troubleshooting

| Symptom | Fix |
|---|---|
| qBittorrent Web UI says **"Unauthorized"** | Check `docker logs qbittorrent` / `config/qBittorrent/logs/qbittorrent.log` for `Invalid Host header, port mismatch`. That means the host port and `WEBUI_PORT` disagree — keep them equal (this compose file already does). As a last resort, edit `config/qBittorrent/qBittorrent.conf` and add `WebUI\HostHeaderValidation=false` under `[WebUI]`, then `docker compose restart qbittorrent`. |
| Forgot qBittorrent password | `docker compose exec qbittorrent /bin/bash`, or delete `qBittorrent.conf` and restart to regenerate (loses settings). |
| TV can't auto-discover the server | Just type `http://192.168.0.172:8096` manually. Docker bridge networking makes UDP broadcast discovery unreliable. |
| Jellyfin shows empty libraries | Check the folder path *inside the container* is exactly `/home/aravind/entertainment/library/movies`, and that files are readable: `docker exec jellyfin ls -l /home/aravind/entertainment/library/movies`. |
| Playback buffers / "not enough CPU" | It's transcoding. Force Direct Play on the TV, or check the Skylake note above. Dashboard → Playback shows the reason for each transcode. |
| Downloads don't show up in Jellyfin | Check qBittorrent's save path is `/downloads/movies` (or `/downloads/tv`). Files must land inside `library/`, and Jellyfin may need **Scan All Libraries**. |
| Ports conflict after an IP change | Set a DHCP reservation for `192.168.0.172`, or edit `.env` and re-run `./setup.sh` + `docker compose up -d`. |
| Stack didn't come back after reboot | `systemctl status media-stack.service` and `journalctl -u media-stack.service -b`. If you ran `docker compose down` before rebooting, this unit recreates the containers; if the unit itself is in a failed state, `sudo systemctl reset-failed media-stack.service && sudo systemctl restart media-stack.service`. |
| Forgot / want to change the Web UI password | Edit `MEDIA_USER` / `MEDIA_PASSWORD` in `.env` and run `./set-credentials.sh`. It re-applies the credentials to both apps and verifies the logins. |

## Things worth knowing / later upgrades

- **Remote access:** install Tailscale on the server + phone/laptop (and the
  Android TV app) for away-from-home streaming without opening a single port.
  Alternatives: WireGuard, Cloudflare Tunnel, Caddy + DuckDNS.
- **Automation:** Prowlarr (indexers) → Sonarr (TV) + Radarr (movies) →
  qBittorrent → library → Jellyfin, plus Jellyseerr (request page) and Bazarr
  (subtitles). The single `library/` folder works with them, though they'll
  move/copy files rather than hardlink.
- **VPN for torrents:** a Gluetun container with a kill switch is the usual way
  to route qBittorrent's traffic through a VPN (`network_mode: service:gluetun`).
  You chose to skip it — just be aware your ISP can see torrent traffic, and
  only download content you're entitled to.
- **Usenet / Real-Debrid:** both plug into Sonarr/Radarr as alternatives to P2P
  torrenting (Real-Debrid needs no VPN and no seeding).
- **Backups:** only `/home/aravind/entertainment/config` really matters. Media is replaceable.
  `tar czf media-config.tgz -C /home/aravind/entertainment config`.
- **Other services on this box:** there's a Langfuse/dev stack with 7
  containers. Don't reuse its ports (3005, 5432, 6380, 8080, 8124, 9002,
  9080, 9092, 9094). RAM is ~7 GB total, so avoid adding heavy services.
