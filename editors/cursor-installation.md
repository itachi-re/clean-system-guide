# Cursor on Linux (Any Distro, Automatically)

Cursor is an AI-first fork of VS Code with agentic editing built in. Unlike Antigravity, Cursor actually ships proper `.deb` and `.rpm` packages alongside its AppImage — Google could learn something here. This guide covers a single script that detects your package manager and installs the right format automatically, on any distro.

---

## What Is Cursor, Actually?

Same VS Code foundation and muscle memory as everything else in this repo, restructured around:

- **Inline AI editing** — Multi-line predictive edits, chat-driven refactors, and agent mode that can plan and execute multi-step changes across a codebase.
- **Model choice** — Not locked to one vendor's model the way Antigravity is tied to Gemini.
- **Familiar extension ecosystem** — Compatible with the same extension format VS Code uses.

---

## The Trade-offs

| What you gain | What you give up |
|---|---|
| Real native `.deb`/`.rpm` packages — no manual sandbox permission fixing | Closed-source (unlike VSCodium) |
| Proper desktop integration out of the box via package manager | Telemetry (Cursor's own, not Microsoft's or Google's) |
| Works across model providers | Paid tiers for heavier usage |
| No forced browser/account-gated features like Antigravity's Browser Subagent | — |

---

## How the Update Script Works

`scripts/update-cursor.sh` in this repo does three things automatically:

1. **Detects your CPU architecture** (`x86_64` → `x64`, `aarch64`/`arm64` → `arm64`)
2. **Detects your package manager**, in this priority order:

   | Detected | Distro family | Format used |
   |---|---|---|
   | `dnf` | Fedora, RHEL, CentOS, Rocky, AlmaLinux | `.rpm` via `dnf install` |
   | `zypper` | openSUSE (Tumbleweed, Leap) | `.rpm` via `zypper install --allow-unsigned-rpm` |
   | `apt` | Debian, Ubuntu, Mint, Pop!_OS | `.deb` via `apt install` |
   | *(none of the above — e.g. Arch/pacman)* | Arch, Manjaro, Void, etc. | Portable `.AppImage` with manual desktop integration |

3. **Queries Cursor's official download API once** — `https://cursor.com/api/download?platform=linux-{arch}&releaseTrack=stable` — which returns a single JSON response containing the current version *and* direct signed URLs for all three formats (AppImage, `.deb`, `.rpm`) at once. No scraping, no guessing version strings, no separate calls per format.

Because it's one script that branches internally, you use the exact same command regardless of what distro you're on:

```bash
chmod +x scripts/update-cursor.sh
./scripts/update-cursor.sh
```

Run it again any time to update — it checks your currently installed version first and exits immediately if you're already current.

---

## What Happens Per Distro

### Fedora / RHEL / CentOS / Rocky / AlmaLinux (`dnf`)
Downloads the `.rpm`, then:
```bash
sudo dnf install -y /tmp/cursor-latest.rpm
```
`dnf` handles the desktop file, icon, and dependency resolution itself — no follow-up steps needed.

### openSUSE Tumbleweed / Leap (`zypper`)
Downloads the `.rpm`, then:
```bash
sudo zypper --non-interactive install --allow-unsigned-rpm /tmp/cursor-latest.rpm
```
The `--allow-unsigned-rpm` flag is required — Cursor's RPM isn't signed against zypper's default trust chain (confirmed: `zypper` prints `Package header is not signed!` during install, but proceeds). This is the same trust trade-off noted in the Antigravity guide for that project's unsigned artifacts.

### Debian / Ubuntu / Mint / Pop!_OS (`apt`)
Downloads the `.deb`, then:
```bash
sudo apt install -y /tmp/cursor-latest.deb
```
Modern `apt` (18.04+/Debian 10+) resolves dependencies from a local `.deb` path directly. On very old systems where this fails, fall back to:
```bash
sudo dpkg -i /tmp/cursor-latest.deb
sudo apt-get install -f -y
```

### Everything else — Arch, Manjaro, Void, etc. (no native package)
Cursor doesn't publish an Arch/pacman package, so the script falls back to the portable AppImage, following the same pattern used for Antigravity in this repo:

1. Downloads `Cursor-<version>-<arch>.AppImage` to `/opt/cursor/cursor.AppImage`
2. Symlinks it to `/usr/local/bin/cursor`
3. Extracts the icon via `--appimage-extract` (AppImages are self-contained SquashFS images — no `asar` needed here, unlike Antigravity)
4. Writes `/usr/share/applications/cursor.desktop` with `--no-sandbox` baked into the launch command

**Why `--no-sandbox` for the AppImage path specifically:** Electron's `chrome-sandbox` helper needs to be a root-owned, setuid binary to sandbox itself properly — the same requirement documented in the Antigravity guide. Since an AppImage mounts its contents read-only at runtime via SquashFS, there's no straightforward way to `chown`/`chmod` a file living inside it before launch. Disabling the sandbox is the standard workaround every community Cursor-AppImage script uses. If you want the sandbox active, you can try dropping the flag from the `.desktop` file's `Exec=` line and test whether your kernel's unprivileged user namespaces make it unnecessary — Arch-family kernels often do.

---

## Manual Install (if you'd rather not run the script)

Query the API yourself to get the current URLs:
```bash
curl -s "https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
# swap linux-x64 for linux-arm64 on ARM
```
This returns `downloadUrl` (AppImage), `debUrl`, and `rpmUrl` — grab whichever matches your package manager and install with the standard command for your distro (`rpm -i`, `dpkg -i`, or just `chmod +x` + run for the AppImage).

---

## Uninstalling

```bash
# dnf
sudo dnf remove cursor

# zypper
sudo zypper remove cursor

# apt
sudo apt remove cursor

# AppImage fallback path
sudo rm -rf /opt/cursor
sudo rm -f /usr/local/bin/cursor
sudo rm -f /usr/share/applications/cursor.desktop
sudo rm -f /usr/share/pixmaps/cursor.png
sudo update-desktop-database /usr/share/applications
```

User settings/extensions live in `~/.config/Cursor` — remove separately if you want a full clean wipe.

---

## Comparison: VS Code / VSCodium / Antigravity / Cursor

| | VS Code | VSCodium | Antigravity | Cursor |
|---|---|---|---|---|
| **Based on** | Code OSS | Code OSS | Code OSS | Code OSS |
| **Telemetry** | Microsoft | None | Google | Cursor |
| **AI provider** | Via extensions | Via extensions | Gemini (locked) | Model-agnostic |
| **Account required** | No | No | Yes (Google) | Yes (Cursor) |
| **Official native Linux packages** | Yes | Yes | No (tarball only) | Yes (`.deb`/`.rpm`/AppImage) |
| **Sandbox setup needed manually** | No | No | Yes | Only on the AppImage fallback path |
| **Our guide** | [vscode-installation.md](vscode-installation.md) | [vscode-installation.md](vscode-installation.md) | [antigravity-installation.md](antigravity-installation.md) | This file |

---

**Done.** One script, every distro, real packages where Cursor provides them, and an honest AppImage fallback where it doesn't.
