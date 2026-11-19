# TAR + zstd + GPG: Private, Fast, Fully-Preserved Archives

> Archive Linux data with **full metadata preservation**, compress it with **Zstandard**, encrypt it with **GPG (AES-256)**, and **verify every layer**, all in one stream, so an unencrypted copy never touches your disk.

Companion to the [Gold Standard Workflow (TAR + 7z)](gold-standard-workflow.md). Part of the [Linux Archiving & Compression Guide](README.md). Written with **openSUSE Tumbleweed** in mind, with notes for Arch, Debian/Ubuntu and Fedora/RHEL.

---

## TL;DR

```bash
cd ~/backups                                    # output goes OUTSIDE the source

# 0. DRY RUN: size, space, file count (writes nothing)
du -sh ~/Documents && df -h .
tar -C ~ -cvf /dev/null Documents | wc -l

# 1. ARCHIVE: tar (metadata) → zstd (compress) → gpg (AES-256)
tar --xattrs --acls --numeric-owner --sparse -C ~ -cf - Documents \
  | zstd -T0 -19 \
  | gpg --symmetric --cipher-algo AES256 \
        --s2k-digest-algo SHA512 --s2k-count 65011712 \
        --compress-algo none -o docs.tar.zst.gpg

# 2. FINGERPRINT
sha256sum docs.tar.zst.gpg > docs.tar.zst.gpg.sha256

# 3. VERIFY: checksum, then decrypt + decompress + read the whole tar
sha256sum -c docs.tar.zst.gpg.sha256
( set -o pipefail; gpg -d docs.tar.zst.gpg | zstd -dc | tar -tf - > /dev/null ) && echo VERIFIED

# 4. RESTORE: into a staging folder first, never over live data
mkdir -p ~/staging/out
( set -o pipefail; gpg -d docs.tar.zst.gpg | zstd -dc \
    | sudo tar --xattrs --acls --numeric-owner -xpf - -C ~/staging/out ) && echo RESTORED
```

