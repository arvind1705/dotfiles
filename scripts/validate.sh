#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

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
  if [[ "$source_dir" == stacks/cube ]]; then
    cp stacks/cube.env.example "$target_dir/.env"
  elif [[ -f "$source_dir/.env.example" ]]; then
    cp "$source_dir/.env.example" "$target_dir/.env"
  fi
  if [[ -f "$source_dir/langfuse.env.example" ]]; then
    cp "$source_dir/langfuse.env.example" "$target_dir/langfuse.env"
  fi
  printf 'Validating %s\n' "$stack"
  (cd "$target_dir" && docker compose config --quiet)
done
