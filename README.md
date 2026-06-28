# Clean System Guide

> You shouldn't have to blindly trust a script to get software installed.
> This repo is for people who want to know exactly what's happening to their system — and why.

---

## The Problem With Most Linux Guides

They ask too much of you upfront:

- *"Add this third-party repo"* — and trust it forever
- *"Run this installer script"* — without reading it first
- *"Just install these 12 dependencies"* — and hope nothing conflicts
- *"It works on my machine"* — yours may vary

If you've ever paused before `sudo bash install.sh` and thought *"wait, what does this actually do?"* — this repo is for you.

---

## What This Is

Battle-tested guides for keeping a Linux system clean, minimal, and fully understood. Every guide here was born from a real problem — a broken install, a cluttered system, an unwanted dependency, or a workflow that needed to be smoother.

**Philosophy:** Understand what you install. Keep what you need. Automate what you repeat. Trust nothing blindly.

---

## Environment

| | |
|---|---|
| **Distro** | openSUSE Tumbleweed |
| **Desktop** | KDE Plasma (Wayland) |
| **Shell** | zsh |
| **Approach** | Minimal installs, portable apps, manual control |
| **App Storage** | `/data/itachi/AppImages/` |

---

## Guides

### 🛠 System Maintenance

| Guide | What It Solves |
|---|---|
| [Clear System Cache](./clear-system-cache.md) | Safely reclaim memory and disk space without breaking anything |
| [File Deletion Guide](./file-deletion-guide.md) | Proper file removal — `rm` isn't always the right answer |

### 📦 File & Data Management

| Guide | What It Solves |
|---|---|
| [Linux Archiving Guide](./linux-archiving-guide.md) | `tar`, compression formats, and knowing which to use when |
| [Linux Archive Extraction Guide](./linux-archive-extraction-guide.md) | Extracting any archive format cleanly, without guessing flags |
| [Photo Management Guide](./photo-management-guide.md) | Managing photos without cloud dependency or bloated software |

### 🌐 Downloads & Networking

| Guide | What It Solves |
|---|---|
| [Aria2c Guide](./aria2c-guide.md) | Multi-connection, resumable downloads from the terminal — no GUI, no daemon, no wasted bandwidth |

### 🎬 Media & Multimedia

| Guide | What It Solves |
|---|---|
| [FFmpeg Guide](./ffmpeg-guide.md) | Encoding, converting, and processing media from the terminal |

### 💻 Development & Software

| Guide | What It Solves |
|---|---|
| [VS Code Without Microsoft's Repo](./vscode-installation.md) | Portable VS Code / VSCodium with zero package manager involvement |
| [Antigravity Installation](./antigravity-installation.md) | Clean install of Antigravity with no system-wide side effects |

### 🎮 Gaming

| Guide | What It Solves |
|---|---|
| [Games from ISO with Lutris](./install-games-iso-lutris-linux.md) | Running ISO-based games on Linux without polluting the system |

### 🐚 Shell & Terminal

| Guide | What It Solves |
|---|---|
| [Shell Aliases](./shell-aliases.md) | Aliases that actually save time — the ones I kept after pruning the rest |

### 🗂 Dotfiles & Configuration

| Guide | What It Solves |
|---|---|
| [GNU Stow Dotfiles](./gnu-stow-dotfiles.md) | Version-controlled config files with symlinks managed automatically — no manual linking, no drift |

---

## Guide Format

Every guide follows the same structure so you can quickly find what you need:

1. **The Problem** — What broke, what was missing, or what needed to improve
2. **The Clean Solution** — How to fix it without polluting the system
3. **The Commands / Workflow** — Exact steps with explanation of each one
4. **Alternatives** — Other approaches, and why I went this direction instead

---

## Why Each Solution Is Done This Way

Every solution here is built around five constraints:

- ✅ **Transparency** — You know exactly what's being installed and why
- ✅ **Portability** — Self-contained where possible, easy to move or remove
- ✅ **Clean rollback** — If something breaks, you can undo it
- ✅ **Minimal trust** — Fewer parties in the chain between you and the software
- ✅ **Readable automation** — Scripts you can audit and modify, not black boxes

These aren't ideals. They're requirements. A guide that violates them doesn't belong here.

---

## Roadmap

More guides coming as I run into new problems worth documenting.

**Planned additions:**
- Flatpak vs AppImage decision guide
- Setting up a minimal dev environment from scratch
- Dotfile management without any tooling (pure symlinks, manual approach)
- *...and whatever breaks next*

---

## Contributing

**Rules:**
- Must solve a real problem, not a hypothetical one
- Prioritize system cleanliness over convenience
- Explain the *why*, not just the *how*
- No "just run this script" without explaining what it does

PRs are open if you've solved something cleanly that fits this philosophy.

---

## Disclaimer

These guides reflect **my** setup, **my** threat model, and **my** preferences. Your requirements may differ. Read, understand, and adapt — don't blindly copy-paste.

Guides that become obsolete won't be deleted. They'll be marked deprecated with an explanation of what changed and why.

---

## License

MIT — Use it, fork it, adapt it. If it helps you keep a cleaner system, that's enough.

---

**Status:** Active &nbsp;|&nbsp; **Guides:** 12 &nbsp;|&nbsp; **Last Updated:** June 2026

*"The best system is one you understand completely and control entirely."*
