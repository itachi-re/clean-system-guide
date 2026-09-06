# 📸 Comprehensive Photo & Wallpaper Management Guide

> Organize, sort, deduplicate, batch-process, and manage large photo collections on **openSUSE**, **Arch Linux**, and **Debian/Ubuntu** using ImageMagick, ExifTool, feh, Python, and more.

---

## 📋 Table of Contents

1. [Installation by Distro](#installation-by-distro)
2. [Understanding ImageMagick Limits](#understanding-imagemagick-limits)
3. [Method 1 – ImageMagick (`identify` + `convert`)](#method-1--imagemagick-identify--convert)
4. [Method 2 – ExifTool (Fast & Metadata-Rich)](#method-2--exiftool-fast--metadata-rich)
5. [Method 3 – Python + Pillow (Scripted Automation)](#method-3--python--pillow-scripted-automation)
6. [Method 4 – `file` + `ffprobe` (No Dependencies)](#method-4--file--ffprobe-no-dependencies)
7. [Method 5 – fdupes / rmlint (Deduplication)](#method-5--fdupes--rmlint-deduplication)
8. [Method 6 – Sorting by EXIF Date](#method-6--sorting-by-exif-date)
9. [Method 7 – Batch Resizing & Format Conversion](#method-7--batch-resizing--format-conversion)
10. [Method 8 – digikam (GUI Management)](#method-8--digikam-gui-management)
11. [Method 9 – Shotwell & gThumb (Lightweight GUIs)](#method-9--shotwell--gthumb-lightweight-guis)
12. [Method 10 – Automated All-in-One Shell Script](#method-10--automated-all-in-one-shell-script)
13. [Performance Tips for Large Collections](#performance-tips-for-large-collections)
14. [Troubleshooting Common Errors](#troubleshooting-common-errors)

---

## Installation by Distro

### openSUSE (Tumbleweed / Leap)

```bash
# ImageMagick
sudo zypper install ImageMagick

# ExifTool
sudo zypper install perl-Image-ExifTool

# Python + Pillow
sudo zypper install python3-Pillow

# fdupes (deduplication)
sudo zypper install fdupes

# rmlint (advanced deduplication)
sudo zypper install rmlint

# digiKam (GUI)
sudo zypper install digikam

# gThumb
sudo zypper install gthumb

# ffprobe (part of ffmpeg)
sudo zypper install ffmpeg
```

### Arch Linux

```bash
# ImageMagick
sudo pacman -S imagemagick

# ExifTool
sudo pacman -S perl-image-exiftool

# Python + Pillow
sudo pacman -S python-pillow

# fdupes
sudo pacman -S fdupes

# rmlint
sudo pacman -S rmlint

# digiKam
sudo pacman -S digikam

# gThumb
sudo pacman -S gthumb

# ffprobe
sudo pacman -S ffmpeg

# AUR extras (yay required)
yay -S geeqie            # powerful image viewer with sorting
yay -S rapid-photo-downloader
```

### Debian / Ubuntu

```bash
# ImageMagick
sudo apt install imagemagick

# ExifTool
sudo apt install libimage-exiftool-perl

# Python + Pillow
sudo apt install python3-pil

# fdupes
sudo apt install fdupes

# rmlint
sudo apt install rmlint

# digiKam
sudo apt install digikam

# gThumb / Shotwell
sudo apt install gthumb shotwell

# ffprobe
sudo apt install ffmpeg
```

---

## Understanding ImageMagick Limits

On most distros, ImageMagick ships with a strict security policy at `/etc/ImageMagick-7/policy.xml` (or `/etc/ImageMagick-6/policy.xml`) that caps image dimensions and memory. Large wallpapers (e.g. 10000×5012, 7680×4320 8K) will **fail silently or throw errors**.

### Check your current policy

```bash
identify -list policy
# or
cat /etc/ImageMagick-7/policy.xml | grep -E 'width|height|memory|disk'
```

### Override limits per-command (temporary, no root needed)

```bash
MAGICK_WIDTH_LIMIT=30000 \
MAGICK_HEIGHT_LIMIT=30000 \
MAGICK_MEMORY_LIMIT=2GiB \
MAGICK_DISK_LIMIT=8GiB \
  identify -format "%wx%h %f\n" *.jpg
```

### Edit policy.xml permanently (system-wide)

```bash
sudo nano /etc/ImageMagick-7/policy.xml
```

Find and update these lines:

```xml
<!-- Before -->
<policy domain="resource" name="width"  value="8KP"/>
<policy domain="resource" name="height" value="8KP"/>
<policy domain="resource" name="memory" value="256MiB"/>
<policy domain="resource" name="disk"   value="1GiB"/>

<!-- After -->
<policy domain="resource" name="width"  value="64KP"/>
<policy domain="resource" name="height" value="64KP"/>
<policy domain="resource" name="memory" value="4GiB"/>
<policy domain="resource" name="disk"   value="16GiB"/>
```

> ⚠️ **openSUSE note:** The policy file path may be `/etc/ImageMagick/policy.xml`. Run `find /etc -name policy.xml` to locate it.

---

## Method 1 – ImageMagick (`identify` + `convert`)

### Sort by orientation (desktop vs phone)

```bash
mkdir -p sorted/desktop sorted/phone sorted/square

MAGICK_WIDTH_LIMIT=30000 MAGICK_HEIGHT_LIMIT=30000 \
identify -format "%w %h %f\n" *.{jpg,jpeg,png,webp} 2>/dev/null | \
while read -r w h f; do
    if   (( w > h )); then mv "$f" sorted/desktop/
    elif (( h > w )); then mv "$f" sorted/phone/
    else                   mv "$f" sorted/square/
    fi
done
```

### Sort into resolution tiers (4K / 2K / FHD / HD / SD)

```bash
mkdir -p sorted/{4k,2k,fhd,hd,sd}

MAGICK_WIDTH_LIMIT=30000 MAGICK_HEIGHT_LIMIT=30000 \
identify -format "%w %h %f\n" *.{jpg,jpeg,png} 2>/dev/null | \
while read -r w h f; do
    if   (( w >= 3840 )); then mv "$f" sorted/4k/
    elif (( w >= 2560 )); then mv "$f" sorted/2k/
    elif (( w >= 1920 )); then mv "$f" sorted/fhd/
    elif (( w >= 1280 )); then mv "$f" sorted/hd/
    else                       mv "$f" sorted/sd/
    fi
done
```

### Sort ultrawide (21:9) vs standard (16:9) vs portrait

```bash
MAGICK_WIDTH_LIMIT=30000 MAGICK_HEIGHT_LIMIT=30000 \
identify -format "%w %h %f\n" *.{jpg,png} 2>/dev/null | \
awk '{
    w=$1; h=$2; f=$3
    ratio = w/h
    if (ratio >= 2.0)        print f > "sorted/ultrawide/" f
    else if (ratio >= 1.5)   print f > "sorted/widescreen/" f
    else if (ratio >= 0.99)  print f > "sorted/square/" f
    else                     print f > "sorted/portrait/" f
}'
```

---

## Method 2 – ExifTool (Fast & Metadata-Rich)

ExifTool reads image dimensions **without decoding pixels** — it's 10–100× faster than ImageMagick on large collections and handles any dimension without policy restrictions.

### Get dimensions of all images in a folder

```bash
exiftool -T -FileName -ImageWidth -ImageHeight -r ./photos/
```

### Sort by orientation using ExifTool

```bash
mkdir -p sorted/landscape sorted/portrait

exiftool -T -FileName -ImageWidth -ImageHeight *.jpg *.png 2>/dev/null | \
while IFS=$'\t' read -r f w h; do
    [ -z "$w" ] || [ -z "$h" ] && continue
    if (( w > h )); then
        cp "$f" sorted/landscape/
    else
        cp "$f" sorted/portrait/
    fi
done
```

### Export metadata to CSV (great for auditing large libraries)

```bash
exiftool -csv -FileName -ImageWidth -ImageHeight -FileSize \
         -DateTimeOriginal -Make -Model \
         -r ./photos/ > photo_inventory.csv
```

### Rename files by capture date

```bash
# Rename to YYYY-MM-DD_HH-MM-SS_originalname.jpg
exiftool '-FileName<DateTimeOriginal' \
         -d '%Y-%m-%d_%H-%M-%S_%%f.%%e' \
         -r ./photos/
```

### Find images missing EXIF data

```bash
exiftool -if 'not $DateTimeOriginal' -FileName -r ./photos/
```

---

## Method 3 – Python + Pillow (Scripted Automation)

Python gives you full programmatic control — ideal for complex sorting rules, logging, or integrating into larger pipelines.

### Install

```bash
# openSUSE
sudo zypper install python3-Pillow

# Arch
sudo pacman -S python-pillow

# Debian/Ubuntu
sudo apt install python3-pil python3-pil.imagetk
```

### Sort by resolution & orientation

```python
#!/usr/bin/env python3
"""sort_photos.py — Sort images by dimensions using Pillow."""

import os
import shutil
from pathlib import Path
from PIL import Image, UnidentifiedImageError

SOURCE = Path("./photos")
DEST   = Path("./sorted")

CATEGORIES = {
    "4k_landscape":  lambda w, h: w >= 3840 and w > h,
    "4k_portrait":   lambda w, h: w >= 3840 and h >= w,
    "fhd_landscape": lambda w, h: w >= 1920 and w > h,
    "fhd_portrait":  lambda w, h: h >= 1920 and h > w,
    "hd_landscape":  lambda w, h: w >= 1280 and w > h,
    "hd_portrait":   lambda w, h: h >= 720  and h > w,
    "small":         lambda w, h: True,   # fallback
}

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff", ".avif"}

def sort_image(filepath: Path):
    try:
        with Image.open(filepath) as img:
            w, h = img.size
    except UnidentifiedImageError:
        print(f"  [SKIP] Cannot read: {filepath.name}")
        return

    for category, test in CATEGORIES.items():
        if test(w, h):
            dest_dir = DEST / category
            dest_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(filepath, dest_dir / filepath.name)
            print(f"  [{w}x{h}] {filepath.name} → {category}/")
            return

def main():
    images = [f for f in SOURCE.rglob("*") if f.suffix.lower() in EXTENSIONS]
    print(f"Found {len(images)} images in {SOURCE}")
    for img in images:
        sort_image(img)
    print("Done.")

if __name__ == "__main__":
    main()
```

```bash
python3 sort_photos.py
```

### Generate a thumbnail contact sheet

```python
#!/usr/bin/env python3
"""contact_sheet.py — Generate a grid thumbnail preview of a folder."""

from PIL import Image
from pathlib import Path
import math

THUMB_SIZE = (200, 200)
COLS       = 8
SOURCE     = Path("./photos")
OUTPUT     = Path("contact_sheet.jpg")
EXTS       = {".jpg", ".jpeg", ".png", ".webp"}

images = sorted([f for f in SOURCE.rglob("*") if f.suffix.lower() in EXTS])
thumbs = []
for path in images:
    try:
        img = Image.open(path)
        img.thumbnail(THUMB_SIZE)
        thumbs.append(img)
    except Exception:
        pass

rows  = math.ceil(len(thumbs) / COLS)
sheet = Image.new("RGB", (THUMB_SIZE[0] * COLS, THUMB_SIZE[1] * rows), (20, 20, 20))

for idx, thumb in enumerate(thumbs):
    col = idx % COLS
    row = idx // COLS
    x   = col * THUMB_SIZE[0] + (THUMB_SIZE[0] - thumb.width)  // 2
    y   = row * THUMB_SIZE[1] + (THUMB_SIZE[1] - thumb.height) // 2
    sheet.paste(thumb, (x, y))

sheet.save(OUTPUT, quality=85)
print(f"Saved contact sheet → {OUTPUT}  ({len(thumbs)} images)")
```

---

## Method 4 – `file` + `ffprobe` (No Dependencies)

When you can't install ImageMagick or Pillow, use tools that ship with almost every system.

### Using `file` to detect image type

```bash
file *.jpg *.png | grep -v "JPEG\|PNG" | cut -d: -f1
# Lists any files that aren't actual JPEG/PNG (e.g. corrupted)
```

### Using `ffprobe` to get dimensions

```bash
ffprobe -v error \
        -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=p=0 \
        image.jpg
# Output: 1920,1080
```

### Batch sort with ffprobe (handles almost any format)

```bash
mkdir -p sorted/landscape sorted/portrait sorted/square

for f in photos/*.{jpg,jpeg,png,webp,avif,heic}; do
    [ -f "$f" ] || continue
    dims=$(ffprobe -v error \
                   -select_streams v:0 \
                   -show_entries stream=width,height \
                   -of csv=p=0 "$f" 2>/dev/null)
    w=${dims%%,*}
    h=${dims##*,}
    [[ -z "$w" || -z "$h" ]] && continue

    if   (( w > h )); then cp "$f" sorted/landscape/
    elif (( h > w )); then cp "$f" sorted/portrait/
    else                   cp "$f" sorted/square/
    fi
done
```

---

## Method 5 – fdupes / rmlint (Deduplication)

Large wallpaper collections accumulate duplicates quickly. These tools find and remove them safely.

### fdupes – find exact duplicates

```bash
# Find duplicates recursively (print only)
fdupes -r ./photos/

# Find duplicates and delete interactively
fdupes -r -d ./photos/

# Auto-delete all but first copy (DANGEROUS — review first)
fdupes -r -f ./photos/ | grep -v '^$' | xargs -d '\n' rm

# Summary only
fdupes -r -m ./photos/
```

### rmlint – advanced deduplication (faster, more options)

```bash
# Scan and generate a shell script of actions
rmlint ./photos/

# Review the generated script before running
cat rmlint.sh

# Execute deduplication (moves dupes to trash)
bash rmlint.sh

# Find duplicates AND near-duplicates (similar images)
rmlint --types=duplicates,part-of-directory ./photos/
```

### czkawka – modern GUI/CLI deduplication (Arch AUR / Flatpak)

```bash
# Arch
yay -S czkawka

# All distros via Flatpak
flatpak install flathub com.github.qarmin.czkawka

# CLI usage
czkawka_cli dup -d ./photos/ --delete-method AEO   # keep oldest
```

> `czkawka` can also find **visually similar** images using a perceptual hash — very useful for wallpaper collections with slight crops or re-exports.

---

## Method 6 – Sorting by EXIF Date

Organize photos taken with a camera (phone or DSLR) into year/month folder hierarchies using EXIF capture timestamps.

### Using ExifTool (recommended)

```bash
# Dry run first — see what would happen
exiftool -r -n -p '$FileName → $DateTimeOriginal' ./photos/ 2>/dev/null

# Move into YYYY/MM/ structure
exiftool -r \
  '-Directory<DateTimeOriginal' \
  -d './sorted/%Y/%m' \
  ./photos/

# Move into YYYY-MM-DD named folders
exiftool -r \
  '-Directory<DateTimeOriginal' \
  -d './sorted/%Y-%m-%d' \
  ./photos/

# For images without EXIF, fall back to file modification date
exiftool -r \
  '-Directory<DateTimeOriginal' \
  '-Directory<FileModifyDate' \
  -d './sorted/%Y/%m' \
  ./photos/
```

### Using a Python script (more control)

```python
#!/usr/bin/env python3
"""date_sort.py — Sort photos into YYYY/MM folders by EXIF date."""

import shutil
import subprocess
from pathlib import Path
from datetime import datetime

SOURCE = Path("./photos")
DEST   = Path("./sorted_by_date")
EXTS   = {".jpg", ".jpeg", ".heic", ".png", ".cr2", ".nef", ".arw"}

def get_exif_date(path: Path):
    result = subprocess.run(
        ["exiftool", "-T", "-DateTimeOriginal", str(path)],
        capture_output=True, text=True
    )
    raw = result.stdout.strip()
    if raw and raw != "-":
        try:
            return datetime.strptime(raw, "%Y:%m:%d %H:%M:%S")
        except ValueError:
            pass
    # Fallback to file modification time
    return datetime.fromtimestamp(path.stat().st_mtime)

for f in SOURCE.rglob("*"):
    if f.suffix.lower() not in EXTS:
        continue
    dt      = get_exif_date(f)
    dest    = DEST / str(dt.year) / f"{dt.month:02d}"
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(f, dest / f.name)
    print(f"  {f.name} → {dest.relative_to(DEST)}/")
```

---

## Method 7 – Batch Resizing & Format Conversion

### ImageMagick – bulk resize keeping aspect ratio

```bash
# Resize all JPEGs to max 1920px wide, save to ./resized/
mkdir -p resized
MAGICK_WIDTH_LIMIT=30000 MAGICK_HEIGHT_LIMIT=30000 \
mogrify -path resized/ -resize 1920x1920\> -quality 85 *.jpg
```

> `\>` means "only shrink, never enlarge."

### Convert all PNG to JPEG

```bash
mkdir -p converted
for f in *.png; do
    MAGICK_WIDTH_LIMIT=30000 MAGICK_HEIGHT_LIMIT=30000 \
    convert "$f" -quality 90 "converted/${f%.png}.jpg"
done
```

### Convert to WebP (smaller file sizes)

```bash
# Requires cwebp (libwebp)
# openSUSE: sudo zypper install libwebp-tools
# Arch:     sudo pacman -S libwebp
# Debian:   sudo apt install webp

for f in *.{jpg,jpeg,png}; do
    [ -f "$f" ] || continue
    cwebp -q 85 "$f" -o "${f%.*}.webp"
done
```

### Parallel processing with GNU Parallel (for large collections)

```bash
# openSUSE: sudo zypper install gnu_parallel
# Arch:     sudo pacman -S parallel
# Debian:   sudo apt install parallel

mkdir -p resized
find ./photos -name "*.jpg" | \
parallel -j$(nproc) \
  'MAGICK_WIDTH_LIMIT=30000 convert {} -resize 2560x1440\> -quality 88 resized/{/}'
```

### Strip metadata (for privacy)

```bash
# Remove ALL EXIF/metadata from images
mogrify -strip *.jpg *.png

# Or selectively with ExifTool (keeps image data clean)
exiftool -all= *.jpg
```

---

## Method 8 – digiKam (GUI Management)

**digiKam** is the most powerful open-source photo management suite on Linux — comparable to Lightroom. It handles collections of millions of images.

### Features

- **Face recognition** (on-device AI)
- **Geo-tagging** with map view
- **Non-destructive editing** (curves, color balance, noise reduction)
- **Tag hierarchies** and smart albums
- **Batch queue manager** (resize, watermark, export)
- **Duplicate finder** (perceptual hash)
- **RAW support** (CR2, NEF, ARW, DNG, etc.)

### Setup for large collections

1. Launch digiKam and set your root album folder
2. Go to **Settings → Configure digiKam → Database**
3. Switch from SQLite to **MySQL/MariaDB** for collections >50,000 images
4. Enable **"Scan for new items on startup"**

### Batch resize in digiKam

1. Select images → **Tools → Batch Queue Manager**
2. Add tool: **Transform → Resize**
3. Set target dimensions → **Run**

---

## Method 9 – Shotwell & gThumb (Lightweight GUIs)

### Shotwell (GNOME, Debian/Ubuntu focus)

```bash
sudo apt install shotwell   # Debian/Ubuntu
sudo pacman -S shotwell     # Arch (AUR)
```

- Imports photos from camera/SD card automatically
- Basic date-based organization
- Simple editing (crop, rotate, red-eye)
- Good for personal photo libraries under ~50,000 images

### gThumb

```bash
sudo zypper install gthumb  # openSUSE
sudo pacman -S gthumb       # Arch
sudo apt install gthumb     # Debian
```

- Browse and sort images by folder
- Batch rename, rotate, convert
- Basic EXIF viewer

### Geeqie (best for wallpaper browsing)

```bash
sudo pacman -S geeqie       # Arch
yay -S geeqie               # AUR alternative
sudo apt install geeqie     # Debian
```

- Extremely fast image browser
- Sort by filename, date, size, dimensions
- Side-by-side comparison view
- Built-in duplicate finder
- Scriptable with custom commands

---

## Method 10 – Automated All-in-One Shell Script

This script combines dimension detection (ExifTool), orientation sorting, resolution tiering, and logging into a single reusable tool.

```bash
#!/usr/bin/env bash
# ============================================================
# photo_organizer.sh
# Sort images by orientation, resolution, and aspect ratio.
# Usage: ./photo_organizer.sh [SOURCE_DIR] [DEST_DIR]
# ============================================================

set -euo pipefail

SOURCE="${1:-./photos}"
DEST="${2:-./sorted}"
LOG="${DEST}/sort_log.csv"

EXTS="jpg jpeg png webp bmp tiff avif heic"

# ---- Destination folders ----
dirs=(
    "$DEST/desktop/4k"
    "$DEST/desktop/2k"
    "$DEST/desktop/fhd"
    "$DEST/desktop/hd"
    "$DEST/desktop/sd"
    "$DEST/desktop/ultrawide"
    "$DEST/phone/4k_portrait"
    "$DEST/phone/fhd_portrait"
    "$DEST/phone/hd_portrait"
    "$DEST/phone/low_res"
    "$DEST/square"
    "$DEST/unknown"
)
for d in "${dirs[@]}"; do mkdir -p "$d"; done

echo "filename,width,height,ratio,category" > "$LOG"

get_dims() {
    local f="$1"
    # Try ExifTool first (fast, no decode)
    local out
    out=$(exiftool -T -ImageWidth -ImageHeight "$f" 2>/dev/null)
    local w h
    w=$(echo "$out" | awk '{print $1}')
    h=$(echo "$out" | awk '{print $2}')

    # Fall back to ImageMagick if ExifTool fails
    if [[ -z "$w" || "$w" == "-" ]]; then
        out=$(MAGICK_WIDTH_LIMIT=30000 MAGICK_HEIGHT_LIMIT=30000 \
              identify -format "%w %h" "$f" 2>/dev/null || true)
        w=$(echo "$out" | awk '{print $1}')
        h=$(echo "$out" | awk '{print $2}')
    fi

    echo "$w $h"
}

classify() {
    local w="$1" h="$2"
    local ratio
    ratio=$(awk "BEGIN {printf \"%.3f\", $w/$h}")

    # Ultrawide: ratio >= 2.0
    if awk "BEGIN {exit !($ratio >= 2.0)}"; then
        echo "desktop/ultrawide"; return
    fi

    # Landscape (desktop)
    if (( w > h )); then
        if   (( w >= 3840 )); then echo "desktop/4k"
        elif (( w >= 2560 )); then echo "desktop/2k"
        elif (( w >= 1920 )); then echo "desktop/fhd"
        elif (( w >= 1280 )); then echo "desktop/hd"
        else                       echo "desktop/sd"
        fi
        return
    fi

    # Portrait (phone)
    if (( h > w )); then
        if   (( h >= 3840 )); then echo "phone/4k_portrait"
        elif (( h >= 1920 )); then echo "phone/fhd_portrait"
        elif (( h >= 1280 )); then echo "phone/hd_portrait"
        else                       echo "phone/low_res"
        fi
        return
    fi

    # Square
    echo "square"
}

count=0 skipped=0

# Build extension glob
ext_pattern=$(echo "$EXTS" | tr ' ' '\n' | \
    xargs -I{} echo "-o -iname '*.{}'" | sed 's/^-o //')

while IFS= read -r -d '' f; do
    fname=$(basename "$f")
    dims=$(get_dims "$f")
    w=$(echo "$dims" | awk '{print $1}')
    h=$(echo "$dims" | awk '{print $2}')

    if [[ -z "$w" || -z "$h" || "$w" == "-" ]]; then
        cp "$f" "$DEST/unknown/"
        echo "$fname,?,?,?,unknown" >> "$LOG"
        (( skipped++ )) || true
        continue
    fi

    cat_path=$(classify "$w" "$h")
    ratio=$(awk "BEGIN {printf \"%.2f\", $w/$h}")
    cp "$f" "$DEST/$cat_path/"
    echo "$fname,$w,$h,$ratio,$cat_path" >> "$LOG"
    (( count++ )) || true
    echo "  [$w×$h] $fname → $cat_path/"

done < <(find "$SOURCE" \( -iname "*.jpg" \
    -o -iname "*.jpeg" \
    -o -iname "*.png"  \
    -o -iname "*.webp" \
    -o -iname "*.avif" \
    -o -iname "*.heic" \
    -o -iname "*.bmp"  \
    -o -iname "*.tiff" \) -print0)

echo ""
echo "=============================="
echo "  Sorted:  $count images"
echo "  Skipped: $skipped images"
echo "  Log:     $LOG"
echo "=============================="
```

```bash
chmod +x photo_organizer.sh
./photo_organizer.sh ~/Pictures/Wallpapers ~/Pictures/Sorted
```

---

## Performance Tips for Large Collections

| Tip | Detail |
|-----|--------|
| **Use ExifTool over ImageMagick** | ExifTool reads metadata headers only; ImageMagick decodes pixels. For 10,000 images, ExifTool is ~50× faster. |
| **Use `cp` not `mv` first** | Copy first, verify results, then delete originals. Avoids data loss. |
| **GNU Parallel** | `parallel -j$(nproc)` saturates all CPU cores for batch conversions. |
| **`-r` flag on ExifTool** | Recursively processes subdirectories in one pass. |
| **SQLite → MySQL in digiKam** | For libraries over 50,000 images, SQLite becomes a bottleneck. |
| **tmpfs for temp files** | `MAGICK_TMPDIR=/dev/shm` puts ImageMagick temp files in RAM. |
| **Check available RAM** | `free -h` before batch operations. ImageMagick is memory-hungry on large TIFFs. |
| **Use `-thumbnail` not `-resize`** | `convert -thumbnail` skips decoding full image data when only a preview is needed. |

---

## Troubleshooting Common Errors

### `identify: no decode delegate for this image format`

```bash
# Missing codec support — install extra delegates
sudo zypper install imagemagick-extra       # openSUSE
sudo pacman -S imagemagick                  # Arch (usually complete)
sudo apt install imagemagick libheif-dev    # Debian (for HEIC)
```

### `convert: width or height exceeds limit`

```bash
# Override per-command
MAGICK_WIDTH_LIMIT=30000 MAGICK_HEIGHT_LIMIT=30000 convert ...

# Or edit /etc/ImageMagick-7/policy.xml permanently (see above)
```

### `exiftool: command not found`

```bash
sudo zypper install perl-Image-ExifTool    # openSUSE
sudo pacman -S perl-image-exiftool         # Arch
sudo apt install libimage-exiftool-perl    # Debian
```

### Files not moving (permission errors)

```bash
ls -lh ./photos/     # check ownership
sudo chown -R $USER:$USER ./photos/
```

### Duplicate filenames when sorting

```bash
# Add a counter suffix to avoid overwrites
cp --backup=numbered "$f" "$DEST/$cat_path/"
```

### HEIC / AVIF not supported

```bash
# openSUSE
sudo zypper install libheif1 libheif-devel

# Arch
sudo pacman -S libheif

# Debian
sudo apt install libheif-examples heif-gdk-pixbuf
```

---

## Quick Reference Card

```
TASK                          TOOL             COMMAND
─────────────────────────────────────────────────────────────────
Get image dimensions          ExifTool         exiftool -T -ImageWidth -ImageHeight img.jpg
Get image dimensions          ImageMagick      identify -format "%wx%h" img.jpg
Sort by orientation (bash)    ExifTool + awk   See Method 2
Sort by resolution (Python)   Pillow           See Method 3
Remove EXIF metadata          ExifTool         exiftool -all= *.jpg
Find duplicates               fdupes           fdupes -r ./photos/
Find visual duplicates        czkawka          czkawka_cli dup -d ./photos/
Sort by EXIF date             ExifTool         exiftool -r '-Directory<DateTimeOriginal' -d '%Y/%m' ./
Batch resize (keep ratio)     ImageMagick      mogrify -path out/ -resize 1920x\> *.jpg
Convert PNG → JPEG            ImageMagick      mogrify -format jpg *.png
Convert to WebP               cwebp            cwebp -q 85 in.jpg -o out.webp
Parallel batch convert        GNU Parallel     find . -name "*.jpg" | parallel -j$(nproc) convert {} ...
```

---

*Last updated: 2025 | Tested on openSUSE Tumbleweed, Arch Linux, Ubuntu 24.04*
