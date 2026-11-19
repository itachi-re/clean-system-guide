# The Gold Standard Archiving Workflow — TAR + 7z + SHA256

> Archive Linux data **without losing metadata**, compress it as hard as LZMA2 allows, optionally encrypt it with AES-256, and **prove** the result is intact, before you ever touch the original.

Part of the [Linux Archiving & Compression Guide](README.md). Written with **openSUSE Tumbleweed** in mind, with notes for Arch, Debian/Ubuntu and Fedora/RHEL.

---

## TL;DR

```bash
cd ~/backups                                   # output goes OUTSIDE the source

# 0. DRY RUN: what will be archived? enough space?
du -sh ~/Documents && df -h .
tar -C ~ -cvf /dev/null Documents | wc -l      # file count, writes nothing

# 1. TAR: keeps permissions, owners, symlinks, xattrs, ACLs
tar --xattrs --acls --numeric-owner --sparse -C ~ -cvf docs.tar Documents

# 2. 7z: LZMA2 max compression + AES-256 (filenames hidden)
7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on -mhe=on -p docs.tar.7z docs.tar

# 3. SHA256: fingerprint both files
sha256sum docs.tar docs.tar.7z > docs.sha256

# 4. VERIFY: checksum + integrity + round-trip
sha256sum -c docs.sha256
7z t docs.tar.7z

# 5. Only after every check passes: remove the intermediate .tar (never the source)
rm docs.tar

# RESTORE: into a staging folder first, never straight over live data
mkdir -p ~/staging && 7z x docs.tar.7z -o"$HOME/staging"
sudo tar --xattrs --acls --numeric-owner -xpf ~/staging/docs.tar -C ~/staging
```

| You want…                    | Use                                                         |
|------------------------------|-------------------------------------------------------------|
| Max ratio, no encryption     | drop `-mhe=on -p` from the 7z command                       |
| Faster, still good           | `-mx=6` instead of `-mx=9`                                  |
| Split for USB / upload       | add `-v2g` to the 7z command                                |
| SELinux system (Fedora/RHEL) | add `--selinux` to **both** create and extract `tar` commands |

> **Golden rules:** the original is never modified, the output lives outside the source, nothing is deleted until it is verified, and restores go to a staging directory first.

---

## Table of Contents

