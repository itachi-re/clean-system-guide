#!/usr/bin/env bash
set -euo pipefail

APPDIR="/opt/antigravity"
TMP_FILE="/tmp/antigravity.tar.gz"
ICON_DEST="/usr/share/pixmaps/antigravity.png"
DESKTOP_FILE="/usr/share/applications/antigravity.desktop"

echo "[+] Resolving latest Antigravity download URL…"
URL=$(curl -fsSL --compressed "https://antigravity.google/download" \
  | grep -Eo 'https://[^" ]+/linux-x64/Antigravity\.tar\.gz' \
  | sort -u \
  | head -n1)

if [[ -z "$URL" ]]; then
    echo "[!] Could not resolve the download URL from the download page" >&2
    exit 1
fi

# URL looks like: https://storage.googleapis.com/antigravity-public/antigravity-hub/2.12.2-6298742303883264/linux-x64/Antigravity.tar.gz
LATEST_VERSION=$(echo "$URL" | grep -oP '(?<=antigravity-hub/)[^/]+')

if [[ -z "$LATEST_VERSION" ]]; then
    echo "[!] Could not parse version from resolved URL: $URL" >&2
    exit 1
fi

CURRENT_VERSION=""
if [[ -f "$APPDIR/.version" ]]; then
    CURRENT_VERSION=$(cat "$APPDIR/.version")
fi

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "[✓] Already on latest version ($LATEST_VERSION)"
    exit 0
fi

echo "[+] Latest version: $LATEST_VERSION (current: ${CURRENT_VERSION:-none})"
echo "[+] Downloading from $URL"
curl -fL "$URL" -o "$TMP_FILE"

echo "[+] Extracting…"
sudo tar -xzf "$TMP_FILE" -C /opt
rm "$TMP_FILE"

# Google's tarball extracts as Antigravity-x64; fold it into our fixed APPDIR
if [[ -d /opt/Antigravity-x64 ]]; then
    sudo rm -rf "$APPDIR"
    sudo mv /opt/Antigravity-x64 "$APPDIR"
fi

echo "[+] Fixing sandbox permissions…"
sudo chown root:root "$APPDIR/chrome-sandbox"
sudo chmod 4755 "$APPDIR/chrome-sandbox"

echo "[+] Symlinking binary…"
sudo ln -sf "$APPDIR/antigravity" /usr/local/bin/antigravity

echo "[+] Locating icon…"
FOUND_ICON=""
# Try a direct icon file shipped alongside the binary first
FOUND_ICON=$(find "$APPDIR" -maxdepth 3 -iname "*icon*.png" 2>/dev/null | sort | head -n1)

# Fall back to pulling it out of app.asar if nothing was found and asar is available
if [[ -z "$FOUND_ICON" ]] && [[ -f "$APPDIR/resources/app.asar" ]] && command -v npx &>/dev/null; then
    rm -rf /tmp/agy-asar
    if npx --yes asar extract "$APPDIR/resources/app.asar" /tmp/agy-asar &>/dev/null; then
        FOUND_ICON=$(find /tmp/agy-asar -iname "*icon*.png" 2>/dev/null | sort | head -n1)
    fi
fi

if [[ -n "$FOUND_ICON" ]]; then
    sudo cp "$FOUND_ICON" "$ICON_DEST"
    echo "    using $FOUND_ICON"
else
    echo "    no icon found, launcher will use a generic icon"
fi
rm -rf /tmp/agy-asar

echo "[+] Writing desktop entry…"
sudo tee "$DESKTOP_FILE" > /dev/null <<EOF
[Desktop Entry]
Type=Application
Name=Antigravity
Exec=$APPDIR/antigravity %U
Icon=${ICON_DEST:-antigravity}
Categories=Development;
Terminal=false
EOF
sudo update-desktop-database /usr/share/applications &>/dev/null || true

echo "$LATEST_VERSION" | sudo tee "$APPDIR/.version" > /dev/null

echo "[✓] Antigravity updated to $LATEST_VERSION"
