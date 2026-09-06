# 🧹 Linux System Cleaning Guide

> Keep your Linux system lean, fast, and clutter-free — covering package cache, user cache, logs, orphaned packages, temp files, and more. Tested on **openSUSE**, **Arch Linux**, and **Debian/Ubuntu**.

---

## 📋 Table of Contents

1. [The Problem](#the-problem)
2. [Quick Wins — One-Liners](#quick-wins--one-liners)
3. [Method 1 – Package Cache Cleaning](#method-1--package-cache-cleaning)
4. [Method 2 – User Cache (`~/.cache`)](#method-2--user-cache-cache)
5. [Method 3 – System Logs (journald)](#method-3--system-logs-journald)
6. [Method 4 – Orphaned Packages](#method-4--orphaned-packages)
7. [Method 5 – Temp Files & `/tmp`](#method-5--temp-files--tmp)
8. [Method 6 – Flatpak & Snap Cleanup](#method-6--flatpak--snap-cleanup)
9. [Method 7 – Old Kernels](#method-7--old-kernels)
10. [Method 8 – Find & Kill Large Files](#method-8--find--kill-large-files)
11. [Method 9 – Zsh / Shell History Trim](#method-9--zsh--shell-history-trim)
12. [Method 10 – Automated All-in-One Script](#method-10--automated-all-in-one-script)
13. [Aliases for Daily Use](#aliases-for-daily-use)
14. [What NOT to Delete](#what-not-to-delete)
15. [Troubleshooting](#troubleshooting)

---

## The Problem

Over time, Linux accumulates:

- **Package manager caches** — downloaded `.rpm` / `.deb` / `.pkg.tar.zst` files that served their purpose and are now dead weight
- **Application caches** — browser data, thumbnail indexes, font caches, app-specific junk
- **System logs** — `journald` will happily grow to gigabytes if unchecked
- **Orphaned packages** — libraries installed as dependencies for software you long since removed
- **Old kernels** — each kernel update leaves the previous one on disk "just in case"
- **Temp files** — `/tmp` and `/var/tmp` accumulate crash dumps, editor backups, partial downloads

None of this is dangerous. But it wastes disk space, slows down package operations, and makes your system harder to audit.

---

## Quick Wins — One-Liners

Run these right now for an immediate cleanup. Details and safe versions follow in each method section.

```bash
# openSUSE — clean zypper cache
sudo zypper clean --all

# Arch — clean pacman cache (keep last 2 versions)
sudo paccache -rk2

# Debian/Ubuntu — clean apt cache
sudo apt clean && sudo apt autoremove --purge

# All distros — clear user cache (check size first!)
du -sh ~/.cache && rm -rf ~/.cache/*

# All distros — vacuum journal logs older than 2 weeks
sudo journalctl --vacuum-time=2weeks

# All distros — remove leftover temp files
sudo find /tmp /var/tmp -type f -atime +7 -delete
```

---

## Method 1 – Package Cache Cleaning

Package managers cache downloaded packages locally. After installation, these files have no ongoing purpose.

### openSUSE (zypper)

```bash
# See how much the cache is using
sudo du -sh /var/cache/zypp/packages/

# Clean all cached packages
sudo zypper clean --all

# Clean only metadata (keeps packages, removes repo metadata)
sudo zypper clean --metadata

# Aggressive: remove everything including repo data
sudo zypper clean -a
```

> **openSUSE note:** Zypper's cache lives at `/var/cache/zypp/`. It can easily reach 2–5 GB after several system updates.

### Arch Linux (pacman)

```bash
# Install paccache (from pacman-contrib)
sudo pacman -S pacman-contrib

# Check cache size
du -sh /var/cache/pacman/pkg/

# Keep last 2 versions of each package (safe default)
sudo paccache -rk2

# Keep only the currently installed version
sudo paccache -rk1

# Remove ALL cached packages (nuclear option)
sudo pacman -Scc

# Auto-clean on every pacman transaction (hook)
sudo systemctl enable paccache.timer
```

### Debian / Ubuntu (apt)

```bash
# Check cache size
du -sh /var/cache/apt/archives/

# Remove downloaded .deb files
sudo apt clean

# Remove partial downloads only
sudo apt autoclean

# Remove unused dependencies
sudo apt autoremove --purge

# All at once
sudo apt clean && sudo apt autoclean && sudo apt autoremove --purge
```

---

## Method 2 – User Cache (`~/.cache`)

`~/.cache` is populated by browsers, thumbnails, fonts, LSP servers, pip, npm, and virtually every desktop app. It is **safe to delete entirely** — apps recreate it on next launch.

### Check what's eating space

```bash
# Total size
du -sh ~/.cache

# Top 10 largest subdirectories
du -sh ~/.cache/*/ 2>/dev/null | sort -rh | head -10
```

### Selective cleaning (recommended)

```bash
# Browser caches (Firefox / Chromium)
rm -rf ~/.cache/mozilla/firefox/*/cache2/
rm -rf ~/.cache/chromium/Default/Cache/

# Thumbnail cache (regenerated automatically)
rm -rf ~/.cache/thumbnails/

# Fontconfig cache
rm -rf ~/.cache/fontconfig/

# pip cache
rm -rf ~/.cache/pip/

# npm cache
npm cache clean --force

# Rust / cargo build cache
rm -rf ~/.cache/sccache/
```

### Nuclear option (clears everything)

```bash
# Preview first
du -sh ~/.cache

# Then delete
rm -rf ~/.cache/*

echo "Cache cleared — apps will rebuild on next launch"
```

---

## Method 3 – System Logs (journald)

`systemd-journald` stores logs in `/var/log/journal/`. Without limits, it can silently grow to gigabytes.

### Check current log size

```bash
journalctl --disk-usage
```

### Vacuum by time (recommended)

```bash
# Keep only logs from the last 2 weeks
sudo journalctl --vacuum-time=2weeks

# Keep only logs from the last 3 days
sudo journalctl --vacuum-time=3days
```

### Vacuum by size

```bash
# Trim logs down to 200MB total
sudo journalctl --vacuum-size=200M

# Trim to 100MB
sudo journalctl --vacuum-size=100M
```

### Set a permanent size cap

Edit `/etc/systemd/journald.conf`:

```bash
sudo nano /etc/systemd/journald.conf
```

Add or uncomment:

```ini
[Journal]
SystemMaxUse=200M
SystemKeepFree=500M
MaxRetentionSec=2weeks
```

Apply the change:

```bash
sudo systemctl restart systemd-journald
```

> ⚠️ Without `SystemMaxUse`, journald defaults to 10% of your filesystem. On a 1TB drive that's 100GB of potential logs.

---

## Method 4 – Orphaned Packages

These are packages installed as dependencies for software you've since removed. They linger silently.

### openSUSE

```bash
# List orphaned packages (installed but not required by anything)
zypper packages --orphaned

# Remove them (review the list before confirming)
sudo zypper remove --clean-deps $(zypper packages --orphaned | awk -F'|' 'NR>4 {print $3}' | tr -d ' ')
```

### Arch Linux

```bash
# List orphans (packages not required by any other package)
pacman -Qtdq

# Remove orphans
sudo pacman -Rns $(pacman -Qtdq)

# If no orphans exist, pacman will report an error — that's fine
```

### Debian / Ubuntu

```bash
# List auto-installed packages no longer needed
apt-mark showmanual | head -20   # show manually installed
sudo apt autoremove --purge      # remove unneeded auto-deps

# For deeper auditing
sudo apt install deborphan
deborphan                        # list orphaned libraries
sudo deborphan | xargs sudo apt remove --purge
```

---

## Method 5 – Temp Files & `/tmp`

`/tmp` is cleared on reboot on most systems, but `/var/tmp` persists across reboots by design.

### Check sizes

```bash
du -sh /tmp /var/tmp
```

### Remove files not accessed in 7+ days

```bash
# Dry run first — see what would be deleted
find /tmp /var/tmp -type f -atime +7

# Then delete
sudo find /tmp /var/tmp -type f -atime +7 -delete
```

### Force-clear `/tmp` right now

```bash
# Safe: only delete files (not directories or symlinks)
sudo find /tmp -maxdepth 1 -mindepth 1 -type f -delete

# Nuclear: wipe /tmp entirely (closes open temp files — reboot after)
sudo rm -rf /tmp/*
```

### Configure systemd-tmpfiles (permanent policy)

```bash
# See current rules
cat /usr/lib/tmpfiles.d/tmp.conf

# View or override with a local rule
sudo nano /etc/tmpfiles.d/tmp.conf
```

Example rule — clear files in `/tmp` older than 1 day on boot:

```
d /tmp 1777 root root 1d
```

---

## Method 6 – Flatpak & Snap Cleanup

Flatpak and Snap store old runtimes and app versions indefinitely.

### Flatpak

```bash
# List installed apps and their sizes
flatpak list --app --columns=application,size

# Remove unused runtimes (biggest space saver)
flatpak uninstall --unused

# Remove a specific app
flatpak uninstall com.example.App

# Full cleanup
flatpak uninstall --unused && flatpak repair
```

### Snap

```bash
# List all snaps and versions
snap list --all

# Snaps keep old revisions on disk — remove them
snap list --all | awk '/disabled/{print $1, $3}' | \
  while read snapname revision; do
    sudo snap remove "$snapname" --revision="$revision"
  done
```

> **openSUSE note:** Snap is not officially supported on openSUSE Tumbleweed. Flatpak is available via `sudo zypper install flatpak`.

---

## Method 7 – Old Kernels

Each kernel update keeps the previous version as a safety net. After confirming the new kernel works, the old ones are just dead weight.

### Check installed kernels

```bash
# All distros
uname -r                          # currently running kernel

# openSUSE
rpm -qa | grep kernel-default

# Arch
pacman -Q linux linux-lts         # or whatever kernel you use

# Debian/Ubuntu
dpkg --list | grep linux-image
```

### openSUSE — remove old kernels

```bash
# zypper handles this automatically with zypper dup
# To manually keep only the latest:
sudo zypper remove $(rpm -qa | grep kernel-default | sort -V | head -n -1)
```

### Arch Linux

```bash
# Arch only keeps one kernel unless you explicitly install extras (linux-lts, etc.)
# List all kernel packages
pacman -Q | grep linux

# Remove a specific old one
sudo pacman -Rns linux-lts   # only if you don't need it
```

### Debian / Ubuntu

```bash
# List old kernels
dpkg --list | grep linux-image | grep -v $(uname -r)

# Remove old kernels automatically
sudo apt autoremove --purge

# Manual removal
sudo apt remove --purge linux-image-5.15.0-76-generic
sudo update-grub
```

> ⚠️ **Never remove your currently running kernel.** Always confirm with `uname -r` first and keep at least one fallback.

---

## Method 8 – Find & Kill Large Files

Sometimes disk space disappears mysteriously. This is how you hunt it down.

### Find the biggest directories

```bash
# Top 10 largest directories from root (skip pseudo-filesystems)
sudo du -h --exclude=/proc --exclude=/sys --exclude=/dev \
  -d 2 / 2>/dev/null | sort -rh | head -20

# Top 10 in your home directory
du -sh ~/* 2>/dev/null | sort -rh | head -10

# Drill into a specific directory
du -sh ~/.local/share/*/ | sort -rh | head -10
```

### Find large files directly

```bash
# Files over 100MB anywhere on disk
sudo find / -xdev -size +100M -type f 2>/dev/null | sort

# Files over 1GB
sudo find / -xdev -size +1G -type f 2>/dev/null

# Large files in your home directory only
find ~ -size +50M -type f 2>/dev/null | sort -k5 -rh
```

### Common culprits

```bash
# VM disk images (VirtualBox / QEMU)
find ~ -name "*.vdi" -o -name "*.vmdk" -o -name "*.qcow2" 2>/dev/null

# Core dumps
find / -name "core" -type f 2>/dev/null
sudo find /var/lib/systemd/coredump/ -type f -delete

# Old Docker images and volumes
docker system df
docker system prune -a --volumes   # nuclear — removes all unused docker data

# Steam games
du -sh ~/.local/share/Steam/steamapps/common/*/ 2>/dev/null | sort -rh | head -10
```

---

## Method 9 – Zsh / Shell History Trim

Shell history files grow unbounded unless you set limits.

### Check current history file size

```bash
du -sh ~/.zsh_history ~/.bash_history 2>/dev/null
wc -l ~/.zsh_history
```

### Set history limits in `~/.zshrc`

```bash
# Add or update these lines in ~/.zshrc
HISTSIZE=5000           # lines kept in memory per session
SAVEHIST=10000          # lines saved to ~/.zsh_history
HISTFILE=~/.zsh_history

# Deduplicate history (don't save repeated commands)
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS

# Don't save commands starting with a space
setopt HIST_IGNORE_SPACE
```

Apply:

```bash
source ~/.zshrc
```

### Manually trim history right now

```bash
# Back up first
cp ~/.zsh_history ~/.zsh_history.bak

# Keep only the last 5000 lines
tail -5000 ~/.zsh_history > /tmp/zsh_history_trim && mv /tmp/zsh_history_trim ~/.zsh_history
```

---

## Method 10 – Automated All-in-One Script

A single script that handles all the common cleaning tasks, shows space saved, and logs what was done.

```bash
#!/usr/bin/env bash
# ============================================================
# system-clean.sh
# Cleans package cache, user cache, logs, temp files, orphans.
# Usage: ./system-clean.sh [--dry-run]
# ============================================================

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

LOG_FILE="/tmp/system-clean-$(date +%Y%m%d-%H%M%S).log"
FREED=0

log() { echo "$1" | tee -a "$LOG_FILE"; }
hr()  { log "──────────────────────────────────────────"; }

dir_size_kb() { du -sk "$1" 2>/dev/null | awk '{print $1}'; }

run() {
    if $DRY_RUN; then
        log "  [DRY-RUN] $*"
    else
        eval "$@" >> "$LOG_FILE" 2>&1 || true
    fi
}

hr
log "🧹 system-clean.sh — $(date)"
log "   Mode: $( $DRY_RUN && echo DRY RUN || echo LIVE )"
hr

# ── 1. Package cache ──────────────────────────────────────
log ""
log "▶ Package cache"

if command -v zypper &>/dev/null; then
    before=$(dir_size_kb /var/cache/zypp/packages)
    run "sudo zypper clean --all"
    after=$(dir_size_kb /var/cache/zypp/packages)
    freed_here=$(( before - after ))
    log "  zypper: freed ~${freed_here} KB"
    FREED=$(( FREED + freed_here ))

elif command -v paccache &>/dev/null; then
    before=$(dir_size_kb /var/cache/pacman/pkg)
    run "sudo paccache -rk2 -q"
    after=$(dir_size_kb /var/cache/pacman/pkg)
    freed_here=$(( before - after ))
    log "  paccache: freed ~${freed_here} KB"
    FREED=$(( FREED + freed_here ))

elif command -v apt &>/dev/null; then
    before=$(dir_size_kb /var/cache/apt/archives)
    run "sudo apt clean"
    run "sudo apt autoremove --purge -y"
    after=$(dir_size_kb /var/cache/apt/archives)
    freed_here=$(( before - after ))
    log "  apt: freed ~${freed_here} KB"
    FREED=$(( FREED + freed_here ))
fi

# ── 2. User cache ─────────────────────────────────────────
log ""
log "▶ User cache (~/.cache)"
before=$(dir_size_kb ~/.cache)
run "rm -rf ~/.cache/*"
after=$(dir_size_kb ~/.cache)
freed_here=$(( before - after ))
log "  ~/.cache: freed ~${freed_here} KB"
FREED=$(( FREED + freed_here ))

# ── 3. Journal logs ───────────────────────────────────────
log ""
log "▶ Journal logs (keeping last 2 weeks)"
run "sudo journalctl --vacuum-time=2weeks"

# ── 4. Temp files ─────────────────────────────────────────
log ""
log "▶ Temp files older than 7 days"
before_tmp=$(dir_size_kb /tmp)
before_var=$(dir_size_kb /var/tmp)
run "sudo find /tmp /var/tmp -type f -atime +7 -delete"
after_tmp=$(dir_size_kb /tmp)
after_var=$(dir_size_kb /var/tmp)
freed_here=$(( (before_tmp + before_var) - (after_tmp + after_var) ))
log "  /tmp + /var/tmp: freed ~${freed_here} KB"
FREED=$(( FREED + freed_here ))

# ── 5. Flatpak unused runtimes ────────────────────────────
if command -v flatpak &>/dev/null; then
    log ""
    log "▶ Flatpak unused runtimes"
    run "flatpak uninstall --unused -y"
fi

# ── 6. Thumbnail cache ────────────────────────────────────
log ""
log "▶ Thumbnail cache"
before=$(dir_size_kb ~/.cache/thumbnails 2>/dev/null || echo 0)
run "rm -rf ~/.cache/thumbnails/*"
log "  thumbnails: freed ~${before} KB"
FREED=$(( FREED + before ))

# ── Summary ───────────────────────────────────────────────
hr
log ""
freed_mb=$(awk "BEGIN {printf \"%.1f\", $FREED/1024}")
log "✅ Done! Estimated space freed: ~${freed_mb} MB"
log "   Log saved to: $LOG_FILE"
log ""
hr
```

```bash
chmod +x system-clean.sh

# Dry run first — see what would happen
./system-clean.sh --dry-run

# Live run
./system-clean.sh
```

---

## Aliases for Daily Use

Add these to `~/.zshrc` for fast, one-command cleaning.

```bash
# ── Cleaning aliases ─────────────────────────────────────

# Show cache size, clean it, confirm it's gone
alias clean-cache='echo "Before: $(du -sh ~/.cache)" && rm -rf ~/.cache/* && echo "After:  $(du -sh ~/.cache)"'

# Clean package cache (auto-detects distro)
alias clean-pkg='
  if command -v zypper &>/dev/null; then sudo zypper clean --all
  elif command -v paccache &>/dev/null; then sudo paccache -rk2
  elif command -v apt &>/dev/null; then sudo apt clean && sudo apt autoremove --purge
  fi
'

# Vacuum journal logs
alias clean-logs='sudo journalctl --vacuum-time=2weeks && journalctl --disk-usage'

# Show disk usage summary
alias diskcheck='df -h / && echo "" && du -sh ~/* 2>/dev/null | sort -rh | head -10'

# Show top 10 largest files in current directory
alias bigfiles='du -sh ./*/ 2>/dev/null | sort -rh | head -10'

# Full system clean (runs the script above)
alias clean-system='~/scripts/system-clean.sh'
```

Reload:

```bash
source ~/.zshrc
```

---

## What NOT to Delete

Some things look like junk but are critical. Leave these alone.

| Path | Why it matters |
|------|----------------|
| `~/.config/` | App settings and configurations — deleting breaks things |
| `~/.local/share/` | App data, installed fonts, Flatpak apps, Steam games |
| `/var/log/` (all of it) | Some logs are not managed by journald — check before deleting |
| `/var/lib/pacman/` | Arch package database — deleting corrupts pacman |
| `/var/lib/rpm/` | openSUSE RPM database — same risk |
| `/boot/` | Kernels and bootloader — only touch old kernels with care |
| `/etc/` | System configuration — never blindly delete here |
| `~/.gnupg/` | GPG keys — deleting means you lose signed git commits, encrypted files |
| `~/.ssh/` | SSH keys — deleting locks you out of servers |

---

## Troubleshooting

### `zypper clean` reports nothing to clean

```bash
# Cache may already be empty, or the path changed
sudo du -sh /var/cache/zypp/
ls /var/cache/zypp/packages/
```

### `paccache: command not found`

```bash
# paccache is in pacman-contrib, not installed by default
sudo pacman -S pacman-contrib
```

### Cleaning `~/.cache` broke an app

Most apps recreate their cache automatically. If an app misbehaves after a cache clear:

```bash
# Just relaunch the app — it will rebuild its cache
# If it asks to re-login, that's normal (session tokens live in cache sometimes)

# For browsers: re-login to sites, re-accept permissions
# For LSP servers (nvim, vscode): cache rebuilds on first file open
```

### `journalctl --vacuum-time` has no effect

```bash
# Check if persistent logging is even enabled
ls /var/log/journal/

# If empty, logs are only in memory. Enable persistent logging:
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
```

### `apt autoremove` wants to remove something important

```bash
# Mark it as manually installed so apt stops trying to remove it
sudo apt-mark manual <package-name>

# Then rerun autoremove safely
sudo apt autoremove --purge
```

---

## Quick Reference Card

```
TASK                              TOOL           COMMAND
──────────────────────────────────────────────────────────────────────
Clean package cache               zypper         sudo zypper clean --all
Clean package cache               pacman         sudo paccache -rk2
Clean package cache               apt            sudo apt clean && sudo apt autoremove --purge
Clear user cache                  rm             rm -rf ~/.cache/*
Vacuum journal logs (2 weeks)     journalctl     sudo journalctl --vacuum-time=2weeks
Vacuum journal logs (200MB cap)   journalctl     sudo journalctl --vacuum-size=200M
Remove orphans                    pacman         sudo pacman -Rns $(pacman -Qtdq)
Remove orphans                    apt            sudo apt autoremove --purge
Remove Flatpak unused runtimes    flatpak        flatpak uninstall --unused
Find largest dirs in home         du             du -sh ~/*/ | sort -rh | head -10
Find files over 100MB             find           sudo find / -xdev -size +100M -type f
Clear old temp files              find           sudo find /tmp /var/tmp -atime +7 -delete
Check journal disk usage          journalctl     journalctl --disk-usage
Show disk usage                   df             df -h /
```

---

*Last updated: 2025 | Tested on openSUSE Tumbleweed, Arch Linux, Ubuntu 24.04*
