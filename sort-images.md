
---

# 📸 Sorting & Managing Large Photo Collections

This guide shows how to **organize wallpapers and photos by dimensions** using different Linux tools. Perfect for large collections (1GB+), especially when dealing with **desktop vs phone wallpapers**, **ultrawide**, or **4K** images.

---

## ⚠️ ImageMagick Security Limits

On **openSUSE** and many distros, ImageMagick enforces strict limits:

```
max dimension: 8000x8000
```

Large wallpapers (e.g., `10000x5012`) will fail with `identify`.

---

## ✅ Method 1: Override Limits (ImageMagick)

Run with temporary limits disabled:

```bash
MAGICK_WIDTH_LIMIT=20000 MAGICK_HEIGHT_LIMIT=20000 \
identify -format "%w %h %f\n" *.(jpg|png|jpeg) | while read w h f; do
    if (( w > h )); then
        mv "$f" desktop/
    else
        mv "$f" phone/
    fi
done
```

- Works with **huge images**
- Only affects this command, not system-wide config

---

## ⚡ Method 2: Use `exiftool` (Faster, No Limits)

Install:

```bash
sudo zypper install exiftool
```

Run:

```bash
exiftool -ImageWidth -ImageHeight -FileName -s3 *.(jpg|png) | \
while read w h f; do
    if (( w > h )); then
        mv "$f" desktop/
    else
        mv "$f" phone/
    fi
done
```

- **No dimension limits**
- Reads metadata directly
- Faster than ImageMagick

---

## 🧠 Method 3: Use `file` (Pro Trick)

```bash
for img in *.(jpg|png); do
    size=$(file "$img" | grep -o '[0-9]\+ x [0-9]\+')
    w=${size%x*}
    h=${size#*x }

    if (( w > h )); then
        mv "$img" desktop/
    else
        mv "$img" phone/
    fi
done
```

- Uses `file` command
- Extremely reliable for **huge collections**
- No external dependencies

---

## 🎯 Advanced Wallpaper Manager Script

For power users, here’s a **20-line script** that auto-sorts into multiple categories:

```bash
mkdir -p phone desktop 4k ultrawide vertical

for img in *.(jpg|png); do
    size=$(file "$img" | grep -o '[0-9]\+ x [0-9]\+')
    w=${size%x*}
    h=${size#*x }

    if (( w > h )); then
        mv "$img" desktop/
        if (( w >= 3840 && h >= 2160 )); then mv "$img" 4k/; fi
        if (( w/h > 2 )); then mv "$img" ultrawide/; fi
    else
        mv "$img" phone/
        if (( h > w )); then mv "$img" vertical/; fi
    fi
done
```

### Output folders:
```
phone/
desktop/
4k/
ultrawide/
vertical/
```

---

## 💡 Tips

- Always **test scripts** on a small subset before running on your full collection.
- Use `mv -n` to avoid overwriting files.
- Combine with `find` for recursive sorting:
  ```bash
  find . -type f -name "*.jpg" -exec bash script.sh {} \;
  ```

---

## 📂 Repo Structure Example

```
wallpapers/
├── phone/
├── desktop/
├── 4k/
├── ultrawide/
└── vertical/
```

---

