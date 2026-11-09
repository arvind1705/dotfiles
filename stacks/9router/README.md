# 9router AI Gateway Stack

9router provides a centralized gateway and proxy for LLM endpoints and tools.

## Endpoints

- **Web UI & API**: `http://9router.local` (or `http://<LAN_IP>:20128`)

## Storage & Credential Isolation

- Live SQLite databases, JWT secrets, machine IDs, and configured provider API keys are stored strictly in `DATA_DIR` (`/home/aravind/data/9router`).
- **Never commit `data/` or `.env` to git.** The repository contains only `compose.yaml` and `.env.example`.
