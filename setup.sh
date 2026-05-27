#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Terminal Environment Setup                                                  ║
# ║  One-click configuration for zsh + tmux + vim                                ║
# ║  Supports: macOS (Homebrew) / Linux (apt, dnf, yum, pacman, apk)             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$REPO_DIR/config"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

# ─── Colors & Formatting ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Output Helpers ───────────────────────────────────────────────────────────
info()    { printf "${BLUE}[*]${RESET} %s\n" "$1"; }
success() { printf "${GREEN}[✓]${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
error()   { printf "${RED}[✗]${RESET} %s\n" "$1" >&2; }
step()    { printf "\n${BOLD}${MAGENTA}── %s ──${RESET}\n" "$1"; }

die() {
  error "$1"
  exit 1
}

# ─── Utilities ────────────────────────────────────────────────────────────────
has() { command -v "$1" &>/dev/null; }

os_type() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

pkg_manager() {
  if has brew;    then echo "brew"
  elif has apt-get; then echo "apt"
  elif has dnf;   then echo "dnf"
  elif has yum;   then echo "yum"
  elif has pacman; then echo "pacman"
  elif has apk;   then echo "apk"
  else echo "none"
  fi
}

sudo_run() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# ─── Package Installation ────────────────────────────────────────────────────
install_pkg() {
  local mgr
  mgr="$(pkg_manager)"
  info "Installing: $* (via $mgr)"

  case "$mgr" in
    brew)   brew install "$@" ;;
    apt)    sudo_run apt-get install -y "$@" ;;
    dnf)    sudo_run dnf install -y "$@" ;;
    yum)    sudo_run yum install -y "$@" ;;
    pacman) sudo_run pacman -S --needed --noconfirm "$@" ;;
    apk)    sudo_run apk add --no-cache "$@" ;;
    *)      die "No supported package manager found. Install manually: $*" ;;
  esac
}

# ─── Backup & Deploy ─────────────────────────────────────────────────────────
backup_file() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
    info "Backed up: $target -> $BACKUP_DIR/"
  fi
}

deploy_config() {
  local src="$1"
  local dst="$2"
  backup_file "$dst"
  cp "$src" "$dst"
  success "Deployed: $dst"
}