- [Why three tools?](#why-three-tools)
- [Prerequisites](#prerequisites)
- [Step 0 — Pre-flight and dry run](#step-0--pre-flight-and-dry-run)
- [Step 1 — Create the TAR](#step-1--create-the-tar)
- [Step 2 — Compress (and encrypt) with 7z](#step-2--compress-and-encrypt-with-7z)
- [Step 3 — Generate checksums](#step-3--generate-checksums)
- [Step 4 — Verify](#step-4--verify)
- [Step 5 — Clean up the intermediate TAR](#step-5--clean-up-the-intermediate-tar)
- [Step 6 — Restore safely](#step-6--restore-safely)
- [Worked examples](#worked-examples)
- [Automation script](#automation-script)
- [What this does NOT preserve](#what-this-does-not-preserve)
- [Troubleshooting](#troubleshooting)
- [Cheat sheet](#cheat-sheet)

---

## Why three tools?

Each tool does one job it is genuinely best at:

| Tool        | Job                                   | Why it is here                                                                 |
|-------------|----------------------------------------|--------------------------------------------------------------------------------|
| `tar`       | Pack files + Linux metadata            | The only common format that natively stores POSIX permissions, owners, symlinks, hard links, device nodes, xattrs and ACLs |
| `7z`        | Compress + encrypt                     | LZMA2 gives top-tier ratios; AES-256 with `-mhe=on` also hides filenames       |
| `sha256sum` | Prove integrity                        | Detects any bit-level change from disk errors, bad transfers or tampering      |

Using `7z` directly on a directory **loses Linux metadata** (owners, xattrs, ACLs, hard links). Putting TAR first fixes that.

---

## Prerequisites

```bash
# openSUSE Tumbleweed
sudo zypper refresh
sudo zypper install tar 7zip rsync      # 7zip = modern upstream 7-Zip

# Arch
sudo pacman -S tar 7zip rsync

# Debian / Ubuntu
sudo apt install tar 7zip rsync         # older releases: p7zip-full

# Fedora / RHEL (EPEL on RHEL)
sudo dnf install tar 7zip rsync         # older releases: p7zip p7zip-plugins
```

Check which 7-Zip binary you got. It may be `7z`, `7zz` or `7za`:

```bash
command -v 7z 7zz 7za
```

> All examples use `7z`. If yours is `7zz`, substitute it everywhere.

`rsync` is used only for the optional restore comparison in [Step 6](#step-6--restore-safely).

---

## Step 0 — Pre-flight and dry run

Look before you write anything.

```bash
# How big is the source, and is there room for tar + 7z output?
du -sh ~/Documents
df -h ~/backups

# What would tar include? Archiving to /dev/null writes nothing.
tar -C ~ -cvf /dev/null Documents | wc -l

# Any unreadable files? Errors show up on stderr.
tar -C ~ -cf /dev/null Documents
```

Rules of thumb:

- **Free space:** have at least the size of the source for the `.tar`, plus the compressed `.7z`. Binary-heavy data compresses poorly, so assume the `.7z` can approach the `.tar` size.
- **Output location:** write **outside** the directory being archived. Otherwise you may archive your own half-written output.
- **System directories:** use `sudo` to read everything, and add `--one-file-system` to avoid crossing into `/proc`, `/sys` or other mounts.

---

## Step 1 — Create the TAR

```bash
tar \
  --xattrs \
  --acls \
  --numeric-owner \
  --sparse \
  -C /path/to/parent \
  -cvf name.tar \
  -- directory_name
```

### Why `-C parent directory_name`?

It stores **relative** paths (`directory_name/file`), so the archive restores cleanly anywhere. If you pass an absolute path, tar strips the leading `/` anyway (the `Removing leading '/'` message is normal), but exclude patterns and restore paths become confusing.

### Flags

| Flag               | Purpose                                                                    |
|--------------------|----------------------------------------------------------------------------|
| `--xattrs`         | Store extended attributes (this includes file capabilities set with `setcap`) |
| `--acls`           | Store POSIX ACLs                                                           |
| `--selinux`        | Store SELinux contexts, **only on SELinux systems** (Fedora/RHEL). Omit on openSUSE, which uses AppArmor |
| `--numeric-owner`  | Store and restore UID/GID as numbers rather than names, which is more faithful when moving between machines |
| `--sparse`         | Store sparse files efficiently (VM images, databases)                      |
| `--one-file-system`| Do not cross filesystem boundaries                                         |
| `--exclude=PATTERN`| Skip matching names, e.g. `--exclude='.cache'`                             |
| `-c` `-v` `-f`     | Create, verbose, output file                                               |

> **About `--preserve-permissions` (`-p`):** it only affects **extraction**. Creating an archive always records permissions, so it is pointless in a create command. Use `-p` when extracting (as root it is already the default).

> **About `--ignore-failed-read`:** useful only for live systems with files that vanish or are unreadable. It silences real problems, so leave it off unless you have a reason.

### Exit codes

| Code | Meaning                                              | What to do                              |
|------|------------------------------------------------------|-----------------------------------------|
| `0`  | Success                                              | Continue                                |
| `1`  | Some files changed while being read                  | Review. Normal on live data, but the changed files may be inconsistent |
| `2`  | Fatal error                                          | Stop and fix before continuing          |

### Common exclusions

```bash
--exclude='.cache' \
--exclude='.local/share/Trash' \
--exclude='node_modules' \
--exclude='__pycache__' \
--exclude='*.tmp'
```

Patterns are **unanchored** by default, so `.cache` matches that name at any depth.

---

## Step 2 — Compress (and encrypt) with 7z

### Encrypted (recommended for anything sensitive)

```bash
7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on -mhe=on -p name.tar.7z name.tar
```

You are prompted for the password twice. It never enters your shell history or process list.

### Compression only

```bash
7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on name.tar.7z name.tar
```

### Faster, lower memory

```bash
7z a -t7z -m0=lzma2 -mx=6 -ms=on -mmt=on -mhe=on -p name.tar.7z name.tar
```

| Option       | Meaning                                                                  |
|--------------|--------------------------------------------------------------------------|
| `a`          | Add to archive                                                           |
| `-t7z`       | 7z container                                                             |
| `-m0=lzma2`  | LZMA2 algorithm                                                          |
| `-mx=9`      | Maximum compression (slow, memory hungry; use `-mx=6` on small machines) |
| `-ms=on`     | Solid mode. It matters little for one big `.tar`, but is harmless and is the default |
| `-mmt=on`    | Use all CPU threads                                                      |
| `-mhe=on`    | Encrypt headers so **filenames are hidden** (needs `-p`)                 |
| `-p`         | Prompt for a password and enable AES-256                                 |
| `-v2g`       | Split into 2 GB volumes (optional)                                       |

> ⚠️ **No password recovery.** Lose the password and the data is gone. Store it in a password manager.

> ⚠️ **`-mhe=on` without `-p` does nothing.** Always use them together.

---

## Step 3 — Generate checksums

Run this in the same directory as the files so the checksum file holds relative names:

```bash
sha256sum name.tar name.tar.7z > name.sha256
cat name.sha256
```

```text
3f2a…c91e  name.tar
b7d0…44a2  name.tar.7z
```

The `.tar` hash is your reference for the **round-trip check** in Step 4. The `.7z` hash detects later corruption in storage or transfer.

---

## Step 4 — Verify

Three checks, each proving something different:

| Check                         | Command                                       | Proves                                             |
|-------------------------------|-----------------------------------------------|----------------------------------------------------|
| 1. Checksum                   | `sha256sum -c name.sha256`                    | Files match what was just written                  |
| 2. 7z integrity               | `7z t name.tar.7z`                            | Archive structure and password are valid           |
| 3. Round-trip (strongest)     | see below                                     | Decompressing yields **exactly** the original TAR  |

```bash
sha256sum -c name.sha256
# name.tar: OK
# name.tar.7z: OK

7z t name.tar.7z
# Everything is Ok
```

### Round-trip check

Decompress to a pipe and compare the hash with the TAR's recorded hash. This writes nothing to disk:

```bash
want=$(sha256sum name.tar | cut -d' ' -f1)
got=$(7z x -so name.tar.7z | sha256sum | cut -d' ' -f1)
[ "$want" = "$got" ] && echo "ROUND-TRIP OK" || echo "MISMATCH, do not delete anything"
```

For encrypted archives you are prompted for the password. A wrong password produces a mismatch rather than a false pass.

### Optional: confirm the TAR itself is readable

```bash
tar -tf name.tar > /dev/null && echo "TAR OK"
```

---

## Step 5 — Clean up the intermediate TAR

**Only after Step 4 fully passes:**

```bash
rm name.tar
```

Important points:

- **Never delete the original source** as part of this workflow. Do that manually, much later, after you have confirmed a restore works.
- If you encrypted, the plain `.tar` holds your data **unencrypted** and must not be left lying around.
- `rm` is not a secure erase on SSDs or copy-on-write filesystems like Btrfs. For highly sensitive data, create the TAR on an encrypted volume or on a RAM-backed location such as `/dev/shm` (if you have the memory).
- Keep `name.sha256`, or keep the `.7z` line from it, next to the archive.

---

## Step 6 — Restore safely

**Never extract directly over live data.** Restore to a staging directory, verify, then copy.

### 6.1 Extract the 7z

```bash
mkdir -p ~/staging
7z x name.tar.7z -o"$HOME/staging"        # note: no space after -o
```

### 6.2 Extract the TAR with metadata

```bash
mkdir -p ~/staging/out
sudo tar --xattrs --acls --numeric-owner -xpf ~/staging/name.tar -C ~/staging/out
```

- Use `sudo` (root) to restore **ownership**, **capabilities** and **security xattrs**. A normal user cannot set files to belong to other users.
- As a normal user, tar silently skips ownership, which is usually fine for personal files.
- Add `--selinux` on SELinux systems (same as at creation time).

### 6.3 Compare against the original (if it still exists)

```bash
# -n = dry run, -i = itemize differences, -c = compare contents by checksum
rsync -aAXHnic --delete ~/Documents/ ~/staging/out/Documents/
```

No output means no differences. Trailing slashes matter: keep them on both paths exactly as shown.

### 6.4 Copy into place (dry run first)

```bash
rsync -aAXHn --info=stats1 ~/staging/out/Documents/ ~/Documents-restored/   # preview
rsync -aAXH  --info=progress2 ~/staging/out/Documents/ ~/Documents-restored/ # real copy
```

Restore to a **new** location first. Only swap it into place once you have inspected it.

### 6.5 Restore a single file

```bash
tar -tf ~/staging/name.tar | grep 'important.txt'          # find the path
tar --xattrs --acls -xpf ~/staging/name.tar -C ~/staging/out 'Documents/important.txt'
```

### 6.6 Stream-extract without a temporary TAR (optional)

```bash
mkdir -p ~/staging/out
7z x -so name.tar.7z | sudo tar --xattrs --acls --numeric-owner -xpf - -C ~/staging/out
```

---

## Worked examples

### Example 1: Home directory backup, encrypted

```bash
mkdir -p /mnt/backup/home && cd /mnt/backup/home       # output on another disk

# Dry run
du -sh "$HOME" && df -h .
tar -C /home --one-file-system --exclude='.cache' --exclude='.local/share/Trash' \
    -cvf /dev/null "$USER" | wc -l

# Archive
tar --xattrs --acls --numeric-owner --sparse --one-file-system \
    --exclude='.cache' --exclude='.local/share/Trash' \
    -C /home -cvf "${USER}_$(date +%F).tar" -- "$USER"
```

Then repeat Steps 2–5 using that filename.

### Example 2: Project source, shareable, no encryption

```bash
tar --xattrs --acls --exclude='.git' --exclude='node_modules' --exclude='__pycache__' \
    -C ~/projects -cvf myproject.tar myproject

7z a -t7z -m0=lzma2 -mx=9 -mmt=on myproject.tar.7z myproject.tar
sha256sum myproject.tar myproject.tar.7z > myproject.sha256
sha256sum -c myproject.sha256 && 7z t myproject.tar.7z
```

> Sharing with Windows/macOS users who do not care about Linux metadata? Plain ZIP is friendlier. See the main guide.

### Example 3: `/etc` as root, preserving everything

```bash
sudo tar --xattrs --acls --numeric-owner --sparse -C / -cvf etc_backup.tar etc
# On Fedora/RHEL also add --selinux

sudo 7z a -t7z -m0=lzma2 -mx=9 -mmt=on -mhe=on -p etc_backup.tar.7z etc_backup.tar
sudo sha256sum etc_backup.tar etc_backup.tar.7z > etc_backup.sha256
sudo sha256sum -c etc_backup.sha256
sudo 7z t etc_backup.tar.7z
sudo chown "$USER": etc_backup.tar.7z etc_backup.sha256   # make it handy to copy
```

Restore to a staging directory and compare with `diff -r` or `rsync -n` **before** replacing anything under `/etc`.

### Example 4: Large archive split into volumes

```bash
7z a -t7z -m0=lzma2 -mx=9 -mmt=on -mhe=on -p -v2g big.tar.7z big.tar
# Produces big.tar.7z.001, big.tar.7z.002, ...

sha256sum big.tar.7z.0* > big.volumes.sha256     # glob matches the volume files only
sha256sum -c big.volumes.sha256

7z t big.tar.7z.001                               # point at the first volume
7z x big.tar.7z.001 -o"$HOME/staging"             # restores from all volumes
```

Keep **all** volumes together. Missing one makes the rest useless.

### Example 5: Quick faster backup (balanced)

```bash
tar --xattrs --acls --numeric-owner --sparse -C ~ -cvf notes.tar Notes
7z a -t7z -m0=lzma2 -mx=5 -mmt=on notes.tar.7z notes.tar
sha256sum notes.tar notes.tar.7z > notes.sha256 && sha256sum -c notes.sha256
```

---

## Automation script

Save as `~/bin/gold-archive.sh` and `chmod +x ~/bin/gold-archive.sh`.

It follows the rules above: supports a **dry run**, never touches the source, never overwrites existing output, verifies with checksum **and** a round-trip hash, and deletes the intermediate TAR **only** if you ask and only after verification.

```bash
#!/usr/bin/env bash
# gold-archive.sh: TAR + 7z (LZMA2) + SHA256, with verification
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gold-archive.sh [-e] [-n] [-s] [-c] [-o OUTDIR] SOURCE_DIR

  -e  encrypt with AES-256 (filenames hidden); prompts for a password
  -n  dry run: show what would be archived, write nothing
  -s  also store SELinux contexts (Fedora/RHEL; skip on openSUSE)
  -c  remove the intermediate .tar after everything has verified
  -o  output directory (must exist; default: current directory)

The source directory is never modified or deleted.
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

ENCRYPT=0; DRYRUN=0; SELINUX=0; CLEAN=0; OUTDIR="."
while getopts "ensco:h" opt; do
  case "$opt" in
    e) ENCRYPT=1 ;;
    n) DRYRUN=1 ;;
    s) SELINUX=1 ;;
    c) CLEAN=1 ;;
    o) OUTDIR="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -eq 1 ]] || { usage; exit 1; }

command -v tar >/dev/null       || die "tar not found"
command -v sha256sum >/dev/null || die "sha256sum not found"
SZ=$(command -v 7z || command -v 7zz || true)
[[ -n "$SZ" ]] || die "7z/7zz not found (openSUSE: sudo zypper install 7zip)"

SRC=$(realpath -- "$1")
[[ -d "$SRC" ]]  || die "not a directory: $1"
[[ "$SRC" != "/" ]] || die "refusing to archive /; choose a subdirectory"
[[ -d "$OUTDIR" ]] || die "output directory does not exist: $OUTDIR"
OUT=$(realpath -- "$OUTDIR")
case "$OUT/" in "$SRC"/*) die "output directory is inside the source" ;; esac

PARENT=$(dirname -- "$SRC")
NAME=$(basename -- "$SRC")

TAR_OPTS=(--xattrs --acls --numeric-owner --sparse)
if (( SELINUX )); then TAR_OPTS+=(--selinux); fi

# ── Dry run ──────────────────────────────────────────────
if (( DRYRUN )); then
  echo "DRY RUN: nothing will be written"
  echo "Source : $SRC"
  echo "Size   : $(du -sh -- "$SRC" | cut -f1)"
  echo "Files  : $(tar "${TAR_OPTS[@]}" -C "$PARENT" -cvf /dev/null -- "$NAME" | wc -l)"
  echo "Free   : $(df -h --output=avail -- "$OUT" | tail -n1 | tr -d ' ') in $OUT"
  exit 0
fi

cd -- "$OUT"
STAMP=$(date +%Y%m%d_%H%M%S)
TAR="${NAME}_${STAMP}.tar"
ARC="${TAR}.7z"
[[ ! -e "$TAR" && ! -e "$ARC" ]] || die "output files already exist"

# ── 1. TAR ───────────────────────────────────────────────
echo "[1/5] Creating TAR: $TAR"
rc=0
tar "${TAR_OPTS[@]}" -C "$PARENT" -cf "$TAR" -- "$NAME" || rc=$?
if (( rc == 1 )); then
  echo "WARNING: some files changed while being read (tar exit 1)" >&2
elif (( rc > 1 )); then
  die "tar failed (exit $rc)"
fi
tar -tf "$TAR" > /dev/null || die "TAR is not readable"
sha256sum -- "$TAR" > "$TAR.sha256"

# ── 2. 7z ────────────────────────────────────────────────
echo "[2/5] Compressing with 7z (LZMA2)"
SZ_OPTS=(-t7z -m0=lzma2 -mx=9 -ms=on -mmt=on)
if (( ENCRYPT )); then SZ_OPTS+=(-mhe=on -p); fi
"$SZ" a "${SZ_OPTS[@]}" "$ARC" "$TAR"

# ── 3. Checksum ──────────────────────────────────────────
echo "[3/5] Writing checksum"
sha256sum -- "$ARC" > "$ARC.sha256"

# ── 4. Verify ────────────────────────────────────────────
echo "[4/5] Verifying"
sha256sum -c -- "$ARC.sha256"
want=$(cut -d' ' -f1 "$TAR.sha256")
got=$("$SZ" x -so "$ARC" | sha256sum | cut -d' ' -f1) \
  || die "round-trip failed; nothing was deleted"
[[ "$want" == "$got" ]] || die "round-trip MISMATCH; nothing was deleted"
echo "Round-trip OK"

# ── 5. Cleanup (only after verification) ─────────────────
echo "[5/5] Cleanup"
if (( CLEAN )); then
  rm -- "$TAR"
  echo "Removed intermediate $TAR"
elif (( ENCRYPT )); then
  echo "WARNING: unencrypted $TAR is still on disk; remove it when you are ready." >&2
fi

echo
echo "Done."
ls -lh -- "$ARC" "$ARC.sha256"
```

Usage:

```bash
gold-archive.sh -n ~/Documents                      # dry run first
gold-archive.sh -e -c -o /mnt/backup ~/Documents    # encrypted, clean up after verifying
```

---

## What this does NOT preserve

Be aware of the limits so you are not surprised:

| Item                                        | Status                                                                 |
|---------------------------------------------|------------------------------------------------------------------------|
| Modification time (mtime)                   | ✅ Preserved                                                            |
| Access / change time (atime, ctime)         | ❌ Not restored by any tool. `ctime` cannot be set on Linux            |
| `chattr` flags (immutable, no-CoW, …)       | ❌ Not stored by tar. Record them with `lsattr -R` if you need them    |
| Btrfs subvolumes, snapshots, reflinks       | ❌ Stored as plain files and directories. Use `btrfs send/receive` for those |
| Mounted filesystems                         | Skipped with `--one-file-system`                                       |
| Hard links                                  | ✅ Preserved within the archive                                         |
| Ownership, permissions, symlinks, devices   | ✅ Preserved (ownership needs root to restore)                          |
| xattrs, ACLs, capabilities                  | ✅ With `--xattrs` / `--acls` on **both** create and extract           |
| Restore onto FAT/exFAT/some network shares  | ❌ These filesystems cannot hold Unix permissions, owners or xattrs     |

> This workflow archives **files**. It is not a bare-metal system image. For full-system recovery use filesystem-level tools (Btrfs snapshots, `dd`/Clonezilla, etc.).

---

## Troubleshooting

### `tar: Removing leading '/' from member names`
Normal and harmless. Using `-C parent name` avoids it entirely.

### `tar: file changed as we read it` (exit 1)
A file was modified during the backup (logs, databases, browser profiles). Stop the service first, snapshot the filesystem, or exclude the path.

### `--selinux` not recognized, or no effect
Your tar lacks SELinux support or the system does not use SELinux (openSUSE uses AppArmor). Omit the flag:

```bash
tar --xattrs --acls -C ~ -cvf name.tar Documents
```

### `7z: command not found`
```bash
command -v 7z 7zz 7za
sudo zypper install 7zip     # openSUSE
```

### `Cannot allocate memory` / system freezes during `-mx=9`
LZMA2 at maximum level needs a lot of RAM, more with many threads. Lower the level or the dictionary:

```bash
7z a -t7z -m0=lzma2 -mx=6 -mmt=2 name.tar.7z name.tar
# or cap the dictionary:  -md=32m
```

### `Data Error in encrypted file. Wrong password?`
Wrong password, or the archive is corrupt. Re-run `sha256sum -c` to tell the two apart.

### `sha256sum: WARNING: 1 computed checksum did NOT match`
Do not use the archive. Re-copy it from the source medium. If it persists, the storage device may be failing. Also make sure it was transferred in binary mode.

### `sha256sum -c` says "No such file"
Run it from the directory containing the files (the checksum file stores relative names).

### Permissions or ownership wrong after restore
- Restore as root (`sudo tar …`) to get ownership back.
- Use `--numeric-owner` on both create and extract when UIDs differ between machines.
- Check the destination filesystem supports Unix permissions (`df -T path`).

### xattrs/ACLs missing after restore
Pass `--xattrs --acls` on **extract** too. Verify the target filesystem supports them (`df -T`; avoid FAT/exFAT).

```bash
touch testfile && setfattr -n user.test -v hello testfile && getfattr -d testfile
```

---

## Cheat sheet

```text
┌─ ARCHIVE ───────────────────────────────────────────────────────────────┐
│ tar --xattrs --acls --numeric-owner --sparse -C PARENT -cvf X.tar DIR   │
│ 7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on -mhe=on -p X.tar.7z X.tar      │
│ sha256sum X.tar X.tar.7z > X.sha256                                     │
├─ VERIFY ────────────────────────────────────────────────────────────────┤
│ sha256sum -c X.sha256                                                   │
│ 7z t X.tar.7z                                                           │
│ 7z x -so X.tar.7z | sha256sum      # compare with X.tar's hash          │
├─ RESTORE (staging first) ───────────────────────────────────────────────┤
│ 7z x X.tar.7z -o"$HOME/staging"                                         │
│ sudo tar --xattrs --acls --numeric-owner -xpf STAGING/X.tar -C OUTDIR   │
│ rsync -aAXHnic --delete ORIGINAL/ OUTDIR/DIR/     # empty output = same │
├─ SAFETY ────────────────────────────────────────────────────────────────┤
│ Output outside source • dry run first • verify before rm • never rm     │
│ the original in this workflow • -mhe=on needs -p • keep the password    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

*Part of the [Clean System Guide](README.md): real solutions from real problems.*
