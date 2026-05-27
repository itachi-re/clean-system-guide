# Linux Archiving & Compression Guide

> A comprehensive, battle-tested reference for ZIP, 7Z, TAR, and every archiving tool worth knowing on Linux — with a focus on **openSUSE Tumbleweed**, covering Arch, Debian, and Red Hat as well.

---

## Table of Contents

- [Philosophy](#philosophy)
- [Quick Reference — Format Comparison](#quick-reference--format-comparison)
- [Installation by Distribution](#installation-by-distribution)
  - [openSUSE Tumbleweed (Primary)](#opensuse-tumbleweed-primary)
  - [Arch Linux](#arch-linux)
  - [Debian / Ubuntu](#debian--ubuntu)
  - [Red Hat / Fedora / RHEL / CentOS Stream](#red-hat--fedora--rhel--centos-stream)
- [Format Deep Dives](#format-deep-dives)
  - [ZIP](#zip)
  - [7Z](#7z)
  - [RAR](#rar)
  - [tar.gz — Gzip](#targz--gzip)
  - [tar.bz2 — Bzip2](#tarbz2--bzip2)
  - [tar.xz — XZ / LZMA2](#tarxz--xz--lzma2)
  - [tar.zst — Zstandard](#tarzst--zstandard)
  - [tar.7z — TAR inside 7Z](#tar7z--tar-inside-7z)
- [Metadata Preservation Deep Dive](#metadata-preservation-deep-dive)
- [The Gold Standard Workflow — TAR + 7Z + SHA256](#the-gold-standard-workflow--tar--7z--sha256)
- [Practical Recipes](#practical-recipes)
- [Benchmarks & Efficiency](#benchmarks--efficiency)
- [Choosing the Right Format](#choosing-the-right-format)
- [Automation Scripts](#automation-scripts)
- [Troubleshooting](#troubleshooting)

---

## Philosophy

Most archiving guides hand you a one-liner and call it a day.  
This guide explains **why** each flag exists, **what metadata gets lost** when you pick the wrong tool, and **which format wins** for each scenario.

> "Know what you're compressing before you compress it."

---

## Quick Reference — Format Comparison

### Compression & Features Matrix

| Format    | Compression   | Speed      | Encryption              | Metadata on Linux | Open Source  | Best Use Case           |
|-----------|---------------|------------|-------------------------|-------------------|--------------|-------------------------|
| `zip`     | Medium        | Fast       | AES-256 (optional)      | Partial ⚠️         | Yes          | Universal cross-platform sharing |
| `7z`      | Excellent     | Medium     | AES-256 + header encrypt| Mediocre ⚠️        | Yes          | Encrypted archives, Windows compat |
| `rar`     | Very Good     | Medium     | AES-256                 | Partial ⚠️         | Partially    | Recovery records, legacy compat |
| `tar.gz`  | Medium        | Fast       | None built-in           | Excellent ✅       | Yes          | Linux packaging, quick archives |
| `tar.bz2` | Good          | Slow       | None built-in           | Excellent ✅       | Yes          | Slightly better than gz (legacy) |
| `tar.xz`  | Excellent     | Slow       | None built-in           | Excellent ✅       | Yes          | Linux distro packages, archival |
| `tar.zst` | Very Good     | **Fastest**| None built-in           | Excellent ✅       | Yes          | Modern backups, speed-critical |
| `tar.7z`  | **Best**      | Slow       | AES-256                 | Excellent ✅       | Yes          | Ultimate archival + encryption |

### Detailed Criteria Matrix

| Format    | Compression Ratio | Compression Speed | Decompression Speed | Encryption      | Symlinks | Permissions | xattrs | ACLs | SELinux |
|-----------|:-----------------:|:-----------------:|:-------------------:|:---------------:|:--------:|:-----------:|:------:|:----:|:-------:|
| `zip`     | ⭐⭐⭐           | ⭐⭐⭐⭐⭐        | ⭐⭐⭐⭐⭐          | ✅ AES-256      | ⚠️ Partial| ⚠️ Partial | ❌     | ❌   | ❌      |
| `7z`      | ⭐⭐⭐⭐⭐        | ⭐⭐⭐            | ⭐⭐⭐              | ✅ AES-256+hdr  | ⚠️ Partial| ⚠️ Partial | ❌     | ❌   | ❌      |
| `rar`     | ⭐⭐⭐⭐          | ⭐⭐⭐            | ⭐⭐⭐⭐            | ✅ AES-256      | ⚠️ Partial| ⚠️ Partial | ❌     | ❌   | ❌      |
| `tar.gz`  | ⭐⭐⭐           | ⭐⭐⭐⭐⭐        | ⭐⭐⭐⭐⭐          | ❌ None         | ✅        | ✅          | ✅     | ✅   | ✅      |
| `tar.bz2` | ⭐⭐⭐⭐          | ⭐⭐             | ⭐⭐               | ❌ None         | ✅        | ✅          | ✅     | ✅   | ✅      |
| `tar.xz`  | ⭐⭐⭐⭐⭐        | ⭐⭐             | ⭐⭐⭐              | ❌ None         | ✅        | ✅          | ✅     | ✅   | ✅      |
| `tar.zst` | ⭐⭐⭐⭐          | ⭐⭐⭐⭐⭐        | ⭐⭐⭐⭐⭐          | ❌ None         | ✅        | ✅          | ✅     | ✅   | ✅      |
| `tar.7z`  | ⭐⭐⭐⭐⭐        | ⭐⭐             | ⭐⭐⭐              | ✅ AES-256+hdr  | ✅        | ✅          | ✅     | ✅   | ✅      |

> **Key insight:** Non-TAR formats (zip, 7z, rar) were designed on/for Windows and carry no concept of Linux POSIX metadata natively. TAR was built for Unix from the ground up — it is the only format that natively preserves the full Linux metadata stack.

---

## Installation by Distribution

### openSUSE Tumbleweed (Primary)

openSUSE Tumbleweed ships with `tar`, `gzip`, `bzip2`, and `xz` out of the box. Install everything else:

```bash
# Refresh repos first (rolling release — always refresh before installing)
sudo zypper refresh

# Core tools (likely already installed)
sudo zypper install tar gzip bzip2 xz

# ZIP tools
sudo zypper install zip unzip

# 7-Zip (p7zip is the CLI; 7zip is the newer upstream port)
sudo zypper install 7zip
# or the legacy p7zip suite:
sudo zypper install p7zip p7zip-full

# Zstandard (zstd)
sudo zypper install zstd

# RAR (unrar is in the Packman repository — non-free)
# First enable Packman:
sudo zypper addrepo --refresh https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ Packman
sudo zypper refresh
sudo zypper install unrar

# rar (create RAR archives — also from Packman)
sudo zypper install rar

# pigz — parallel gzip (optional, much faster gzip)
sudo zypper install pigz

# pbzip2 — parallel bzip2 (optional)
sudo zypper install pbzip2

# lz4 — extremely fast compression
sudo zypper install lz4

# Verify installs
tar --version
7z i          # 7-Zip info
zstd --version
zip --version
unrar --version
```

> **openSUSE Tumbleweed note:** The newer `7zip` package (upstream `7-Zip 24.x`) replaces the older `p7zip`. Prefer `7zip` if available — the command is `7z` or `7zz` depending on version.

```bash
# Check which 7z binary you have:
which 7z 7zz 2>/dev/null
7z i | head -3
```

---

### Arch Linux

```bash
# Sync and update first
sudo pacman -Syu

# Core (installed by default in base)
sudo pacman -S tar gzip bzip2 xz

# ZIP
sudo pacman -S zip unzip

# 7-Zip
sudo pacman -S 7zip
# legacy p7zip:
sudo pacman -S p7zip

# Zstandard
sudo pacman -S zstd

# RAR (AUR — non-free)
# Using yay:
yay -S rar unrar
# or paru:
paru -S rar unrar

# Parallel compression tools
sudo pacman -S pigz pbzip2

# lz4
sudo pacman -S lz4
```

---

### Debian / Ubuntu

```bash
sudo apt update

# Core (installed by default)
sudo apt install tar gzip bzip2 xz-utils

# ZIP
sudo apt install zip unzip

# 7-Zip
sudo apt install 7zip           # Debian 12+ / Ubuntu 22.04+
# or legacy:
sudo apt install p7zip-full p7zip-rar

# Zstandard
sudo apt install zstd

# RAR
sudo apt install rar unrar      # non-free repo required on Debian
# On Debian, enable non-free first:
# Add "non-free" to /etc/apt/sources.list, then:
sudo apt update && sudo apt install rar unrar

# Parallel tools
sudo apt install pigz pbzip2

# lz4
sudo apt install lz4
```

---

### Red Hat / Fedora / RHEL / CentOS Stream

```bash
# Fedora
sudo dnf update

# Core
sudo dnf install tar gzip bzip2 xz

# ZIP
sudo dnf install zip unzip

# 7-Zip
sudo dnf install 7zip            # Fedora 39+
# or:
sudo dnf install p7zip p7zip-plugins

# Zstandard
sudo dnf install zstd

# RAR (RPM Fusion — non-free)
# Enable RPM Fusion first:
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install unrar

# RHEL / CentOS Stream — enable EPEL first:
sudo dnf install epel-release
sudo dnf install p7zip p7zip-plugins unrar

# Parallel tools
sudo dnf install pigz pbzip2

# lz4
sudo dnf install lz4
```

---

## Format Deep Dives

### ZIP

The universal format. Works everywhere — Windows, macOS, Linux, web servers. The lowest common denominator, but that's exactly its strength when sharing files with non-Linux users.

**Strengths:**
- Universally supported (no tools needed on Windows/macOS)
- Random access — extract single files without reading the whole archive
- Per-file compression (each file compressed independently)
- AES-256 encryption available (with compatible tools)

**Weaknesses:**
- No native support for Unix permissions, symlinks, xattrs, ACLs, or SELinux contexts
- Compression ratio is mediocre compared to xz or 7z
- Encrypted ZIP has compatibility quirks (older tools use weak ZipCrypto by default)

#### Basic ZIP commands

```bash
# Create a zip archive
zip archive.zip file1 file2 file3

# Create from a directory (recursive)
zip -r archive.zip directory/

# Create with maximum compression
zip -r -9 archive.zip directory/

# Create with AES-256 encryption (requires Info-ZIP 3.0+ or 7z)
zip -r -e archive.zip directory/           # prompts for password (ZipCrypto — weak)
7z a -tzip -mem=AES256 -p archive.zip directory/  # AES-256 via 7z — preferred

# List contents
zip -sf archive.zip          # short list
unzip -l archive.zip         # detailed list

# Extract
unzip archive.zip
unzip archive.zip -d /target/directory/

# Extract specific file
unzip archive.zip file.txt

# Test archive integrity
unzip -t archive.zip

# Update existing archive (add/replace files)
zip -u archive.zip newfile.txt

# Exclude files
zip -r archive.zip directory/ --exclude "*.log" --exclude ".git/*"
```

> **Warning:** Never use ZIP's built-in `-e` encryption for sensitive data. It uses ZipCrypto by default, which is cryptographically broken. Use `7z a -tzip -mem=AES256` instead if you need AES-256 in ZIP format.

---

### 7Z

The best standalone compression format by ratio. LZMA2 algorithm, AES-256 encryption with optional header/filename encryption.

**Strengths:**
- Best compression ratio of any standalone format (beats ZIP and RAR)
- AES-256 with `-mhe=on` encrypts filenames and archive headers — contents are invisible to an attacker without the password
- Solid archive mode (`-ms=on`) treats all files as one stream — better compression for many small files
- Open-source (LGPL)

**Weaknesses:**
- On Linux, 7z handles Linux metadata (permissions, symlinks, xattrs) poorly — it was designed for Windows
- Slower compression than gzip or zstd
- For Linux-specific metadata: always use TAR first, then 7z (see [Gold Standard Workflow](#the-gold-standard-workflow--tar--7z--sha256))

#### Basic 7z commands

```bash
# Create archive (default compression)
7z a archive.7z file1 file2 directory/

# Create with maximum compression
7z a -mx=9 archive.7z directory/

# Create with LZMA2 max compression + solid mode
7z a -t7z -m0=lzma2 -mx=9 -ms=on archive.7z directory/

# Create encrypted (password prompt)
7z a -t7z -m0=lzma2 -mx=9 -mhe=on -ms=on -p archive.7z directory/

# Create encrypted with specific password (avoid — leaves password in shell history)
7z a -p"yourpassword" archive.7z directory/

# List contents
7z l archive.7z

# Extract (preserves directory structure)
7z x archive.7z

# Extract to specific directory
7z x archive.7z -o/target/directory/

# Extract flat (no directory structure)
7z e archive.7z

# Test archive integrity
7z t archive.7z

# Test with password
7z t archive.7z -p

# Show archive info
7z i archive.7z 2>/dev/null | head -20
```

#### 7z options reference

| Option        | Meaning                                           |
|---------------|---------------------------------------------------|
| `-t7z`        | Use 7z container format                           |
| `-m0=lzma2`   | LZMA2 compression algorithm (best ratio)          |
| `-m0=bzip2`   | Bzip2 algorithm (faster, worse ratio)             |
| `-m0=deflate` | Deflate algorithm (ZIP-compatible speed)          |
| `-mx=1`       | Fastest compression (worst ratio)                 |
| `-mx=5`       | Balanced (default)                                |
| `-mx=9`       | Maximum compression (slowest)                     |
| `-mhe=on`     | Encrypt headers/filenames (requires `-p`)         |
| `-ms=on`      | Solid mode — one stream for all files             |
| `-ms=off`     | Non-solid — random access to individual files     |
| `-mmt=on`     | Enable multithreading                             |
| `-mmt=4`      | Use 4 threads                                     |
| `-p`          | Prompt for password interactively                 |
| `-v100m`      | Split archive into 100MB volumes                  |
| `-sdel`       | Delete source files after archiving               |

---

### RAR

Proprietary format from RARLab. The only reason to use RAR today is for **recovery records** — a feature no other format offers natively. RAR can embed redundant data so that a partially corrupted archive can still be repaired.

**Strengths:**
- Recovery records (`-rr`) — repair corrupted archives
- AES-256 encryption
- Better compression than ZIP
- Multi-volume splitting with recovery

**Weaknesses:**
- Proprietary (rar create tool is non-free)
- Worse compression than 7z or tar.xz
- Linux metadata support is incomplete

```bash
# Create RAR archive
rar a archive.rar file1 file2 directory/

# Create with maximum compression
rar a -m5 archive.rar directory/

# Create with recovery record (5% redundancy)
rar a -rr5 archive.rar directory/

# Create with encryption
rar a -p archive.rar directory/       # prompts for password

# Create encrypted with filename encryption
rar a -hp archive.rar directory/      # -hp encrypts filenames too

# Create multi-volume (100MB splits)
rar a -v100m archive.part1.rar directory/

# List contents
rar l archive.rar
unrar l archive.rar

# Extract
unrar x archive.rar                   # with full paths
unrar e archive.rar                   # flat extract

# Test integrity
unrar t archive.rar

# Repair corrupted archive (requires recovery record)
rar r archive.rar
```

> **openSUSE note:** `rar` (create) requires the Packman repo (non-free). `unrar` (extract only) is also in Packman. If you only need to extract `.rar` files, `unrar-free` (LGPL reimplementation) may be available but has limited support for newer RAR5 format.

---

### tar.gz — Gzip

The classic. Gzip (`tar.gz` / `.tgz`) has been the standard Linux distribution format for decades. Fast, well-supported everywhere, reasonable compression.

**Strengths:**
- Universally available — gzip is on every Unix/Linux system
- Fast compression and decompression
- Full Linux metadata preservation via TAR
- Streamable (no seeking required — good for pipes)

**Weaknesses:**
- Compression ratio is mediocre compared to xz or zst at high settings
- No built-in encryption
- No random access to individual files without extracting

```bash
# Create tar.gz
tar -czf archive.tar.gz directory/
tar -czf archive.tar.gz file1 file2 file3

# Create with full metadata preservation
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -czf archive.tar.gz \
  directory/

# Create with maximum gzip compression (-9)
tar -czf archive.tar.gz --use-compress-program="gzip -9" directory/

# Create using pigz (parallel gzip — much faster on multi-core)
tar -cf - directory/ | pigz -9 > archive.tar.gz
# or:
tar --use-compress-program="pigz -9" -cf archive.tar.gz directory/

# Verbose output (show files as they're added)
tar -czvf archive.tar.gz directory/

# List contents
tar -tzf archive.tar.gz
tar -tzvf archive.tar.gz    # verbose

# Extract
tar -xzf archive.tar.gz
tar -xzf archive.tar.gz -C /target/directory/

# Extract with metadata restoration
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -xzf archive.tar.gz

# Extract single file
tar -xzf archive.tar.gz path/to/specific/file.txt

# Test integrity
tar -tzf archive.tar.gz > /dev/null && echo "OK" || echo "CORRUPT"

# Append files to existing tar (not .gz — can't append to compressed)
tar -rf archive.tar newfile.txt
```

---

### tar.bz2 — Bzip2

Bzip2 offers slightly better compression than gzip at the cost of significantly slower speed. Mostly a legacy format now — `tar.xz` and `tar.zst` are better in almost every scenario.

```bash
# Create tar.bz2
tar -cjf archive.tar.bz2 directory/

# With metadata
tar --xattrs --acls --selinux --preserve-permissions -cjf archive.tar.bz2 directory/

# With parallel bzip2 (pbzip2)
tar -cf - directory/ | pbzip2 -9 > archive.tar.bz2

# Extract
tar -xjf archive.tar.bz2
tar -xjf archive.tar.bz2 -C /target/directory/

# List contents
tar -tjf archive.tar.bz2
```

> **Recommendation:** Avoid bzip2 for new archives. Use `tar.xz` if you want better-than-gzip compression, or `tar.zst` if you want better-than-gzip speed. Bzip2 has no advantages over either.

---

### tar.xz — XZ / LZMA2

The gold standard for Linux distribution packages. XZ uses the LZMA2 algorithm (same as 7z's default) and delivers excellent compression ratios — at the cost of significant time and RAM.

**Strengths:**
- Best compression ratio of the native TAR formats
- Full Linux metadata preservation
- Used by almost all major Linux distros for package distribution (`.deb`, `.rpm`, kernel tarballs)

**Weaknesses:**
- Very slow compression (2–10× slower than gzip)
- High memory usage during compression
- Slow decompression relative to zstd

```bash
# Create tar.xz
tar -cJf archive.tar.xz directory/

# With metadata preservation (recommended for archival)
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -cJf archive.tar.xz \
  directory/

# Control compression level (0=fastest, 9=best, default=6)
tar -cf - directory/ | xz -9 > archive.tar.xz
tar -cf - directory/ | xz -e -9 > archive.tar.xz  # -e = extra compression passes

# Multithreaded xz compression (xz 5.2+)
tar -cf - directory/ | xz -T 0 -9 > archive.tar.xz  # -T 0 = use all cores

# Extract
tar -xJf archive.tar.xz
tar -xJf archive.tar.xz -C /target/directory/

# With metadata restoration
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -xJf archive.tar.xz

# List contents
tar -tJf archive.tar.xz

# Decompress only (without extracting tar)
xz -d archive.tar.xz       # produces archive.tar
xz -dk archive.tar.xz      # -k keeps original
```

---

### tar.zst — Zstandard

The modern standard. Zstandard (zstd), developed by Meta/Facebook, achieves compression ratios competitive with bzip2 and xz at speeds that rival or beat gzip. This is now the preferred format in Arch Linux packages, the Linux kernel, and modern backup systems.

**Strengths:**
- Extremely fast — often 3–10× faster than xz for similar ratios
- Tunable across a wide range (level 1–19, ultra levels 20–22)
- Full Linux metadata preservation via TAR
- Multithreaded by default
- Decompression is blindingly fast

**Weaknesses:**
- Not universally pre-installed (but available everywhere now)
- No built-in encryption

```bash
# Create tar.zst
tar -cf archive.tar.zst --use-compress-program=zstd directory/
# or using the -a flag (auto-detect from extension):
tar -acf archive.tar.zst directory/

# With metadata preservation
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -acf archive.tar.zst \
  directory/

# Control compression level (1=fastest, 19=best ratio)
tar -cf - directory/ | zstd -19 > archive.tar.zst

# Ultra compression levels (20–22, slow but very good)
tar -cf - directory/ | zstd --ultra -22 > archive.tar.zst

# Multithreaded (use all cores)
tar -cf - directory/ | zstd -T0 -19 > archive.tar.zst

# Fast backup (level 3 — best speed/ratio balance)
tar -cf - directory/ | zstd -3 -T0 > archive.tar.zst

# Extract
tar -xf archive.tar.zst --use-compress-program=unzstd
# or auto-detect:
tar -axf archive.tar.zst
tar -axf archive.tar.zst -C /target/directory/

# With metadata restoration
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -axf archive.tar.zst

# List contents
tar -atf archive.tar.zst

# Compress file only (not tar)
zstd file.txt               # produces file.txt.zst
zstd -d file.txt.zst        # decompress

# Decompress only
zstd -d archive.tar.zst     # produces archive.tar
```

> **openSUSE Tumbleweed note:** zstd is the compression format used by Btrfs's built-in transparent compression (mount option `compress=zstd`). If you're on Btrfs with zstd compression, your `.tar.zst` files may see reduced benefit — the filesystem is already compressing them.

---

### tar.7z — TAR inside 7Z

The best of both worlds. TAR handles Linux metadata, 7Z handles compression and optional encryption. This is the **recommended format for long-term archival of Linux data** — especially when encryption is required.

See the full workflow in the [Gold Standard Workflow](#the-gold-standard-workflow--tar--7z--sha256) section.

```bash
# Quick create (no encryption)
tar \
  --xattrs --acls --selinux --preserve-permissions \
  -cf - directory/ | \
  7z a -t7z -m0=lzma2 -mx=9 -ms=on -si archive.tar.7z

# Create with AES-256 encryption
tar \
  --xattrs --acls --selinux --preserve-permissions \
  -cf - directory/ | \
  7z a -t7z -m0=lzma2 -mx=9 -mhe=on -ms=on -p -si archive.tar.7z

# Extract
7z x archive.tar.7z        # extracts archive.tar
tar \
  --xattrs --acls --selinux --preserve-permissions \
  -xvf archive.tar
```

---

## Metadata Preservation Deep Dive

This is where most archiving guides fail you. Understanding what metadata each format preserves is critical if you're archiving system directories, home directories, or any Linux filesystem.

### What Linux Metadata Exists

| Metadata Type     | Description                                     | Example                         |
|-------------------|-------------------------------------------------|---------------------------------|
| Permissions       | rwxr-xr-x mode bits                            | `chmod 755`                     |
| Ownership         | User ID (UID) and Group ID (GID)               | `chown user:group`              |
| Timestamps        | mtime, atime, ctime                             | `touch -t`                      |
| Symlinks          | Symbolic links to other files                   | `ln -s`                         |
| Hard links        | Multiple names for same inode                   | `ln`                            |
| Special files     | Block/char devices, FIFOs, sockets             | `/dev/sda`, named pipes         |
| xattrs            | Extended attributes                             | `setfattr`                      |
| ACLs              | POSIX access control lists                      | `setfacl`                       |
| SELinux contexts  | Security labels                                 | `chcon`                         |
| Capabilities      | Linux capabilities on executables               | `setcap`                        |

### Preservation by Format

| Format    | Perms | UID/GID | Timestamps | Symlinks | Hard Links | Devices | xattrs | ACLs | SELinux |
|-----------|:-----:|:-------:|:----------:|:--------:|:----------:|:-------:|:------:|:----:|:-------:|
| `zip`     | ⚠️    | ❌      | mtime only | ⚠️       | ❌         | ❌      | ❌     | ❌   | ❌      |
| `7z`      | ⚠️    | ❌      | mtime only | ⚠️       | ❌         | ❌      | ❌     | ❌   | ❌      |
| `rar`     | ⚠️    | ❌      | mtime only | ⚠️       | ❌         | ❌      | ❌     | ❌   | ❌      |
| `tar.*`   | ✅    | ✅      | ✅ all 3   | ✅       | ✅         | ✅      | ✅     | ✅   | ✅      |

> **Critical note on UID/GID:** TAR stores numeric UID/GID. When extracting on a different machine where UID 1000 maps to a different username, you may need `--numeric-owner` during creation and `--no-same-owner` during extraction (or map manually).

---

## The Gold Standard Workflow — TAR + 7Z + SHA256

This is the recommended workflow for archiving Linux data when you need:

- Full Linux metadata preservation
- Maximum compression
- AES-256 encryption (optional)
- Cryptographic integrity verification

It uses three tools in sequence:
- `tar` → preserves all Linux metadata into a portable container
- `7z` → applies LZMA2 compression + AES-256 encryption
- `sha256sum` → generates a checksum for integrity verification

---

### Step 1 — Create TAR Archive

```bash
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -cvf filename.tar \
  /path/to/directory/
```

#### What Each Flag Preserves

| Flag                    | What It Does                                        |
|-------------------------|-----------------------------------------------------|
| `--xattrs`              | Preserve extended attributes (`getfattr` values)    |
| `--acls`                | Preserve POSIX ACLs (`getfacl` values)              |
| `--selinux`             | Preserve SELinux security contexts                  |
| `--preserve-permissions`| Preserve all mode bits, UID, GID                    |
| `-c`                    | Create archive                                      |
| `-v`                    | Verbose — print each file as it's added             |
| `-f filename.tar`       | Output file name                                    |

**Additional useful TAR flags for archival:**

```bash
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  --numeric-owner \          # Store UID/GID as numbers, not names
  --sparse \                 # Handle sparse files efficiently
  --ignore-failed-read \     # Continue on unreadable files
  -cvf filename.tar \
  /path/to/directory/
```

| Flag                    | When to Use                                              |
|-------------------------|----------------------------------------------------------|
| `--numeric-owner`       | Archiving for transfer to a different system             |
| `--sparse`              | Directories with sparse files (databases, disk images)   |
| `--ignore-failed-read`  | Archiving live systems with locked files                 |
| `--exclude=PATTERN`     | Skip files matching pattern (`--exclude="*.log"`)        |
| `--one-file-system`     | Don't cross filesystem boundaries (skip /proc, /sys etc) |

**Example: Archive home directory safely**

```bash
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  --numeric-owner \
  --sparse \
  --one-file-system \
  --exclude="$HOME/.cache" \
  --exclude="$HOME/.local/share/Trash" \
  -cvf home_backup.tar \
  "$HOME/"
```

---

### Step 2 — Compress + Encrypt with 7z

```bash
7z a \
  -t7z \
  -m0=lzma2 \
  -mx=9 \
  -mhe=on \
  -ms=on \
  -p \
  filename.tar.7z \
  filename.tar
```

7z will securely prompt for a password interactively — it does **not** appear in shell history or process list.

#### Options Explained

| Option        | Meaning                                                             |
|---------------|---------------------------------------------------------------------|
| `a`           | Add to archive                                                      |
| `-t7z`        | Use 7z container format                                             |
| `-m0=lzma2`   | LZMA2 compression algorithm (best ratio, same as xz)               |
| `-mx=9`       | Maximum compression level                                           |
| `-mhe=on`     | Encrypt archive headers — filenames invisible without password      |
| `-ms=on`      | Solid archive mode — all files in one stream (better compression)   |
| `-p`          | Interactive password prompt (secure — not stored in history)        |
| `-mmt=on`     | Enable multithreading (add this for faster compression)             |

**Faster variant (balanced speed/ratio):**

```bash
7z a \
  -t7z \
  -m0=lzma2 \
  -mx=6 \
  -mhe=on \
  -ms=on \
  -mmt=on \
  -p \
  filename.tar.7z \
  filename.tar
```

**No encryption (compression only):**

```bash
7z a \
  -t7z \
  -m0=lzma2 \
  -mx=9 \
  -ms=on \
  -mmt=on \
  filename.tar.7z \
  filename.tar
```

---

### Step 3 — Generate SHA256 Checksum

```bash
sha256sum filename.tar.7z > filename.tar.7z.sha256
```

This creates a file like:

```text
a3f1c2d9e8b74f...  filename.tar.7z
```

**Also consider generating checksums for the intermediate TAR:**

```bash
sha256sum filename.tar > filename.tar.sha256
sha256sum filename.tar.7z > filename.tar.7z.sha256
```

This lets you verify the TAR is intact before and after the 7z step, and verify the final archive separately.

---

### Step 4 — Verify Checksum Later

```bash
sha256sum -c filename.tar.7z.sha256
```

Expected output:

```text
filename.tar.7z: OK
```

If the file is corrupted:

```text
filename.tar.7z: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
```

---

### Step 5 — Test Archive Integrity

```bash
7z t filename.tar.7z
```

This verifies:
- The password is correct (prompts if encrypted)
- No corruption in the compressed data
- Internal 7z checksums match

Expected output:

```text
Everything is Ok
```

---

### Step 6 — Extract the Archive

#### Extract the 7z archive

```bash
# Interactive password prompt
7z x filename.tar.7z

# Extract to specific directory
7z x filename.tar.7z -o/path/to/destination/
```

#### Extract the TAR archive with full metadata restoration

```bash
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  -xvf filename.tar
```

> **Note on permissions:** If you're extracting as root on a different machine, use `--numeric-owner` to restore original UID/GID. If extracting as a regular user, `--no-same-owner` prevents errors from trying to restore ownership you don't have permission to set.

```bash
# Restoring on same machine (same UID/GID mapping):
tar --xattrs --acls --selinux --preserve-permissions -xvf filename.tar

# Restoring on different machine or as different user:
tar --xattrs --acls --selinux --no-same-owner -xvf filename.tar
```

---

### Complete Workflow — One Reference Block

```bash
# ── ARCHIVE ──────────────────────────────────────────────
# 1. Create TAR (preserves all Linux metadata)
tar \
  --xattrs --acls --selinux --preserve-permissions \
  --numeric-owner --sparse \
  -cvf archive.tar \
  /path/to/source/

# 2. Compress + Encrypt with 7z (LZMA2 + AES-256)
7z a -t7z -m0=lzma2 -mx=9 -mhe=on -ms=on -mmt=on -p \
  archive.tar.7z archive.tar

# 3. Generate SHA256 checksums
sha256sum archive.tar     > archive.tar.sha256
sha256sum archive.tar.7z  > archive.tar.7z.sha256

# 4. Clean up intermediate TAR (optional — keep if space allows)
# rm archive.tar

# ── VERIFY ───────────────────────────────────────────────
# Test archive integrity
7z t archive.tar.7z

# Verify checksum
sha256sum -c archive.tar.7z.sha256

# ── RESTORE ──────────────────────────────────────────────
# Extract 7z
7z x archive.tar.7z -o/tmp/restore/

# Extract TAR with full metadata
tar \
  --xattrs --acls --selinux --preserve-permissions \
  -xvf /tmp/restore/archive.tar \
  -C /path/to/destination/
```

---

## Practical Recipes

### Backup with Zstandard (fast, no encryption)

```bash
# Fast backup — zstd level 3, multithreaded
tar \
  --xattrs --acls --selinux --preserve-permissions \
  --numeric-owner --sparse \
  -cf - /path/to/source/ | \
  zstd -3 -T0 > backup_$(date +%Y%m%d_%H%M%S).tar.zst

# Generate checksum
sha256sum backup_*.tar.zst > backup_$(date +%Y%m%d).sha256
```

### Archive Project for Cross-Platform Sharing

```bash
# ZIP — readable everywhere
zip -r project_v1.0.zip project/ \
  --exclude "*.pyc" \
  --exclude "__pycache__/*" \
  --exclude ".git/*" \
  --exclude "node_modules/*"
```

### Encrypted Backup of Sensitive Data

```bash
# TAR + 7Z + AES-256 — best for sensitive archives
tar --xattrs --acls --selinux --preserve-permissions \
  -cf sensitive.tar /path/to/sensitive/

7z a -t7z -m0=lzma2 -mx=9 -mhe=on -ms=on -p \
  sensitive.tar.7z sensitive.tar

sha256sum sensitive.tar.7z > sensitive.tar.7z.sha256
rm sensitive.tar    # remove unencrypted intermediate
```

### Split Large Archive into Volumes

```bash
# 7z with 1GB volume splits
7z a -t7z -mx=9 -mhe=on -p -v1g \
  large_backup.tar.7z large_backup.tar

# This creates: large_backup.tar.7z.001, .002, .003 ...

# Verify multi-volume archive
7z t large_backup.tar.7z.001

# Extract multi-volume (point to first volume)
7z x large_backup.tar.7z.001
```

### Compare Compression of Multiple Formats

```bash
#!/bin/bash
# Compress the same directory with multiple formats and compare

DIR="$1"
NAME="test_compression"

echo "=== Compression Comparison ==="
echo "Source: $DIR"
echo ""

# Original size
ORIG=$(du -sb "$DIR" | awk '{print $1}')
echo "Original size: $(du -sh "$DIR" | awk '{print $1}')"
echo ""

formats=(
  "tar.gz:tar --xattrs --acls -czf"
  "tar.xz:tar --xattrs --acls -cJf"
  "tar.zst:tar --xattrs --acls -acf"
)

for fmt in "${formats[@]}"; do
  name="${fmt%%:*}"
  cmd="${fmt##*:}"
  outfile="${NAME}.${name}"

  start=$(date +%s%N)
  $cmd "$outfile" "$DIR" 2>/dev/null
  end=$(date +%s%N)

  size=$(du -sh "$outfile" | awk '{print $1}')
  elapsed=$(( (end - start) / 1000000 ))

  echo "  $name: $size  (${elapsed}ms)"
  rm -f "$outfile"
done
```

### Exclude Common Junk When Archiving

```bash
tar \
  --xattrs --acls --selinux --preserve-permissions \
  --exclude=".git" \
  --exclude="*.pyc" \
  --exclude="__pycache__" \
  --exclude="node_modules" \
  --exclude=".cache" \
  --exclude="*.log" \
  --exclude="*.tmp" \
  --exclude=".DS_Store" \
  --exclude="Thumbs.db" \
  -czf clean_backup.tar.gz \
  /path/to/project/
```

---

## Benchmarks & Efficiency

Approximate relative performance on a typical multi-core system compressing a mixed-content directory (~1GB of code, configs, and documents). Results vary significantly by content type — already-compressed content (JPEG, MP4, PDF) compresses poorly with any algorithm.

### Compression Speed (relative, higher = faster)

```
tar.zst (level 3)   ████████████████████  ~500 MB/s
tar.gz              ██████████████        ~200 MB/s  
tar.bz2             ████                  ~50 MB/s
tar.xz              ███                   ~30 MB/s
tar.zst (level 19)  ████                  ~40 MB/s
7z (mx=9)           ██                    ~20 MB/s
tar.7z (mx=9)       ██                    ~18 MB/s
```

### Compression Ratio (smaller = better)

```
tar.7z  (mx=9)   ██                        ~28% of original
tar.xz           ████                      ~32% of original
7z      (mx=9)   ████                      ~30% of original
tar.zst (lv 19)  █████                     ~34% of original
tar.bz2          ██████                    ~38% of original
tar.zst (lv 3)   ████████                  ~42% of original
tar.gz           █████████                 ~48% of original
zip              █████████                 ~50% of original
```

### Decompression Speed (relative, higher = faster)

```
tar.zst     ████████████████████  ~1200 MB/s
tar.gz      ████████████          ~600 MB/s
tar.7z      ████████              ~400 MB/s
7z          ███████               ~350 MB/s
tar.xz      █████                 ~250 MB/s
tar.bz2     ████                  ~150 MB/s
```

> **Key takeaways:**
> - `tar.zst` wins on speed. Level 3 is the sweet spot for backups — nearly as fast as no compression but with ~50% size reduction.
> - `tar.xz` and `tar.7z` win on ratio. Use when archive size matters more than time.
> - `tar.gz` is the safe default — fast enough, good enough, supported everywhere.
> - `tar.bz2` has no compelling use case in 2025 — superseded by zstd in every way.

---

## Choosing the Right Format

```
What matters most?
│
├─ Cross-platform sharing (Windows/macOS users) ──────────► ZIP
│   └─ Need encryption? ─────────────────────────────────► ZIP with AES-256 via 7z
│
├─ Speed (backup, sync) ──────────────────────────────────► tar.zst (level 3–6)
│
├─ Compression ratio (storage cost matters) ─────────────► tar.xz or tar.7z
│
├─ Encryption required + Linux metadata ─────────────────► tar.7z (AES-256)
│
├─ Linux packages / distribution ────────────────────────► tar.xz (standard)
│
├─ Damaged archive recovery ─────────────────────────────► RAR (recovery records)
│
└─ General safe default ──────────────────────────────────► tar.gz
```

---

## Automation Scripts

### Universal Backup Script

Save as `~/bin/archive-backup.sh`:

```bash
#!/bin/bash
# archive-backup.sh — Create a verified, optionally encrypted backup
# Usage: ./archive-backup.sh <source_dir> [--encrypt]

set -euo pipefail

SOURCE="${1:?Usage: $0 <source_dir> [--encrypt]}"
ENCRYPT="${2:-}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASENAME=$(basename "$SOURCE")
TARFILE="${BASENAME}_${TIMESTAMP}.tar"
OUTFILE="${TARFILE}.zst"

# If encrypting, use 7z; otherwise use zstd
if [[ "$ENCRYPT" == "--encrypt" ]]; then
  OUTFILE="${TARFILE}.7z"
fi

echo "[1/4] Creating TAR archive: $TARFILE"
tar \
  --xattrs \
  --acls \
  --selinux \
  --preserve-permissions \
  --numeric-owner \
  --sparse \
  -cvf "$TARFILE" \
  "$SOURCE"

if [[ "$ENCRYPT" == "--encrypt" ]]; then
  echo "[2/4] Compressing + encrypting with 7z (LZMA2 + AES-256)..."
  7z a -t7z -m0=lzma2 -mx=9 -mhe=on -ms=on -mmt=on -p "$OUTFILE" "$TARFILE"
  rm "$TARFILE"
else
  echo "[2/4] Compressing with zstd..."
  zstd -T0 -9 "$TARFILE" -o "$OUTFILE"
  rm "$TARFILE"
fi

echo "[3/4] Generating SHA256 checksum..."
sha256sum "$OUTFILE" > "${OUTFILE}.sha256"

echo "[4/4] Verifying..."
if [[ "$ENCRYPT" == "--encrypt" ]]; then
  7z t "$OUTFILE"
else
  zstd -t "$OUTFILE"
fi
sha256sum -c "${OUTFILE}.sha256"

echo ""
echo "Done."
echo "  Archive:  $OUTFILE"
echo "  Checksum: ${OUTFILE}.sha256"
echo "  Size:     $(du -sh "$OUTFILE" | awk '{print $1}')"
```

```bash
chmod +x ~/bin/archive-backup.sh

# Usage — unencrypted
./archive-backup.sh ~/Documents

# Usage — encrypted
./archive-backup.sh ~/Documents --encrypt
```

### Batch Verify All Checksums in a Directory

```bash
#!/bin/bash
# verify-checksums.sh — Verify all .sha256 files in current directory

PASS=0
FAIL=0

for chk in *.sha256; do
  [[ -f "$chk" ]] || continue
  if sha256sum -c "$chk" 2>/dev/null; then
    ((PASS++))
  else
    echo "FAILED: $chk"
    ((FAIL++))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
```

---

## Troubleshooting

### `--selinux` flag not recognized

SELinux context preservation requires `tar` to be compiled with SELinux support. On openSUSE (which uses AppArmor, not SELinux by default), omit `--selinux`:

```bash
# openSUSE / AppArmor systems (no SELinux):
tar --xattrs --acls --preserve-permissions -cvf archive.tar directory/

# SELinux systems (Fedora, RHEL, CentOS):
tar --xattrs --acls --selinux --preserve-permissions -cvf archive.tar directory/
```

### `7z` command not found after installing `p7zip`

Some distributions install the binary as `7za` or `7zr`:

```bash
which 7z 7za 7zr 7zz 2>/dev/null
ls /usr/bin/7z* 2>/dev/null
```

On openSUSE Tumbleweed with the `7zip` package:

```bash
sudo zypper install 7zip
7z i     # should work
```

### `unrar` works but `rar` (create) is missing

`rar` (create) is a non-free binary. `unrar` is available as an open reimplementation. For creating RAR archives on openSUSE, you need the Packman repo:

```bash
sudo zypper addrepo --refresh \
  https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ Packman
sudo zypper refresh
sudo zypper install rar
```

### Permissions not restored on extraction

Ensure you're running `tar` with the correct restoration flags **and** have appropriate privileges:

```bash
# Must run as root (or with sudo) to restore ownership:
sudo tar --xattrs --acls --selinux --preserve-permissions -xvf archive.tar

# As regular user (drops ownership restoration):
tar --xattrs --acls --no-same-owner -xvf archive.tar
```

### SHA256 mismatch after transfer

Check if the file was transferred in text mode (common with FTP/SFTP clients that do line-ending conversion). Always use binary mode for archive transfers.

```bash
# Re-verify locally:
sha256sum archive.tar.7z

# Compare with stored checksum:
cat archive.tar.7z.sha256
```

### Archive seems corrupt — try 7z repair

```bash
# Test first
7z t archive.tar.7z

# If it fails and archive has recovery data (RAR):
rar r archive.rar
```

### `xattrs` not preserved after extraction

Some filesystems don't support extended attributes (FAT32, exFAT, some network mounts). Check:

```bash
# Check filesystem type of destination
df -T /destination/path/

# Check if xattrs are supported
touch /destination/test_file
setfattr -n user.test -v "hello" /destination/test_file 2>&1
```

---

## Summary

| Scenario                                       | Recommended Format | Key Flags                                          |
|------------------------------------------------|--------------------|----------------------------------------------------|
| Cross-platform sharing                         | `zip`              | `-r -9` or `7z a -tzip -mem=AES256`               |
| Fast Linux backup                              | `tar.zst`          | `--xattrs --acls`, `zstd -T0 -3`                  |
| Long-term archival (no encryption)             | `tar.xz`           | `--xattrs --acls`, `xz -9 -T0`                    |
| Long-term archival (with encryption)           | `tar.7z`           | `tar` + `7z -mhe=on -ms=on -p`                    |
| Linux package distribution                     | `tar.xz`           | `--xattrs --acls`                                  |
| Encrypted sensitive data                       | `tar.7z`           | `7z -m0=lzma2 -mx=9 -mhe=on -mmt=on -p`           |
| Archive with corruption recovery               | `rar`              | `rar a -rr5 -hp`                                   |
| General safe default                           | `tar.gz`           | `--xattrs --acls --preserve-permissions`           |

---

*Part of the [Clean System Guide](README.md) — real solutions from real problems.*