| You want…                    | Change                                                          |
|------------------------------|-----------------------------------------------------------------|
| Much faster backups          | `zstd -T0 -3` instead of `-19`                                  |
| No passphrase to type (cron) | `gpg --encrypt --recipient YOUR_KEY` (see [public-key mode](#public-key-mode-no-passphrase-prompts)) |
| Split for USB / upload       | `split` the **encrypted** file (see [example 5](#example-5-split-into-parts)) |
| SELinux system               | add `--selinux` to **both** create and extract `tar` commands   |

> **Golden rules:** the source is never touched, output lives outside the source, plaintext never hits disk, and restores go to staging first.
> **Order matters:** compress **then** encrypt. Encrypted data looks random and can no longer be compressed.

---

## Table of Contents

- [Why this stack](#why-this-stack)
- [TAR + zstd + GPG vs TAR + 7z](#tar--zstd--gpg-vs-tar--7z)
- [Prerequisites](#prerequisites)
- [Step 0: Pre-flight and dry run](#step-0--pre-flight-and-dry-run)
- [Step 1: Archive](#step-1--archive)
- [Step 2: Checksum](#step-2--checksum)
- [Step 3: Verify (three levels)](#step-3--verify-three-levels)
- [Step 4: Restore safely](#step-4--restore-safely)
- [Public-key mode (no passphrase prompts)](#public-key-mode-no-passphrase-prompts)
- [Worked examples](#worked-examples)
- [Automation script](#automation-script)
- [Privacy and security notes](#privacy-and-security-notes)
- [What this does NOT preserve](#what-this-does-not-preserve)
- [Troubleshooting](#troubleshooting)
- [Cheat sheet](#cheat-sheet)

---

## Why this stack

| Layer   | Tool   | Job                              | Why                                                                    |
|---------|--------|----------------------------------|------------------------------------------------------------------------|
| Pack    | `tar`  | Preserve Linux metadata          | Permissions, owners, symlinks, hard links, devices, xattrs, ACLs, capabilities |
| Shrink  | `zstd` | Compress                         | Very fast, good ratio, multithreaded, built-in frame checksum          |
| Protect | `gpg`  | Encrypt + integrity-protect      | AES-256, passphrase- or key-based, tampering is detected on decrypt    |

zstd and gpg only see a byte stream, so **they cannot lose metadata**. Everything Linux-specific is captured by `tar` before the stream starts.

Streaming (`tar | zstd | gpg`) means:

- **Privacy:** no unencrypted `.tar` is ever written to disk.
- **Efficiency:** you only need free space for the final compressed, encrypted file.
- **Filenames are hidden:** the whole tar is inside the encrypted payload.

---

## TAR + zstd + GPG vs TAR + 7z

| Aspect                  | TAR + zstd + GPG                           | TAR + 7z (`-mhe=on`)                    |
|-------------------------|--------------------------------------------|------------------------------------------|
| Compression speed       | **Much faster**                            | Slow at `-mx=9`                          |
| Compression ratio       | Very good at `-19`                         | Slightly better (LZMA2)                  |
| Decompression speed     | **Very fast**                              | Medium                                   |
| Encryption              | AES-256 (GPG), passphrase or public key    | AES-256, passphrase only                 |
| Plaintext on disk       | **None** (streaming)                       | Intermediate `.tar` unless you manage it |
| Public-key encryption   | ✅ (good for unattended backups)           | ❌                                       |
| Tools to restore        | `gpg`, `zstd`, `tar` (all common)          | `7z`, `tar`                              |
| Linux metadata          | ✅ Full                                    | ✅ Full (via tar)                        |

Both are good. Choose this one when you want **speed + no plaintext on disk + optional key-based encryption**, and 7z when you want the **smallest possible file**.

---

## Prerequisites

```bash
# openSUSE Tumbleweed
sudo zypper refresh
sudo zypper install tar zstd gpg2 rsync       # gpg2 provides the `gpg` command

# Arch
sudo pacman -S tar zstd gnupg rsync

# Debian / Ubuntu
sudo apt install tar zstd gnupg rsync

# Fedora / RHEL
sudo dnf install tar zstd gnupg2 rsync
```

Verify:

```bash
tar --version | head -1
zstd --version
gpg --version | head -1
```

If `gpg` cannot show a password prompt (SSH sessions, minimal terminals), set this first:

```bash
export GPG_TTY=$(tty)
```

---

## Step 0: Pre-flight and dry run

```bash
du -sh ~/Documents                         # source size
df -h ~/backups                            # free space at destination
tar -C ~ -cvf /dev/null Documents | wc -l  # file count; writes nothing
tar -C ~ -cf /dev/null Documents           # stderr shows unreadable files
```

- **Free space:** the encrypted output is at most about the source size (already-compressed media barely shrinks). You do **not** need extra space for a tar.
- **Output location:** never inside the directory you are archiving.
- **System directories:** add `--one-file-system` to avoid `/proc`, `/sys` and other mounts.

---

## Step 1: Archive

```bash
tar --xattrs --acls --numeric-owner --sparse -C /path/to/parent -cf - -- dirname \
  | zstd -T0 -19 \
  | gpg --symmetric --cipher-algo AES256 \
        --s2k-digest-algo SHA512 --s2k-count 65011712 \
        --compress-algo none \
        -o dirname.tar.zst.gpg
```

You will be asked for a passphrase **twice** (set and confirm).

### Tar flags

| Flag                | Purpose                                                                  |
|---------------------|--------------------------------------------------------------------------|
| `--xattrs`          | Extended attributes, including file capabilities (`setcap`)              |
| `--acls`            | POSIX ACLs                                                               |
| `--selinux`         | SELinux contexts, only on SELinux systems (Fedora/RHEL). Skip on openSUSE |
| `--numeric-owner`   | Store UID/GID numerically (use it on extract too)                        |
| `--sparse`          | Efficiently store sparse files (VM images, databases)                    |
| `--one-file-system` | Do not cross mount points                                                |
| `--exclude=PATTERN` | Skip names, e.g. `--exclude='.cache'` (unanchored, matches at any depth) |
| `-C parent`         | Store relative paths, so restores land where you expect                  |

> `--preserve-permissions` (`-p`) only matters on **extraction**; creating an archive always records permissions.

### zstd levels

| Level        | Speed        | Ratio       | Use when                               |
|--------------|--------------|-------------|----------------------------------------|
| `-1` … `-3`  | Fastest      | Decent      | Frequent backups, big data             |
| `-9`         | Fast         | Good        | Balanced                               |
| `-19`        | Slow         | Very good   | Archival (recommended default here)    |
| `--ultra -22`| Very slow    | Best        | Rarely worth it; needs lots of RAM and adds `--long` complexity |

- `-T0` uses all CPU cores.
- Already-compressed data (video, JPEG, ZIPs) will not shrink much at any level. Use `-3`.
- For huge files with long-range repetition, `--long=27` can help. Decompression then also needs a window large enough (`27` is accepted by default).
- zstd writes a content checksum into each frame by default, so corruption is detected on decompress.

### gpg options explained

| Option                          | Meaning                                                                  |
|---------------------------------|--------------------------------------------------------------------------|
| `--symmetric`                   | Passphrase-based encryption (no keys needed)                             |
| `--cipher-algo AES256`          | AES-256 (explicit, even if it is already your default)                   |
| `--s2k-digest-algo SHA512`      | Hash for turning your passphrase into the key                            |
| `--s2k-count 65011712`          | Maximum key-derivation iterations. Slows brute-force guessing            |
| `--compress-algo none`          | Do not let gpg compress. zstd already did, and double compression wastes time |
| `-o file`                       | Output file. gpg will not silently overwrite an existing one             |

Never pass the passphrase on the command line (`--passphrase "…"`). It lands in shell history and the process list.

### tar exit codes inside a pipeline

| Code | Meaning                                  | Action                                                   |
|------|------------------------------------------|----------------------------------------------------------|
| `0`  | Success                                  | Continue                                                 |
| `1`  | Some files changed while being read      | Review. Normal on live data but those files may be inconsistent |
| `2`  | Fatal error                              | Discard the output and fix the cause                     |

To see each stage's status in bash, read `PIPESTATUS` immediately after the pipeline:

```bash
tar … | zstd … | gpg …
echo "${PIPESTATUS[@]}"        # e.g. "0 0 0"  (tar zstd gpg)
```

---

## Step 2: Checksum

```bash
sha256sum dirname.tar.zst.gpg > dirname.tar.zst.gpg.sha256
cat dirname.tar.zst.gpg.sha256
```

Run it in the same directory as the file so the checksum file stores a relative name. Keep the checksum file next to the archive.

---

## Step 3: Verify (three levels)

| Level | Command                                                      | Proves                                                                 |
|-------|--------------------------------------------------------------|------------------------------------------------------------------------|
| 1     | `sha256sum -c file.sha256`                                   | The file is bit-for-bit what was written                               |
| 2     | decrypt → `zstd -dc` → `tar -tf -`                           | Passphrase works; gpg integrity check, zstd checksum and tar structure all pass |
| 3     | restore to staging + `rsync -n` compare                      | The restored content **matches the original source**                   |

### Level 1 and 2

```bash
sha256sum -c dirname.tar.zst.gpg.sha256
# dirname.tar.zst.gpg: OK

( set -o pipefail; gpg -d dirname.tar.zst.gpg | zstd -dc | tar -tf - > /dev/null ) \
  && echo "VERIFIED" || echo "FAILED, do not trust this archive"
```

Level 2 reads the whole stream, because tar cannot skip data on a pipe. `set -o pipefail` makes the group fail if **any** stage fails (a wrong passphrase, a corrupt file, a bad tar).

### Level 3 (do this at least once per important backup)

```bash
mkdir -p ~/staging/out
( set -o pipefail; gpg -d dirname.tar.zst.gpg | zstd -dc \
    | tar --xattrs --acls --numeric-owner -xpf - -C ~/staging/out )

# Dry run comparison; empty output = identical
rsync -aAXHnic --delete ~/Documents/ ~/staging/out/Documents/
```

Keep the trailing slashes exactly as shown. A backup you have never restored is a hope, not a backup.

---

## Step 4: Restore safely

**Never extract straight over live data.** Restore to staging, check, then copy.

### Full restore

```bash
mkdir -p ~/staging/out
( set -o pipefail; gpg -d dirname.tar.zst.gpg | zstd -dc \
    | sudo tar --xattrs --acls --numeric-owner -xpf - -C ~/staging/out ) \
  && echo "Restore OK" || echo "RESTORE FAILED, do not use ~/staging/out"
```

- Use `sudo` on **tar only** to restore ownership, capabilities and security xattrs. Run `gpg` as your normal user.
- As a normal user, tar skips ownership, which is fine for personal files.
- Add `--selinux` on SELinux systems.
- GPG verifies its integrity tag only **at the end of the stream**, so some data reaches tar before a problem is detected. That is why you extract to staging and check the final status, and never into the live location.

### Copy into place (dry run first)

```bash
rsync -aAXHn --info=stats1 ~/staging/out/Documents/ ~/Documents-restored/    # preview
rsync -aAXH  --info=progress2 ~/staging/out/Documents/ ~/Documents-restored/ # real copy
```

Restore to a **new** location first, inspect, and only then swap.

### List contents or restore one file

```bash
gpg -d dirname.tar.zst.gpg | zstd -dc | tar -tf - | less        # list

( set -o pipefail; gpg -d dirname.tar.zst.gpg | zstd -dc \
    | tar --xattrs --acls -xpf - -C ~/staging/out 'Documents/important.txt' )
```

The whole stream still has to be decrypted and decompressed to find one file. That is inherent to a single compressed tar.

---

## Public-key mode (no passphrase prompts)

Use this for unattended or scheduled backups. You encrypt to a **public key**, so no passphrase is needed at backup time. Only the **private key** can decrypt.

```bash
# One-time: create a key (choose a strong passphrase for the private key)
gpg --full-generate-key

# Back up the PRIVATE key and store it offline. Without it, archives are unrecoverable.
gpg --export-secret-keys --armor YOUR_KEY_ID > private-key-BACKUP.asc
chmod 600 private-key-BACKUP.asc

# Archive
tar --xattrs --acls --numeric-owner --sparse -C ~ -cf - Documents \
  | zstd -T0 -19 \
  | gpg --encrypt --recipient YOUR_KEY_ID --compress-algo none -o docs.tar.zst.gpg

# Restore (asks for the private key's passphrase)
gpg -d docs.tar.zst.gpg | zstd -dc | tar -tf - > /dev/null
```

Notes:

- If gpg complains the key is not trusted, mark **your own** key as trusted: `gpg --edit-key YOUR_KEY_ID`, then `trust`, then `5`, then `quit`.
- Do not keep the only copy of the private key on the machine being backed up.
- Anyone with the private key **and** its passphrase can decrypt everything, so protect both.

---

## Worked examples

### Example 1: Home directory, encrypted

```bash
mkdir -p /mnt/backup/home && cd /mnt/backup/home      # output on another disk

du -sh "$HOME" && df -h .
tar -C /home --one-file-system --exclude='.cache' --exclude='.local/share/Trash' \
    -cvf /dev/null "$USER" | wc -l                    # dry run

OUT="${USER}_$(date +%F).tar.zst.gpg"
tar --xattrs --acls --numeric-owner --sparse --one-file-system \
    --exclude='.cache' --exclude='.local/share/Trash' \
    -C /home -cf - -- "$USER" \
  | zstd -T0 -19 \
  | gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 \
        --s2k-count 65011712 --compress-algo none -o "$OUT"

sha256sum "$OUT" > "$OUT.sha256"
sha256sum -c "$OUT.sha256"
( set -o pipefail; gpg -d "$OUT" | zstd -dc | tar -tf - > /dev/null ) && echo VERIFIED
```

### Example 2: Quick, fast backup of a project

```bash
tar --xattrs --acls --exclude='node_modules' --exclude='__pycache__' \
    -C ~/projects -cf - myproject \
  | zstd -T0 -3 \
  | gpg --symmetric --cipher-algo AES256 --compress-algo none -o myproject.tar.zst.gpg
```

### Example 3: `/etc` as root, preserving everything

Run **only tar** with `sudo`, so `gpg` keeps using your own keyring and prompt:

```bash
sudo -v                                               # cache sudo credentials first
sudo tar --xattrs --acls --numeric-owner --sparse -C / -cf - etc \
  | zstd -T0 -19 \
  | gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 \
        --s2k-count 65011712 --compress-algo none -o etc_backup.tar.zst.gpg
# On Fedora/RHEL also add --selinux to tar
```

Restore to staging and compare with `diff -r` or `rsync -n` **before** replacing anything under `/etc`.

### Example 4: Unattended backup with a public key

```bash
tar --xattrs --acls --numeric-owner --sparse -C ~ -cf - Documents \
  | zstd -T0 -9 \
  | gpg --encrypt --recipient YOUR_KEY_ID --compress-algo none \
        -o "docs_$(date +%F).tar.zst.gpg"
```

### Example 5: Split into parts

Split the **encrypted** file so parts leak nothing about their contents:

```bash
split -b 2G -d -a 3 docs.tar.zst.gpg docs.tar.zst.gpg.part-
# Produces docs.tar.zst.gpg.part-000, -001, ...

sha256sum docs.tar.zst.gpg > docs.tar.zst.gpg.sha256     # checksum of the WHOLE file
sha256sum docs.tar.zst.gpg.part-* > docs.parts.sha256    # checksums of each part
```

Rejoin and verify:

```bash
sha256sum -c docs.parts.sha256
cat docs.tar.zst.gpg.part-* > joined.tar.zst.gpg
# Compare against the original checksum (the filename in the file is the original name)
echo "$(cut -d' ' -f1 docs.tar.zst.gpg.sha256)  joined.tar.zst.gpg" | sha256sum -c
```

Keep **all** parts together. A missing part makes the rest useless.

---

## Automation script

Save as `~/bin/zstd-gpg-archive.sh`, then `chmod +x ~/bin/zstd-gpg-archive.sh`.

It supports a **dry run**, never touches the source, never overwrites existing output, writes no plaintext to disk, and verifies the result by decrypting and reading it through every layer.

```bash
#!/usr/bin/env bash
# zstd-gpg-archive.sh: TAR → zstd → GPG (AES-256), streamed, with verification
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: zstd-gpg-archive.sh [-n] [-l LEVEL] [-r KEY] [-s] [-o OUTDIR] SOURCE_DIR

  -n        dry run: show what would be archived, write nothing
  -l LEVEL  zstd level 1-19 (default 19; use 3 for speed)
  -r KEY    encrypt to a GPG public key (ID or email) instead of a passphrase
  -s        also store SELinux contexts (Fedora/RHEL; skip on openSUSE)
  -o DIR    output directory (must exist; default: current directory)

The source is never modified or deleted.
No unencrypted copy is ever written to disk.
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

DRYRUN=0; LEVEL=19; RECIP=""; SELINUX=0; OUTDIR="."
while getopts "nl:r:so:h" opt; do
  case "$opt" in
    n) DRYRUN=1 ;;
    l) LEVEL="$OPTARG" ;;
    r) RECIP="$OPTARG" ;;
    s) SELINUX=1 ;;
    o) OUTDIR="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -eq 1 ]] || { usage; exit 1; }
[[ "$LEVEL" =~ ^([1-9]|1[0-9])$ ]] || die "level must be 1-19"

for t in tar zstd gpg sha256sum; do
  command -v "$t" >/dev/null || die "$t not found"
done

SRC=$(realpath -- "$1")
[[ -d "$SRC" ]]     || die "not a directory: $1"
[[ "$SRC" != "/" ]] || die "refusing to archive /; choose a subdirectory"
[[ -d "$OUTDIR" ]]  || die "output directory does not exist: $OUTDIR"
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
ARC="${NAME}_${STAMP}.tar.zst.gpg"
[[ ! -e "$ARC" ]] || die "output already exists: $ARC"

if [[ -n "$RECIP" ]]; then
  GPG_ENC=(gpg --encrypt --recipient "$RECIP" --compress-algo none -o "$ARC")
else
  GPG_ENC=(gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512
           --s2k-count 65011712 --compress-algo none -o "$ARC")
fi

umask 077

# ── 1. Archive (streamed) ────────────────────────────────
echo "[1/4] tar | zstd -$LEVEL | gpg  →  $ARC"
set +e
tar "${TAR_OPTS[@]}" -C "$PARENT" -cf - -- "$NAME" | zstd -q -T0 "-$LEVEL" | "${GPG_ENC[@]}"
st=("${PIPESTATUS[@]}")
set -e
(( st[2] == 0 )) || die "gpg failed (exit ${st[2]}); a partial file may remain: $ARC"
(( st[1] == 0 )) || die "zstd failed (exit ${st[1]}); a partial file may remain: $ARC"
if (( st[0] == 1 )); then
  echo "WARNING: some files changed while being read (tar exit 1)" >&2
elif (( st[0] > 1 )); then
  die "tar failed (exit ${st[0]}); a partial file may remain: $ARC"
fi

# ── 2. Checksum ──────────────────────────────────────────
echo "[2/4] Writing checksum"
sha256sum -- "$ARC" > "$ARC.sha256"

# ── 3. Verify ────────────────────────────────────────────
echo "[3/4] Verifying checksum"
sha256sum -c -- "$ARC.sha256"

echo "[3/4] Verifying decrypt → zstd → tar (reads the whole archive)"
set +e
gpg --decrypt "$ARC" | zstd -dc -q | tar -tf - > /dev/null
vs=("${PIPESTATUS[@]}")
set -e
(( vs[0] == 0 && vs[1] == 0 && vs[2] == 0 )) \
  || die "verification FAILED (gpg=${vs[0]} zstd=${vs[1]} tar=${vs[2]}); do not trust $ARC"
echo "Verification OK"

# ── 4. Done ──────────────────────────────────────────────
echo "[4/4] Done"
ls -lh -- "$ARC" "$ARC.sha256"
echo
echo "Next: do a staging restore + 'rsync -aAXHnic --delete' at least once."
echo "Tip : 'gpgconf --kill gpg-agent' clears the cached passphrase."
```

Usage:

```bash
zstd-gpg-archive.sh -n ~/Documents                       # dry run first
zstd-gpg-archive.sh -o /mnt/backup ~/Documents           # passphrase mode, level 19
zstd-gpg-archive.sh -l 3 -o /mnt/backup ~/Videos         # fast
zstd-gpg-archive.sh -r YOUR_KEY_ID -o /mnt/backup ~/Documents   # public-key mode
```

---

## Privacy and security notes

- **Passphrase:** use a long passphrase (5+ random words) from a password manager. If you lose it, the data is gone. There is no recovery.
- **Agent cache:** gpg-agent caches the passphrase for a while after use. Clear it with `gpgconf --kill gpg-agent` when you finish on a shared machine.
- **No secrets on the command line:** never use `--passphrase` in a command. For unattended jobs use public-key mode.
- **What stays visible:** the archive's **file name**, its **size** and timestamps. Give it a neutral name and avoid names like `bank_statements_2026`. Contents and inner filenames are hidden.
- **Integrity vs authenticity:** the `.sha256` file catches accidental corruption. GPG's built-in integrity check catches modification of the encrypted data. A checksum stored next to the archive does not stop someone who can replace both files. If that matters, store the checksum somewhere separate.
- **Original files:** this workflow never deletes them. Remove sources manually only after a **successful staging restore and comparison**.
- **Deleting is not erasing:** on SSDs and copy-on-write filesystems (Btrfs), `rm` does not securely erase. Streaming avoids creating plaintext copies in the first place.
- **Alternative to GPG:** `age -p` is a simpler passphrase encryptor with a smaller attack surface, and it drops into the same pipeline in place of `gpg`. It is less universal, so restoring needs `age` installed.

---

## What this does NOT preserve

| Item                                      | Status                                                                  |
|-------------------------------------------|-------------------------------------------------------------------------|
| Modification time (mtime)                 | ✅ Preserved                                                             |
| Access / change time (atime, ctime)       | ❌ Not restored by any tool (`ctime` cannot be set on Linux)            |
| `chattr` flags (immutable, no-CoW, …)     | ❌ Not stored by tar. Record with `lsattr -R` if needed                 |
| Btrfs subvolumes, snapshots, reflinks     | ❌ Stored as plain files. Use `btrfs send/receive` for those            |
| Hard links, symlinks, devices, permissions| ✅ Preserved                                                             |
| Ownership                                 | ✅ Stored; restoring it needs root                                      |
| xattrs, ACLs, capabilities                | ✅ With `--xattrs --acls` on **both** create and extract                |
| Restoring onto FAT/exFAT/some network shares | ❌ Those filesystems cannot hold Unix permissions, owners or xattrs   |

> This archives **files**. It is not a bare-metal system image.

---

## Troubleshooting

### gpg cannot ask for a passphrase (`cannot open '/dev/tty'`, `Inappropriate ioctl`)
```bash
export GPG_TTY=$(tty)
```
On headless or SSH sessions, make sure a terminal pinentry such as `pinentry-curses` is installed and configured.

### `gpg: decryption failed: Bad session key` or `zstd: unsupported format`
Wrong passphrase, or the file is damaged. Check `sha256sum -c` first to tell them apart.

### `gpg: WARNING: message was not integrity protected` or `modification detected`
The data was changed or corrupted. Do **not** use that archive. If you restored from it, discard the staging directory.

### Verification says FAILED but the checksum is OK
Most likely a wrong passphrase, or a tar/zstd error that occurred while creating the archive. Check the stage statuses printed by the script. Recreate the archive.

### `zstd: Frame requires too much memory for decoding`
The archive was made with a very large window (`--long` or `--ultra`). Decompress with a matching `--long=NN` or raise `--memory=`.

### Compression eats all RAM
`--ultra -22` and very large `--long` windows need a lot of memory. Stay at `-19` or lower.

### `tar: file changed as we read it` (exit 1)
A live file was modified during the backup. Stop the service, snapshot the filesystem, or exclude that path.

### `--selinux` not recognized or no effect
Your system does not use SELinux (openSUSE uses AppArmor) or tar lacks support. Omit the flag.

### Permissions or ownership wrong after restore
- Run `tar` with `sudo` on extraction.
- Use `--numeric-owner` on both create and extract when UIDs differ between machines.
- Check the destination filesystem supports Unix permissions (`df -T path`).

### Lost track of which stage failed
```bash
tar … | zstd … | gpg …
echo "${PIPESTATUS[@]}"      # one exit code per stage
```

---

## Cheat sheet

```text
┌─ ARCHIVE (streamed, no plaintext on disk) ──────────────────────────────┐
│ tar --xattrs --acls --numeric-owner --sparse -C PARENT -cf - DIR \      │
│   | zstd -T0 -19 \                                                      │
│   | gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 \     │
│         --s2k-count 65011712 --compress-algo none -o X.tar.zst.gpg      │
│ sha256sum X.tar.zst.gpg > X.tar.zst.gpg.sha256                          │
├─ VERIFY ────────────────────────────────────────────────────────────────┤
│ sha256sum -c X.tar.zst.gpg.sha256                                       │
│ (set -o pipefail; gpg -d X.tar.zst.gpg | zstd -dc | tar -tf - >/dev/null)│
├─ RESTORE (staging first) ───────────────────────────────────────────────┤
│ (set -o pipefail; gpg -d X.tar.zst.gpg | zstd -dc \                     │
│    | sudo tar --xattrs --acls --numeric-owner -xpf - -C STAGING/out)    │
│ rsync -aAXHnic --delete ORIGINAL/ STAGING/out/DIR/   # empty = identical│
├─ SAFETY ────────────────────────────────────────────────────────────────┤
│ Output outside source • dry run first • compress THEN encrypt • restore │
│ to staging • never delete originals here • no passphrase on the CLI     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

*Part of the [Clean System Guide](README.md): real solutions from real problems.*
