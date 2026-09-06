# VS Code Without Microsoft's Repo on openSUSE

You want VS Code without trusting Microsoft's repo on your openSUSE box. Smart move. Here's how to automate it properly.

---

## Option 1: Portable Tarball Installation (Recommended)

**Why this approach:**
- No repo dependencies
- No root required
- Easy rollback
- Automation-friendly
- Self-contained installation
- Fits existing `/data/itachi/AppImages/` structure

**Important Note:** This downloads the official Microsoft binary (which still contains telemetry). If you want a truly Microsoft-free solution, use **VSCodium** instead (see Option 2 below).

---

### Initial Setup

```bash
mkdir -p /data/itachi/AppImages/vscode
mkdir -p /data/itachi/AppImages/vscode/extensions
mkdir -p /data/itachi/AppImages/vscode/user-data
cd /data/itachi/AppImages/vscode
```

**Why these directories?**
- `extensions/` - Keeps all extensions self-contained (instead of `~/.vscode/extensions`)
- `user-data/` - Stores settings, keybindings, snippets (instead of `~/.config/Code`)

---

### Automated Update Script

Create `update-vscode.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APPDIR="/data/itachi/AppImages/vscode"
URL="https://update.code.visualstudio.com/latest/linux-x64/stable"

cd "$APPDIR"

echo "[+] Downloading latest VS Code…"
curl -fL "$URL" -o vscode.tar.gz

echo "[+] Extracting…"
rm -rf VSCode-linux-x64
tar -xzf vscode.tar.gz
rm vscode.tar.gz

chmod +x VSCode-linux-x64/code
ln -sf "$APPDIR/VSCode-linux-x64/code" code

echo "[✓] VS Code updated successfully"
echo "[i] Extensions and settings preserved in $APPDIR"
```

Make it executable:
```bash
chmod +x update-vscode.sh
```

Run the update:
```bash
./update-vscode.sh
```

---

### Desktop Integration

**1. Create the directory (if it doesn't exist):**
```bash
mkdir -p ~/.local/share/applications
```

**2. Create the desktop file:**
```bash
nvim ~/.local/share/applications/code.desktop
```

**3. Add this content:**

**For X11 users (default):**
```ini
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
Exec=/data/itachi/AppImages/vscode/code --extensions-dir /data/itachi/AppImages/vscode/extensions --user-data-dir /data/itachi/AppImages/vscode/user-data
Icon=/data/itachi/AppImages/vscode/VSCode-linux-x64/resources/app/resources/linux/code.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Code
```

**For Wayland users (if you experience blurring/crashing on X11 config):**
```ini
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
Exec=/data/itachi/AppImages/vscode/code --enable-features=UseOzonePlatform --ozone-platform=wayland --extensions-dir /data/itachi/AppImages/vscode/extensions --user-data-dir /data/itachi/AppImages/vscode/user-data
Icon=/data/itachi/AppImages/vscode/VSCode-linux-x64/resources/app/resources/linux/code.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Code
```

**⚠️ Security Warning:** 
- **Never use** `--no-sandbox` unless VS Code absolutely refuses to launch
- This disables Electron's security sandbox and exposes your system if a malicious extension executes
- Only add it as a last resort for compatibility issues

**4. Refresh the desktop database:**
```bash
update-desktop-database ~/.local/share/applications
```

---

### Optional: System Hardening

**Increase file watcher limit** (prevents crashes with large projects):

```bash
echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/99-vscode.conf
sudo sysctl --system
```

---

### Launch VS Code

**From terminal:**
```bash
/data/itachi/AppImages/vscode/code
```

**Or search for "Visual Studio Code" in your application launcher.**

---

### Backup Your Setup

Since everything is self-contained, backup is trivial:

```bash
# Backup entire VS Code setup (binaries + extensions + settings)
tar -czf vscode-backup-$(date +%Y%m%d).tar.gz /data/itachi/AppImages/vscode/

# Restore
tar -xzf vscode-backup-YYYYMMDD.tar.gz -C /
```

---

## Option 2: VSCodium (True Microsoft-Free Alternative)

If you want to completely avoid Microsoft telemetry and proprietary licensing, use **VSCodium** instead. It's the same codebase with all Microsoft tracking stripped out.

### VSCodium AppImage Setup

```bash
mkdir -p /data/itachi/AppImages/vscodium
cd /data/itachi/AppImages/vscodium
```

**Download the latest VSCodium AppImage:**
```bash
curl -fL "https://github.com/VSCodium/vscodium/releases/latest/download/VSCodium-x86_64.AppImage" -o VSCodium.AppImage
chmod +x VSCodium.AppImage
```

**For self-contained setup (recommended):**
```bash
mkdir -p /data/itachi/AppImages/vscodium/extensions
mkdir -p /data/itachi/AppImages/vscodium/user-data
```

**Create update script for VSCodium:**

```bash
nvim update-vscodium.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail

APPDIR="/data/itachi/AppImages/vscodium"
URL="https://github.com/VSCodium/vscodium/releases/latest/download/VSCodium-x86_64.AppImage"

cd "$APPDIR"

echo "[+] Downloading latest VSCodium…"
curl -fL "$URL" -o VSCodium.AppImage.new

chmod +x VSCodium.AppImage.new
mv VSCodium.AppImage.new VSCodium.AppImage

echo "[✓] VSCodium updated successfully"
```

```bash
chmod +x update-vscodium.sh
```

**Desktop file for VSCodium:**
```bash
nvim ~/.local/share/applications/vscodium.desktop
```

**X11 version:**
```ini
[Desktop Entry]
Name=VSCodium
Comment=Code Editing. Redefined. (Telemetry-Free)
Exec=/data/itachi/AppImages/vscodium/VSCodium.AppImage --extensions-dir /data/itachi/AppImages/vscodium/extensions --user-data-dir /data/itachi/AppImages/vscodium/user-data
Icon=vscodium
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=VSCodium
```

**Wayland version:**
```ini
[Desktop Entry]
Name=VSCodium
Comment=Code Editing. Redefined. (Telemetry-Free)
Exec=/data/itachi/AppImages/vscodium/VSCodium.AppImage --enable-features=UseOzonePlatform --ozone-platform=wayland --extensions-dir /data/itachi/AppImages/vscodium/extensions --user-data-dir /data/itachi/AppImages/vscodium/user-data
Icon=vscodium
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=VSCodium
```

**Refresh:**
```bash
update-desktop-database ~/.local/share/applications
```

---

## Comparison: VS Code vs VSCodium

| Feature | VS Code (Option 1) | VSCodium (Option 2) |
|---------|-------------------|---------------------|
| **Telemetry** | Yes (Microsoft) | None |
| **Licensing** | Microsoft proprietary | MIT (fully open) |
| **Extensions** | Microsoft Marketplace | Open VSX Registry |
| **Updates** | Official MS server | GitHub releases |
| **Binary Source** | Microsoft | Community-built |
| **Installation** | Tarball | AppImage |

**Bottom line:** If you care about privacy and avoiding Microsoft entirely, use VSCodium. If you need access to Microsoft's extension marketplace and don't mind telemetry, use VS Code.

---

**Done.** Zero Microsoft repos, fully portable, completely self-contained, automation-ready.