# ─── Clone / Update a Git Repo ───────────────────────────────────────────────
ensure_repo() {
  local url="$1"
  local dest="$2"
  local depth="${3:-}"

  if [[ -d "$dest/.git" ]]; then
    info "Updating: $(basename "$dest")"
    git -C "$dest" pull --ff-only --quiet 2>/dev/null || true
  else
    info "Cloning: $url"
    if [[ -n "$depth" ]]; then
      git clone --depth="$depth" "$url" "$dest" --quiet
    else
      git clone "$url" "$dest" --quiet
    fi
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1: Prerequisites
# ══════════════════════════════════════════════════════════════════════════════
install_prerequisites() {
  step "Checking prerequisites"

  local OS
  OS="$(os_type)"

  # Install Homebrew on macOS if missing
  if [[ "$OS" == "macos" ]] && ! has brew; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Source brew for this session
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    success "Homebrew installed"
  fi

  # Update package index on apt-based systems
  if [[ "$(pkg_manager)" == "apt" ]]; then
    info "Updating apt package index..."
    sudo_run apt-get update -qq
  fi

  # Required tools
  local needed=()
  has git  || needed+=(git)
  has zsh  || needed+=(zsh)
  has tmux || needed+=(tmux)
  has vim  || needed+=(vim)
  has curl || needed+=(curl)

  if [[ ${#needed[@]} -gt 0 ]]; then
    install_pkg "${needed[@]}"
  fi

  # Verify
  for cmd in git zsh tmux vim curl; do
    has "$cmd" || die "$cmd failed to install"
  done

  success "All prerequisites satisfied"
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2: Zsh Environment
# ══════════════════════════════════════════════════════════════════════════════
setup_zsh() {
  step "Setting up Zsh"

  # ── Oh My Zsh ──
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "Oh My Zsh installed"
  else
    success "Oh My Zsh already present"
  fi

  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  # ── Powerlevel10k theme ──
  ensure_repo "https://github.com/romkatv/powerlevel10k.git" \
    "$ZSH_CUSTOM/themes/powerlevel10k" "1"
  success "Powerlevel10k theme ready"

  # ── Plugins ──
  ensure_repo "https://github.com/zsh-users/zsh-completions.git" \
    "$ZSH_CUSTOM/plugins/zsh-completions"
  ensure_repo "https://github.com/zsh-users/zsh-autosuggestions.git" \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  ensure_repo "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  success "Zsh plugins ready"

  # ── Deploy configs ──
  deploy_config "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc"
  deploy_config "$CONFIG_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3: Tmux Environment
# ══════════════════════════════════════════════════════════════════════════════
setup_tmux() {
  step "Setting up Tmux"

  # ── TPM (Tmux Plugin Manager) ──
  ensure_repo "https://github.com/tmux-plugins/tpm.git" \
    "$HOME/.tmux/plugins/tpm"
  success "TPM ready"

  # ── Deploy config ──
  deploy_config "$CONFIG_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

  # ── Install plugins ──
  if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
    info "Installing tmux plugins..."
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true
    success "Tmux plugins installed"
  else
    warn "Start tmux and press prefix+I to install plugins"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 4: Vim Environment
# ══════════════════════════════════════════════════════════════════════════════
setup_vim() {
  step "Setting up Vim"
  deploy_config "$CONFIG_DIR/vim/.vimrc" "$HOME/.vimrc"
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 5: Nerd Font (for Powerlevel10k icons)
# ══════════════════════════════════════════════════════════════════════════════
install_fonts() {
  step "Installing Nerd Font (MesloLGS NF)"

  local font_dir
  if [[ "$(os_type)" == "macos" ]]; then
    font_dir="$HOME/Library/Fonts"
  else
    font_dir="$HOME/.local/share/fonts"
  fi
  mkdir -p "$font_dir"

  local base_url="https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master"
  local fonts=(
    "MesloLGS%20NF%20Regular.ttf"
    "MesloLGS%20NF%20Bold.ttf"
    "MesloLGS%20NF%20Italic.ttf"
    "MesloLGS%20NF%20Bold%20Italic.ttf"
  )
  local names=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
  )

  local all_present=true
  for name in "${names[@]}"; do
    [[ -f "$font_dir/$name" ]] || { all_present=false; break; }
  done

  if $all_present; then
    success "Fonts already installed"
    return
  fi

  for i in "${!fonts[@]}"; do
    curl -fsSL "$base_url/${fonts[$i]}" -o "$font_dir/${names[$i]}"
  done

  # Refresh font cache on Linux
  if has fc-cache; then
    fc-cache -f "$font_dir" 2>/dev/null || true
  fi

  success "MesloLGS NF fonts installed to: $font_dir"
  warn "Set your terminal emulator font to: MesloLGS NF"
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 6: Set Zsh as Default Shell
# ══════════════════════════════════════════════════════════════════════════════
set_default_shell() {
  step "Setting default shell"

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    success "Default shell is already zsh"
    return
  fi

  # Ensure zsh is in /etc/shells
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    info "Adding $zsh_path to /etc/shells"
    echo "$zsh_path" | sudo_run tee -a /etc/shells >/dev/null
  fi

  if has chsh; then
    info "Changing default shell to zsh..."
    chsh -s "$zsh_path" 2>/dev/null && success "Default shell changed to zsh" \
      || warn "Could not change shell automatically. Run: chsh -s $zsh_path"
  else
    warn "chsh not found. Manually set your shell to: $zsh_path"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════════════
main() {
  printf "\n"
  printf "${BOLD}${CYAN}"
  printf "  ╔══════════════════════════════════════════════════╗\n"
  printf "  ║     Terminal Environment Setup                   ║\n"
  printf "  ║     zsh + tmux + vim :: one-click config         ║\n"
  printf "  ╚══════════════════════════════════════════════════╝\n"
  printf "${RESET}\n"
  printf "  ${DIM}OS: $(uname -s) $(uname -m) | User: $(whoami)${RESET}\n\n"

  install_prerequisites
  setup_zsh
  setup_tmux
  setup_vim
  install_fonts
  set_default_shell

  # ── Summary ──
  printf "\n"
  printf "${BOLD}${GREEN}"
  printf "  ╔══════════════════════════════════════════════════╗\n"
  printf "  ║     Setup Complete!                             ║\n"
  printf "  ╚══════════════════════════════════════════════════╝\n"
  printf "${RESET}\n"

  if [[ -d "$BACKUP_DIR" ]]; then
    info "Old configs backed up to: $BACKUP_DIR"
  fi

  printf "\n"
  printf "  ${BOLD}Next steps:${RESET}\n"
  printf "  ${DIM}1.${RESET} Open a new terminal (or run: ${CYAN}exec zsh${RESET})\n"
  printf "  ${DIM}2.${RESET} Set terminal font to: ${CYAN}MesloLGS NF${RESET}\n"
  printf "  ${DIM}3.${RESET} (Optional) Add secrets to: ${CYAN}~/.zshrc.local${RESET}\n"
  printf "     e.g. export GITHUB_TOKEN=\"your_token_here\"\n"
  printf "\n"
}

main "$@"
