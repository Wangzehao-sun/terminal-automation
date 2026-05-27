#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Terminal Environment Setup                                                  ║
# ║  One-click configuration for zsh + tmux + vim                                ║
# ║  Supports: macOS (Homebrew) / Linux (apt, dnf, yum, pacman, apk)             ║
# ║  Works with or without sudo privileges (builds from source if needed)        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$REPO_DIR/config"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
LOCAL_PREFIX="$HOME/.local"
LOCAL_SRC="$HOME/.local/src"
HAS_SUDO=false

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

# Check if we have sudo access (without prompting for password)
check_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    HAS_SUDO=true
  elif sudo -n true 2>/dev/null; then
    HAS_SUDO=true
  else
    HAS_SUDO=false
  fi
}

sudo_run() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  elif $HAS_SUDO; then
    sudo "$@"
  else
    error "No sudo access for: $*"
    return 1
  fi
}

# Ensure ~/.local/bin is in PATH for this session
ensure_local_path() {
  mkdir -p "$LOCAL_PREFIX/bin"
  if [[ ":$PATH:" != *":$LOCAL_PREFIX/bin:"* ]]; then
    export PATH="$LOCAL_PREFIX/bin:$PATH"
  fi
}

# ─── Package Installation (system-level) ─────────────────────────────────────
install_pkg() {
  local mgr
  mgr="$(pkg_manager)"

  # brew doesn't need sudo
  if [[ "$mgr" == "brew" ]]; then
    info "Installing: $* (via brew)"
    brew install "$@"
    return
  fi

  if ! $HAS_SUDO; then
    return 1
  fi

  info "Installing: $* (via $mgr)"
  case "$mgr" in
    apt)    sudo_run apt-get install -y "$@" ;;
    dnf)    sudo_run dnf install -y "$@" ;;
    yum)    sudo_run yum install -y "$@" ;;
    pacman) sudo_run pacman -S --needed --noconfirm "$@" ;;
    apk)    sudo_run apk add --no-cache "$@" ;;
    *)      return 1 ;;
  esac
}

# ─── Build from Source (user-level, no sudo) ─────────────────────────────────
install_from_source() {
  local tool="$1"
  ensure_local_path
  mkdir -p "$LOCAL_SRC"

  case "$tool" in
    zsh)   _build_zsh ;;
    tmux)  _build_tmux ;;
    vim)   _build_vim ;;
    *)     die "Don't know how to build: $tool" ;;
  esac
}

_build_zsh() {
  if has zsh; then return; fi
  info "Building zsh from source (into $LOCAL_PREFIX)..."

  local version="5.9"
  local url="https://sourceforge.net/projects/zsh/files/zsh/${version}/zsh-${version}.tar.xz/download"
  local src_dir="$LOCAL_SRC/zsh-${version}"

  if [[ ! -d "$src_dir" ]]; then
    curl -fsSL "$url" -o "$LOCAL_SRC/zsh-${version}.tar.xz"
    tar -xf "$LOCAL_SRC/zsh-${version}.tar.xz" -C "$LOCAL_SRC"
    rm -f "$LOCAL_SRC/zsh-${version}.tar.xz"
  fi

  cd "$src_dir"
  ./configure --prefix="$LOCAL_PREFIX" --without-tcsetpgrp 2>&1 | tail -3
  make -j"$(nproc 2>/dev/null || echo 2)" 2>&1 | tail -3
  make install 2>&1 | tail -3
  cd "$REPO_DIR"

  has zsh && success "zsh $version installed to $LOCAL_PREFIX/bin/zsh" \
          || die "zsh build failed"
}

