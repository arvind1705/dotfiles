#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
unset POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB CLICKHOUSE_USER CLICKHOUSE_PASSWORD \
  MINIO_ROOT_USER MINIO_ROOT_PASSWORD INITIAL_PASSWORD COMPOSE_ENV_FILES COMPOSE_FILE COMPOSE_PROFILES

while IFS= read -r -d '' file; do
  case "$file" in
    *.sh|home/bin/dev) bash -n "$file" ;;
    home/zsh/.zshenv|home/zsh/.zprofile|home/zsh/.zshrc|*.zsh|*.zsh.example) zsh -n "$file" ;;
  esac
done < <(git ls-files -z)

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
for stack in stacks/*/compose.yaml; do
  source_dir="${stack%/*}"
  target_dir="$scratch/${source_dir##*/}"
  mkdir -p "$target_dir"
  cp "$stack" "$target_dir/compose.yaml"
  if [[ -f "$source_dir/.env.example" ]]; then
    cp "$source_dir/.env.example" "$target_dir/.env.example"
  fi
  if [[ -f "$source_dir/langfuse.env.example" ]]; then
    cp "$source_dir/langfuse.env.example" "$target_dir/langfuse.env.example"
  fi
done
cp stacks/cube.env.example "$scratch/cube.env.example"
cp "$scratch/media-server/.env.example" "$scratch/media-server/.env"
python3 stacks/provision-env.py "$scratch" 127.0.0.1
for stack in stacks/*/compose.yaml; do
  source_dir="${stack%/*}"
  printf 'Validating %s\n' "$stack"
  (cd "$scratch/${source_dir##*/}" && docker compose config --quiet)
done
