# =============================================================================
#   CUSTOM FUNCTIONS
# =============================================================================

# =============================================================================
#   UPDATES
# =============================================================================

# Upgrade all development tools
ua() {
  echo "→ brew"
  if brew update >/dev/null 2>&1 && brew upgrade -y >/dev/null 2>&1 && brew cleanup >/dev/null 2>&1; then
    echo "✓ brew latest"
  else
    echo "✗ brew failed"
  fi

  echo "→ cmd"
  if cmd update >/dev/null 2>&1; then
    echo "✓ cmd $(cmd --version 2>/dev/null)"
  else
    echo "✗ cmd failed"
  fi

  echo "→ opencode2"
  if opencode2 upgrade >/dev/null 2>&1; then
    echo "✓ $(opencode2 --version 2>/dev/null)"
  else
    echo "✗ opencode2 failed"
  fi

  echo "→ codex"
  if codex update >/dev/null 2>&1; then
    echo "✓ codex $(codex --version 2>/dev/null)"
  else
    echo "✗ codex failed"
  fi

  echo "→ agy"
  if agy update >/dev/null 2>&1; then
    echo "✓ agy $(agy --version 2>/dev/null)"
  else
    echo "✗ agy failed"
  fi

  echo "✓ All upgrades complete"
}


# =============================================================================
#   GIT / ARUBA
# =============================================================================

# Fetch all git repos under $ARUBA_HOME in parallel
fetcharuba() {
    local jobs=20

    find "$ARUBA_HOME" -type d -name .git -print0 |
    xargs -0 -n1 -P "$jobs" sh -c '
        repo="${1%/.git}"
        name=$(basename "$repo")

        printf "[START] %s\n" "$name"

        if git -C "$repo" fetch --all --prune --jobs=4 --quiet; then
            printf "[DONE ] %s\n" "$name"
        else
            printf "[ERROR] %s\n" "$name" >&2
        fi
    ' _
}


# =============================================================================
#   MLX
# =============================================================================

# Start MLX inference server on port 8005 with model selection
mlxstart() {
  local port=8005
  local log="$HOME/mlx-lm/mlx-server.log"

  # Check if already running
  if lsof -ti :"$port" >/dev/null; then
    echo "MLX already running on :$port"
    echo "Model: $(curl -sf http://localhost:$port/v1/models 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")"
    return
  fi

  # --- Model selection menu ---
  local models=(
    "mlx-community/Qwen3.5-4B-MLX-4bit"    # 1 — current default
    "ornith-ai/Ornith-1.5-9B-MLX-8bit"       # 2 — already cached
  )
  local labels=(
    "Qwen 3.5-4B (4-bit, fast)"
    "Ornith-1.5-9B (8-bit, smarter)"
  )

  local num=${#models[@]}

  echo "Pick an MLX model:"
  for i in $(seq 1 "$num"); do
    printf "  %d) %s\n" "$i" "$labels[$i]"
  done
  echo "  c) Custom model name"
  echo "  q) Quit"

  local choice
  read -r "choice?Select [1-$num/c/q]: "

  local model=""
  case "$choice" in
    [1-9])
      if (( choice >= 1 && choice <= num )); then
        model="$models[$choice]"
      else
        echo "Invalid choice. Aborting."
        return 1
      fi
      ;;
    [cC])
      read -r "model?Enter Hugging Face model ID: "
      if [[ -z "$model" ]]; then
        echo "No model entered. Aborting."
        return 1
      fi
      ;;
    [qQ])
      echo "Aborted."
      return 0
      ;;
    *)
      echo "Invalid choice. Aborting."
      return 1
      ;;
  esac

  echo "Starting MLX with: $model"
  echo "  → Port:  $port"
  echo "  → Log:   $log"

  # Launch server in background
  (
    cd ~/mlx-lm || { echo "mlx-lm dir not found"; exit 1; }
    conda activate base 2>/dev/null
    nohup mlx_lm.server --model "$model" --port "$port" > "$log" 2>&1 &
  )

  # Capture PID right after launch
  sleep 1
  local pid
  pid=$(lsof -ti :"$port" 2>/dev/null)
  if [[ -n "$pid" ]]; then
    echo "  → PID:   $pid"
  fi

  # Poll until ready (up to 30s)
  echo "Waiting for MLX server..."
  local elapsed=""
  for i in $(seq 1 30); do
    if curl -sf http://localhost:$port/v1/models >/dev/null 2>&1; then
      elapsed=$i
      break
    fi
    sleep 1
  done

  if [[ -n "$elapsed" ]]; then
    echo "  ✓ Ready on port $port (after ${elapsed}s)"
    echo "  ✓ Health: $(curl -sf http://localhost:$port/v1/models >/dev/null && echo OK || echo FAILED)"
    echo "  ✓ Model:  $(curl -sf http://localhost:$port/v1/models 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")"
    if [[ -n "$pid" ]]; then
      echo "  ✓ PID:    $pid"
    fi
  else
    echo "MLX didn't become ready within 30s — check $log"
    return 1
  fi
}

# Stop MLX inference server
mlxstop() {
  local port=8005
  local pids
  pids=$(lsof -ti :"$port" 2>/dev/null)

  if [[ -z "$pids" ]]; then
    echo "No MLX server running on port $port"
    return
  fi

  local count
  count=$(echo "$pids" | wc -l | tr -d ' ')
  echo "Stopping MLX server on port $port ..."
  echo "Killing $count process(es): $(echo "$pids" | tr '\n' ' ')"

  kill $pids 2>/dev/null

  # Wait briefly and verify
  sleep 1
  if lsof -ti :"$port" >/dev/null 2>&1; then
    echo "Process still alive, force killing..."
    kill -9 $pids 2>/dev/null
    sleep 0.5
  fi

  if lsof -ti :"$port" >/dev/null 2>&1; then
    echo "Could not stop MLX on port $port"
    return 1
  else
    echo "MLX server stopped on port $port"
  fi
}


# =============================================================================
#   AWS
# =============================================================================

# AWS SSO login — prints verification code in huge text
sso() {
  local profile="${1:-shared_repo}"
  local seen=0
  setopt localoptions pipefail 2>/dev/null
  aws sso login --profile "$profile" --use-device-code --no-browser 2>&1 |
    while IFS= read -r line; do
      local trimmed="${line//[[:space:]]/}"
      if [[ $seen -eq 0 && "$trimmed" =~ ^[A-Z0-9]{4}-[A-Z0-9]{4}$ ]]; then
        echo ""
        python3 -c "
import sys, subprocess
code = sys.argv[1]
parts = code.split('-')
for i, group in enumerate(parts):
    if i > 0:
        print('  \033[1;90m─────\033[0m\n')
    result = subprocess.run(['figlet', '-f', 'banner', group], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    for line in lines:
        print('  \033[1;92m' + line + '\033[0m')
    print()
" "$trimmed"
        seen=1
      fi
      print -r -- "$line"
    done
}
