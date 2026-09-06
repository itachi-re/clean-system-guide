# Deleting Files and Directories in Linux — The Complete Guide

> From `rm` to forensic-grade wiping. Every tool, every flag, every caveat — with real examples.

---

## Table of Contents

1. [The Problem With "Deleting" Files](#the-problem-with-deleting-files)
2. [Quick Reference — Tool Comparison](#quick-reference--tool-comparison)
3. [Basic Deletion — `rm` and `rmdir`](#basic-deletion--rm-and-rmdir)
4. [Secure Deletion — `shred`](#secure-deletion--shred)
5. [Secure Deletion — `srm` and `secure-delete` Suite](#secure-deletion--srm-and-the-secure-delete-suite)
6. [Secure Deletion — `wipe`](#secure-deletion--wipe)
7. [Nuclear Option — `dd`](#nuclear-option--dd)
8. [The Filesystem Reality Check](#the-filesystem-reality-check)
9. [SSD / NVMe — A Special Warning](#ssd--nvme--a-special-warning)
10. [Installation Across Distros](#installation-across-distros)
11. [Decision Tree — Which Tool to Use](#decision-tree--which-tool-to-use)
12. [Automation Script](#automation-script)
13. [Alternatives — Encryption as True Deletion](#alternatives--encryption-as-true-deletion)

---

## The Problem With "Deleting" Files

When you run `rm file.txt`, the OS does **not** erase the data. It does two things:

1. Removes the directory entry (the filename pointer).
2. Marks the inode and associated disk blocks as **free**.

The actual bytes remain on disk, intact, until new data happens to overwrite that space. Any forensic tool — `testdisk`, `photorec`, `foremost`, `scalpel` — can trivially recover them.

```
Before rm:               After rm:                  After new write:
┌────────────┐           ┌────────────┐              ┌────────────┐
│  filename  │──────┐    │  (gone)    │              │  (gone)    │
├────────────┤      │    ├────────────┤              ├────────────┤
│   inode    │◄─────┘    │  inode=    │              │  inode=    │
│  (meta)    │           │  (free)    │              │  (free)    │
├────────────┤           ├────────────┤              ├────────────┤
│  DATA      │           │  DATA      │◄─STILL HERE  │  NEW DATA  │◄─overwritten
│  BLOCKS    │           │  BLOCKS    │              │  BLOCKS    │
└────────────┘           └────────────┘              └────────────┘
```

**This guide** covers tools that actually overwrite the data before unlinking the file — and explains exactly when each approach works and when it doesn't.

---

## Quick Reference — Tool Comparison

| Tool | Package | HDD | SSD/NVMe | Btrfs/ZFS | Dirs | Free Space | RAM/Swap | Speed | Notes |
|------|---------|-----|----------|-----------|------|-----------|---------|-------|-------|
| `rm` | coreutils | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ⚡⚡⚡ | No overwrite, just unlinks |
| `shred` | coreutils | ✓ | ⚠ | ✗ | ✗ | ✗ | ✗ | ⚡⚡ | Built-in, no install needed |
| `srm` | secure-delete | ✓ | ⚠ | ✗ | ✓ | ✗ | ✗ | ⚡ | 38-pass Gutmann method |
| `sfill` | secure-delete | ✓ | ⚠ | ✗ | — | ✓ | ✗ | 🐢 | Wipes free space on a mount |
| `sswap` | secure-delete | ✓ | ⚠ | ✗ | — | ✗ | ✓ | 🐢 | Wipes swap partition |
| `sdmem` | secure-delete | — | — | — | — | ✗ | ✓ | ⚡ | Wipes RAM |
| `wipe` | wipe | ✓ | ⚠ | ✗ | ✓ | ✗ | ✗ | ⚡ | Magnetic media focused |
| `dd` | coreutils | ✓ | ⚠ | ✗ | — | ✓ | ✗ | 🐢 | Block-level, full device wipe |
| `nvme` | nvme-cli | ✗ | ✓ | ✓ | — | ✓ | ✗ | ⚡ | Proper SSD/NVMe erase |

> ⚠ = Tool runs but effectiveness not guaranteed due to wear leveling / CoW / journaling  
> ✗ = Not applicable or not effective  
> ✓ = Works as intended

---

## Basic Deletion — `rm` and `rmdir`

These are your daily drivers. They are **not** secure. Know what they do and use them accordingly.

### `rm` — Remove Files

```bash
# Delete a single file
rm file.txt

# Delete multiple files
rm file1.txt file2.txt file3.txt

# Interactive mode — asks before each deletion
rm -i file.txt

# Force delete — suppresses errors, no prompts
rm -f file.txt

# Recursive delete — removes directory and all contents
rm -r my_directory/

# Recursive + force — THE DANGEROUS ONE
rm -rf my_directory/

# Verbose — show what's being deleted
rm -rv my_directory/
```

**The cardinal rule:** `rm -rf /` or `rm -rf /*` will destroy your entire system. There is no undo. Modern `rm` implementations require `--no-preserve-root` to even attempt it, but don't test this.

### `rmdir` — Remove Directories

`rmdir` only removes **empty** directories. It will refuse to delete anything with files inside.

```bash
# Remove a single empty directory
rmdir empty_dir/

# Remove nested empty directories (parents too, if they become empty)
rmdir -p path/to/empty/nested/dir/
```

> For non-empty directories, use `rm -r`.

---

## Secure Deletion — `shred`

`shred` is part of GNU coreutils — **available everywhere, no install required**. It overwrites a file's data blocks multiple times before (optionally) unlinking it.

### How It Works

By default, `shred` does **3 passes**: random data, random data, random data. You can customize the number of passes. The final pass can optionally be zeros to mask that shredding occurred.

### Basic Usage

```bash
# Overwrite a file 3 times (default), but do NOT delete it
shred secret.txt

# Overwrite AND delete the file (-u = unlink after)
shred -u secret.txt

# Verbose output — shows progress per pass
shred -v secret.txt

# Specify number of passes (25 passes — overkill for most)
shred -n 25 secret.txt

# Add a final zero-pass to hide the shredding (-z)
shred -vuz secret.txt
```

The output of `shred -v` looks like:

```
shred: secret.txt: pass 1/4 (random)...
shred: secret.txt: pass 2/4 (random)...
shred: secret.txt: pass 3/4 (random)...
shred: secret.txt: pass 4/4 (000000)...
shred: secret.txt: removing
shred: secret.txt: renamed to 00000000
shred: secret.txt: renamed to 0000000
shred: secret.txt: renamed to 000000
shred: secret.txt: renamed to 00000
shred: secret.txt: renamed to 0000
shred: secret.txt: renamed to 000
shred: secret.txt: renamed to 00
shred: secret.txt: renamed to 0
shred: secret.txt: removed
```

Note: `shred -u` also renames the file progressively to zero-length names before unlinking, making filename recovery harder too.

### Shredding a Whole Device

`shred` can operate directly on block devices — useful for HDDs before disposal:

```bash
# Wipe an entire HDD (3 passes — WILL TAKE HOURS)
sudo shred -vz /dev/sdb

# Faster single pass (less secure but often sufficient)
sudo shred -n 1 -vz /dev/sdb
```

> **Warning:** This will destroy everything on the device. Triple-check your device path with `lsblk` first.

### `shred` All Options

| Flag | Description |
|------|-------------|
| `-n N` | Number of overwrite passes (default: 3) |
| `-u` | Unlink (delete) the file after overwriting |
| `-z` | Add a final zero pass to hide shredding |
| `-v` | Verbose — show progress |
| `-f` | Force write permissions if needed |
| `-x` | Don't round up file size to block boundary |
| `-s N` | Shred only N bytes |

### What `shred` Cannot Do

`shred` **does not handle directories**. To shred all files inside a directory:

```bash
# Shred all regular files recursively, then remove the directory
find /path/to/dir -type f -exec shred -vuz {} \;
rm -rf /path/to/dir
```

---

## Secure Deletion — `srm` and the `secure-delete` Suite

`secure-delete` is a package that provides four tools, each targeting a different part of the storage system. The underlying algorithm uses Peter Gutmann's method — cryptographically informed multi-pass overwriting with specific patterns designed to defeat magnetic force microscopy.

The four tools:

| Tool | Target |
|------|--------|
| `srm` | Files and directories |
| `sfill` | Free space on a mounted filesystem |
| `sswap` | Swap partition |
| `sdmem` | RAM (physical memory) |

### Default Behavior — 38 Passes

`srm` uses **38 passes** by default:
- 35 passes using Gutmann patterns (fixed bit patterns designed for magnetic recovery defeat)
- 2 passes with random data
- 1 final pass of zeros

This is thorough but slow. The `-l` flag reduces this.

### `srm` — Secure Remove

```bash
# Securely delete a single file (38-pass Gutmann)
srm secret.txt

# Delete a directory recursively
srm -r secret_folder/

# Faster — only 2 passes (0xff + random)
srm -l secret.txt

# Even faster — 1 random pass only
srm -ll secret.txt

# Verbose
srm -v secret.txt

# Include hidden dot-files when deleting directory contents
srm -d -r .hidden_dir/
```

### `sfill` — Free Space Wiper

`sfill` fills all available free space on a partition with secure data, then deletes the fill file. This ensures previously deleted files that `rm` left on disk are overwritten.

```bash
# Wipe free space on the partition containing /home
sfill /home

# Faster version
sfill -l /home

# Verbose
sfill -v /home
```

> This will temporarily consume all free space on the partition. Make sure you have enough slack or run it on a partition where temporary space exhaustion is acceptable.

### `sswap` — Swap Partition Wiper

Swap can contain fragments of sensitive data — decryption keys, passwords typed in a terminal, etc.

```bash
# Step 1: Find your swap partition
cat /proc/swaps
# or
swapon --show

# Step 2: Disable swap (REQUIRED before wiping)
sudo swapoff /dev/sda2

# Step 3: Wipe it
sudo sswap /dev/sda2

# Step 4: Re-enable
sudo swapon /dev/sda2
```

> **Do not skip step 2.** Running `sswap` on an active swap partition can crash your system.

### `sdmem` — RAM Wiper

Wipes data from physical memory. Useful when you're about to hand off or power-cycle a machine.

```bash
# Standard wipe
sdmem

# Fast — one random pass
sdmem -l

# Very fast — one zero pass
sdmem -ll
```

> `sdmem` cannot wipe the memory it is itself using, and modern hardware/OS combinations may cause RAM to be refreshed anyway. This is mostly useful for older hardware or high-paranoia scenarios.

---

## Secure Deletion — `wipe`

`wipe` is specifically designed for **magnetic media**. It uses Gutmann's 35-pass method and randomizes write order to defeat timing-based analysis. The man page explicitly notes it is unreliable on SSDs.

```bash
# Wipe a file
wipe secret.txt

# Wipe a directory recursively
wipe -r secret_folder/

# Wipe free space on a mountpoint
wipe -f /home

# Quick mode — fewer passes
wipe -q secret.txt

# Silent mode
wipe -s secret.txt
```

### `wipe` vs `shred` at a glance

| Aspect | `shred` | `wipe` |
|--------|---------|--------|
| Part of coreutils | ✓ (no install) | ✗ (needs install) |
| Default passes | 3 | 35 (Gutmann) |
| Directory support | ✗ (use `find`) | ✓ (`-r` flag) |
| Free space wipe | ✗ | ✓ (`-f`) |
| Crypto techniques | ✗ | ✓ |
| SSD effectiveness | ⚠ | ⚠ (explicitly warns) |

---

## Nuclear Option — `dd`

`dd` is a low-level block copier. It has no concept of files or filesystems — it operates on raw bytes. Used correctly, it's one of the most reliable ways to wipe entire devices or partitions.

### Wipe a Device with Zeros

```bash
# Wipe /dev/sdb completely with zeros (confirms to the drive: nothing here)
sudo dd if=/dev/zero of=/dev/sdb bs=4M status=progress
```

### Wipe with Random Data

Random data is harder to analyze than zeros. `/dev/urandom` is non-blocking and fast enough for wiping:

```bash
# Single random pass — suitable for most threat models
sudo dd if=/dev/urandom of=/dev/sdb bs=4M status=progress
```

For maximum paranoia, alternate random passes and zero passes:

```bash
# 3-pass wipe: random → zeros → random
sudo dd if=/dev/urandom of=/dev/sdb bs=4M status=progress
sudo dd if=/dev/zero    of=/dev/sdb bs=4M status=progress
sudo dd if=/dev/urandom of=/dev/sdb bs=4M status=progress
```

### Simulate sfill with `dd` (No Package Required)

If `sfill` is unavailable but you want to wipe free space on a mounted partition:

```bash
# Fill free space with zeros
dd if=/dev/zero of=/mnt/target/freespace_fill bs=1M status=progress
sync

# Delete the fill file
rm /mnt/target/freespace_fill
sync
```

The `sync` calls force buffers to flush, ensuring data hits the disk.

### `dd` Flags

| Flag | Meaning |
|------|---------|
| `if=` | Input file (source) |
| `of=` | Output file (destination) |
| `bs=` | Block size — larger = faster (4M–64M is common) |
| `status=progress` | Show transfer speed and progress |
| `conv=fdatasync` | Sync after write (ensures physical write) |

---

## The Filesystem Reality Check

This is the most important section of this guide. **Secure deletion tools lie to you on modern filesystems.** Here's why:

### Journaling Filesystems (ext4, XFS)

Journaling filesystems write a transaction log (the journal) before committing changes to disk. In `data=journal` mode, actual file **data** goes through the journal — meaning your "securely overwritten" data may still exist in the journal.

| ext4 journal mode | `shred` effective? |
|-------------------|--------------------|
| `data=writeback` | ✓ Yes |
| `data=ordered` (default) | ✓ Yes |
| `data=journal` | ✗ No — data logged in journal |

Check your current mode:

```bash
# For the root filesystem
tune2fs -l /dev/sda1 | grep "Default mount options"

# Or check /proc/mounts
grep ext4 /proc/mounts
```

openSUSE Tumbleweed defaults to `data=ordered` for ext4, so `shred` works in the standard case.

### Copy-on-Write Filesystems — Btrfs (openSUSE Default)

**Btrfs is openSUSE Tumbleweed's default filesystem.** This is critical. Btrfs never overwrites data in place — instead it writes new data to a new location and updates the metadata to point there. The old block is then marked free.

This means:

- `shred` opens the file, writes new data → Btrfs writes it **elsewhere**
- The original data blocks are untouched, just marked as free
- They remain recoverable until the space is reused

```
Btrfs on shred attempt:

[DATA OLD] ← shred writes "new" data → [DATA NEW] written to different block
              Btrfs redirects pointer   [DATA OLD] ← still physically here
```

**On Btrfs, file-level secure deletion tools do not work.** Your options are:

1. **Full-device encryption** (LUKS) — the only reliable answer (see [Encryption section](#alternatives--encryption-as-true-deletion))
2. **Device-level wipe** — `dd` or `shred /dev/sdX` on the entire block device before disposal
3. **`nvme secure-erase`** — for NVMe drives (see next section)

To verify you're on Btrfs:

```bash
df -T /
# or
findmnt /
```

### Snapshots (Btrfs / ZFS)

Even if you overwrite data at the file level, snapshots preserve the original. On openSUSE Tumbleweed with snapper, snapshots are created on every zypper transaction.

```bash
# List your snapper snapshots
snapper list

# Delete a specific snapshot (this does NOT guarantee data is gone — CoW still applies)
sudo snapper delete 42
```

Deleting snapshots removes the references, but the actual CoW blocks are only freed when the filesystem reclaims them. It is **not** a secure deletion method.

---

## SSD / NVMe — A Special Warning

Traditional secure deletion is designed around magnetic HDDs, where data is written to a fixed physical location. SSDs and NVMe drives are fundamentally different:

**Wear Leveling:** The SSD firmware distributes writes across all cells to extend lifespan. When `shred` writes to logical block 0x4000, the firmware may store it at physical cell C7 while the original data at the logical address actually lived at physical cell A2 — which was never touched.

**Over-Provisioning:** SSDs reserve 7-28% of their NAND as unaddressable space used for wear leveling. Data can be cached in this region and is inaccessible through standard OS commands.

This means `shred`, `wipe`, and `srm` on SSDs give you **false security**.

### The Right Way to Wipe an NVMe Drive

Use the drive's own secure erase command via `nvme-cli`:

```bash
# Install nvme-cli
# openSUSE Tumbleweed:
sudo zypper install nvme-cli

# Check if your drive supports secure format
nvme id-ctrl /dev/nvme0 | grep fna

# Perform a cryptographic erase (fastest — key rotation, data becomes gibberish)
sudo nvme format /dev/nvme0 --ses=2

# Perform a user data erase (overwrites all user data)
sudo nvme format /dev/nvme0 --ses=1
```

| `--ses` value | Meaning |
|---------------|---------|
| `0` | No secure erase (default format only) |
| `1` | User data erase — overwrites all user data |
| `2` | Cryptographic erase — erases encryption key (instant, most effective if drive supports it) |

### For SATA SSDs

Use `hdparm` with ATA Secure Erase:

```bash
# Check if drive supports secure erase
sudo hdparm -I /dev/sda | grep -i erase

# Set a temporary security password (required before erase)
sudo hdparm --user-master u --security-set-pass temppass /dev/sda

# Issue the secure erase command
sudo hdparm --user-master u --security-erase temppass /dev/sda
```

> The drive must not be frozen. If it reports `frozen`, power-cycle the machine and try immediately after boot before the drive freezes again.

---

## Installation Across Distros

### openSUSE Tumbleweed (Primary Focus)

```bash
# secure-delete (srm, sfill, sswap, sdmem)
sudo zypper install secure-delete

# wipe
sudo zypper install wipe

# nvme-cli (for SSD/NVMe)
sudo zypper install nvme-cli

# shred — already installed (part of coreutils)
which shred   # should output /usr/bin/shred

# dd — already installed (part of coreutils)
which dd
```

Search if you're unsure of the exact package name:

```bash
zypper search secure-delete
zypper search wipe
```

### Arch Linux

```bash
# secure-delete
sudo pacman -S secure-delete

# wipe
sudo pacman -S wipe

# nvme-cli
sudo pacman -S nvme-cli

# shred and dd — part of coreutils (always installed)
```

Or from AUR for less common tools:

```bash
yay -S secure-delete
```

### Debian / Ubuntu

```bash
# secure-delete (provides srm, sfill, sswap, sdmem)
sudo apt install secure-delete

# wipe
sudo apt install wipe

# nvme-cli
sudo apt install nvme-cli

# shred and dd — part of coreutils
```

### Red Hat / Fedora / CentOS Stream

```bash
# secure-delete
sudo dnf install secure-delete

# wipe
sudo dnf install wipe

# nvme-cli
sudo dnf install nvme-cli

# shred and dd — coreutils
```

On older RHEL/CentOS 7 where `secure-delete` might not be in repos:

```bash
# Enable EPEL first
sudo dnf install epel-release
sudo dnf install secure-delete
```

---

## Decision Tree — Which Tool to Use

```
What are you trying to delete?
│
├── A file or directory
│   │
│   ├── I just want it gone (no adversary, no forensics concern)
│   │   └── rm -rf target/
│   │
│   ├── I want it somewhat secure (casual privacy)
│   │   ├── HDD → shred -vuz file.txt
│   │   └── SSD/NVMe → use LUKS (file-level tools don't work reliably)
│   │
│   └── I want serious security
│       ├── HDD, ext4 (data=ordered/writeback)
│       │   └── srm -v file.txt  (38-pass Gutmann)
│       ├── HDD, Btrfs → not possible at file level → wipe whole device
│       └── SSD/NVMe → nvme format --ses=2  or  hdparm secure-erase
│
├── Free space on a partition (recover previously rm'd files)
│   ├── HDD / ext4 → sfill /mountpoint/
│   ├── No package available → dd if=/dev/zero of=fill; sync; rm fill
│   └── SSD/NVMe → pointless; use full-device erase
│
├── Swap partition
│   └── swapoff /dev/sdX2 → sswap /dev/sdX2 → swapon /dev/sdX2
│
├── Entire drive (disposal / resale)
│   ├── HDD → shred -vz /dev/sdX  OR  dd if=/dev/urandom of=/dev/sdX
│   ├── NVMe → nvme format /dev/nvme0 --ses=2
│   └── SATA SSD → hdparm --security-erase
│
└── RAM contents (high-paranoia handoff)
    └── sdmem -v
```

---

## Automation Script

A reusable shell script for secure deletion with auto-detection of file/directory/device:

```bash
#!/usr/bin/env bash
# secure-rm.sh — Wrapper for secure deletion with sanity checks
# Usage: ./secure-rm.sh [-n passes] [-f] target

set -euo pipefail

PASSES=3
FORCE=false
TARGET=""

usage() {
    echo "Usage: $0 [-n passes] [-f] <file|directory|device>"
    echo "  -n N    Number of overwrite passes (default: 3)"
    echo "  -f      Force — skip confirmation prompts"
    exit 1
}

while getopts "n:fh" opt; do
    case "$opt" in
        n) PASSES="$OPTARG" ;;
        f) FORCE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

[[ -z "${1:-}" ]] && usage
TARGET="$1"

confirm() {
    if [[ "$FORCE" == false ]]; then
        read -rp "Are you sure you want to securely delete '$TARGET'? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
    fi
}

if [[ ! -e "$TARGET" && ! -b "$TARGET" ]]; then
    echo "Error: '$TARGET' does not exist."
    exit 1
fi

# Detect filesystem type for the target
FS_TYPE=$(df --output=fstype "$TARGET" 2>/dev/null | tail -1)

# Warn if Btrfs
if [[ "$FS_TYPE" == "btrfs" ]]; then
    echo "⚠  WARNING: '$TARGET' is on a Btrfs filesystem."
    echo "   File-level overwriting is NOT effective on Btrfs (copy-on-write)."
    echo "   For true secure deletion on Btrfs, use full-device encryption (LUKS)."
    echo "   Proceeding anyway (will overwrite the current copy only)..."
    echo ""
fi

confirm

# Handle block device
if [[ -b "$TARGET" ]]; then
    echo "→ Block device detected. Wiping with dd ($PASSES passes)..."
    for i in $(seq 1 "$PASSES"); do
        echo "  Pass $i/$PASSES (random)..."
        sudo dd if=/dev/urandom of="$TARGET" bs=4M status=progress conv=fdatasync
    done
    echo "  Final pass (zeros)..."
    sudo dd if=/dev/zero of="$TARGET" bs=4M status=progress conv=fdatasync
    echo "✓ Device wiped."
    exit 0
fi

# Handle directory
if [[ -d "$TARGET" ]]; then
    echo "→ Directory detected."
    if command -v srm &>/dev/null; then
        echo "  Using srm (Gutmann method)..."
        srm -rfv "$TARGET"
    else
        echo "  srm not found. Using shred + rm..."
        find "$TARGET" -type f -exec shred -n "$PASSES" -vuz {} \;
        rm -rf "$TARGET"
    fi
    echo "✓ Directory deleted."
    exit 0
fi

# Handle regular file
if [[ -f "$TARGET" ]]; then
    echo "→ File detected."
    if command -v srm &>/dev/null; then
        echo "  Using srm (Gutmann method)..."
        srm -v "$TARGET"
    else
        echo "  srm not found. Using shred..."
        shred -n "$PASSES" -vuz "$TARGET"
    fi
    echo "✓ File deleted."
    exit 0
fi

echo "Error: '$TARGET' is not a regular file, directory, or block device."
exit 1
```

Save it, make executable:

```bash
chmod +x secure-rm.sh

# Examples:
./secure-rm.sh secret.txt
./secure-rm.sh -n 7 sensitive_folder/
./secure-rm.sh -f /dev/sdb   # Block device, no prompt
```

---

## Alternatives — Encryption as True Deletion

On modern filesystems (especially Btrfs — the openSUSE default), file-level overwriting is unreliable. The most robust solution is **full disk encryption with LUKS**. When you encrypt a drive:

- All data is stored encrypted at rest
- "Deleting" becomes: erase the LUKS header and key slots
- The encrypted data becomes permanently unreadable in milliseconds

```bash
# Check if your drive is already LUKS-encrypted
sudo cryptsetup isLuks /dev/nvme0n1 && echo "LUKS" || echo "Not LUKS"

# If disposing of a LUKS-encrypted drive: wipe the header (fast, effective)
sudo cryptsetup erase /dev/nvme0n1

# Or manually zero the LUKS header (first 2MB covers all key slots)
sudo dd if=/dev/zero of=/dev/nvme0n1 bs=512 count=4096
```

Once the LUKS header is gone, the data is cryptographically unrecoverable — even if every byte of ciphertext remains on disk.

**Setup LUKS from scratch** (during install or on a secondary drive):

```bash
# Format a partition with LUKS2
sudo cryptsetup luksFormat --type luks2 /dev/sdb

# Open it
sudo cryptsetup open /dev/sdb my_secure_volume

# Format with a filesystem (Btrfs example)
sudo mkfs.btrfs /dev/mapper/my_secure_volume

# Mount and use normally
sudo mount /dev/mapper/my_secure_volume /mnt/secure
```

> On openSUSE Tumbleweed, the installer offers LUKS setup during installation. If security is a concern, enable it then — retrofitting encryption to an existing system is painful.

---

## Summary

- **For casual cleanup:** `rm -rf` is fine.
- **For HDD file-level wiping:** `shred -vuz` (built-in) or `srm -v` (more thorough).
- **For directory wiping on HDD:** `srm -rfv dir/` or `find + shred`.
- **For free-space sanitization:** `sfill /mountpoint` or `dd` fill trick.
- **For swap:** `swapoff → sswap → swapon`.
- **For SSD/NVMe:** `nvme format --ses=2` or `hdparm --security-erase`. File-level tools are ineffective.
- **For Btrfs (openSUSE default):** File-level tools do not reliably overwrite. Use LUKS encryption, then wipe the LUKS header on disposal.
- **For maximum security regardless of setup:** Full-disk encryption with LUKS. "Deleting" the key makes all data permanently unreadable.

The hierarchy, from weakest to strongest:

```
rm  <  shred  <  srm (Gutmann)  <  device wipe (dd/nvme)  <  LUKS header erase
```

---

**Status:** Active | **Last Updated:** May 2026

*"Deleted doesn't mean gone. Encrypted and key-wiped does."*