_build_tmux() {
  if has tmux; then return; fi
  info "Building tmux from source (into $LOCAL_PREFIX)..."

  # ── libevent (tmux dependency) ──
  if [[ ! -f "$LOCAL_PREFIX/lib/libevent.a" ]]; then
    local ev_version="2.1.12"
    local ev_url="https://github.com/libevent/libevent/releases/download/release-${ev_version}-stable/libevent-${ev_version}-stable.tar.gz"
    local ev_dir="$LOCAL_SRC/libevent-${ev_version}-stable"

    if [[ ! -d "$ev_dir" ]]; then
      info "Building dependency: libevent ${ev_version}"
      curl -fsSL "$ev_url" -o "$LOCAL_SRC/libevent.tar.gz"
      tar -xzf "$LOCAL_SRC/libevent.tar.gz" -C "$LOCAL_SRC"
      rm -f "$LOCAL_SRC/libevent.tar.gz"
    fi

    cd "$ev_dir"
    ./configure --prefix="$LOCAL_PREFIX" --disable-shared 2>&1 | tail -3
    make -j"$(nproc 2>/dev/null || echo 2)" 2>&1 | tail -3
    make install 2>&1 | tail -3
    cd "$REPO_DIR"
  fi

  # ── ncurses (tmux dependency, if not present) ──
  if [[ ! -f "$LOCAL_PREFIX/lib/libncurses.a" ]] && ! pkg-config ncurses 2>/dev/null; then
    local nc_version="6.4"
    local nc_url="https://ftp.gnu.org/gnu/ncurses/ncurses-${nc_version}.tar.gz"
    local nc_dir="$LOCAL_SRC/ncurses-${nc_version}"

    if [[ ! -d "$nc_dir" ]]; then
      info "Building dependency: ncurses ${nc_version}"
      curl -fsSL "$nc_url" -o "$LOCAL_SRC/ncurses.tar.gz"
      tar -xzf "$LOCAL_SRC/ncurses.tar.gz" -C "$LOCAL_SRC"
      rm -f "$LOCAL_SRC/ncurses.tar.gz"
    fi

    cd "$nc_dir"
    ./configure --prefix="$LOCAL_PREFIX" --with-shared --without-debug 2>&1 | tail -3
    make -j"$(nproc 2>/dev/null || echo 2)" 2>&1 | tail -3
    make install 2>&1 | tail -3
    cd "$REPO_DIR"
  fi

  # ── tmux ──
  local tmux_version="3.4"
  local tmux_url="https://github.com/tmux/tmux/releases/download/${tmux_version}/tmux-${tmux_version}.tar.gz"
  local tmux_dir="$LOCAL_SRC/tmux-${tmux_version}"

  if [[ ! -d "$tmux_dir" ]]; then
    curl -fsSL "$tmux_url" -o "$LOCAL_SRC/tmux.tar.gz"
    tar -xzf "$LOCAL_SRC/tmux.tar.gz" -C "$LOCAL_SRC"
    rm -f "$LOCAL_SRC/tmux.tar.gz"
  fi

  cd "$tmux_dir"
  PKG_CONFIG_PATH="$LOCAL_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
  CFLAGS="-I$LOCAL_PREFIX/include -I$LOCAL_PREFIX/include/ncurses" \
  LDFLAGS="-L$LOCAL_PREFIX/lib" \
    ./configure --prefix="$LOCAL_PREFIX" 2>&1 | tail -3
  make -j"$(nproc 2>/dev/null || echo 2)" 2>&1 | tail -3
  make install 2>&1 | tail -3
  cd "$REPO_DIR"

  has tmux && success "tmux $tmux_version installed to $LOCAL_PREFIX/bin/tmux" \
           || die "tmux build failed"
}

