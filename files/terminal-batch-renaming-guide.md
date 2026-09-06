# Batch Renaming & File Structure — Terminal Guide

A practical, tested reference for renaming files in bulk from the terminal — safely, without clobbering existing files, and without breaking extensions.

Every command in this guide has been tested in a real shell against filenames with spaces, mixed case, hidden files, and duplicate targets before being written down here.

## Table of Contents

1. [Safety Rules First](#1-safety-rules-first)
2. [Bash String Manipulation Refresher](#2-bash-string-manipulation-refresher)
3. [Splitting a Filename into Base + Extension](#3-splitting-a-filename-into-base--extension)
4. [Common Batch Rename Tasks](#4-common-batch-rename-tasks)
5. [Collision-Safe Renaming (Never Overwrite)](#5-collision-safe-renaming-never-overwrite)
6. [Dry-Run Before You Commit](#6-dry-run-before-you-commit)
7. [The `rename` Command (Regex Power Tool)](#7-the-rename-command-regex-power-tool)
8. [Recursive Renaming with `find`](#8-recursive-renaming-with-find)
9. [Full Script: `batch-rename.sh`](#9-full-script-batch-renamesh)
10. [Cheatsheet](#10-cheatsheet)
11. [Common Pitfalls](#11-common-pitfalls)
12. [TODOs](#12-todos)

---

## 1. Safety Rules First

Before touching a folder full of files, follow these rules:

- **Always dry-run first.** Print what *would* happen before running the real command.
- **Use `mv -n`** (no-clobber) so `mv` refuses to overwrite an existing file instead of silently destroying it.
- **Never rename in place without a plan for collisions** — two different filenames can normalize to the same new name (e.g. `Report Draft.txt` and `Report_Draft.txt` both become `Report_Draft.txt`).
- **Test on a copy of a few files** in a scratch folder before running anything across an entire directory.
- **Quote every variable**: `"$f"`, not `$f`. Unquoted variables break on filenames with spaces.

---

## 2. Bash String Manipulation Refresher

These are Bash's built-in parameter expansions — no external tools (`tr`, `sed`, `awk`) required:

| Expansion | Meaning |
|---|---|
| `${var%pattern}` | Remove **shortest** match of `pattern` from the **end** |
| `${var%%pattern}` | Remove **longest** match of `pattern` from the **end** |
| `${var#pattern}` | Remove **shortest** match of `pattern` from the **start** |
| `${var##pattern}` | Remove **longest** match of `pattern` from the **start** |
| `${var/pattern/repl}` | Replace **first** match of `pattern` with `repl` |
| `${var//pattern/repl}` | Replace **all** matches of `pattern` with `repl` |
| `${var,,}` | Convert to **lowercase** (Bash 4+) |
| `${var^^}` | Convert to **UPPERCASE** (Bash 4+) |

> **Important:** when `pattern` comes from a variable (e.g. a prefix you want to strip), quote it — `${f#"$prefix"}` — otherwise special glob characters in the prefix (`*`, `?`, `[`) get interpreted as wildcards instead of literal text.

---

## 3. Splitting a Filename into Base + Extension

The naive approach:

```bash
filename="Linux Survival Guide for Internet Debates.md"
echo "${filename%.*}" | tr ' ' '_'   # base, spaces replaced
echo "${filename##*.}"                # extension
```

Combined:

```bash
echo "$(echo "${filename%.*}" | tr ' ' '_').${filename##*.}"
# Linux_Survival_Guide_for_Internet_Debates.md
```

This works for a single file, but two cases will trip you up across a whole folder:

- **Multi-dot files**: `archive.tar.gz` → `${filename%.*}` gives `archive.tar`, `${filename##*.}` gives `gz`. That's usually what you want (only the last extension is treated as "the extension"), but be aware of it.
- **Dotfiles**: `.bashrc` or `.hidden file` — treating the leading dot as an "extension separator" would wrongly split `.hidden` from `file`. A batch script needs to explicitly exclude leading dots.

A safe splitter function, tested against both cases:

```bash
split_ext() {
    local f="$1"
    if [[ "$f" == *.* && "$f" != .* ]]; then
        printf '%s\n%s\n' "${f%.*}" "${f##*.}"
    else
        printf '%s\n\n' "$f"   # no extension, or a dotfile
    fi
}
```

Verified behavior:

| Input | Base | Extension |
|---|---|---|
| `photo.JPG` | `photo` | `JPG` |
| `archive.tar.gz` | `archive.tar` | `gz` |
| `.hidden file` | `.hidden file` | *(none)* |
| `noext_file` | `noext_file` | *(none)* |

---

## 4. Common Batch Rename Tasks

All of these operate on every file in the **current directory** (non-recursive). Add `shopt -s dotglob` before the loop if you also want hidden files included in the `*` glob.

### Replace spaces with underscores (extension preserved)

```bash
for f in *; do
    [[ -f "$f" ]] || continue
    base="${f%.*}"; ext="${f##*.}"
    [[ "$f" == "$base" ]] && { mv -n -- "$f" "${f// /_}"; continue; }
    mv -n -- "$f" "${base// /_}.$ext"
done
```

### Remove all whitespace entirely (no separator)

```bash
for f in *; do
    [[ -f "$f" ]] || continue
    new="${f// /}"
    [[ "$f" == "$new" ]] && continue
    mv -n -- "$f" "$new"
done
```

### Add a prefix to every file

```bash
for f in *.jpg; do
    mv -n -- "$f" "2026_$f"
done
```

Tested: `IMG_holiday.jpg` → `2026_IMG_holiday.jpg`.

### Remove a specific prefix (glob-safe)

```bash
prefix="2026_"
for f in "${prefix}"*; do
    mv -n -- "$f" "${f#"$prefix"}"
done
```

Tested: `2026_IMG_holiday.jpg` → `IMG_holiday.jpg`. Quoting `"$prefix"` inside `${f#"$prefix"}` matters — without it, characters like `.` or `*` in the prefix would be treated as glob patterns instead of literal text.

### Add a suffix before the extension

```bash
for f in *.jpg; do
    base="${f%.*}"; ext="${f##*.}"
    mv -n -- "$f" "${base}_edited.${ext}"
done
```

### Remove a specific suffix before the extension

```bash
for f in *_OLD.*; do
    ext="${f##*.}"
    base="${f%_OLD.*}"
    mv -n -- "$f" "${base}.${ext}"
done
```

Tested: `vacation_OLD.jpg` → `vacation.jpg`, `vacation_OLD.png` → `vacation.png` (both handled correctly in the same loop since the glob matches all extensions).

### Change/normalize a file extension

```bash
for f in *.TXT; do
    mv -n -- "$f" "${f%.TXT}.md"
done
```

Tested: `REPORT.TXT` → `REPORT.md`.

### Lowercase (or uppercase) every filename

```bash
for f in *; do
    [[ -f "$f" ]] || continue
    new="${f,,}"
    [[ "$f" == "$new" ]] && continue   # skip files already lowercase
    mv -n -- "$f" "$new"
done
```

Swap `${f,,}` for `${f^^}` to uppercase instead. The `[[ "$f" == "$new" ]] && continue` guard matters — without it, `mv` prints a harmless but noisy `mv: not replacing 'x'` for every file that's already in the target case.

### Bonus: zero-pad a sequence (e.g. for video frame exports or photo dumps)

```bash
i=1
for f in *.jpg; do
    printf -v num "%03d" "$i"
    mv -n -- "$f" "IMG_${num}.jpg"
    ((i++))
done
```

`photo1.jpg`, `photo2.jpg`, ... → `IMG_001.jpg`, `IMG_002.jpg`, ...

---

## 5. Collision-Safe Renaming (Never Overwrite)

The single biggest risk in batch renaming: two different source files normalizing to the **same** target name. For example, `Report Draft.txt` and `Report_Draft.txt` both become `Report_Draft.txt` when you replace spaces with underscores — a plain `mv` would silently destroy one of them.

This function checks for an existing target and, if found, appends `_(1)`, `_(2)`, etc. instead of overwriting:

```bash
safe_rename() {
    local src="$1" dst="$2"
    [[ "$src" == "$dst" ]] && return 0
    if [[ -e "$dst" ]]; then
        local base ext i=1
        if [[ "$dst" == *.* && "$dst" != .* ]]; then
            base="${dst%.*}"; ext=".${dst##*.}"
        else
            base="$dst"; ext=""
        fi
        while [[ -e "${base}_($i)${ext}" ]]; do
            ((i++))
        done
        dst="${base}_($i)${ext}"
    fi
    mv -n -- "$src" "$dst"
    echo "Renamed: '$src' -> '$dst'"
}
```

Tested: with both `Report Draft.txt` and `Report_Draft.txt` present, running the space→underscore rename processed `Report_Draft.txt` first (no-op), then renamed `Report Draft.txt` to `Report_Draft_(1).txt` instead of overwriting.

---

## 6. Dry-Run Before You Commit

Before running any batch rename for real, preview it. Two easy ways:

**A. Print instead of executing:**

```bash
for f in *; do
    [[ -f "$f" ]] || continue
    echo "would rename: '$f' -> '${f// /_}'"
done
```

**B. Build a `DRY_RUN` flag into your script** (used in the full script below):

```bash
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if $DRY_RUN; then
    echo "[dry-run] '$src' -> '$dst'"
else
    mv -n -- "$src" "$dst"
fi
```

Always run with `--dry-run` first, read the output, then run for real.

---

## 7. The `rename` Command (Regex Power Tool)

There are two very different tools that both go by the name `rename`:

- **util-linux `rename`** (simple substitution): `rename OLDSTRING NEWSTRING file...`
- **Perl `rename`** (aka `prename`, full regex): `rename 's/PATTERN/REPLACEMENT/' file...`

Check which one you have:

```bash
rename --version
```

On openSUSE, the Perl version isn't always installed by default. Look for it with:

```bash
zypper search rename
sudo zypper install perl-rename   # package name may vary — check search results
```

**Perl `rename` examples** (once confirmed):

```bash
# Spaces to underscores, all files
rename 's/ /_/g' *

# Lowercase every filename
rename 'y/A-Z/a-z/' *

# Strip a prefix
rename 's/^2026_//' *

# Change extension
rename 's/\.TXT$/.md/' *
```

Perl `rename` will **not** overwrite an existing file by default — it skips and warns. Add `-f` only if you explicitly want to force overwrites (not recommended without a prior dry-run using `-n`):

```bash
rename -n 's/ /_/g' *   # -n = dry-run, prints what would happen
```

---

## 8. Recursive Renaming with `find`

To rename files inside subfolders too, use `find` with null-delimited output so filenames with spaces or newlines are handled safely:

```bash
find . -type f -name "* *" -print0 | while IFS= read -r -d '' f; do
    dir=$(dirname -- "$f")
    base=$(basename -- "$f")
    newbase="${base// /_}"
    mv -n -- "$f" "$dir/$newbase"
done
```

- `-print0` / `read -r -d ''` — null-delimited, safe against spaces and special characters.
- `dirname` / `basename` — split the path so only the filename (not the directory path) gets transformed.

For collision safety recursively, source the `safe_rename` function from Section 5 and call `safe_rename "$f" "$dir/$newbase"` instead of `mv` directly.

---

## 9. Full Script: `batch-rename.sh`

A ready-to-use, tested script combining dry-run mode, collision protection, and a single place (`transform()`) to define your rename rule.

```bash
#!/usr/bin/env bash
#
# batch-rename.sh — safe batch renaming with collision protection and dry-run mode.
#
# Usage:
#   ./batch-rename.sh --dry-run     # preview only, no changes made
#   ./batch-rename.sh               # apply changes for real
#
# Edit the transform() function to define what happens to each filename.

set -uo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Split "name.ext" into base/ext on stdout (two lines). Dotfiles and
# extensionless files are treated as having no extension.
split_ext() {
    local f="$1"
    if [[ "$f" == *.* && "$f" != .* ]]; then
        printf '%s\n%s\n' "${f%.*}" "${f##*.}"
    else
        printf '%s\n\n' "$f"
    fi
}

# Define your rename rule here. $1 = basename (without extension).
# Uncomment/adjust exactly one strategy at a time.
transform() {
    local base="$1"
    base="${base// /_}"          # spaces -> underscores
    # base="${base#OLD_PREFIX_}" # strip a known prefix
    # base="NEW_PREFIX_${base}" # add a prefix
    # base="${base%_OLD_SUFFIX}" # strip a known suffix
    # base="${base,,}"          # lowercase
    printf '%s' "$base"
}

# Collision-safe move: never overwrites an existing file.
safe_rename() {
    local src="$1" dst="$2"
    [[ "$src" == "$dst" ]] && return 0
    if [[ -e "$dst" ]]; then
        local base ext i=1
        if [[ "$dst" == *.* && "$dst" != .* ]]; then
            base="${dst%.*}"; ext=".${dst##*.}"
        else
            base="$dst"; ext=""
        fi
        while [[ -e "${base}_($i)${ext}" ]]; do
            ((i++))
        done
        dst="${base}_($i)${ext}"
    fi
    if $DRY_RUN; then
        echo "[dry-run] '$src' -> '$dst'"
    else
        mv -n -- "$src" "$dst"
        echo "Renamed: '$src' -> '$dst'"
    fi
}

shopt -s nullglob dotglob
for f in *; do
    [[ -f "$f" ]] || continue
    [[ "$f" == "$(basename -- "$0")" ]] && continue   # skip the script itself
    mapfile -t parts < <(split_ext "$f")
    base="${parts[0]}"
    ext="${parts[1]}"
    newbase="$(transform "$base")"
    if [[ -n "$ext" ]]; then
        newname="${newbase}.${ext}"
    else
        newname="$newbase"
    fi
    safe_rename "$f" "$newname"
done
shopt -u nullglob dotglob
```

Tested against a folder containing spaces, mixed case, a dotfile, a no-extension file, and a deliberate naming collision — all handled correctly: extensions preserved, dotfile left as a single unit, and the collision resolved to `_(1)` instead of overwriting.

---

## 10. Cheatsheet

| Task | Command |
|---|---|
| Spaces → `_` (text) | `echo "text" \| tr ' ' '_'` |
| Spaces → `-` (text) | `echo "text" \| tr ' ' '-'` |
| `_` → spaces (text) | `echo "text" \| tr '_' ' '` |
| Lowercase (text) | `echo "TEXT" \| tr '[:upper:]' '[:lower:]'` |
| Uppercase (text) | `echo "text" \| tr '[:lower:]' '[:upper:]'` |
| Rename one file, keep extension | `base="${f%.*}"; ext="${f##*.}"; mv -n -- "$f" "${base// /_}.$ext"` |
| Add prefix to all files | `for f in *.ext; do mv -n -- "$f" "PREFIX_$f"; done` |
| Remove prefix (glob-safe) | `for f in PREFIX_*; do mv -n -- "$f" "${f#"PREFIX_"}"; done` |
| Add suffix before extension | `base="${f%.*}"; ext="${f##*.}"; mv -n -- "$f" "${base}_SUFFIX.${ext}"` |
| Remove suffix before extension | `for f in *_OLD.*; do ext="${f##*.}"; base="${f%_OLD.*}"; mv -n -- "$f" "${base}.${ext}"; done` |
| Remove all whitespace | `for f in *; do new="${f// /}"; [[ "$f" != "$new" ]] && mv -n -- "$f" "$new"; done` |
| Change extension | `for f in *.TXT; do mv -n -- "$f" "${f%.TXT}.md"; done` |
| Lowercase all filenames | `for f in *; do new="${f,,}"; [[ "$f" != "$new" ]] && mv -n -- "$f" "$new"; done` |
| Zero-pad a sequence | `printf -v num "%03d" "$i"; mv -n -- "$f" "IMG_${num}.jpg"` |
| Preview before running (dry-run) | `echo` the target instead of calling `mv`, or use `rename -n '...'` |
| Regex rename (if Perl `rename` installed) | `rename 's/PATTERN/REPLACEMENT/g' *` |
| Recursive, space-safe | `find . -type f -print0 \| while IFS= read -r -d '' f; do ...; done` |
| Never overwrite | Always add `mv -n`, and use the `safe_rename` function for pre-emptive collision handling |

---

## 11. Common Pitfalls

- **Hidden files skipped silently.** `*` does not match dotfiles by default. Use `shopt -s dotglob` to include them, and `shopt -u dotglob` afterward to restore normal behavior.
- **Unquoted variables break on spaces.** Always use `"$f"`, never bare `$f`.
- **`${f#$prefix}` without quotes treats the prefix as a glob pattern.** Quote it: `${f#"$prefix"}`.
- **Multi-dot files** (`archive.tar.gz`) only have their *last* dot treated as the extension by `${f##*.}` — this is usually desired, but double-check for files where that's not the case.
- **`mv -n` fails silently on purpose.** It won't overwrite, but it also won't warn loudly by default in a loop — check output or use `-v` for verbose confirmation.
- **Renaming a file onto itself** (e.g. lowercasing an already-lowercase name) triggers a harmless `mv: not replacing` message unless you guard with a `[[ "$f" == "$new" ]] && continue` check first.
- **`rename` command ambiguity.** util-linux's `rename` and Perl's `rename` use completely different syntax. Always check `rename --version` before assuming which one you have.

---

## 12. TODOs

- [ ] Add a section comparing GUI tools (`krename`, Dolphin's built-in batch rename) for quick one-off jobs
- [ ] Add Unicode normalization (NFC vs NFD) notes for filenames that behave differently across filesystems (e.g. exFAT drives, macOS-formatted external disks)
- [ ] Add `exiftool`-based renaming (rename photos/videos using embedded EXIF "date taken" metadata)
- [ ] Add `fd` + `parallel` examples for renaming across very large directory trees efficiently
- [ ] Add `mmv` / `qmv` (renameutils) as an interactive alternative to scripting `mv` loops
- [ ] Add a checksum-based dedupe pass (e.g. `sha256sum`) to run before a rename, to catch true duplicates rather than just name collisions
- [ ] Add `git mv`-aware renaming for batch-renaming files inside a Git-tracked repository without breaking history
- [ ] Add a cross-platform filename sanitizer (strip characters illegal on Windows/exFAT: `< > : " / \ | ? *`) for files headed into shared or archived storage
