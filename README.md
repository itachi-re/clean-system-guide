# Clean System Guide

> Battle-tested guides from my ongoing journey through Linux system administration.
> Real problems. Real solutions. No hand-waving.

---

## What Is This?

This repository documents my journey of keeping a Linux system clean, minimal, and fully understood. Every guide here was born from a real problem I hit — a broken install, a cluttered system, a dependency I didn't want, or a workflow that needed to be smoother.

**Philosophy:** Understand what you install. Keep what you need. Automate what you repeat. Trust nothing blindly.

---

## Environment

| | |
|---|---|
| **Distro** | openSUSE |
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
| [Photo Management Guide](./photo-management-guide.md) | Managing photos without cloud dependency or bloated software |

### 💻 Development Tools

| Guide | What It Solves |
|---|---|
| [VS Code Without Microsoft's Repo](./vscode-installation.md) | Portable VS Code / VSCodium with zero package manager involvement |
| [Antigravity Installation](./antigravity-installation.md) | Clean install of Antigravity with no system-wide side effects |

### 🐚 Shell & Terminal

| Guide | What It Solves |
|---|---|
| [Shell Aliases](./shell-aliases.md) | Aliases that actually save time — the ones I kept after pruning the rest |

---

## Guide Format

Every guide follows the same structure so you can quickly find what you need:

1. **The Problem** — What broke, what was missing, or what needed to improve
2. **The Clean Solution** — How to fix it without polluting the system
3. **The Script** — Automation to make it repeatable
4. **Alternatives** — Other approaches, and why I went this direction instead

---

## Why This Exists

Most Linux guides assume you're fine with:

- Adding unknown third-party repositories
- Installing a chain of dependencies you'll never audit
- Running installer scripts from the internet
- Cluttering your system in ways you can't easily undo

This repo takes the opposite approach. Every solution here prioritizes:

- ✅ **Transparency** — You know exactly what's being installed and why
- ✅ **Portability** — Self-contained where possible, easy to move or remove
- ✅ **Clean rollback** — If something breaks, you can undo it
- ✅ **Minimal trust** — Fewer parties in the chain between you and the software
- ✅ **Readable automation** — Scripts you can audit and modify, not black boxes

---

## Roadmap

More guides coming as I run into new problems worth documenting. If you've solved something cleanly that fits this philosophy, PRs are open.

**Planned additions:**
- Flatpak vs AppImage decision guide
- Setting up a minimal dev environment from scratch
- Dotfile management without a framework
- *...and whatever breaks next*

---

## Contributing

**Rules:**
- Must solve a real problem, not a hypothetical one
- Prioritize system cleanliness over convenience
- Explain the *why*, not just the *how*
- No "just run this script" without explaining what it does

---

## Disclaimer

These guides reflect **my** setup, **my** threat model, and **my** preferences. Your requirements may differ. Read, understand, and adapt — don't blindly copy-paste.

Guides that become obsolete won't be deleted. They'll be marked deprecated with an explanation of what changed and why.

---

## License

MIT — Use it, fork it, adapt it. If it helps you keep a cleaner system, that's enough.

---

**Status:** Active &nbsp;|&nbsp; **Last Updated:** May 2026

*"The best system is one you understand completely and control entirely."*
