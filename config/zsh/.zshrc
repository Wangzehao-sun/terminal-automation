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

# ─── Conda ───────────────────────────────────────────────────────────────────
# `conda init zsh` will insert its managed block below on first setup.
# As a fallback, auto-detect conda if the init block hasn't run yet.
if [ -z "$CONDA_SHLVL" ]; then
  for _conda_path in \
    "$HOME/anaconda3" \
    "$HOME/miniconda3" \
    "$HOME/miniforge3" \
    "/opt/homebrew/anaconda3" \
    "/opt/homebrew/Caskroom/miniconda/base" \
    "/usr/local/anaconda3" \
    "/usr/local/miniconda3" \
    "/opt/anaconda3" \
    "/opt/miniconda3" \
    "/opt/conda"; do
    if [ -f "$_conda_path/bin/conda" ]; then
      __conda_setup="$("$_conda_path/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"
      if [ $? -eq 0 ]; then
        eval "$__conda_setup"
      else
        [ -f "$_conda_path/etc/profile.d/conda.sh" ] && . "$_conda_path/etc/profile.d/conda.sh"
      fi
      unset __conda_setup
      break
    fi
  done
  unset _conda_path
fi

# ─── Local Overrides ─────────────────────────────────────────────────────────
# Source a local file for machine-specific settings (tokens, paths, etc.)
# This file is NOT tracked by git.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

: # ensure .zshrc ends with exit code 0

: # ensure .zshrc ends with exit code 0
