#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Claude Code statusline installer                                            ║
# ║  Deploys statusline.sh (claude-hud) and points settings.json at it.          ║
# ║  Only the "statusLine" key of settings.json is touched; safe to re-run.      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#   Usage: bash install.sh [--skip-plugin]
#     --skip-plugin  don't touch the claude CLI / claude-hud plugin (statusline files only)
#   If the claude CLI is missing it is installed with the official installer.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
TARGET="$CLAUDE_DIR/statusline.sh"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
HUD_ID="claude-hud@claude-hud"
HUD_REPO="jarrodwatts/claude-hud"
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'
info()    { printf "${BLUE}[*]${RESET} %s\n" "$1"; }
success() { printf "${GREEN}[✓]${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
die()     { printf "${RED}[✗]${RESET} %s\n" "$1" >&2; exit 1; }
has()     { command -v "$1" &>/dev/null; }

backup_copy() {
  mkdir -p "$BACKUP_DIR"
  cp "$1" "$BACKUP_DIR/$(basename "$1")"
  info "Backed up: $1 -> $BACKUP_DIR/"
}

# ── Claude Code CLI: install with the official native installer if missing ───
ensure_claude() {
  # The installer puts the launcher in ~/.local/bin, which may not be on PATH yet
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
  has claude && return 0

  has curl || { warn "curl not found -- cannot install Claude Code automatically"; return 1; }
  info "Claude Code not found -- installing via $CLAUDE_INSTALL_URL ..."
  if curl -fsSL "$CLAUDE_INSTALL_URL" | bash && has claude; then
    success "Claude Code installed: $(claude --version 2>/dev/null || true)"
  else
    warn "Claude Code install failed. Install it manually (https://code.claude.com/docs/en/setup), then re-run."
    return 1
  fi
}

# ── claude-hud plugin (the statusline is just a launcher for it) ─────────────
install_plugin() {
  ensure_claude || { warn "Skipping claude-hud install"; return; }
  # Capture first: `claude ... | grep -q` would trip pipefail via SIGPIPE
  local installed
  installed="$(claude plugin list --json 2>/dev/null || true)"
  if grep -qF "\"$HUD_ID\"" <<<"$installed"; then
    success "claude-hud plugin already installed"
    return
  fi
  info "Installing claude-hud plugin..."
  claude plugin marketplace add "$HUD_REPO" >/dev/null 2>&1 || true   # may already be added
  if claude plugin install "$HUD_ID" >/dev/null 2>&1; then
    success "claude-hud plugin installed"
  else
    warn "Could not install claude-hud automatically. Inside Claude Code run:"
    warn "  /plugin marketplace add $HUD_REPO"
    warn "  /plugin install $HUD_ID"
  fi
}

# ── settings.json editing (jq, with a python3 fallback) ──────────────────────
# Prints the current statusLine.command if its type is "command", else nothing.
read_status_cmd() {
  if has jq; then
    jq -r 'if .statusLine.type == "command" then .statusLine.command // "" else "" end' "$SETTINGS"
  else
    python3 - "$SETTINGS" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])).get("statusLine") or {}
print(s.get("command", "") if s.get("type") == "command" else "")
PY
  fi
}

# Prints the whole settings.json with statusLine set; other keys (and any extra
# statusLine keys such as "padding") are preserved.
render_settings() {
  if has jq; then
    jq --arg cmd "$1" '.statusLine = ((.statusLine // {}) + {type: "command", command: $cmd})' "$SETTINGS"
  else
    python3 - "$SETTINGS" "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
s = d.get("statusLine") if isinstance(d.get("statusLine"), dict) else {}
s.update(type="command", command=sys.argv[2])
d["statusLine"] = s
print(json.dumps(d, indent=2, ensure_ascii=False))
PY
  fi
}

install_statusline() {
  local src="$SRC_DIR/statusline.sh"
  [[ -f "$src" ]] || die "Missing $src"
  has jq || has python3 || die "Need jq or python3 to edit $SETTINGS. Add this by hand instead:
  \"statusLine\": {\"type\": \"command\", \"command\": \"bash $TARGET\"}"

  mkdir -p "$CLAUDE_DIR"

  # ── script ──
  if [[ -f "$TARGET" ]] && cmp -s "$src" "$TARGET"; then
    info "Up to date: $TARGET"
  else
    [[ -f "$TARGET" ]] && backup_copy "$TARGET"
    cp "$src" "$TARGET"
    success "Deployed: $TARGET"
  fi
  chmod +x "$TARGET"

  # ── settings.json: statusLine only ──
  local cmd='bash ~/.claude/statusline.sh'
  [[ "$CLAUDE_DIR" == "$HOME/.claude" ]] || cmd="bash \"$TARGET\""

  local existed=false
  if [[ -s "$SETTINGS" ]]; then existed=true; else echo '{}' > "$SETTINGS"; fi

  local current updated
  current="$(read_status_cmd)" || die "Could not parse $SETTINGS (expected a JSON object); fix it and re-run"
  if [[ "$current" == "$cmd" ]]; then
    success "statusLine already set in $SETTINGS"
    return
  fi

  updated="$(render_settings "$cmd")" || die "Could not update $SETTINGS; left unchanged"
  $existed && backup_copy "$SETTINGS"
  # Write in place (not mv) so file mode and symlinks are preserved
  printf '%s\n' "$updated" > "$SETTINGS"
  if [[ -n "$current" ]]; then
    success "statusLine replaced in $SETTINGS (was: ${current:0:60}...)"
  else
    success "statusLine set in $SETTINGS"
  fi
}

main() {
  local skip_plugin=false
  for arg in "$@"; do
    case "$arg" in
      --skip-plugin) skip_plugin=true ;;
      -h|--help) echo "Usage: bash install.sh [--skip-plugin]"; exit 0 ;;
      *) die "Unknown option: $arg" ;;
    esac
  done

  info "Claude config dir: $CLAUDE_DIR"
  $skip_plugin || install_plugin
  install_statusline
  info "Restart Claude Code (or wait for the next refresh) to see the statusline."
}

main "$@"
