#!/usr/bin/env bash
# Claude Code statusline: renders the claude-hud plugin.
# Claude Code pipes session JSON to stdin; claude-hud prints the status line.
# Deployed to ~/.claude/statusline.sh by install-statusline.sh -- edit it here,
# not there. Contains no machine-specific paths, so it works on any machine.

# Width of the terminal (stty needs a tty; fall back to 120 when there is none)
cols=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
export COLUMNS=$(( ${cols:-120} > 4 ? ${cols:-120} - 4 : 1 ))

# node: PATH first, then the newest nvm-installed one (nvm isn't loaded in
# non-interactive shells, so PATH alone can miss it)
node_bin=$(command -v node 2>/dev/null || true)
if [ -z "$node_bin" ]; then
  node_bin=$(ls -d "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | sort -V | tail -1)
fi

# newest installed claude-hud version under <config dir>/plugins/cache/
plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  | tail -1 | cut -f2-)

if [ -z "$node_bin" ]; then
  echo "statusline: node not found"; exit 0
fi
if [ ! -f "${plugin_dir}dist/index.js" ]; then
  echo "statusline: claude-hud plugin not installed"; exit 0
fi

exec "$node_bin" "${plugin_dir}dist/index.js"
