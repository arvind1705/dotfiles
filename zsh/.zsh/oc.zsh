# =============================================================================
#   OPENCODE GO — usage meters
# =============================================================================
#   ocgo            show the Go subscription meters
#   ocgo -w [N]     refresh every N seconds (default 5), ctrl-c to stop
#
#   Requires:  export OC_KEY="oc_sk_..."      (see ~/.zsh/secrets.zsh)
# =============================================================================

typeset -g _OC_URL="https://opencode.ai/console/api/go/status"
typeset -g _OC_BADGE="" _OC_BADGE_W=0 _OC_W=0
typeset -gA _OC_LABEL=(
  fiveHour "Rolling usage"
  week     "Weekly usage"
  month    "Monthly usage"
)

# -----------------------------------------------------------------------------
#   COLOURS  (truecolor -> 8-colour -> none)
# -----------------------------------------------------------------------------

_ocgo_colors() {
  emulate -L zsh
  _OC_RST=$'\033[0m'
  if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${TERM:-}" == dumb ]]; then
    _OC_RST="" _OC_BOLD="" _OC_DIM="" _OC_EDGE="" _OC_TITLE="" _OC_TRACK=""
    _OC_GREEN="" _OC_AMBER="" _OC_RED="" _OC_BG_GREEN="" _OC_BG_AMBER="" _OC_BG_RED=""
    return
  fi
  _OC_BOLD=$'\033[1m'
  if [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]; then
    _OC_DIM=$'\033[38;2;156;163;175m'
    _OC_EDGE=$'\033[38;2;63;63;70m'
    _OC_TITLE=$'\033[38;2;244;244;245m'
    _OC_TRACK=$'\033[38;2;82;82;91m'
    _OC_GREEN=$'\033[38;2;134;239;172m'
    _OC_AMBER=$'\033[38;2;252;211;77m'
    _OC_RED=$'\033[38;2;252;165;165m'
    _OC_BG_GREEN=$'\033[38;2;134;239;172;48;2;20;83;45m'
    _OC_BG_AMBER=$'\033[38;2;252;211;77;48;2;66;32;6m'
    _OC_BG_RED=$'\033[38;2;252;165;165;48;2;69;10;10m'
  else
    _OC_DIM=$'\033[90m'
    _OC_EDGE=$'\033[90m'
    _OC_TITLE=$'\033[97m'
    _OC_TRACK=$'\033[90m'
    _OC_GREEN=$'\033[32m'
    _OC_AMBER=$'\033[33m'
    _OC_RED=$'\033[31m'
    _OC_BG_GREEN=$'\033[30;42m'
    _OC_BG_AMBER=$'\033[30;43m'
    _OC_BG_RED=$'\033[30;41m'
  fi
}

_ocgo_tone() { # tenths of a percent -> green | amber | red
  if   (( $1 >= 900 )); then print -r -- RED
  elif (( $1 >= 700 )); then print -r -- AMBER
  else print -r -- GREEN
  fi
}

# -----------------------------------------------------------------------------
#   HELPERS
# -----------------------------------------------------------------------------

_ocgo_epoch() { # ISO-8601 UTC -> unix seconds (BSD date)
  local s="$1"
  s="${s%%.*}"          # drop fractional seconds
  s="${s%Z}"            # drop trailing Z
  [[ -z "$s" ]] && { print -r -- 0; return }
  date -j -u -f '%Y-%m-%dT%H:%M:%S' "$s" +%s 2>/dev/null || print -r -- 0
}

_ocgo_until() { # ISO-8601 UTC -> "4h 51m" | "4d 15h" | "now"
  local target left
  target="$(_ocgo_epoch "$1")"
  (( target == 0 )) && { print -r -- "—"; return }
  left=$(( target - $(date +%s) ))
  (( left <= 0 )) && { print -r -- "now"; return }
  local d=$(( left / 86400 )) h=$(( left % 86400 / 3600 )) m=$(( left % 3600 / 60 ))
  if   (( d > 0 )); then print -r -- "${d}d ${h}h"
  elif (( h > 0 )); then print -r -- "${h}h ${m}m"
  else print -r -- "${m}m"
  fi
}

_ocgo_bar() { # $1 tenths used, $2 width
  emulate -L zsh
  local t="${1:-0}" w="${2:-40}" filled empty tone name
  (( t < 0 )) && t=0
  filled=$(( t * w / 1000 ))
  (( filled > w )) && filled=$w
  (( t > 0 && filled == 0 )) && filled=1
  empty=$(( w - filled ))
  tone="$(_ocgo_tone "$t")"
  name="_OC_${tone}"
  printf '%s%s%s%s%s%s' \
    "${(P)name}" "${(l:filled::█:)}" "$_OC_RST" \
    "$_OC_TRACK" "${(l:empty::░:)}" "$_OC_RST"
}