_build_vim() {
  if has vim; then return; fi
  info "Building vim from source (into $LOCAL_PREFIX)..."

  local vim_version="9.1.0"
  local vim_url="https://github.com/vim/vim/archive/refs/tags/v${vim_version}.tar.gz"
  local vim_dir="$LOCAL_SRC/vim-${vim_version}"

  if [[ ! -d "$vim_dir" ]]; then
    curl -fsSL "$vim_url" -o "$LOCAL_SRC/vim.tar.gz"
    tar -xzf "$LOCAL_SRC/vim.tar.gz" -C "$LOCAL_SRC"
    rm -f "$LOCAL_SRC/vim.tar.gz"
  fi

  cd "$vim_dir"
  ./configure --prefix="$LOCAL_PREFIX" --with-features=huge --enable-multibyte 2>&1 | tail -3
  make -j"$(nproc 2>/dev/null || echo 2)" 2>&1 | tail -3
  make install 2>&1 | tail -3
  cd "$REPO_DIR"

  has vim && success "vim installed to $LOCAL_PREFIX/bin/vim" \
          || die "vim build failed"
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

  # Detect sudo availability
  check_sudo
  if $HAS_SUDO; then
    info "Sudo access: available"
  else
    warn "Sudo access: unavailable -- will build from source if needed"
  fi

  ensure_local_path

  # Install Homebrew on macOS if missing
  if [[ "$OS" == "macos" ]] && ! has brew; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    success "Homebrew installed"
  fi

  # Update package index on apt-based systems (if we have sudo)
  if [[ "$(pkg_manager)" == "apt" ]] && $HAS_SUDO; then
    info "Updating apt package index..."
    sudo_run apt-get update -qq
  fi

  # Ensure basic build tools exist (needed for source builds)
  if ! $HAS_SUDO && [[ "$(pkg_manager)" != "brew" ]]; then
    for tool in make gcc; do
      has "$tool" || die "'$tool' is required to build from source but not found. Ask your admin to install build-essential."
    done
  fi

  # Check and install each required tool
  local tools=(git curl zsh tmux vim)
  local missing=()

  for t in "${tools[@]}"; do
    has "$t" || missing+=("$t")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    success "All prerequisites already installed"
    return
  fi

  info "Missing tools: ${missing[*]}"

  # Try system package manager first
  if $HAS_SUDO || [[ "$(pkg_manager)" == "brew" ]]; then
    install_pkg "${missing[@]}" && missing=()
  fi

  # Build anything still missing from source
  for t in "${missing[@]}"; do
    if ! has "$t"; then
      install_from_source "$t"
    fi
  done

  # Final verification
  for cmd in git curl zsh; do
    has "$cmd" || die "$cmd is still missing after installation attempts"
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

  if ! has zsh; then
    warn "zsh not installed -- skipping shell change"
    return
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    success "Default shell is already zsh"
    return
  fi

  # With sudo: standard chsh approach
  if $HAS_SUDO; then
    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
      info "Adding $zsh_path to /etc/shells"
      echo "$zsh_path" | sudo_run tee -a /etc/shells >/dev/null
    fi

    if has chsh; then
      info "Changing default shell to zsh..."
      chsh -s "$zsh_path" 2>/dev/null && success "Default shell changed to zsh" \
        || warn "Could not change shell automatically. Run: chsh -s $zsh_path"
    fi
    return
  fi

  # Without sudo: inject `exec zsh` into ~/.bashrc
  warn "No sudo access -- cannot use chsh"
  info "Workaround: adding 'exec zsh' to ~/.bashrc"

  local bashrc="$HOME/.bashrc"
  local marker="# >>> terminal-automation: auto-launch zsh >>>"

  if [[ -f "$bashrc" ]] && grep -qF "$marker" "$bashrc"; then
    success "Auto-launch zsh already configured in ~/.bashrc"
  else
    cat >> "$bashrc" <<BASHRC

$marker
# Automatically start zsh when bash is launched interactively.
# Remove this block if you want to revert to bash.
if [ -x "$zsh_path" ] && [ -z "\$ZSH_VERSION" ]; then
  export PATH="$LOCAL_PREFIX/bin:\$PATH"
  exec "$zsh_path" -l
fi
# <<< terminal-automation: auto-launch zsh <<<
BASHRC
    success "Added auto-launch zsh to ~/.bashrc"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 7: Ensure ~/.local/bin in shell profile (persistent PATH)
# ══════════════════════════════════════════════════════════════════════════════
ensure_persistent_path() {
  # Only needed if we installed things to ~/.local
  if [[ ! -d "$LOCAL_PREFIX/bin" ]] || [[ "$(ls -A "$LOCAL_PREFIX/bin" 2>/dev/null)" == "" ]]; then
    return
  fi

  local marker="# >>> terminal-automation: local PATH >>>"

  # Add to .zshrc.local so it persists
  local local_rc="$HOME/.zshrc.local"
  if [[ -f "$local_rc" ]] && grep -qF "$marker" "$local_rc"; then
    return
  fi

  cat >> "$local_rc" <<PATHRC

$marker
export PATH="$LOCAL_PREFIX/bin:\$PATH"
# <<< terminal-automation: local PATH <<<
PATHRC
  success "Added $LOCAL_PREFIX/bin to PATH in ~/.zshrc.local"
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
  ensure_persistent_path

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
