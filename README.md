# Terminal Automation

One-click setup for my personalized terminal environment (zsh + tmux + vim).  
Clone this repo on any new machine, run one command, done.

## Quick Start

```bash
git clone https://github.com/Wangzehao-sun/terminal-automation.git
cd terminal-automation
./setup.sh
```

That's it. The script handles everything automatically.

## What It Does

1. Detects your OS (macOS / Linux) and package manager
2. Installs missing prerequisites: `zsh`, `git`, `tmux`, `vim`, `curl`
3. Installs [Oh My Zsh](https://ohmyz.sh/) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme
4. Installs zsh plugins: `zsh-completions`, `zsh-autosuggestions`, `zsh-syntax-highlighting`
5. Installs [TPM](https://github.com/tmux-plugins/tpm) and tmux plugins
6. Deploys all config files (`~/.zshrc`, `~/.p10k.zsh`, `~/.tmux.conf`, `~/.vimrc`)
7. Installs MesloLGS NF font (required for Powerlevel10k icons)
8. Sets zsh as default shell

All existing configs are backed up to `~/.dotfiles-backup/<timestamp>/` before overwriting.

## Supported Systems

| OS | Package Manager |
|---|---|
| macOS | Homebrew (auto-installed if missing) |
| Debian / Ubuntu | apt |
| Fedora | dnf |
| CentOS / RHEL | yum |
| Arch Linux | pacman |
| Alpine Linux | apk |

## After Setup

1. Open a new terminal (or run `exec zsh`)
2. Set your terminal font to **MesloLGS NF**
3. (Optional) Create `~/.zshrc.local` for machine-specific settings:

```bash
# ~/.zshrc.local -- not tracked by git
export GITHUB_TOKEN="your_token_here"
export CUSTOM_PATH="/some/local/path"
```

## Project Structure

```
terminal-automation/
├── setup.sh                 # Main installer (run this)
├── config/
│   ├── zsh/.zshrc           # Zsh configuration
│   ├── zsh/.p10k.zsh        # Powerlevel10k theme config
│   ├── tmux/.tmux.conf      # Tmux configuration
│   └── vim/.vimrc           # Vim configuration
└── README.md
```

## Tmux Shortcuts

| Key | Action |
|---|---|
| `prefix` + `-` | Split pane vertically |
| `prefix` + `\|` | Split pane horizontally |
| `prefix` + `r` | Reload tmux config |

Default prefix is `Ctrl-b`.

## Font Setup by Terminal

| Terminal | Where to set font |
|---|---|
| iTerm2 | Preferences > Profiles > Text > Font |
| VS Code | `terminal.integrated.fontFamily`: `MesloLGS NF` |
| Alacritty | `font.normal.family = "MesloLGS NF"` in config |
| kitty | `font_family MesloLGS NF` in kitty.conf |
| WezTerm | `font = wezterm.font("MesloLGS NF")` |
| GNOME Terminal | Preferences > Profile > Text > Custom font |
