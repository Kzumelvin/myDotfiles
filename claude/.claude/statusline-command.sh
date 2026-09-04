#!/usr/bin/env bash
# Claude Code status line.
# No PS1 was found in the user's shell config; this mirrors the look of
# their Starship prompt (~/.config/starship.toml): truncated cwd, git
# branch, and git status glyphs.

input=$(cat)
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir')

BOLD_CYAN='\033[1;36m'
CYAN='\033[36m'
YELLOW='\033[33m'
RESET='\033[0m'

# --- directory (last 2 path segments, like starship's truncation_length=2) ---
display_dir="${dir/#$HOME/~}"
IFS='/' read -ra parts <<< "$display_dir"
clean_parts=()
for p in "${parts[@]}"; do
  [ -n "$p" ] && clean_parts+=("$p")
done
count=${#clean_parts[@]}
if [ "$count" -gt 2 ]; then
  short_dir="…/${clean_parts[$((count-2))]}/${clean_parts[$((count-1))]}"
else
  short_dir="$display_dir"
fi

# --- git branch + status (locks skipped so we never block the real git process) ---
branch=""
status_str=""
if git -C "$dir" --no-optional-locks rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || \
           git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  ahead=0
  behind=0
  upstream=$(git -C "$dir" --no-optional-locks rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [ -n "$upstream" ]; then
    counts=$(git -C "$dir" --no-optional-locks rev-list --left-right --count "HEAD...$upstream" 2>/dev/null)
    read -r ahead behind <<< "$counts"
    ahead=${ahead:-0}
    behind=${behind:-0}
  fi

  modified=0
  untracked=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "${line:0:2}" in
      "??") untracked=$((untracked + 1)) ;;
      *) modified=$((modified + 1)) ;;
    esac
  done <<< "$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null)"

  glyphs=""
  [ "$ahead" -gt 0 ] && glyphs="${glyphs}⇡${ahead} "
  [ "$behind" -gt 0 ] && glyphs="${glyphs}⇣${behind} "
  [ "$modified" -gt 0 ] && glyphs="${glyphs}✗ "
  [ "$untracked" -gt 0 ] && glyphs="${glyphs}? "
  status_str="${glyphs% }"
fi

# --- usage: session cost, 5h/7d rate limits, context window fill ---
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')
five_h_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
ctx_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

usage_parts=()
[ -n "$five_h_pct" ] && usage_parts+=("5h ${five_h_pct%.*}%")
[ -n "$seven_d_pct" ] && usage_parts+=("7d ${seven_d_pct%.*}%")
[ -n "$ctx_pct" ] && usage_parts+=("${ctx_pct%.*}% ctx")
[ -n "$cost" ] && usage_parts+=("$(printf 'API-Wert ~$%.2f' "$cost")")

usage_str=""
if [ "${#usage_parts[@]}" -gt 0 ]; then
  usage_str=$(printf '%s · ' "${usage_parts[@]}")
  usage_str="${usage_str% · }"
fi

out=$(printf "${BOLD_CYAN}%s${RESET}" "$short_dir")
[ -n "$branch" ] && out="$out $(printf "${CYAN}%s${RESET}" "$branch")"
[ -n "$status_str" ] && out="$out $(printf "${CYAN}%s${RESET}" "$status_str")"
[ -n "$usage_str" ] && out="$out $(printf "${YELLOW}%s${RESET}" "$usage_str")"

printf '%s' "$out"
