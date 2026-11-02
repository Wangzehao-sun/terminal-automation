#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; MAGENTA='\033[35m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
  # Cache git status for 5s, it can be slow on network filesystems
  CACHE="/tmp/statusline-git-$(echo "$DIR" | md5sum | cut -c1-8)"
  if [ ! -f "$CACHE" ] || [ $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -gt 5 ]; then
    # Write to a temp file and rename, so concurrent readers never see an empty or half-written cache.
    # On failure keep the old cache (touch it to back off) instead of caching an empty result.
    # --no-optional-locks: read-only, never takes .git/index.lock so it can't block other git commands
    TMP="$CACHE.$$"
    if git --no-optional-locks -C "$DIR" status --porcelain=v2 --branch > "$TMP" 2>/dev/null; then
      mv -f "$TMP" "$CACHE"
    else
      rm -f "$TMP"; touch "$CACHE" 2>/dev/null
    fi
  fi

  if [ -s "$CACHE" ]; then
    GIT_HEAD=$(awk '/^# branch.head/ {print $3}' "$CACHE")
    [ "$GIT_HEAD" = "(detached)" ] && GIT_HEAD="$(awk '/^# branch.oid/ {print substr($3, 1, 7)}' "$CACHE")"
    AHEAD=$(awk '/^# branch.ab/ {print substr($3, 2)}' "$CACHE")
    BEHIND=$(awk '/^# branch.ab/ {print substr($4, 2)}' "$CACHE")
    STAGED=$(grep -c '^[12] [^.]' "$CACHE")
    MODIFIED=$(grep -c '^[12] .[^.]' "$CACHE")
    UNTRACKED=$(grep -c '^?' "$CACHE")
    CONFLICT=$(grep -c '^u' "$CACHE")

    GIT_FLAGS=""
    [ "${AHEAD:-0}" -gt 0 ] && GIT_FLAGS="$GIT_FLAGS ↑$AHEAD"
    [ "${BEHIND:-0}" -gt 0 ] && GIT_FLAGS="$GIT_FLAGS ↓$BEHIND"
    [ "$STAGED" -gt 0 ] && GIT_FLAGS="$GIT_FLAGS ${GREEN}+$STAGED${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_FLAGS="$GIT_FLAGS ${YELLOW}~$MODIFIED${RESET}"
    [ "$UNTRACKED" -gt 0 ] && GIT_FLAGS="$GIT_FLAGS ${RED}?$UNTRACKED${RESET}"
    [ "$CONFLICT" -gt 0 ] && GIT_FLAGS="$GIT_FLAGS ${RED}!$CONFLICT${RESET}"
    [ -z "$GIT_FLAGS" ] && GIT_FLAGS=" ${GREEN}✓${RESET}"

    BRANCH=" | 🌿 ${GIT_HEAD}${GIT_FLAGS}"
  fi
fi

EFFORT_FMT=""
if [ -n "$EFFORT" ]; then
  case "$EFFORT" in
    low) N=1 ;; medium) N=2 ;; high) N=3 ;; xhigh) N=4 ;; max) N=5 ;; *) N=0 ;;
  esac
  printf -v E_ON "%${N}s"; printf -v E_OFF "%$((5 - N))s"
  EFFORT_FMT=" ${MAGENTA}${E_ON// /●}${E_OFF// /○} ${EFFORT}${RESET}"
fi

echo -e "${CYAN}[$MODEL]${RESET}${EFFORT_FMT} 📁 ${DIR##*/}$BRANCH"
COST_FMT=$(printf '$%.2f' "$COST")
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"
