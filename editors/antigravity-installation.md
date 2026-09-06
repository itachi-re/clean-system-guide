# Google Antigravity on Linux (Without Losing Your Mind)

Antigravity is Google's agentic IDE — a VS Code fork with autonomous AI agents built into the editor, terminal, and browser surfaces. This guide covers installing it cleanly on **any Linux distro** using the portable tarball, since Google doesn't ship an official, well-behaved package for any of them — plus every gotcha this repo's maintainer actually hit while setting it up.

---

## What Is Antigravity, Actually?

Antigravity forks the open-source VS Code foundation but restructures the UX around agent management rather than pure text editing. Three surfaces:

- **Editor** — Standard VS Code layout: file explorer, IntelliSense, debugger, keybindings, command palette.
- **Agent Manager** — A control panel for autonomous agents. Give an agent a goal; it plans, writes code, runs tests, and verifies results, with review checkpoints along the way.
- **Browser Subagent** — A built-in Chrome-backed browser agents can drive: clicking, scrolling, reading the DOM, screenshots. **Currently broken on Linux across all distros** — see [Known Issues](#known-issues).

It uses **Open VSX** (not Microsoft's Marketplace) for extensions.

---

## The Honest Trade-offs

| What you gain | What you give up |
|---|---|
| Gemini access baked into the editor | Google account sign-in required |
| Familiar VS Code muscle memory | Chrome-backed browser surface |
| Open VSX extensions | Google telemetry |
| Autonomous multi-step agent execution | Internet connection needed for AI features |
| No Microsoft Marketplace dependency | No official, reliable Linux installer — tarball only |

**Bottom line:** if avoiding Google specifically is your threat model, skip this. Otherwise it's a genuinely capable tool once you get past Linux packaging being an afterthought.

---

## System Requirements

- **glibc** ≥ 2.28, **glibcxx** ≥ 3.4.25 (any distro from roughly the last 4–5 years clears this: Ubuntu 20.04+, Debian 11+, Fedora 34+, openSUSE Leap 15.3+/Tumbleweed, Arch — anything current)
- 8GB RAM minimum
- ~400–500MB disk space
- `curl`, `tar`, and (optionally) `npx`/Node.js for icon extraction — all standard or one package-manager command away on every major distro

Check your glibc version:
```bash
ldd --version
```

---

## Option 1: Portable Tarball (Recommended, works identically everywhere)

Google doesn't publish a stable "latest" download link or a listable release index — the tarball lives behind a Google Cloud Storage bucket that **allows direct downloads but blocks directory listing** (confirmed: hitting the bucket's listing API directly returns a 403, regardless of distro — this is server-side, not a local config issue). The only reliable way to resolve the current version is scraping the direct link off the download page itself.

### Resolve and download the current tarball

```bash
mkdir -p /tmp/antigravity-install && cd /tmp/antigravity-install

URL=$(curl -fsSL --compressed "https://antigravity.google/download" \
  | grep -Eo 'https://[^" ]+/linux-x64/Antigravity\.tar\.gz' \
  | sort -u | head -n1)

echo "Resolved: $URL"
curl -fL "$URL" -o antigravity.tar.gz
```

> If `$URL` comes back empty, the download page's markup has likely changed — open it in a browser and adjust the `grep` pattern. This step is identical on every distro; it's a plain HTTP request with no distro-specific dependency.

### Extract and install

The tarball extracts to `Antigravity-x64/` (not `antigravity-linux-x64/` — don't assume based on naming conventions from other Google Linux tools).

```bash
sudo tar -xzf antigravity.tar.gz -C /opt
sudo mv /opt/Antigravity-x64 /opt/antigravity
```

`/opt` is the standard location for self-contained third-party software across essentially all Linux distros (Debian, Ubuntu, Fedora, RHEL, openSUSE, Arch, etc. all follow this convention) — no distro-specific pathing needed.

### Fix the sandbox binary — do not skip this, on any distro

Antigravity is Electron/Chromium-based. Its `chrome-sandbox` helper **must** be root-owned with the setuid bit set, or the app fails to sandbox itself properly:

```bash
sudo chown root:root /opt/antigravity/chrome-sandbox
sudo chmod 4755 /opt/antigravity/chrome-sandbox
```

This is required regardless of distro or install location — putting the app in a user-local directory instead of `/opt` does not avoid the need for a root-owned setuid binary. The only way around it is launching with `--no-sandbox`, which works but disables a real security boundary — not recommended as a permanent habit.

### Symlink the binary

```bash
sudo ln -sf /opt/antigravity/antigravity /usr/local/bin/antigravity
antigravity --version
```

`/usr/local/bin` is on `$PATH` by default on essentially every distro's default shell config.

---

## Automated Update Script

Since there's no package manager tracking this on any distro, updates mean repeating the resolve → extract → sandbox-fix cycle. `scripts/update-antigravity.sh` in this repo automates all of it, including desktop-icon upkeep, and needs nothing distro-specific — just `bash`, `curl`, `tar`, and `sudo`:

```bash
./scripts/update-antigravity.sh
```

What it does on every run:
1. Resolves the current tarball URL from the download page (same method as above)
2. Skips the download entirely if you're already on the latest version (tracked via `/opt/antigravity/.version`)
3. Extracts and re-applies the `chrome-sandbox` permission fix (a fresh extraction resets it every time)
4. Re-symlinks `/usr/local/bin/antigravity`
5. Re-locates the icon and rewrites the `.desktop` launcher so menu integration never goes stale across updates

Run it manually whenever you want to update, or wire it into a cron job / systemd timer if you'd rather it check on a schedule.

---

## Desktop Integration

These steps use the **freedesktop.org XDG specification** for `.desktop` files and icon paths — this is a cross-desktop-environment, cross-distro standard (GNOME, KDE, Hyprland, XFCE, everything that implements a standard app launcher follows it), so nothing here needs adjusting per distro.

### Icon

The icon isn't a loose file in the tarball — it's packed inside `resources/app.asar`. Extract it once (the update script does this automatically on every run). Requires Node.js/npm; install via your distro's package manager if you don't already have it (`apt install nodejs npm`, `dnf install nodejs npm`, `pacman -S nodejs npm`, `zypper install nodejs npm`, etc.):

```bash
npx --yes asar extract /opt/antigravity/resources/app.asar /tmp/agy-extracted
sudo cp /tmp/agy-extracted/icon.png /usr/share/pixmaps/antigravity.png
```

### Launcher

```bash
sudo tee /usr/share/applications/antigravity.desktop > /dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Antigravity
Exec=/opt/antigravity/antigravity %U
Icon=/usr/share/pixmaps/antigravity.png
Categories=Development;
Terminal=false
EOF

sudo update-desktop-database /usr/share/applications
sudo gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
```

`update-desktop-database` and `gtk-update-icon-cache` ship in `desktop-file-utils` and `gtk-update-icon-cache`/`libgtk` packages respectively — present by default on virtually every desktop-oriented distro install; install manually only on minimal/server-base installs missing a desktop stack.

Because both the binary and the icon live at fixed paths (not a versioned folder), this `.desktop` file never needs manual edits across updates — the update script always folds the new version back into the same path.

---

## Known Issues

### Browser Subagent fails with a Playwright 404 (upstream bug, unfixed as of writing, affects every distro)

Asking the agent to open or interact with a website fails with:
```
failed to install playwright: could not install driver: 404 Not Found
https://playwright.azureedge.net/builds/driver/playwright-1.57.0-linux.zip
```
This is a confirmed, reproducible upstream bug — Antigravity's bundled `playwright-go` targets a driver version hosted on a CDN path Microsoft has since retired, and all three CDN mirrors 404. It's been reported on Google's own AI developer forum across multiple Linux distros (and even WSL2) with no fix yet; reinstalling Antigravity, Chromium, or Playwright locally does not help, since the fetch happens inside an isolated subagent environment. This is not something distro-specific packaging or configuration can work around.

**Workaround: none.** Avoid triggering the Browser Subagent until Google ships a fix. Everything else — the editor, terminal, non-browser agent tasks — is unaffected.

**Side effect to watch for:** if you interrupt the app with repeated `Ctrl+C` while it's hung on this feature's shutdown path, it can segfault. Send one interrupt (or use the app's own Quit), wait, and only escalate to `pkill -9` if it's still hanging after 15–20 seconds.

### Third-party distro packages lag behind and may conflict

Every distro has some community packaging effort for Antigravity, and all of them share the same problem: Google's lack of a stable release feed means these packages go stale and get abandoned or rebuilt inconsistently. Known examples at time of writing:

| Distro | Mechanism | Note |
|---|---|---|
| openSUSE | `opi antigravity` (OBS project) | Not officially Google's; can lag several versions behind |
| Arch | AUR `antigravity` package | Flagged with a low trust score by AUR's own trust signals — vet the PKGBUILD before building |
| Debian/Ubuntu | `unfallenwill/antigravity` GitHub releases (`.deb`) | Unofficial repackage of Google's tarball, not Google's own binary |
| Fedora/RHEL | `unfallenwill/antigravity` GitHub releases (`.rpm`) | Same project as above, RPM variant |

If you've ever installed via any of these, check for leftovers before troubleshooting anything else, since a stale package install can coexist badly with a manual `/opt/antigravity` install:

```bash
# Debian/Ubuntu
dpkg -l | grep -i antigravity

# Fedora/RHEL/openSUSE (RPM-based)
rpm -qa | grep -i antigravity

# Arch
pacman -Qs antigravity
```

Remove with your distro's package manager if found (`apt remove`, `dnf remove`, `zypper remove`, `pacman -R`), or delete orphaned files manually (commonly under `/usr/share/antigravity` or similar) if nothing owns them.

---

## Uninstalling

```bash
sudo rm -rf /opt/antigravity
sudo rm -f /usr/local/bin/antigravity
sudo rm -f /usr/share/applications/antigravity.desktop
sudo rm -f /usr/share/pixmaps/antigravity.png
sudo update-desktop-database /usr/share/applications
rm -rf ~/.config/Antigravity
```

Identical on every distro — nothing here touches a package manager, since this guide never uses one.

---

## What Antigravity Phones Home

By default: usage telemetry, agent prompts/outputs processed server-side (Gemini runs in Google's cloud), and your Google account identity tied to the install. There's no fully offline mode — the AI features are remote by design, on every platform. If that's a hard blocker, look at **Continue.dev** or **Aider** instead, both of which support local models with zero account requirements.

---

## Comparison: VS Code / VSCodium / Antigravity

| | VS Code | VSCodium | Antigravity |
|---|---|---|---|
| **Based on** | Code OSS | Code OSS | Code OSS |
| **Telemetry** | Microsoft | None | Google |
| **Extensions** | MS Marketplace | Open VSX | Open VSX |
| **AI agents** | Via extensions | Via extensions | Built-in |
| **Account required** | No | No | Yes (Google) |
| **Official Linux packaging** | Yes (all major distros) | Yes (all major distros) | No (tarball only, all distros) |
| **Our guide** | [vscode-installation.md](vscode-installation.md) | [vscode-installation.md](vscode-installation.md) | This file |

---

**Done.** Portable, sandboxed correctly, and honest about the one feature that's currently just broken — on every distro equally.
