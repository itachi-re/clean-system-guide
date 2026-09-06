# Installing Windows Games from ISO on Linux (Lutris + Wine)

> A repeatable, clean workflow for installing Windows games distributed as ISO images — without leaving mounts, temp files, or orphaned Wine prefixes behind.

---

## The Problem

Windows games distributed as ISO images don't have a native Linux install path. You need to:

- Extract the archive (if the ISO is packed inside a `.rar` or similar)
- Mount the ISO without permanently adding it anywhere
- Run the installer through a managed Wine prefix via Lutris
- Keep the final game files somewhere sane, not buried inside a Wine prefix
- Clean up every temporary artifact afterward

Do this carelessly and you end up with dangling loop mounts, stale prefixes from failed installs, the game sitting inside `drive_c/` where it's hard to manage, and a broken Lutris entry because the executable path is wrong after you move anything.

---

## The Clean Solution

The approach here:

1. Extract to `/tmp/` — it's gone on reboot regardless
2. Mount the ISO as a loop device only for the duration of the install
3. Let Lutris create the Wine prefix, but keep the actual game files in `~/Games/`
4. Move the installed game out of `drive_c/` into `~/Games/` after install
5. Update Lutris to point at the new location
6. Unmount and wipe everything temporary

This keeps `~/Games/` as the single source of truth for all game data, and the Wine prefix only holds runtime state — not the game itself.

---

## Step 1 — Rename the Archive (Optional but Recommended)

Scene-style archive names are long and annoying to type. Rename before you start:

    mv /path/to/VeryLongArchiveName.rar ~/Games/game.rar

This has no functional effect — it just keeps your shell history readable.

---

## Step 2 — Extract to a Temp Directory

Create a staging area under `/tmp/` and extract there:

    mkdir -p /tmp/game
    unrar x ~/Games/game.rar /tmp/game/

`/tmp/` is intentional. It's on tmpfs on most systems, it's fast, and it self-cleans on reboot. You don't want extraction debris in your home directory.

---

## Step 3 — Locate the ISO

Navigate into the extracted folder and confirm the ISO is there:

    cd /tmp/game/ExtractedFolder
    find . -name "*.iso"

Some archives contain additional files alongside the ISO (text files, URL shortcuts, NFO files). Ignore those — only the `.iso` matters.

---

## Step 4 — Mount the ISO

Create a mount point and attach the ISO as a loop device:

    mkdir -p /tmp/game-iso
    sudo mount -o loop ./game.iso /tmp/game-iso

The `read-only` warning is expected and harmless — ISOs are inherently read-only. The mounted contents will appear at `/tmp/game-iso/`.

---

## Step 5 — Install via Lutris

1. Open **Lutris**
2. Click **+** → *Add locally installed game*
3. Set the **Wine prefix** path to something identifiable, e.g. `~/.local/share/lutris/prefixes/mygame`
4. Under **Game options**, set the executable to the installer inside `/tmp/game-iso/` — typically `setup.exe` or `install.exe`
5. Run it and complete the installer wizard

> **If the install fails mid-way:** wipe the prefix before retrying, otherwise Wine will carry over broken state from the failed attempt:
>
>     rm -rf ~/.local/share/lutris/prefixes/mygame

---

## Step 6 — Unmount and Clean Up Temporaries

Once the installer finishes, the ISO is no longer needed:

    sudo umount /tmp/game-iso
    rm -rf /tmp/game /tmp/game-iso

If `umount` says *not mounted*, it was already detached — that's fine, skip it.

Delete the source archive too once you've confirmed the game runs:

    rm -rf ~/Games/game.rar

---

## Step 7 — Move the Game Out of the Wine Prefix

By default, the game installs into the Wine prefix's fake `C:` drive:

    ~/.local/share/lutris/prefixes/mygame/drive_c/GameFolder/

Move it to `~/Games/` where it belongs alongside everything else:

    mv "$HOME/.local/share/lutris/prefixes/mygame/drive_c/GameFolder" \
       "$HOME/Games/GameFolder"

The Wine prefix itself stays where it is — it holds registry entries, DLL overrides, and runtime config, none of which need to travel with the game files.

---

## Step 8 — Update the Lutris Entry

After moving, Lutris still points at the old path inside `drive_c/`. Fix it:

1. Right-click the game in Lutris → **Configure**
2. Under the **Game** tab:
   - **Executable** → set to the `.exe` inside `~/Games/GameFolder/`
   - **Working directory** → set to `~/Games/GameFolder/`
3. Under the **Runner** tab:
   - Confirm the Wine prefix still points to `~/.local/share/lutris/prefixes/mygame`
4. Save and launch to verify

Getting the working directory right matters — some games load assets relative to their own location. If it's wrong the game will either crash on launch or fail to find its data files.

---

## Verification Checklist

Before calling it done:

- [ ] ISO is unmounted (`findmnt | grep loop` shows nothing relevant)
- [ ] `/tmp/game` and `/tmp/game-iso` are gone
- [ ] Source archive deleted
- [ ] Game files are in `~/Games/`, not inside `drive_c/`
- [ ] Lutris executable and working directory both point to `~/Games/GameFolder/`
- [ ] Game launches cleanly from Lutris

---

## Alternatives

**Using `7z` instead of `unrar`**
If the archive is a `.7z` or a multi-part `.rar` that `unrar` chokes on, `7z x archive.rar -o/tmp/game/` handles both. `p7zip-full` is available in most repos.

**Mounting without `sudo`**
`udisksctl loop-setup -f game.iso` mounts an ISO as your user without needing root. The mount point ends up under `/run/media/$USER/`. Useful if you'd rather not use `sudo` for a temporary mount.

**Skipping the move entirely**
You can leave game files inside `drive_c/` and just update Lutris to point there. The downside is your game data is buried inside a hidden dot-directory, harder to back up, and tied to the prefix — if you ever recreate the prefix, you risk losing the game directory in the process. Moving it out is cleaner.

**Using `bottles` instead of Lutris**
Bottles is a more modern Wine frontend with better container isolation per-game. The ISO mounting and cleanup steps are identical — only the GUI workflow differs.

---

## Notes

- This workflow applies to any Windows game distributed as an ISO, regardless of what's bundled alongside it
- For AMD GPUs, Lutris auto-detects the `amdgpu` driver — no manual configuration needed
- Wine prefix size is usually small (under 500 MB) — the game files themselves are the bulk of the disk use, which is why keeping them in `~/Games/` and separate from the prefix makes backups straightforward

---

*Last updated: June 2026*
