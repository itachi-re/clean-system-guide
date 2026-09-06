# Linux Archive Extraction Guide

> A comprehensive, practical reference for `unzip`, `tar`, and `xz`/`unxz` on Linux — covering every common extraction case with real examples.

---

## Table of Contents

- [1. `unzip` — ZIP Archives](#1-unzip--zip-archives)
- [2. `tar` — Multi-Format Tape Archive](#2-tar--multi-format-tape-archive)
- [3. `xz` / `unxz` — XZ Compression](#3-xz--unxz--xz-compression)
- [4. Quick Reference Table](#4-quick-reference-table)
- [5. Recipes & Real-World Combinations](#5-recipes--real-world-combinations)

---

## 1. `unzip` — ZIP Archives

ZIP is a container format that stores both compressed data and metadata (timestamps, permissions, directory structure). The `unzip` utility handles `.zip` files exclusively.

> **Key behavior:** `unzip` **always keeps the original `.zip` file** after extraction. You must explicitly delete it if unwanted.

---

### 1.1 Basic Extraction

```bash
unzip archive.zip
```

Extracts all contents into the **current working directory**, recreating the directory tree stored inside the archive.

```
Archive:  archive.zip
  inflating: src/main.c
  inflating: src/utils.c
  inflating: README.md
```

---

### 1.2 Extract to a Different Directory

```bash
unzip archive.zip -d /path/to/destination/
```

The `-d` flag specifies the target directory. The directory will be **created automatically** if it does not exist.

```bash
# Extract into ~/projects/myapp/
unzip archive.zip -d ~/projects/myapp/

# Extract into a relative path
unzip archive.zip -d ./extracted/
```

---

### 1.3 Keep the Original Archive (Default)

No special flags needed — `unzip` never removes the source file.

```bash
unzip archive.zip
ls
# archive.zip  src/  README.md
```

---

### 1.4 Delete the Original Archive After Extraction

`unzip` has no built-in flag for this. Chain commands manually:

```bash
# Delete only on successful extraction
unzip archive.zip && rm archive.zip

# Extract to a specific dir, then delete
unzip archive.zip -d ~/output/ && rm archive.zip
```

Using `&&` ensures the archive is only deleted if extraction **succeeds** (exit code 0).

---

### 1.5 Preserve Directory Structure (Default)

By default, `unzip` **preserves** the full internal directory structure of the ZIP file.

```bash
unzip archive.zip
# Creates: src/lib/helpers.c, docs/api/index.html, etc.
```

---

### 1.6 Flatten / Junk the Directory Structure

Use `-j` to strip all path info and dump every file into the destination directory flat:

```bash
unzip -j archive.zip
# All files land in CWD regardless of their original paths
```

```bash
# Flatten into a specific directory
unzip -j archive.zip -d ~/flat-output/
```

> **Warning:** If two files share the same filename but live in different subdirectories, they will collide. `unzip` will prompt you unless `-o` or `-n` is also passed.

---

### 1.7 Overwrite Existing Files Without Prompting

```bash
unzip -o archive.zip
```

All existing files in the destination are silently overwritten.

---

### 1.8 Never Overwrite Existing Files

```bash
unzip -n archive.zip
```

Existing files are skipped entirely. Only new files are extracted.

---

### 1.9 List Archive Contents Without Extracting

```bash
# Short listing (filename, size, date)
unzip -l archive.zip

# Verbose listing (compression ratio, CRC, method)
unzip -v archive.zip
```

```
Archive:  archive.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
     1024  2024-03-15 10:22   src/main.c
      512  2024-03-14 09:15   README.md
---------                     -------
     1536                     2 files
```

---

### 1.10 Extract Specific Files

```bash
# Extract a single file
unzip archive.zip README.md

# Extract multiple specific files
unzip archive.zip src/main.c docs/index.html
```

---

### 1.11 Extract Files Matching a Pattern (Glob)

```bash
# Extract all .txt files
unzip archive.zip "*.txt"

# Extract all .c files (quote the glob to prevent shell expansion)
unzip archive.zip "src/*.c"
```

---

### 1.12 Exclude Files During Extraction

```bash
# Exclude a single file
unzip archive.zip -x README.md

# Exclude all .log files
unzip archive.zip -x "*.log"

# Exclude multiple files
unzip archive.zip -x "*.log" "*.tmp" "build/*"
```

---

### 1.13 Extract a Password-Protected ZIP

```bash
# Pass password on the command line (visible in process list)
unzip -P "mysecretpassword" protected.zip

# Prompt for password interactively (safer)
unzip protected.zip
# Enter password: _
```

---

### 1.14 Test Archive Integrity Without Extracting

```bash
unzip -t archive.zip
```

```
testing: src/main.c              OK
testing: README.md               OK
No errors detected in compressed data of archive.zip.
```

---

### 1.15 Quiet Mode (Suppress Output)

```bash
unzip -q archive.zip          # suppress normal output
unzip -qq archive.zip         # suppress everything including warnings
```

---

### 1.16 Extract to stdout (Pipe to Another Command)

```bash
# Print contents of a file inside the zip to stdout
unzip -p archive.zip README.md

# Pipe directly into another command
unzip -p archive.zip data.json | jq '.users'
```

---

### 1.17 Preserve File Permissions

```bash
# Restore Unix permissions stored in the archive
unzip -X archive.zip

# Also retain SUID/SGID/sticky bits
unzip -K archive.zip
```

---

### 1.18 Update — Only Extract Newer or New Files

```bash
# Extract only files newer than existing ones, plus new files
unzip -u archive.zip

# Freshen — only update existing files if archive version is newer
unzip -f archive.zip
```

---

### 1.19 `unzip` Flag Summary

| Flag | Effect |
|------|--------|
| `-d DIR` | Extract into `DIR` |
| `-l` | List contents |
| `-v` | Verbose list |
| `-t` | Test integrity |
| `-o` | Overwrite without prompt |
| `-n` | Never overwrite |
| `-j` | Junk paths (flatten) |
| `-q` / `-qq` | Quiet / very quiet |
| `-p` | Extract to stdout |
| `-x PATTERN` | Exclude files |
| `-P PASSWORD` | Supply password |
| `-X` | Restore UID/GID |
| `-K` | Retain SUID bits |
| `-u` | Update (newer + new) |
| `-f` | Freshen (existing only) |

---

## 2. `tar` — Multi-Format Tape Archive

`tar` is the standard Unix archiving tool. By itself it only bundles files; compression is handled by combining with `gzip` (`-z`), `bzip2` (`-j`), `xz` (`-J`), or `zstd` (`--zstd`).

Common archive formats and their extensions:

| Format | Extension(s) | `tar` flag |
|--------|-------------|------------|
| Uncompressed tar | `.tar` | *(none)* |
| Gzip-compressed | `.tar.gz`, `.tgz` | `-z` |
| Bzip2-compressed | `.tar.bz2`, `.tbz2` | `-j` |
| XZ-compressed | `.tar.xz`, `.txz` | `-J` |
| Zstd-compressed | `.tar.zst` | `--zstd` |

> **Key behavior:** `tar` **always keeps the original archive** after extraction. The archive is read-only during extraction.

---

### 2.1 Basic Extraction

```bash
# Auto-detect compression (modern GNU tar)
tar -xf archive.tar.gz

# Explicit flags (equivalent)
tar -xzf archive.tar.gz       # gzip
tar -xjf archive.tar.bz2      # bzip2
tar -xJf archive.tar.xz       # xz
tar -xf archive.tar.zst --zstd  # zstd
tar -xf archive.tar           # uncompressed
```

The `-f` flag **must** immediately precede the archive filename. `-x` = extract, `-f` = file.

Adding `-v` prints each filename as it is extracted:

```bash
tar -xvf archive.tar.gz
```

---

### 2.2 Extract to a Different Directory

```bash
tar -xf archive.tar.gz -C /path/to/destination/
```

The `-C` (change directory) flag redirects extraction. The target directory **must already exist**.

```bash
# Create the directory first, then extract
mkdir -p ~/projects/myapp
tar -xf archive.tar.gz -C ~/projects/myapp

# One-liner with shell subshell trick
mkdir -p ~/output && tar -xf archive.tar.gz -C ~/output
```

---

### 2.3 Keep the Original Archive (Default)

No flags needed. `tar` reads the archive and writes extracted files; the archive itself is untouched.

```bash
tar -xf archive.tar.gz
ls
# archive.tar.gz  extracted-dir/
```

---

### 2.4 Delete the Original Archive After Extraction

`tar` has no native delete-after-extract flag. Use shell chaining:

```bash
tar -xf archive.tar.gz && rm archive.tar.gz
```

---

### 2.5 Preserve Directory Structure (Default)

`tar` preserves the full directory tree stored in the archive by default.

```bash
tar -xf archive.tar.gz
# Recreates: src/lib/utils.c, docs/api/index.html, etc.
```

---

### 2.6 Strip Leading Directory Components

Use `--strip-components=N` to remove the first N path segments. Useful when an archive wraps everything in a top-level folder you don't want:

```bash
# Archive contains: myproject-1.0/src/main.c
# Strip the top-level folder, extract directly to CWD
tar -xf archive.tar.gz --strip-components=1
# Result: src/main.c (no myproject-1.0/ prefix)

# Strip 2 levels
tar -xf archive.tar.gz --strip-components=2
# Result: main.c
```

Combine with `-C` to control both what is stripped and where extraction lands:

```bash
mkdir -p ~/src
tar -xf archive.tar.gz --strip-components=1 -C ~/src
```

---

### 2.7 Flatten All Paths (No Directory Structure)

There is no single `tar` flag equivalent to `unzip -j`. The standard approach is to pipe through `--transform` or use `--strip-components` aggressively. The simplest flat-extraction method:

```bash
# Extract only files matching *.c from any depth, flat into CWD
tar -xf archive.tar.gz --wildcards --no-anchored "*.c" \
    --transform 's|.*/||'
```

`--transform 's|.*/||'` is a sed expression that strips all leading path components, effectively flattening the output.

---

### 2.8 Preserve Permissions and Timestamps

```bash
# Preserve file permissions (default for root; explicit for regular users)
tar -xpf archive.tar.gz

# Preserve permissions + ownership (requires root or CAP_CHOWN)
tar -xpf archive.tar.gz --same-owner

# Use numeric UID/GID instead of resolving names
tar -xpf archive.tar.gz --numeric-owner
```

---

### 2.9 Do Not Overwrite Existing Files

```bash
tar -xf archive.tar.gz --keep-old-files
```

If a file already exists, `tar` will print a warning and skip it.

```bash
# Treat existing files as errors (non-zero exit)
tar -xf archive.tar.gz --keep-old-files --skip-old-files
```

---

### 2.10 Overwrite Existing Files

```bash
tar -xf archive.tar.gz --overwrite
```

---

### 2.11 Extract to a New Subdirectory Automatically

```bash
# Extract everything under a new folder named after the archive
tar -xf archive.tar.gz --one-top-level

# Specify the subdirectory name explicitly
tar -xf archive.tar.gz --one-top-level=myproject
```

`--one-top-level` is equivalent to creating the directory and using `-C`, but does it in one step.

---

### 2.12 List Archive Contents Without Extracting

```bash
tar -tf archive.tar.gz            # list files
tar -tvf archive.tar.gz           # verbose (permissions, size, date)
```

---

### 2.13 Extract Specific Files or Directories

```bash
# Extract a single file (path must match exactly as stored in archive)
tar -xf archive.tar.gz src/main.c

# Extract a directory and everything under it
tar -xf archive.tar.gz src/

# Extract multiple targets
tar -xf archive.tar.gz src/main.c docs/README.md
```

---

### 2.14 Extract Files Matching a Glob Pattern

```bash
# Extract all .c files anywhere in the archive
tar -xf archive.tar.gz --wildcards "*.c"

# Extract all .c files only at top level
tar -xf archive.tar.gz --wildcards "src/*.c"

# Pattern not anchored to path start (matches anywhere in path)
tar -xf archive.tar.gz --wildcards --no-anchored "*.c"
```

---

### 2.15 Exclude Files or Patterns During Extraction

```bash
# Exclude a single file
tar -xf archive.tar.gz --exclude="README.md"

# Exclude by pattern
tar -xf archive.tar.gz --exclude="*.log"

# Exclude an entire directory
tar -xf archive.tar.gz --exclude="build/"

# Multiple exclusions
tar -xf archive.tar.gz --exclude="*.log" --exclude="*.tmp" --exclude="build/"
```

---

### 2.16 Test Archive Integrity Without Extracting

```bash
# With GNU tar
tar -tf archive.tar.gz > /dev/null && echo "OK" || echo "CORRUPT"
```

For deeper integrity testing on a `.tar.gz`, you can verify the gzip layer separately:

```bash
gzip -t archive.tar.gz && echo "gzip layer OK"
```

---

### 2.17 Extract to stdout / Pipe

```bash
# Extract a file and print its contents
tar -xOf archive.tar.gz src/main.c

# Pipe into another command
tar -xOf archive.tar.gz data/config.json | jq '.database'
```

`-O` sends extracted content to stdout instead of writing to disk.

---

### 2.18 `tar` Flag Summary

| Flag | Effect |
|------|--------|
| `-x` | Extract |
| `-t` | List |
| `-v` | Verbose |
| `-f FILE` | Archive filename |
| `-z` | Gzip compression |
| `-j` | Bzip2 compression |
| `-J` | XZ compression |
| `--zstd` | Zstd compression |
| `-C DIR` | Extract to `DIR` (must exist) |
| `-p` | Preserve permissions |
| `--same-owner` | Restore ownership |
| `--numeric-owner` | Use numeric UID/GID |
| `--strip-components=N` | Strip N leading path segments |
| `--one-top-level[=DIR]` | Wrap output in a subdirectory |
| `--keep-old-files` | Don't overwrite existing files |
| `--overwrite` | Overwrite existing files |
| `--wildcards` | Enable glob patterns |
| `--no-anchored` | Match pattern anywhere in path |
| `--exclude=PATTERN` | Exclude matching files |
| `-O` | Extract to stdout |
| `--transform=EXPR` | Apply sed transform to filenames |

---

## 3. `xz` / `unxz` — XZ Compression

`xz` is a **compression-only** tool — it compresses or decompresses a **single file**. It does not bundle multiple files. For multiple files, combine with `tar` (see `tar -J`).

> **Critical difference from `unzip` and `tar`:**  
> By default, `xz -d` and `unxz` **delete the original compressed file** after decompression.  
> This is the opposite of `unzip` and `tar`. Always use `--keep` / `-k` if you want to retain the `.xz` file.

---

### 3.1 Basic Decompression

```bash
# Using xz with -d (decompress) flag
xz -d file.xz
# Produces: file  (original file.xz is DELETED)

# Using the unxz alias (identical behavior)
unxz file.xz
# Produces: file  (original file.xz is DELETED)
```

The output filename is `file.xz` stripped of the `.xz` extension.

---

### 3.2 Keep the Original `.xz` File After Decompression

```bash
xz -d --keep file.xz
# or
xz -dk file.xz

unxz --keep file.xz
unxz -k file.xz
```

Both the decompressed `file` and the original `file.xz` will be present afterwards.

---

### 3.3 Delete the Original — Default Behavior

```bash
xz -d file.xz
# file.xz is gone; only the decompressed file remains
```

This is the default. No extra flags needed.

---

### 3.4 Decompress to stdout (No File Written, No Deletion)

```bash
# Decompress to stdout, original file is untouched
xz -dc file.xz
# or
xz --decompress --stdout file.xz
# or
unxz -c file.xz

# Pipe into another command
xz -dc archive.tar.xz | tar -x
```

Using `-c` / `--stdout` writes to stdout instead of a file, and **does not delete the source**.

---

### 3.5 Decompress to a Different Location

`xz` always decompresses the file in the **same directory** as the source by default. To change the output path, use stdout redirection:

```bash
xz -dc /path/to/file.xz > /different/path/file
```

Or decompress keeping the original, then move:

```bash
xz -dk file.xz && mv file /desired/path/
```

---

### 3.6 Decompress Multiple Files

```bash
# Decompress all .xz files in current directory (all originals deleted)
xz -d *.xz

# Keep all originals
xz -dk *.xz

# Verbose output for each file
xz -dv *.xz
```

---

### 3.7 Decompress `.tar.xz` (Most Common Use Case)

For `.tar.xz` bundles, **always use `tar`** directly — do not use `xz` and `tar` separately:

```bash
tar -xJf archive.tar.xz

# Extract to a specific directory
tar -xJf archive.tar.xz -C ~/destination/

# Verbose
tar -xJvf archive.tar.xz
```

`tar` handles both decompression and unpacking in a single pass and **keeps the original `.tar.xz` file** (unlike standalone `xz`).

---

### 3.8 List Contents of `.tar.xz` Without Extracting

```bash
tar -tJf archive.tar.xz
tar -tJvf archive.tar.xz  # verbose
```

---

### 3.9 Test Integrity Without Decompressing

```bash
# Test the xz file (no output written, no deletion)
xz -t file.xz
# or
xz --test file.xz

# Exit code 0 = OK, non-zero = corrupt
xz -t file.xz && echo "Integrity OK" || echo "File corrupt"
```

---

### 3.10 Get File Information

```bash
xz -l file.xz
```

```
Strms  Blocks   Compressed Uncompressed  Ratio  Check   Filename
    1       1      1.0 MiB      3.8 MiB  0.263  CRC64   file.xz
```

---

### 3.11 Verbose Output

```bash
xz -dv file.xz
```

```
file.xz (1/1)
  100 %         1,024.0 KiB / 3,840.0 KiB = 0.267
```

---

### 3.12 `xz` / `unxz` Flag Summary

| Flag | Effect |
|------|--------|
| `-d` / `--decompress` | Decompress (default: delete source) |
| `-k` / `--keep` | Keep original file after decompression |
| `-c` / `--stdout` | Write to stdout (source untouched) |
| `-t` / `--test` | Test integrity |
| `-l` / `--list` | Show file info |
| `-v` / `--verbose` | Verbose progress |
| `-q` / `--quiet` | Suppress warnings |
| `-T N` / `--threads=N` | Use N threads (0 = auto) |
| `-0` to `-9` | Compression level (decompress ignores this) |

---

## 4. Quick Reference Table

| Task | unzip | tar | xz/unxz |
|------|-------|-----|---------|
| Basic extract | `unzip f.zip` | `tar -xf f.tar.gz` | `unxz f.xz` |
| Extract to dir | `unzip f.zip -d DIR` | `tar -xf f.tar.gz -C DIR` | `xz -dc f.xz > DIR/f` |
| Keep original | *(always kept)* | *(always kept)* | `unxz -k f.xz` |
| Delete original | `unzip f.zip && rm f.zip` | `tar -xf f.tar.gz && rm f.tar.gz` | `unxz f.xz` *(default!)* |
| Preserve dir structure | *(default)* | *(default)* | N/A (single file) |
| Flatten structure | `unzip -j f.zip` | `--transform 's|.*/||'` | N/A |
| List contents | `unzip -l f.zip` | `tar -tf f.tar.gz` | `xz -l f.xz` |
| Test integrity | `unzip -t f.zip` | `gzip -t f.tar.gz` | `xz -t f.xz` |
| Extract to stdout | `unzip -p f.zip file` | `tar -xOf f.tar.gz file` | `xz -dc f.xz` |
| Extract specific file | `unzip f.zip file.txt` | `tar -xf f.tar.gz path/file.txt` | N/A |
| Glob patterns | `unzip f.zip "*.txt"` | `tar -xf f.tar.gz --wildcards "*.txt"` | N/A |
| Exclude files | `unzip f.zip -x "*.log"` | `tar -xf f.tar.gz --exclude="*.log"` | N/A |
| No overwrite | `unzip -n f.zip` | `tar -xf f.tar.gz --keep-old-files` | N/A |
| Strip top-level dir | — | `--strip-components=1` | N/A |
| Quiet | `unzip -q f.zip` | `tar -xf f.tar.gz` (no `-v`) | `xz -dq f.xz` |

---

## 5. Recipes & Real-World Combinations

### 5.1 Download and Extract in One Pipeline

```bash
# tar.gz — no file saved to disk
curl -L https://example.com/release.tar.gz | tar -xz

# tar.xz — pipe through xz then tar
curl -L https://example.com/release.tar.xz | tar -xJ

# Extract to specific directory
curl -L https://example.com/release.tar.gz | tar -xz -C ~/apps/
```

---

### 5.2 Extract Only if Archive is Valid

```bash
# unzip
unzip -t archive.zip && unzip archive.zip -d ~/output/

# tar
tar -tf archive.tar.gz > /dev/null && tar -xf archive.tar.gz -C ~/output/

# xz
xz -t file.xz && xz -dk file.xz
```

---

### 5.3 Extract and Delete Original (All Three Tools)

```bash
unzip archive.zip && rm archive.zip
tar -xf archive.tar.gz && rm archive.tar.gz
unxz file.xz               # xz deletes by default — nothing extra needed
```

---

### 5.4 Extract to Directory Named After the Archive

```bash
# unzip — strip the .zip extension
dir="${file%.zip}"; mkdir -p "$dir" && unzip "$file" -d "$dir"

# tar — strip the .tar.gz extension
file="project-1.0.tar.gz"
dir="${file%.tar.gz}"
mkdir -p "$dir" && tar -xf "$file" -C "$dir"
```

---

### 5.5 Batch Extract All Archives in a Directory

```bash
# All zip files
for f in *.zip; do unzip -q "$f" -d "${f%.zip}"; done

# All tar.gz files
for f in *.tar.gz; do
  mkdir -p "${f%.tar.gz}"
  tar -xf "$f" -C "${f%.tar.gz}"
done

# All xz files (keep originals)
for f in *.xz; do xz -dk "$f"; done
```

---

### 5.6 Extract, Strip Top-Level Dir, Place in Target

```bash
# Archive: mylib-2.1/src/, mylib-2.1/include/
# Goal: ~/libs/mylib/src/, ~/libs/mylib/include/
mkdir -p ~/libs/mylib
tar -xf mylib-2.1.tar.gz --strip-components=1 -C ~/libs/mylib
```

---

### 5.7 Inspect Before Extracting

```bash
# See what's inside before committing
unzip -l unknown.zip
tar -tvf unknown.tar.gz | head -30
xz -l unknown.xz
```

Always good practice before extracting untrusted archives.

---

### 5.8 Extract Only Specific File Types

```bash
# Extract only header files from a tarball
tar -xf sdk.tar.gz --wildcards --no-anchored "*.h"

# Extract only text files from a zip
unzip archive.zip "*.txt" "*.md" -d ~/docs/
```

---

### 5.9 Parallel XZ Decompression (Large Files)

```bash
# Use all available CPU threads
xz -dT0 largefile.xz

# Or with pixz (parallel implementation, if installed)
pixz -d largefile.tar.xz
```

---

### 5.10 Verify and Preserve Everything (Trusted Archive Restore)

```bash
# Full fidelity extraction: permissions, ownership, timestamps
sudo tar -xpf backup.tar.gz --same-owner --numeric-owner -C /restore/point/
```

---

*Generated for Linux (GNU coreutils / GNU tar / Info-ZIP unzip / XZ Utils). Behavior may vary slightly on BSD/macOS.*
