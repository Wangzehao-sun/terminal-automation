#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Claude Code Statusline Snapshot                                             ║
# ║  Copies the statusline script deployed on this machine back INTO this repo   ║
# ║  (~/.claude/statusline.sh -> config/claude/statusline.sh).                   ║
# ║  Only the statusline is captured for now. The reverse direction (deploy) is  ║
# ║  config/claude/install.sh, also run by `./setup.sh --with-claude`.           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="$REPO_DIR/config/claude/statusline.sh"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SRC="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { printf "${BLUE}[*]${RESET} %s\n" "$1"; }
success() { printf "${GREEN}[✓]${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }

printf "\n${BOLD}Snapshotting Claude Code statusline:${RESET}\n"
printf "  %s -> %s\n\n" "$SRC" "$DST"

# ── Nothing deployed: explain why instead of failing ──
if [[ ! -f "$SRC" ]]; then
  if [[ -f "$SETTINGS" ]] && grep -q '"statusLine"' "$SETTINGS"; then
    warn "$SRC not found: the statusLine in settings.json is an inline command, not statusline.sh"
    info "Switch to the repo's script with:  bash $REPO_DIR/config/claude/install.sh"
  else
    warn "No statusline found in $CLAUDE_DIR -- nothing to snapshot"
  fi
  exit 0
fi

# ── statusline.sh ──
if [[ -f "$DST" ]] && cmp -s "$SRC" "$DST"; then
  success "statusline.sh (unchanged)"
else
  if [[ -f "$DST" ]]; then
    diff -u "$DST" "$SRC" || true
    printf "\n"
  fi
  mkdir -p "$(dirname "$DST")"
  cp "$SRC" "$DST"
  success "statusline.sh"
fi

# This repo is public: keep machine-specific paths out of the script
if grep -qF "$HOME" "$DST"; then
  warn "statusline.sh contains your home directory ($HOME) -- use \$HOME or \$(command -v ...) before committing"
fi

# The deployed script only matters if settings.json actually runs it
if [[ ! -f "$SETTINGS" ]] || ! grep -q 'statusline\.sh' "$SETTINGS"; then
  warn "settings.json statusLine does not run statusline.sh -- run config/claude/install.sh to set it"
fi

printf "\n${GREEN}${BOLD}Snapshot complete!${RESET}\n"
info "Review changes:  git diff config/claude/statusline.sh"
info "Commit & push:   git add config/claude/statusline.sh && git commit -m 'Update Claude statusline'"
printf "\n"