# _ocgo_badge <tenths>  ->  sets $_OC_BADGE (coloured) and $_OC_BADGE_W (display width)
#   Deliberately sets globals rather than printing: it is called in a context where
#   the caller needs both the rendered badge and its visible width.
_ocgo_badge() {
  emulate -L zsh
  local t="${1:-0}" txt tone name
  txt="$(( t / 10 )).$(( t % 10 ))%"
  _OC_BADGE_W=$(( ${#txt} + 2 ))
  tone="$(_ocgo_tone "$t")"
  name="_OC_BG_${tone}"
  _OC_BADGE="${(P)name} ${txt} ${_OC_RST}"
}

# _ocgo_row <left-vis> <left-text> <right-vis> <right-text>
#   Renders "│  <left>…<right>  │" with the caption pushed to the right edge.
#   The *-vis arguments are display widths ignoring ANSI escapes.
_ocgo_row() {
  emulate -L zsh
  local pad=$(( _OC_W - 4 - $1 - $3 ))
  (( pad < 1 )) && pad=1
  printf '%s│%s  %s%*s%s  %s│%s\n' \
    "$_OC_EDGE" "$_OC_RST" "$2" "$pad" '' "$4" "$_OC_EDGE" "$_OC_RST"
}

_ocgo_barrow() {
  emulate -L zsh
  printf '%s│%s  ' "$_OC_EDGE" "$_OC_RST"
  _ocgo_bar "$1" "$(( _OC_W - 4 ))"
  printf '  %s│%s\n' "$_OC_EDGE" "$_OC_RST"
}

_ocgo_blank() { printf '%s│%s%*s%s│%s\n' "$_OC_EDGE" "$_OC_RST" "$_OC_W" '' "$_OC_EDGE" "$_OC_RST" }

_ocgo_rule() {
  emulate -L zsh
  local l=$1 r=$2
  printf '%s%s%s%s%s\n' "$_OC_EDGE" "$l" "${(l:_OC_W::─:)}" "$r" "$_OC_RST"
}

# -----------------------------------------------------------------------------
#   RENDER
# -----------------------------------------------------------------------------

_ocgo_render() {
  emulate -L zsh
  setopt localoptions pipefail

  local raw body code
  raw="$(curl --silent --show-error --compressed --max-time 10 "$_OC_URL" \
         --header "Authorization: Bearer ${OC_KEY}" \
         --write-out $'\n%{http_code}')" || {
    print -u2 "✗ request failed (network)"; return 1
  }
  code="${raw##*$'\n'}"
  body="${raw%$'\n'*}"

  case "$code" in
    200) ;;
    401) print -u2 "✗ HTTP 401 — OC_KEY is missing, invalid or revoked"
         print -u2 "  put a fresh key in ~/.zsh/secrets.zsh and run \`source ~/.zshrc\`"; return 1 ;;
    403) print -u2 "✗ HTTP 403 — this key cannot read usage"; return 1 ;;
    *)   print -u2 "✗ HTTP ${code}: $(print -r -- "$body" | head -c 160)"; return 1 ;;
  esac

  if ! print -r -- "$body" | jq -e '.access.meters' >/dev/null 2>&1; then
    print -u2 "✗ unexpected response:"
    print -u2 "  $(print -r -- "$body" | head -c 200)"
    return 1
  fi

  local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
  _OC_W=$(( cols - 8 ))
  (( _OC_W < 44 )) && _OC_W=44
  (( _OC_W > 72 )) && _OC_W=72

  printf '\n  %s%sGo-Subscription%s\n' "$_OC_TITLE" "$_OC_BOLD" "$_OC_RST"
  printf '  %sLow cost coding models for everyone%s\n\n' "$_OC_DIM" "$_OC_RST"

  _ocgo_rule '╭' '╮'

  local -a rows
  rows=("${(@f)$(print -r -- "$body" | jq -r '
      . as $r | ["fiveHour","week","month"][] as $k
      | .access.meters[$k] | select(. != null)
      | [ $k, (.resetsAt // $r.access.endsAt // ""),
          .usedMicroCents, .limitMicroCents ] | @tsv')}")

  local i=0 line label reset used limit tenths right left_vis
  for line in "${rows[@]}"; do
    IFS=$'\t' read -r label reset used limit <<< "$line"
    [[ -z "$label" ]] && continue

    tenths=0
    [[ -n "$limit" && "$limit" != "0" ]] && tenths=$(( ${used:-0} * 1000 / limit ))
    (( tenths > 1000 )) && tenths=1000

    (( i > 0 )) && _ocgo_rule '├' '┤'
    (( i++ ))
    _ocgo_blank

    _ocgo_badge "$tenths"
    right="Resets in $(_ocgo_until "$reset")"
    left_vis=$(( ${#${_OC_LABEL[$label]:-$label}} + 2 + _OC_BADGE_W ))

    _ocgo_row "$left_vis" \
      "${_OC_TITLE}${_OC_BOLD}${_OC_LABEL[$label]:-$label}${_OC_RST}  ${_OC_BADGE}" \
      "${#right}" "${_OC_DIM}${right}${_OC_RST}"
    _ocgo_barrow "$tenths"
  done

  _ocgo_blank
  _ocgo_rule '╰' '╯'
  printf '\n'
}

# -----------------------------------------------------------------------------
#   ENTRY POINT
# -----------------------------------------------------------------------------

ocgo() {
  emulate -L zsh
  [[ -z "$OC_KEY" ]] && { print -u2 "✗ OC_KEY is not set — add \`export OC_KEY=\"oc_sk_...\"\` to ~/.zsh/secrets.zsh"; return 1 }

  local watch=0 every=5
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -w|--watch) watch=1; [[ -n "${2:-}" && "${2:-}" != -* ]] && { every="$2"; shift } ;;
      -h|--help)  print -r -- "usage: ocgo [-w|--watch [seconds]]"; return 0 ;;
      *) print -u2 "✗ unknown option: $1"; return 1 ;;
    esac
    shift
  done

  if (( ! watch )); then
    _ocgo_colors
    _ocgo_render
    return
  fi

  while :; do
    _ocgo_colors
    printf '\033[2J\033[H'
    _ocgo_render || return 1
    printf '  %srefreshing every %ss · ctrl-c to stop%s\n' "$_OC_DIM" "$every" "$_OC_RST"
    sleep "$every"
  done
}
