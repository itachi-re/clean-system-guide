# Shell Aliases — A Comprehensive Guide

> Battle-tested aliases for a faster, safer, and more ergonomic terminal experience.
> Covers **Arch Linux**, **Debian/Ubuntu**, and **openSUSE**.

---

## Table of Contents

- [What is an Alias?](#what-is-an-alias)
- [Where to Put Your Aliases](#where-to-put-your-aliases)
- [How to Reload](#how-to-reload)
- [Core Aliases (Distro-Agnostic)](#core-aliases-distro-agnostic)
  - [Navigation](#-navigation)
  - [Editor](#-editor)
  - [Listing & Files](#-listing--files)
  - [Safety Nets](#-safety-nets)
  - [Git](#-git)
  - [System Info](#-system-info)
  - [Network](#-network)
  - [Process Management](#-process-management)
  - [Archives](#-archives)
  - [Development](#-development)
  - [Misc & Quality of Life](#-misc--quality-of-life)
- [Package Manager Aliases by Distro](#package-manager-aliases-by-distro)
  - [Arch Linux (pacman / yay / paru)](#arch-linux-pacman--yay--paru)
  - [Debian / Ubuntu (apt)](#debian--ubuntu-apt)
  - [openSUSE (zypper)](#opensuse-zypper)
- [Distro Detection — One File for All](#distro-detection--one-file-for-all)
- [Advanced Alias Patterns](#advanced-alias-patterns)
- [Installing the Aliases](#installing-the-aliases)
- [Tips & Gotchas](#tips--gotchas)

---

## What is an Alias?

An alias is a short name that expands to a longer command. It lives in your shell config and is evaluated before anything else in the command search path.

```zsh
alias gs='git status'   # gs → git status
alias ll='ls -lah'      # ll → ls -lah --human-readable
```

Aliases are shell-specific. These examples work in **Zsh** and **Bash**. For Fish, the syntax differs (`alias gs 'git status'`).

---

## Where to Put Your Aliases

| Shell | Config File | Notes |
|-------|-------------|-------|
| Zsh | `~/.zshrc` | Or a dedicated `~/.zsh_aliases` sourced from `.zshrc` |
| Bash | `~/.bashrc` | Or a dedicated `~/.bash_aliases` sourced from `.bashrc` |
| Both | `~/.aliases` | Source this from both `.zshrc` and `.bashrc` |

**Recommended approach — keep aliases in a separate file:**

```zsh
# In ~/.zshrc or ~/.bashrc
[ -f ~/.aliases ] && source ~/.aliases
```

This keeps your main config clean and lets you share aliases across shells.

---

## How to Reload

After editing aliases, reload without restarting the terminal:

```zsh
# Reload Zsh config
alias reload='source ~/.zshrc'

# Reload Bash config
alias reload='source ~/.bashrc'
```

---

## Core Aliases (Distro-Agnostic)

These work identically on Arch, Debian, and openSUSE.

---

### 🗂 Navigation

```zsh
# ── Quick jumps ────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias home='cd ~'
alias dl='cd ~/Downloads'
alias docs='cd ~/Documents'
alias dots='cd ~/.dotfiles'
alias conf='cd ~/.config'

# ── Directory shortcuts ─────────────────────────────────────
alias md='mkdir -p'           # Create nested dirs in one shot
alias rd='rmdir'
alias mkcd='mkdir -p "$1" && cd "$1"'   # Create and enter dir (use as function — see Advanced)
```

---

### ✏️ Editor

```zsh
# ── Neovim (replace with your editor of choice) ────────────
alias v='nvim'
alias vi='nvim'
alias vim='nvim'
alias nv='nvim'

# ── Quick config edits ──────────────────────────────────────
alias ezsh='nvim ~/.zshrc'
alias ebash='nvim ~/.bashrc'
alias ealias='nvim ~/.aliases'
alias estarship='nvim ~/.config/starship.toml'
alias ehosts='sudo nvim /etc/hosts'
```

---

### 📋 Listing & Files

```zsh
# ── ls replacements ─────────────────────────────────────────
alias ls='ls --color=auto -h'
alias ll='ls -lah'            # Long, all, human-readable
alias la='ls -la'             # Long, all
alias l='ls -alF'             # Long, all, with type indicator
alias lsd='ls -d */'          # List directories only
alias lsf='ls -p | grep -v /' # List files only
alias lt='ls -laht'           # Sort by newest first
alias lz='ls -lahS'           # Sort by size

# ── Disk usage ──────────────────────────────────────────────
alias df='df -h'                          # Human-readable disk usage
alias du='du -sh'                         # Directory size summary
alias dua='du -sh *'                      # Size of everything in current dir
alias durank='du -sh * | sort -rh | head' # Top 10 space hogs

# ── File operations ─────────────────────────────────────────
alias cp='cp -i'         # Prompt before overwrite
alias mv='mv -i'         # Prompt before overwrite
alias rm='rm -i'         # Prompt before delete
alias ln='ln -i'         # Prompt before overwrite
alias rmf='rm -rf'       # Force remove (use consciously)

# ── Searching ───────────────────────────────────────────────
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias rg='rg --color=auto'    # ripgrep (install separately)
alias ff='find . -name'       # Quick find by name: ff "*.log"
```

---

### 🛡 Safety Nets

```zsh
# ── Prevent foot-guns ───────────────────────────────────────
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# ── Dangerous command warnings ──────────────────────────────
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'

# ── Redo last command with sudo ─────────────────────────────
alias fuck='sudo $(fc -ln -1)'            # Zsh
# alias fuck='sudo $(history -p !-1)'     # Bash equivalent

# ── Accidental unmount message ──────────────────────────────
alias unmount='echo "Did you mean: umount" 1>&2; false'
```

---

### 🌿 Git

```zsh
# ── Core ────────────────────────────────────────────────────
alias g='git'
alias gi='git init'
alias gs='git status'
alias ga='git add'
alias gaa='git add .'
alias gap='git add -p'                     # Interactive staging
alias gc='git commit -m'
alias gca='git commit --amend'
alias gcane='git commit --amend --no-edit' # Amend without editing message
alias gp='git push'
alias gpf='git push --force-with-lease'    # Safer force push
alias gpl='git pull'
alias gpr='git pull --rebase'

# ── Branching ───────────────────────────────────────────────
alias gb='git branch'
alias gba='git branch -a'                 # All branches (local + remote)
alias gbd='git branch -d'                 # Safe delete
alias gbD='git branch -D'                 # Force delete
alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias gswc='git switch -c'

# ── Inspection ──────────────────────────────────────────────
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gll='git log --format="%C(yellow)%h%Creset %s %C(cyan)(%cr)%Creset %C(dim)— %an%Creset"'
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'

# ── Remote ──────────────────────────────────────────────────
alias gf='git fetch'
alias gfa='git fetch --all'
alias gr='git remote -v'
alias gra='git remote add'

# ── Cleanup ─────────────────────────────────────────────────
alias gclean='git clean -fd'                      # Remove untracked files/dirs
alias gprune='git remote prune origin'            # Remove stale remote refs
alias gdelbranches='git branch | grep -v "main\|master\|develop" | xargs git branch -d'
```

---

### 🖥 System Info

```zsh
# ── Resources ───────────────────────────────────────────────
alias free='free -h'
alias meminfo='cat /proc/meminfo'
alias cpuinfo='cat /proc/cpuinfo'
alias pscpu='ps auxf | sort -nr -k 3 | head -10'    # Top CPU processes
alias psmem='ps auxf | sort -nr -k 4 | head -10'    # Top memory processes
alias top='htop'        # Requires htop installed

# ── Hardware ────────────────────────────────────────────────
alias lsblk='lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL'
alias lspci='lspci -v'
alias lsusb='lsusb -v 2>/dev/null | grep -E "Bus|iProduct|bDeviceClass"'

# ── Logs ────────────────────────────────────────────────────
alias jctl='journalctl -xe'           # System journal (errors)
alias jctlf='journalctl -f'           # Follow live journal
alias jctlb='journalctl -b'           # Current boot logs
alias syslog='sudo tail -f /var/log/syslog'

# ── Boot & Services ─────────────────────────────────────────
alias sctl='systemctl'
alias sctls='systemctl status'
alias sctlr='sudo systemctl restart'
alias sctlen='sudo systemctl enable'
alias sctldis='sudo systemctl disable'
alias sctldr='sudo systemctl daemon-reload'
alias services='systemctl list-units --type=service --state=running'
```

---

### 🌐 Network

```zsh
# ── Info ────────────────────────────────────────────────────
alias ip='ip --color=auto'
alias myip='curl -s ifconfig.me && echo'          # Public IP
alias localip="ip route get 1 | awk '{print \$7;exit}'"  # Local IP
alias ports='ss -tulanp'                           # All open ports
alias listening='ss -tlnp'                         # Listening ports only

# ── Connectivity ────────────────────────────────────────────
alias ping='ping -c 5'                  # Limit to 5 packets
alias fastping='ping -c 100 -i 0.2'
alias wget='wget -c'                    # Resume downloads by default

# ── DNS ─────────────────────────────────────────────────────
alias flushdns='sudo systemd-resolve --flush-caches && echo "DNS flushed"'
alias dnslookup='dig +short'           # Quick DNS: dnslookup google.com
alias whois='whois -H'                 # Cleaner whois output

# ── Firewall ────────────────────────────────────────────────
alias fwstatus='sudo ufw status verbose'
alias fwlist='sudo iptables -L -v -n --line-numbers'
```

---

### ⚙️ Process Management

```zsh
alias ps='ps auxf'
alias psg='ps aux | grep -v grep | grep -i'  # Search processes: psg firefox
alias killall='killall -v'
alias k9='kill -9'

# ── Background jobs ─────────────────────────────────────────
alias j='jobs -l'
```

---

### 📦 Archives

```zsh
# ── Extract anything ────────────────────────────────────────
# Usage: extract file.tar.gz
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)  tar xjf "$1"     ;;
            *.tar.gz)   tar xzf "$1"     ;;
            *.tar.xz)   tar xJf "$1"     ;;
            *.tar.zst)  tar --zstd -xf "$1" ;;
            *.bz2)      bunzip2 "$1"     ;;
            *.rar)      unrar x "$1"     ;;
            *.gz)       gunzip "$1"      ;;
            *.tar)      tar xf "$1"      ;;
            *.tbz2)     tar xjf "$1"     ;;
            *.tgz)      tar xzf "$1"     ;;
            *.zip)      unzip "$1"       ;;
            *.Z)        uncompress "$1"  ;;
            *.7z)       7z x "$1"        ;;
            *.zst)      zstd -d "$1"     ;;
            *)          echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# ── Create archives ─────────────────────────────────────────
alias mktar='tar -czf'     # mktar archive.tar.gz folder/
alias mkzip='zip -r'       # mkzip archive.zip folder/
```

---

### 🔧 Development

```zsh
# ── Python ──────────────────────────────────────────────────
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv .venv && source .venv/bin/activate'
alias activate='source .venv/bin/activate'

# ── Node / NPM ──────────────────────────────────────────────
alias ni='npm install'
alias nid='npm install --save-dev'
alias nr='npm run'
alias nrs='npm run start'
alias nrd='npm run dev'
alias nrb='npm run build'
alias nrt='npm run test'

# ── pnpm ────────────────────────────────────────────────────
alias pi='pnpm install'
alias pr='pnpm run'
alias prd='pnpm run dev'
alias prb='pnpm run build'

# ── Docker ──────────────────────────────────────────────────
alias d='docker'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dprune='docker system prune -af'

# ── HTTP testing ────────────────────────────────────────────
alias headers='curl -I'                        # Fetch headers only
alias get='curl -sL'                           # Silent GET: get https://example.com
alias post='curl -sL -X POST -H "Content-Type: application/json" -d'

# ── Ports ───────────────────────────────────────────────────
alias serve='python3 -m http.server 8080'      # Quick static server
```

---

### 🎉 Misc & Quality of Life

```zsh
# ── History ─────────────────────────────────────────────────
alias h='history | tail -50'
alias hg='history | grep'         # Search history: hg docker

# ── Shell ───────────────────────────────────────────────────
alias reload='source ~/.zshrc'    # or ~/.bashrc
alias path='echo $PATH | tr ":" "\n"'
alias clr='clear'
alias c='clear'
alias q='exit'

# ── Time & date ─────────────────────────────────────────────
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias week='date +%V'
alias timestamp='date +%s'

# ── Cache ───────────────────────────────────────────────────
alias clean-cache='du -sh ~/.cache && rm -rf ~/.cache/* && echo "Cache cleaned"'

# ── Clipboard (requires xclip or wl-clipboard) ──────────────
alias pbcopy='xclip -selection clipboard'   # X11
alias pbpaste='xclip -selection clipboard -o'
# alias pbcopy='wl-copy'                    # Wayland alternative
# alias pbpaste='wl-paste'                  # Wayland alternative

# ── Colorscheme ─────────────────────────────────────────────
alias swc='wal -i ~/Pictures/Wallpapers/rei.jpg'  # pywal: set wallpaper + colors

# ── Quick look ──────────────────────────────────────────────
alias o='less'
alias cat='bat --style=plain'      # bat: syntax-highlighted cat (install separately)
alias diff='diff --color=auto'
```

---

## Package Manager Aliases by Distro

---

### Arch Linux (pacman / yay / paru)

```zsh
# ── pacman ──────────────────────────────────────────────────
alias pac='sudo pacman'
alias update='sudo pacman -Syu'                     # Full system update
alias install='sudo pacman -S'                      # Install package
alias remove='sudo pacman -Rns'                     # Remove + orphan deps
alias search='pacman -Ss'                           # Search repos
alias info='pacman -Si'                             # Package info (remote)
alias localinfo='pacman -Qi'                        # Package info (installed)
alias listinstalled='pacman -Qe'                    # Explicitly installed
alias listorphans='pacman -Qdt'                     # Orphaned packages
alias cleanorphans='sudo pacman -Rns $(pacman -Qdtq)'  # Remove orphans
alias paclog='cat /var/log/pacman.log | tail -50'   # Recent pacman activity
alias pacclean='sudo pacman -Sc'                    # Clean package cache
alias paccleanall='sudo pacman -Scc'                # Clean entire cache

# ── AUR helpers (yay) ───────────────────────────────────────
alias yayu='yay -Syu'                               # Update everything (repo + AUR)
alias yayinstall='yay -S'
alias yaysearch='yay -Ss'
alias yayremove='yay -Rns'
alias yayorphans='yay -Yc'                         # Clean AUR orphans

# ── AUR helpers (paru — uncomment if using paru) ────────────
# alias update='paru -Syu'
# alias install='paru -S'
# alias search='paru -Ss'
# alias remove='paru -Rns'
```

---

### Debian / Ubuntu (apt)

```zsh
# ── apt ─────────────────────────────────────────────────────
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias purge='sudo apt purge'                        # Remove + config files
alias autoremove='sudo apt autoremove -y'           # Remove unused deps
alias search='apt search'
alias show='apt show'                               # Package details
alias listinstalled='apt list --installed 2>/dev/null | grep "\[installed\]"'
alias aptclean='sudo apt clean && sudo apt autoclean'

# ── dpkg helpers ────────────────────────────────────────────
alias dpkglist='dpkg -l | grep'           # dpkglist nginx
alias dpkgfiles='dpkg -L'                 # Files owned by package
alias dpkgowner='dpkg -S'                # Which package owns a file

# ── dist-upgrade (careful) ──────────────────────────────────
alias distupgrade='sudo apt update && sudo apt dist-upgrade'

# ── snap (optional) ─────────────────────────────────────────
alias snaplist='snap list'
alias snapupdate='sudo snap refresh'
```

---

### openSUSE (zypper)

```zsh
# ── zypper ──────────────────────────────────────────────────
alias update='sudo zypper refresh && sudo zypper dup'  # Full distribution update
alias install='sudo zypper install'
alias remove='sudo zypper remove'
alias search='zypper search'
alias info='zypper info'
alias repos='zypper repos'                              # List configured repos
alias addrepo='sudo zypper addrepo'
alias removerepo='sudo zypper removerepo'
alias repoclean='sudo zypper clean --all'               # Clear zypper cache
alias zypperlog='sudo cat /var/log/zypp/history | tail -30'

# ── Patterns & packages ─────────────────────────────────────
alias patterns='zypper patterns'
alias installpattern='sudo zypper install -t pattern'   # installpattern devel_basis

# ── YaST shortcuts ──────────────────────────────────────────
alias yast='sudo yast2'
alias yast-update='if test "$EUID" = 0 ; then /sbin/yast2 online_update ; else su - -c "/sbin/yast2 online_update" ; fi'

# ── RPM helpers ─────────────────────────────────────────────
alias rpmlist='rpm -qa | grep'         # rpmlist nginx
alias rpmfiles='rpm -ql'              # Files owned by package
alias rpmowner='rpm -qf'              # Which package owns a file
```

---

## Distro Detection — One File for All

If you share your dotfiles across distros, use a single `~/.aliases` with auto-detection:

```zsh
# ~/.aliases — distro-agnostic core aliases + auto-detected package manager

# ── Core (always loaded) ─────────────────────────────────────────────────────
alias ll='ls -lah'
alias la='ls -la'
alias ..='cd ..'
alias ...='cd ../..'
alias v='nvim'
alias g='git'
# ... (all the core aliases above)

# ── Package manager detection ────────────────────────────────────────────────
if command -v pacman &>/dev/null; then
    # ── Arch Linux ──────────────────────────────────────────
    alias update='sudo pacman -Syu'
    alias install='sudo pacman -S'
    alias remove='sudo pacman -Rns'
    alias search='pacman -Ss'
    alias listinstalled='pacman -Qe'
    alias cleanorphans='sudo pacman -Rns $(pacman -Qdtq) 2>/dev/null'

    if command -v yay &>/dev/null; then
        alias aur='yay -S'
        alias aurupdate='yay -Syu'
    elif command -v paru &>/dev/null; then
        alias aur='paru -S'
        alias aurupdate='paru -Syu'
    fi

elif command -v apt &>/dev/null; then
    # ── Debian / Ubuntu ─────────────────────────────────────
    alias update='sudo apt update && sudo apt upgrade -y'
    alias install='sudo apt install'
    alias remove='sudo apt remove'
    alias purge='sudo apt purge'
    alias search='apt search'
    alias autoremove='sudo apt autoremove -y'
    alias listinstalled='apt list --installed 2>/dev/null'

elif command -v zypper &>/dev/null; then
    # ── openSUSE ────────────────────────────────────────────
    alias update='sudo zypper refresh && sudo zypper dup'
    alias install='sudo zypper install'
    alias remove='sudo zypper remove'
    alias search='zypper search'
    alias repos='zypper repos'
    alias repoclean='sudo zypper clean --all'
fi
```

Source it from your shell config:

```zsh
# ~/.zshrc or ~/.bashrc
[ -f ~/.aliases ] && source ~/.aliases
```

---

## Advanced Alias Patterns

Some things an `alias` can't do — use **functions** instead.

```zsh
# ── Create dir and enter it ─────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }

# ── Search inside files recursively ────────────────────────
rgs() { grep -rn --color=auto "$1" "${2:-.}"; }
# Usage: rgs "TODO" ./src

# ── Quick backup of a file ──────────────────────────────────
bak() { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"; }
# Usage: bak config.toml

# ── cd and list in one step ─────────────────────────────────
cl() { cd "$1" && ll; }

# ── Create a timestamped directory ─────────────────────────
mkts() { mkdir -p "${1}-$(date +%Y%m%d_%H%M%S)" && cd "$_"; }

# ── Show the PATH entries, one per line ─────────────────────
alias path='echo $PATH | tr ":" "\n" | nl'

# ── Repeat a command N times ────────────────────────────────
repeat() { for i in $(seq "$1"); do eval "$2"; done; }
# Usage: repeat 5 "echo hello"

# ── Open a man page in nvim ─────────────────────────────────
vman() { man "$1" | col -b | nvim -c 'set ft=man nomod nolist' -; }

# ── Weather in terminal ─────────────────────────────────────
alias weather='curl wttr.in'
alias weather-city='curl wttr.in/Dhaka'   # Replace with your city
```

---

## Installing the Aliases

**Option A — Append to your existing shell config:**

```zsh
cat aliases.zsh >> ~/.zshrc && source ~/.zshrc
```

**Option B — Dedicated aliases file (recommended):**

```zsh
cp aliases.zsh ~/.aliases
echo '[ -f ~/.aliases ] && source ~/.aliases' >> ~/.zshrc
source ~/.zshrc
```

**Option C — Symlink from dotfiles repo:**

```zsh
ln -sf ~/.dotfiles/aliases ~/.aliases
echo '[ -f ~/.aliases ] && source ~/.aliases' >> ~/.zshrc
source ~/.zshrc
```

---

## Tips & Gotchas

**Aliases don't work in scripts.** They are only expanded in interactive shells. Use functions or the full command in scripts.

**Aliases shadow real commands.** If you alias `cat` to `bat`, remember the real `cat` is still at `/bin/cat`. Escape with `\cat` to call the original.

**Order matters in the config.** If you define an alias twice, the last definition wins. Keep your overrides at the bottom.

**`sudo` doesn't expand aliases.** To make `sudo` see your aliases, add this:

```zsh
alias sudo='sudo '    # The trailing space tells Zsh to expand the next word as an alias
```

**Test before committing.** Run `alias myalias` to verify what it expands to before relying on it.

**Debug a slow shell startup:**

```zsh
# Zsh — profile startup time
zsh -i -c exit 2>&1 | head -20
# or
time zsh -i -c exit
```

---

> **Philosophy:** Every alias here should make you faster without hiding what's actually happening under the hood. If you don't know what a command does, don't alias it — understand it first.

---

**Last Updated:** March 2026 | **Shell:** Zsh / Bash | **Distros:** Arch · Debian · openSUSE
