<div align="center">

# 🧼 Clean System Guide

### Practical, transparent Linux guides for people who want to know what's happening to their system.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)](#)
[![Distro Agnostic](https://img.shields.io/badge/Distro-Agnostic-informational)](#)
[![openSUSE Tumbleweed](https://img.shields.io/badge/openSUSE-Tumbleweed-73BA25?logo=opensuse&logoColor=white)](#)
[![KDE Plasma](https://img.shields.io/badge/DE-KDE%20Plasma-1D99F3?logo=kdeplasma&logoColor=white)](#)
[![Wayland](https://img.shields.io/badge/Display-Wayland-FBB03B)](#)
[![Shell](https://img.shields.io/badge/Shell-zsh-89E051?logo=gnu-bash&logoColor=white)](#)
[![Guides](https://img.shields.io/badge/Guides-12-success)](#-guide-index)
[![Maintained](https://img.shields.io/badge/Maintained-yes-brightgreen)](#)
[![Last Updated](https://img.shields.io/badge/Updated-June%202026-orange)](#)

**[Guide Index](#-guide-index)** · **[Philosophy](#-philosophy)** · **[Quick Start](#-quick-start)** · **[Contributing](#-contributing)** · **[FAQ](#-faq)**

</div>

---

## 📌 Why This Repository Exists

Most Linux guides ask for blind trust:

> *"Add this third-party repo."*
> *"Run this installer script."*
> *"Just install these 12 dependencies."*
> *"It works on my machine."*

If you've ever paused before `sudo bash install.sh` and thought **"wait, what does this actually do?"** — this repository is for you.

`clean-system-guide` is a collection of battle-tested Linux guides that explain not just the commands, but the reasoning behind them: what gets installed, what it touches on your system, and how to undo it if it goes wrong. Every guide here came out of a real problem — a broken install, a bloated dependency tree, an unwanted background daemon, or a workflow that had to be cleaner.

---

## 🎯 Philosophy

> Understand what you install. Keep what you need. Automate what you repeat. Trust nothing blindly.

Every guide in this repository is built around five non-negotiable constraints:

| Principle | What it means in practice |
|---|---|
| ✅ **Transparency** | You know exactly what's being installed, from where, and why |
| ✅ **Portability** | Solutions are self-contained where possible — easy to move, easy to remove |
| ✅ **Clean rollback** | If something breaks, there's a documented way to undo it |
| ✅ **Minimal trust** | Fewer parties in the chain between you and your software |
| ✅ **Readable automation** | Scripts you can audit line-by-line, not black boxes |

These aren't aspirations — they're requirements. A guide that violates them doesn't get merged.

---

## ✨ What Makes This Different

- **No blind `curl | bash`.** Every script is explained before it's run, not after.
- **Written from real breakage**, not theoretical best practices — each guide exists because something needed fixing.
- **Distro-agnostic where it matters**, tested primarily on openSUSE Tumbleweed but written for Arch, Fedora, Debian, and Ubuntu users alike.
- **Terminal-first.** GUI tools are mentioned when relevant, but every guide assumes you're comfortable in a shell.
- **No dead guides.** Outdated content is marked `deprecated` with an explanation, never silently deleted.

---

## 🚀 Quick Start

```bash
git clone https://github.com/itachi-re/clean-system-guide.git
cd clean-system-guide
```

Browse the [Guide Index](#-guide-index) below, or jump straight to a category:

```bash
# Example: reading the aria2c guide before touching your download setup
less aria2c-guide.md
```

No build step, no dependencies, no tooling required — it's Markdown, meant to be read.

---

## 🗂 Guide Index

### 🛠 System Maintenance

| Guide | Solves |
|---|---|
| [Clear System Cache](./clear-system-cache.md) | Safely reclaim memory and disk space without breaking anything |
| [File Deletion Guide](./file-deletion-guide.md) | Proper file removal — `rm` isn't always the right answer |

### 📦 File & Data Management

| Guide | Solves |
|---|---|
| [Linux Archiving Guide](./linux-archiving-guide.md) | `tar`, compression formats, and knowing which to use when |
| [Linux Archive Extraction Guide](./linux-archive-extraction-guide.md) | Extracting any archive format cleanly, without guessing flags |
| [Photo Management Guide](./photo-management-guide.md) | Managing photos without cloud dependency or bloated software |

### 🌐 Downloads & Networking

| Guide | Solves |
|---|---|
| [Aria2c Guide](./aria2c-guide.md) | Multi-connection, resumable downloads from the terminal — no GUI, no daemon, no wasted bandwidth |

### 🎬 Media & Multimedia

| Guide | Solves |
|---|---|
| [FFmpeg Guide](./ffmpeg-guide.md) | Encoding, converting, and processing media entirely from the terminal |

### 💻 Development & Software

| Guide | Solves |
|---|---|
| [VS Code Without Microsoft's Repo](./vscode-installation.md) | Portable VS Code / VSCodium with zero package-manager involvement |
| [Antigravity Installation](./antigravity-installation.md) | A clean install with no system-wide side effects |

### 🎮 Gaming

| Guide | Solves |
|---|---|
| [Games from ISO with Lutris](./install-games-iso-lutris-linux.md) | Running ISO-based games on Linux without polluting the system |

### 🐚 Shell & Terminal

| Guide | Solves |
|---|---|
| [Shell Aliases](./shell-aliases.md) | Aliases that actually save time — the ones that survived a hard pruning pass |

### 🗂 Dotfiles & Configuration

| Guide | Solves |
|---|---|
| [GNU Stow Dotfiles](./gnu-stow-dotfiles.md) | Version-controlled configs with symlinks managed automatically — no manual linking, no drift |

<details>
<summary><b>⭐ Featured guides — start here if you're new</b></summary>
<br>

If you only read three guides in this repository, make it these:

1. **[Aria2c Guide](./aria2c-guide.md)** — the single highest-leverage guide here; multi-connection downloads with full control, no GUI client required.
2. **[GNU Stow Dotfiles](./gnu-stow-dotfiles.md)** — the cleanest dotfile-management approach that doesn't require learning a new tool's DSL.
3. **[VS Code Without Microsoft's Repo](./vscode-installation.md)** — a good example of the repo's core philosophy: same software, fewer trusted parties.

</details>

---

## 📚 Repository Structure

Every guide follows the same four-part structure, so you always know where to look:

```
1. The Problem          → what broke, what was missing, or what needed to improve
2. The Clean Solution    → how to fix it without polluting the system
3. The Commands          → exact steps, each one explained
4. Alternatives          → other approaches, and why this one was chosen instead
```

This consistency means you can skim any guide in this repo the same way, whether it's about `ffmpeg` or dotfiles.

---

## 💡 Design Principles

<details>
<summary><b>Why "clean" specifically?</b></summary>
<br>

"Clean" here means auditable and reversible — not minimal for its own sake. A guide can install ten packages and still be clean, as long as you know what each one does and how to remove it. Conversely, a one-line installer script that silently touches your shell config, adds a repo, and drops a systemd service is *not* clean, even though it looks simple.

</details>

<details>
<summary><b>Why terminal-first?</b></summary>
<br>

GUI installers hide state changes behind a progress bar. The terminal makes every step explicit and, more importantly, scriptable and reviewable — you can read a shell command before running it in a way you generally can't with a GUI wizard.

</details>

<details>
<summary><b>Why openSUSE Tumbleweed as the primary environment?</b></summary>
<br>

Tumbleweed is a rolling-release distro with a strict build-and-test pipeline (openQA), which surfaces packaging issues fast. Guides developed here tend to hold up well on Arch, Fedora, Debian, and Ubuntu too — but where a specific distro's package manager or path layout matters, it's called out explicitly rather than papered over.

</details>

---

## 🧩 Environment This Repo Is Built On

| | |
|---|---|
| **Distro** | openSUSE Tumbleweed |
| **Desktop** | KDE Plasma (Wayland) |
| **Shell** | zsh |
| **Approach** | Minimal installs, portable apps, manual control |
| **App Storage** | `/data/itachi/AppImages/` |

Your setup doesn't need to match this exactly — the guides are written to be adapted, not copy-pasted verbatim.

---

## ❓ FAQ

<details>
<summary><b>Do these guides work on Arch / Fedora / Debian / Ubuntu?</b></summary>
<br>

Yes, in most cases. Guides are developed and tested primarily on openSUSE Tumbleweed, but package-manager-specific commands are called out per distro wherever they differ (`zypper` vs `pacman` vs `dnf` vs `apt`). If a guide is genuinely openSUSE-specific, that's noted at the top.

</details>

<details>
<summary><b>Why not just use Flatpak / Snap for everything?</b></summary>
<br>

Sometimes that's exactly the right answer, and a guide will say so. This repo isn't anti-sandboxing — it's anti-*unexamined* installation. A Flatpak install you understand is perfectly "clean" by this repo's standard.

</details>

<details>
<summary><b>Are these guides beginner-friendly?</b></summary>
<br>

They assume basic terminal comfort — you should know your way around `cd`, `sudo`, and a text editor. Beyond that, every command is explained, so you don't need prior expertise with the specific tool being covered.

</details>

<details>
<summary><b>What happens to outdated guides?</b></summary>
<br>

They're marked `deprecated` with a note explaining what changed and why, rather than deleted outright. History has value, even when the advice no longer applies.

</details>

---

## 🤝 Contributing

Contributions are welcome if they fit the repository's philosophy.

**Rules:**

- Must solve a real problem, not a hypothetical one.
- Prioritize system cleanliness and transparency over convenience.
- Explain the *why*, not just the *how*.
- No "just run this script" without a full explanation of what it does.

Open a PR if you've solved something cleanly and it fits here. Open an issue if a guide is out of date or a command no longer works as written.

---

## 🛣 Roadmap

Planned additions, in no particular order:

- [ ] Flatpak vs AppImage decision guide
- [ ] Minimal dev environment setup from scratch
- [ ] Dotfile management without any tooling — pure symlinks, manual approach
- [ ] *...and whatever breaks next*

---

## 🌟 Star History

<!-- Replace OWNER/REPO once the chart is generated -->
[![Star History Chart](https://api.star-history.com/svg?repos=itachi-re/clean-system-guide&type=Date)](https://star-history.com/#itachi-re/clean-system-guide&Date)

---

## ❤️ Support the Project

If a guide here saved you from a broken install or a bloated dependency tree, consider:

- ⭐ **Starring the repo** — it's the easiest way to help others find it.
- 🐛 **Opening an issue** if something's out of date.
- 🔧 **Submitting a PR** if you've solved something cleanly.

---

## 📝 License

MIT — use it, fork it, adapt it. If it helps you run a system you actually understand, that's enough.

---

<div align="center">

**Disclaimer:** These guides reflect one person's setup, threat model, and preferences. Read, understand, and adapt them — don't blindly copy-paste, for the same reason this repo exists in the first place.

*"The best system is one you understand completely and control entirely."*

**Status:** Active · **Guides:** 12 · **Last Updated:** June 2026

</div>
