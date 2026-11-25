#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

while IFS= read -r -d '' file; do
  [[ -f "$file" ]] || continue
  case "$file" in
    *.sh) bash -n "$file" ;;
    home/zsh/.zshenv|home/zsh/.zprofile|home/zsh/.zshrc|*.zsh|*.zsh.example) zsh -n "$file" ;;
  esac
done < <(git ls-files -z)
