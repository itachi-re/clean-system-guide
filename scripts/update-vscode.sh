#!/usr/bin/env bash
set -euo pipefail

APPDIR="/data/itachi/AppImages/vscode"
URL="https://update.code.visualstudio.com/latest/linux-x64/stable"
TMP_FILE="/tmp/vscode.tar.gz"

echo "[+] Downloading latest VS Code…"
curl -fL "$URL" -o "$TMP_FILE"

echo "[+] Extracting…"
cd "$APPDIR"
rm -rf VSCode-linux-x64
tar -xzf "$TMP_FILE"
rm "$TMP_FILE"

chmod +x VSCode-linux-x64/code
ln -sf "$APPDIR/VSCode-linux-x64/code" code

echo "[✓] VS Code updated successfully"
