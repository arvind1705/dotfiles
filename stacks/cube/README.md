# Cube semantic layer

Cube is managed as the `cube` Compose stack by the dotfiles repository. It
uses the shared `ai-infra-local` network and the PostgreSQL service from the
`devdeps` stack. The HTTP API is exposed through Caddy at `http://cube.local`;
the Cube SQL protocol remains available on the configured LAN port. The cache/queue driver is memory-backed for this single-node deployment, and the refresh worker stays off until pre-aggregations are added.

Operate it with `./stacks/stacks.sh {status,up,down,restart} cube` or
`systemctl status stack@cube`. The live `.env` is machine-local and excluded
from git; start from `.env.example` when provisioning another host.
