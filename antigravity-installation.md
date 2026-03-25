# Google Antigravity on openSUSE (Without Losing Your Mind)

Antigravity is Google's agentic IDE — a VS Code fork with autonomous AI agents baked directly into the editor, terminal, and browser surfaces. This guide covers how to install it on openSUSE the clean way: portable tarball first, zypper repo second, with full honesty about what you're trading away.

---

## What Is Antigravity, Actually?

Antigravity forks the open-source VS Code foundation but restructures the UX around agent management rather than pure text editing. The interface has three surfaces:

- **Editor** — Familiar VS Code layout. Same file explorer, IntelliSense, debugger, keybindings, command palette. Works exactly as you'd expect.
- **Agent Manager** — A control panel for spinning up autonomous agents. You give an agent a goal; it builds a plan you can review before anything executes, then writes code, creates files, runs tests, and verifies results on its own.
- **Browser** — A built-in Chrome-backed browser that agents can actually operate: clicking, scrolling, reading the DOM, taking screenshots, recording test sessions.

It uses **Open VSX** (not Microsoft's Marketplace) by default — which fits the philosophy of this repo just fine.

---

## The Honest Trade-offs

Before you install, know what you're signing up for:

| What you gain | What you give up |
|---|---|
| Free Gemini 3 Pro access (generous limits) | Mandatory Google account sign-in |
| Familiar VS Code muscle memory | Chrome browser required (browser surface) |
| Open VSX extensions (no Microsoft repo) | Google telemetry (like VS Code, but Google's) |
| Powerful multi-agent task execution | Internet connection needed for AI features |
| Import settings from VS Code/Cursor | `gpgcheck=0` in the official RPM repo config |

**Bottom line:** If your threat model involves Google specifically, this tool is not for you — full stop. If you're okay with Google having your usage data the same way you're already okay with Gmail or Android, it's a genuinely useful piece of software.

---

## System Requirements

- **glibc** >= 2.28 and **glibcxx** >= 3.4.25 (openSUSE Leap 15.4+ and Tumbleweed both exceed this)
- **Chrome** browser (required for the browser agent surface)
- **Personal Gmail account** (Google Workspace accounts not supported during preview)
- 8GB RAM minimum, 16GB recommended
- ~400MB disk space for the binary

Check your glibc version:
```bash
ldd --version
```

---

## Option 1: Portable Tarball (Recommended)

Same approach as the VS Code guide. No root, no repos, easy rollback, fits the existing `/data/itachi/AppImages/` structure.

### Initial Setup

```bash
mkdir -p /data/itachi/AppImages/antigravity
mkdir -p /data/itachi/AppImages/antigravity/user-data
cd /data/itachi/AppImages/antigravity
```

**Why a separate `user-data` dir?**  
By default Antigravity stores everything in `~/.antigravity`. Overriding this keeps your home directory clean and makes backups trivial.

---

### Download the Tarball

```bash
cd /data/itachi/AppImages/antigravity

curl -fL "https://antigravity.google/download/linux" -o antigravity.tar.gz
```

> **Verify you're getting the right thing.** The file should be roughly 300–400MB. If your download is suspiciously small, something redirected wrong.

Extract it:
```bash
tar -xzf antigravity.tar.gz
rm antigravity.tar.gz
```

This produces a folder like `antigravity-linux-x64/`. Make the binary executable and create a symlink:
```bash
chmod +x antigravity-linux-x64/antigravity
ln -sf /data/itachi/AppImages/antigravity/antigravity-linux-x64/antigravity antigravity
```

---

### Automated Update Script

Create `update-antigravity.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APPDIR="/data/itachi/AppImages/antigravity"
URL="https://antigravity.google/download/linux"

cd "$APPDIR"

echo "[+] Downloading latest Antigravity…"
curl -fL "$URL" -o antigravity.tar.gz

echo "[+] Extracting…"
rm -rf antigravity-linux-x64
tar -xzf antigravity.tar.gz
rm antigravity.tar.gz

chmod +x antigravity-linux-x64/antigravity
ln -sf "$APPDIR/antigravity-linux-x64/antigravity" antigravity

echo "[✓] Antigravity updated successfully"
echo "[i] User data preserved in $APPDIR/user-data"
```

Make it executable:
```bash
chmod +x update-antigravity.sh
```

Run it:
```bash
./update-antigravity.sh
```

---

### Desktop Integration

**1. Create the applications directory if it doesn't exist:**
```bash
mkdir -p ~/.local/share/applications
```

**2. Create the desktop entry:**
```bash
nvim ~/.local/share/applications/antigravity.desktop
```

**For X11:**
```ini
[Desktop Entry]
Name=Antigravity
Comment=Agent-first AI development platform
Exec=/data/itachi/AppImages/antigravity/antigravity --user-data-dir /data/itachi/AppImages/antigravity/user-data
Icon=/data/itachi/AppImages/antigravity/antigravity-linux-x64/resources/app/resources/linux/antigravity.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Antigravity
```

**For Wayland (if you see blurring or crashes on the X11 config):**
```ini
[Desktop Entry]
Name=Antigravity
Comment=Agent-first AI development platform
Exec=/data/itachi/AppImages/antigravity/antigravity --enable-features=UseOzonePlatform --ozone-platform=wayland --user-data-dir /data/itachi/AppImages/antigravity/user-data
Icon=/data/itachi/AppImages/antigravity/antigravity-linux-x64/resources/app/resources/linux/antigravity.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Antigravity
```

**3. Refresh the desktop database:**
```bash
update-desktop-database ~/.local/share/applications
```

---

### CLI Tool (`agy`)

Antigravity ships a CLI launcher called `agy`. Add a symlink so you can open projects from the terminal:

```bash
ln -sf /data/itachi/AppImages/antigravity/antigravity-linux-x64/bin/agy ~/.local/bin/agy
```

Make sure `~/.local/bin` is in your `$PATH`:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Open a project:
```bash
agy /path/to/your/project
```

---

### File Watcher Limit (Prevent Crashes on Large Projects)

```bash
echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/99-antigravity.conf
sudo sysctl --system
```

---

### First Launch

```bash
/data/itachi/AppImages/antigravity/antigravity \
  --user-data-dir /data/itachi/AppImages/antigravity/user-data
```

On first launch you'll be walked through:
1. **Setup flow** — Choose to import from VS Code/Cursor settings, or start fresh
2. **Theme** — Pick your preferred editor theme
3. **Keybindings and extensions** — Configure preferences, install recommended extensions
4. **Sign in to Google** — Required. Personal Gmail only during preview. This opens your system browser.
5. **Terms of Use** — You can opt out of additional telemetry here

---

### Backup Your Setup

```bash
# Backup binaries + user data
tar -czf antigravity-backup-$(date +%Y%m%d).tar.gz /data/itachi/AppImages/antigravity/

# Restore
tar -xzf antigravity-backup-YYYYMMDD.tar.gz -C /
```

---

## Option 2: zypper / RPM Repo (System-wide Install)

If you prefer zypper to manage updates and don't mind a system-wide install, Google publishes an official RPM repository.

### ⚠️ Read This First

The official RPM repo config uses `gpgcheck=0`. This means zypper will **not** verify package signatures before installing. This is Google's own published configuration — GPG verification reportedly fails with their Artifact Registry key in practice. You're trusting the repo URL itself rather than cryptographic signatures.

That's a meaningful trust reduction. Decide consciously.

### Add the RPM Repository

```bash
sudo tee /etc/zypp/repos.d/antigravity.repo << EOL
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOL
```

Refresh and install:
```bash
sudo zypper refresh
sudo zypper install antigravity
```

### Updating

```bash
sudo zypper update antigravity
```

### Removing Cleanly

```bash
sudo zypper remove antigravity
sudo rm /etc/zypp/repos.d/antigravity.repo
sudo zypper refresh
```

User data lives in `~/.antigravity` — remove it manually if you want a full clean wipe:
```bash
rm -rf ~/.antigravity
```

---

## Option 1 vs Option 2

| | Portable Tarball (Opt. 1) | zypper Repo (Opt. 2) |
|---|---|---|
| **Root required** | No | Yes |
| **Auto-updates** | Manual script | `zypper update` |
| **Rollback** | Trivial (keep old folder) | Zypper history |
| **GPG verification** | N/A | Disabled (`gpgcheck=0`) |
| **System pollution** | None | Standard RPM paths |
| **Fits AppImages structure** | ✅ Yes | ❌ No |

For this system's philosophy: **Option 1**.

---

## Understanding What Antigravity Phones Home

Unlike VS Code where Microsoft telemetry is the concern, Antigravity's data goes to Google. By default:

- **Usage telemetry** — Which features you use, session duration, errors
- **Agent interactions** — Prompts and outputs are processed server-side (Gemini runs in Google's cloud)
- **Google account** — Your identity is permanently linked to your installation

**To minimize telemetry during first-run setup:** On the Terms of Use screen, opt out of additional data collection. This doesn't eliminate cloud processing (the AI models are remote by design), but it reduces passive background reporting.

There is no fully offline mode for agent features. If that's a hard requirement, Antigravity is the wrong tool — look at local-model setups with Continue.dev or Ollama instead.

---

## The Browser Extension

For the browser agent surface to work, you need the Chrome extension:

1. Open Antigravity and start a task in the Playground
2. The app will prompt you to install the extension automatically
3. Or install it directly from the Chrome Web Store by searching "Antigravity"

The extension lets agents click, scroll, type, read the DOM, capture screenshots, and record test sessions in the browser. Without it, the editor and terminal surfaces still work fine — you just lose browser automation.

---

## Comparison: VS Code / VSCodium / Antigravity

| | VS Code | VSCodium | Antigravity |
|---|---|---|---|
| **Based on** | Code OSS | Code OSS | Code OSS |
| **Telemetry** | Microsoft | None | Google |
| **Extensions** | MS Marketplace | Open VSX | Open VSX |
| **AI agents** | Via extensions | Via extensions | Built-in (Gemini 3) |
| **Account required** | No | No | Yes (Gmail) |
| **Offline capable** | Yes | Yes | Editor only |
| **Our guide** | [vscode-installation.md](vscode-installation.md) | [vscode-installation.md](vscode-installation.md) | This file |

---

## Alternatives If Google Account Is a Non-Starter

If signing into Google is a hard blocker for your threat model, these accomplish similar agent-based coding without the account requirement:

- **Continue.dev** — Open-source, runs in VS Code/VSCodium, connects to any model including local Ollama instances
- **Aider** — Terminal-based coding agent, works with local or remote models, zero accounts required
- **Cursor** — Requires an account (Cursor's own, not Google's), similar agent capabilities

---

**Done.** Portable, self-contained, fully honest about what you're trading away.
