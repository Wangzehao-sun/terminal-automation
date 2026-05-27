# ─── Powerlevel10k Instant Prompt ─────────────────────────────────────────────
# Must stay at the top. Initialization code that may require console input
# (password prompts, [y/n] confirmations, etc.) must go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ─── Oh My Zsh ───────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ─── Shell Options ───────────────────────────────────────────────────────────
setopt autocd
setopt correct
setopt extended_history
setopt hist_ignore_dups
setopt share_history

HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"

# ─── Aliases ─────────────────────────────────────────────────────────────────
alias ca="conda activate"
alias ce="conda env"

# ─── Powerlevel10k Config ────────────────────────────────────────────────────
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# ─── NVM (Node Version Manager) ─────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ─── Local Overrides ─────────────────────────────────────────────────────────
# Source a local file for machine-specific settings (tokens, paths, etc.)
# This file is NOT tracked by git.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ─── Conda ───────────────────────────────────────────────────────────────────
# >>> conda initialize >>>
# This section is auto-managed by `conda init zsh`.
# If empty, the setup script will populate it on install.
# <<< conda initialize <<<
