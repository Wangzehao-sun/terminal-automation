#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Claude Code Config Snapshot                                                 ║
# ║  Copies your current Claude Code configuration INTO this repo so it can be   ║
# ║  deployed on other machines via setup.sh.                                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="$REPO_DIR/config/claude"
SRC="$HOME/.claude-internal"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { printf "${BLUE}[*]${RESET} %s\n" "$1"; }
success() { printf "${GREEN}[✓]${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }

if [[ ! -d "$SRC" ]]; then
  warn "$SRC does not exist -- nothing to snapshot"
  exit 0
fi

mkdir -p "$DST"

printf "\n${BOLD}Snapshotting Claude Code config:${RESET}\n"
printf "  ${SRC} -> ${DST}\n\n"

# ── settings.json ──
if [[ -f "$SRC/settings.json" ]]; then
  cp "$SRC/settings.json" "$DST/settings.json"
  # Sanitize: replace hardcoded node path with dynamic lookup (claude-hud statusline)
  if grep -q '/Users/[^"]*/node\|/home/[^"]*/node' "$DST/settings.json"; then
    sed -E -i.bak 's|\\"(/Users/[^/]*/.nvm/[^"]*node\|/home/[^/]*/[^"]*node)\\"|\\"$(command -v node)\\"|g' "$DST/settings.json" 2>/dev/null \
      || python3 -c "
import json,sys,re
p='$DST/settings.json'
d=json.load(open(p))
if 'statusLine' in d and 'command' in d['statusLine']:
    d['statusLine']['command']=re.sub(r'\"/(Users|home)/[^\"]*node\"', '\"\$(command -v node)\"', d['statusLine']['command'])
    json.dump(d, open(p,'w'), indent=2)
"
    rm -f "$DST/settings.json.bak"
    info "  sanitized hardcoded node path -> \$(command -v node)"
  fi
  success "settings.json"
fi

# ── CLAUDE.md (global memory) ──
if [[ -f "$SRC/CLAUDE.md" ]]; then
  cp "$SRC/CLAUDE.md" "$DST/CLAUDE.md"
  success "CLAUDE.md"
fi

# ── keybindings.json ──
if [[ -f "$SRC/keybindings.json" ]]; then
  cp "$SRC/keybindings.json" "$DST/keybindings.json"
  success "keybindings.json"
fi

# ── agents/ (custom subagents) ──
if [[ -d "$SRC/agents" ]] && [[ -n "$(ls -A "$SRC/agents" 2>/dev/null)" ]]; then
  rm -rf "$DST/agents"
  cp -R "$SRC/agents" "$DST/agents"
  success "agents/ ($(ls "$DST/agents" | wc -l | tr -d ' ') items)"
fi

# ── commands/ (custom slash commands) ──
if [[ -d "$SRC/commands" ]] && [[ -n "$(ls -A "$SRC/commands" 2>/dev/null)" ]]; then
  rm -rf "$DST/commands"
  cp -R "$SRC/commands" "$DST/commands"
  success "commands/ ($(ls "$DST/commands" | wc -l | tr -d ' ') items)"
fi

printf "\n${GREEN}${BOLD}Snapshot complete!${RESET}\n"
info "Review changes:  git diff config/claude/"
info "Commit & push:   git add config/claude && git commit -m 'Update Claude config'"
printf "\n"
