# aria2c — The Terminal Download Manager You'll Never Stop Using

> **Philosophy:** Every download should be fast, resumable, auditable, and land exactly where you want it. `aria2c` does all of that without a GUI, without a daemon, and without touching your system unnecessarily.

---

## Table of Contents

1. [Why aria2c](#1-why-aria2c)
2. [Installation on openSUSE Tumbleweed](#2-installation-on-opensuse-tumbleweed)
3. [Core Concepts Before You Start](#3-core-concepts-before-you-start)
4. [Basic Downloads](#4-basic-downloads)
5. [Controlling Output — Filenames and Directories](#5-controlling-output--filenames-and-directories)
6. [Multi-Connection Downloads (The Main Speed Boost)](#6-multi-connection-downloads-the-main-speed-boost)
7. [Resuming Interrupted Downloads](#7-resuming-interrupted-downloads)
8. [Downloading Multiple Files](#8-downloading-multiple-files)
9. [Input Files — Batch Downloads From a List](#9-input-files--batch-downloads-from-a-list)
10. [Throttling — Rate Limiting Your Downloads](#10-throttling--rate-limiting-your-downloads)
11. [Authentication — HTTP, FTP, and Proxies](#11-authentication--http-ftp-and-proxies)
12. [BitTorrent Downloads](#12-bittorrent-downloads)
13. [Metalink Downloads](#13-metalink-downloads)
14. [Headers, User-Agents, and Cookies](#14-headers-user-agents-and-cookies)
15. [Checksum Verification](#15-checksum-verification)
16. [The aria2c Configuration File](#16-the-aria2c-configuration-file)
17. [aria2c as a Daemon — RPC Mode](#17-aria2c-as-a-daemon--rpc-mode)
18. [Practical Real-World Examples](#18-practical-real-world-examples)
19. [Exit Codes and What They Mean](#19-exit-codes-and-what-they-mean)
20. [Troubleshooting](#20-troubleshooting)
21. [Quick Reference Cheatsheet](#21-quick-reference-cheatsheet)

---

## 1. Why aria2c

### The Problem With `wget` and `curl`

`wget` and `curl` are excellent tools. But they are single-connection downloaders by default. When you download a 1 GB ISO, you get one TCP connection to one server. That is often nowhere near your actual maximum bandwidth.

`aria2c` splits a single file across **multiple connections and multiple servers simultaneously**. It also handles torrents, metalinks, batch downloads, and has a daemon mode with an RPC interface — all in one binary.

| Feature | `wget` | `curl` | `aria2c` |
|---|---|---|---|
| Multi-segment download | ❌ | ❌ | ✅ |
| Multi-server download | ❌ | ❌ | ✅ |
| BitTorrent | ❌ | ❌ | ✅ |
| Metalink | ❌ | ❌ | ✅ |
| Batch input file | ✅ | ❌ | ✅ |
| Resume support | ✅ | ✅ | ✅ |
| RPC/Daemon mode | ❌ | ❌ | ✅ |
| Config file | ✅ | ✅ | ✅ |

---

## 2. Installation on openSUSE Tumbleweed

aria2c is in the official Tumbleweed repositories. No third-party repo needed.

```bash
sudo zypper install aria2
```

Verify the install:

```bash
aria2c --version
```

Expected output:
```
aria2 version 1.37.0
Copyright (C) 2006, 2019 Tatsuhiro Tsujikawa
...
```

> The binary is called `aria2c`, not `aria2`. The package name is `aria2`. This is intentional — keep it in mind.

---

## 3. Core Concepts Before You Start

Understanding these three concepts will make every flag in this guide make immediate sense.

### Connections vs. Segments vs. Servers

- **Connection:** A single TCP connection to a server.
- **Segment:** A chunk (byte range) of the file being downloaded.
- **Server:** A mirror or alternative source for the same file.

aria2c can open **multiple connections to the same server**, each requesting a different byte range of the same file. It can also download the same file from **multiple servers at once**, assembling the pieces locally.

### The `.aria2` Control File

When a download starts, aria2c creates a companion file alongside your download:

```
ubuntu-24.04.iso          ← the actual file (partial)
ubuntu-24.04.iso.aria2    ← control file (tracks progress)
```

The `.aria2` file is how resume works. **Never delete it** while a download is in progress or if you want to resume later. It is automatically deleted when the download completes.

### URIs, Not Just URLs

aria2c accepts URIs — this includes `http://`, `https://`, `ftp://`, `sftp://`, `magnet:?`, and local file paths for `.torrent` and `.metalink` files.

---

## 4. Basic Downloads

### Download a Single File

```bash
aria2c https://example.com/file.iso
```

The file is saved in the **current working directory** with the filename inferred from the URL.

### See What Is Happening

aria2c prints a live progress display to the terminal:

```
[#1234ab 10MiB/1024MiB(1%) CN:4 DL:15MiB ETA:1m4s]
```

Breaking that down:

| Field | Meaning |
|---|---|
| `#1234ab` | Download GID (internal identifier) |
| `10MiB/1024MiB(1%)` | Downloaded / Total (percent) |
| `CN:4` | Active connections |
| `DL:15MiB` | Current download speed |
| `ETA:1m4s` | Estimated time remaining |

### Suppress Output (Quiet Mode)

```bash
aria2c -q https://example.com/file.iso
```

Nothing is printed. Useful in scripts.

---

## 5. Controlling Output — Filenames and Directories

This is one of the most important sections if you want downloads to land exactly where you want them.

### Save to a Specific Filename

```bash
aria2c -o myfile.iso https://example.com/latest.iso
```

> `-o` sets the **output filename**. The directory is still your current directory.

### Save to a Specific Directory

```bash
aria2c -d /data/itachi/AppImages/ https://example.com/app.AppImage
```

> `-d` sets the **destination directory**. The filename is still inferred from the URL.

The directory **must already exist**. aria2c will not create it for you.

```bash
mkdir -p /data/itachi/AppImages/ && aria2c -d /data/itachi/AppImages/ https://example.com/app.AppImage
```

### Save to a Specific Directory With a Specific Filename

Combine `-d` and `-o`:

```bash
aria2c -d /data/itachi/AppImages/ -o zen-browser.AppImage https://example.com/zen-browser-x86_64.AppImage
```

Result: `/data/itachi/AppImages/zen-browser.AppImage`

### Download Into a Subdirectory Created From the URL Path

Use `--dir` (long form of `-d`) with a custom path:

```bash
aria2c --dir=/home/user/downloads/isos https://releases.ubuntu.com/24.04/ubuntu-24.04.iso
```

### Multiple Files, Each to a Different Directory

When downloading multiple URIs on one command line, each URI can have its own `-d` and `-o` by using the **per-URI option block** syntax — covered in detail in [Section 8](#8-downloading-multiple-files).

---

## 6. Multi-Connection Downloads (The Main Speed Boost)

### Split a Single File Across Multiple Connections

```bash
aria2c -x 16 https://example.com/bigfile.iso
```

> `-x N` — Maximum number of connections **per server**. Default is `1`. Maximum is `16`.

### Split the File Into More Segments

```bash
aria2c -x 16 -s 16 https://example.com/bigfile.iso
```

> `-s N` — Number of segments the file is split into. Each segment is downloaded by one connection. Default is `5`.

**Best practice:** Set `-x` and `-s` to the same value. Each segment gets its own connection.

### The Sweet Spot for Most Downloads

```bash
aria2c -x 16 -s 16 -k 1M https://example.com/bigfile.iso
```

> `-k SIZE` — Minimum segment size. Prevents aria2c from splitting too aggressively on small files. `1M` = 1 megabyte minimum per segment.

### Download From Multiple Mirrors Simultaneously

If a file is hosted on multiple mirrors, list them all as separate URIs for the same download. aria2c treats them as alternative sources for the same file:

```bash
aria2c \
  "https://mirror1.example.com/ubuntu-24.04.iso" \
  "https://mirror2.example.com/ubuntu-24.04.iso" \
  "https://mirror3.example.com/ubuntu-24.04.iso"
```

> All three URIs must point to the **identical file**. aria2c will distribute segments across all three servers and assemble them into one output file.

Combine with connection splitting:

```bash
aria2c -x 4 -s 16 -k 1M \
  "https://mirror1.example.com/ubuntu-24.04.iso" \
  "https://mirror2.example.com/ubuntu-24.04.iso" \
  "https://mirror3.example.com/ubuntu-24.04.iso"
```

This opens up to 4 connections per mirror, splitting the file into 16 segments total, downloading simultaneously from all three mirrors.

---

## 7. Resuming Interrupted Downloads

### Resume a Partial Download

```bash
aria2c -c https://example.com/bigfile.iso
```

> `-c` — Continue/resume. If a partial file and its `.aria2` control file are found in the output directory, the download continues from where it stopped.

If the `.aria2` file is missing but the partial file is present, aria2c will start over. **Do not delete the `.aria2` file.**

### Resume Into a Specific Directory

```bash
aria2c -c -d /data/itachi/downloads/ https://example.com/bigfile.iso
```

The partial file and `.aria2` file must both be present in `/data/itachi/downloads/`.

### Always Resume by Default

Put `-c` in your config file (see [Section 16](#16-the-aria2c-configuration-file)) so resume is always on:

```ini
continue=true
```

---

## 8. Downloading Multiple Files

### Method 1 — Multiple URIs on the Command Line (Same Options)

```bash
aria2c \
  https://example.com/file1.tar.gz \
  https://example.com/file2.tar.gz \
  https://example.com/file3.tar.gz
```

All three files download to the current directory. Downloads run **sequentially** by default.

### Download Multiple Files in Parallel

```bash
aria2c -j 3 \
  https://example.com/file1.tar.gz \
  https://example.com/file2.tar.gz \
  https://example.com/file3.tar.gz
```

> `-j N` — Maximum number of **parallel downloads**. Default is `5`.

### Method 2 — Per-URI Options With the `--` Separator

When you need different options for each URI, use the `--` separator between URI groups:

```bash
aria2c \
  -d /data/itachi/isos/ -o arch.iso "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso" \
  -- \
  -d /data/itachi/AppImages/ -o zen.AppImage "https://github.com/zen-browser/desktop/releases/latest/download/zen.AppImage" \
  -- \
  -d /home/user/downloads/ "https://example.com/document.pdf"
```

Each `--` block defines one download with its own `-d` and `-o`. This is the cleanest way to batch-download files to different locations in one command.

### Control Parallel Count Across a Batch

```bash
aria2c -j 2 \
  -d /data/itachi/isos/ "https://example.com/arch.iso" \
  -- \
  -d /data/itachi/isos/ "https://example.com/ubuntu.iso" \
  -- \
  -d /data/itachi/isos/ "https://example.com/fedora.iso"
```

Only 2 of the 3 downloads run at the same time. When one finishes, the third starts.

---

## 9. Input Files — Batch Downloads From a List

For large batches, putting everything on the command line is impractical. aria2c accepts an **input file** that lists URIs and per-download options.

### Basic Input File Format

Create a file called `downloads.txt`:

```
https://example.com/file1.iso
https://example.com/file2.tar.gz
https://example.com/file3.AppImage
```

Run it:

```bash
aria2c -i downloads.txt
```

### Per-Download Options in the Input File

Each URI block can have indented option lines immediately below it:

```
https://example.com/arch.iso
  dir=/data/itachi/isos
  out=arch-linux.iso

https://example.com/app.AppImage
  dir=/data/itachi/AppImages
  out=myapp.AppImage

https://mirror1.example.com/ubuntu.iso
https://mirror2.example.com/ubuntu.iso
  dir=/data/itachi/isos
  out=ubuntu-24.04.iso
```

> **Note:** Multiple URIs without a blank line between them are treated as **mirrors for the same file**.

Run with parallel downloads:

```bash
aria2c -j 3 -i downloads.txt
```

### The Full Per-Download Input File Syntax

```
# Lines starting with # are comments

# Single URI
https://example.com/file1.iso
  dir=/data/itachi/isos
  out=file1-renamed.iso
  checksum=sha-256=abc123...

# Two mirrors for the same file — blank line between groups
https://mirror1.example.com/file2.tar.gz
https://mirror2.example.com/file2.tar.gz
  dir=/home/user/downloads
  out=file2.tar.gz
  max-connection-per-server=8

# FTP source
ftp://ftp.example.com/pub/file3.bin
  dir=/tmp
  ftp-user=anonymous
  ftp-passwd=user@example.com
```

---

## 10. Throttling — Rate Limiting Your Downloads

### Limit Download Speed

```bash
aria2c --max-download-limit=2M https://example.com/file.iso
```

> `--max-download-limit=SPEED` — Caps the download speed. Accepts `K` (kilobytes), `M` (megabytes), `G` (gigabytes) suffixes. `0` means unlimited.

Short form:

```bash
aria2c --max-download-limit=500K https://example.com/file.iso
```

### Limit Upload Speed (for BitTorrent)

```bash
aria2c --max-upload-limit=100K myfile.torrent
```

### Set Both at Once

```bash
aria2c \
  --max-download-limit=5M \
  --max-upload-limit=500K \
  myfile.torrent
```

---

## 11. Authentication — HTTP, FTP, and Proxies

### HTTP Basic Authentication

```bash
aria2c --http-user=myuser --http-passwd=mypassword https://private.example.com/file.zip
```

Or encode it in the URL (less safe — appears in shell history and `ps` output):

```bash
aria2c https://myuser:mypassword@private.example.com/file.zip
```

### FTP Authentication

```bash
aria2c --ftp-user=ftpuser --ftp-passwd=ftppassword ftp://ftp.example.com/file.bin
```

Anonymous FTP (most public FTP servers):

```bash
aria2c ftp://ftp.example.com/pub/file.bin
```

aria2c uses `ANONYMOUS` as the username and an empty password by default for FTP.

### HTTP Proxy

```bash
aria2c --http-proxy=http://proxy.example.com:8080 https://example.com/file.iso
```

With authentication:

```bash
aria2c \
  --http-proxy=http://proxy.example.com:8080 \
  --http-proxy-user=proxyuser \
  --http-proxy-passwd=proxypassword \
  https://example.com/file.iso
```

### SOCKS5 Proxy

```bash
aria2c --all-proxy=socks5://127.0.0.1:1080 https://example.com/file.iso
```

> `--all-proxy` applies to all protocols (HTTP, FTP, BitTorrent trackers).

### Skip Proxy for Specific Hosts

```bash
aria2c \
  --http-proxy=http://proxy.example.com:8080 \
  --no-proxy=internal.example.com,192.168.0.0/16 \
  https://example.com/file.iso
```

---

## 12. BitTorrent Downloads

### Download a Torrent File

```bash
aria2c myfile.torrent
```

### Download a Torrent to a Specific Directory

```bash
aria2c -d /data/itachi/torrents/ myfile.torrent
```

### Download a Magnet Link

```bash
aria2c "magnet:?xt=urn:btih:HASH&dn=filename&tr=https://tracker.example.com/announce"
```

Always quote magnet links — the `&` character has special meaning in most shells.

### Limit Seeding After Download

By default aria2c seeds indefinitely. Stop seeding when the ratio reaches 1.0 (you've uploaded as much as you downloaded):

```bash
aria2c --seed-ratio=1.0 myfile.torrent
```

Stop seeding after a time limit (seconds):

```bash
aria2c --seed-time=30 myfile.torrent
```

Stop seeding immediately after download (no seeding at all):

```bash
aria2c --seed-time=0 myfile.torrent
```

### Control BitTorrent Connections

```bash
aria2c \
  --bt-max-peers=50 \
  --bt-request-peer-speed-limit=1M \
  --max-upload-limit=500K \
  myfile.torrent
```

### Download Only Specific Files From a Torrent

First, list the files in the torrent without downloading:

```bash
aria2c --show-files myfile.torrent
```

Output:
```
Files:
idx|path/length
===+==============================================
  1|ubuntu-24.04/ubuntu-24.04.iso
     |4,048,357,376 bytes
  2|ubuntu-24.04/ubuntu-24.04.iso.sha256
     |95 bytes
```

Download only index 1:

```bash
aria2c --select-file=1 myfile.torrent
```

Download indices 1 and 3 (comma-separated):

```bash
aria2c --select-file=1,3 myfile.torrent
```

Download a range:

```bash
aria2c --select-file=1-3 myfile.torrent
```

---

## 13. Metalink Downloads

Metalink is an XML format that lists multiple mirrors for the same file along with checksums. aria2c handles them natively.

```bash
aria2c https://example.com/file.meta4
```

Or a local metalink:

```bash
aria2c /path/to/file.metalink
```

aria2c reads the mirror list from the metalink, verifies the checksum automatically, and downloads from multiple mirrors simultaneously. You do not need to pass any extra flags for verification — it is built into the metalink spec.

---

## 14. Headers, User-Agents, and Cookies

### Set a Custom User-Agent

Some servers block the default `aria2` user agent. Override it:

```bash
aria2c \
  --user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0" \
  https://example.com/file.iso
```

### Add a Custom HTTP Header

```bash
aria2c \
  --header="Accept-Language: en-US,en;q=0.9" \
  --header="Referer: https://example.com/" \
  https://example.com/file.iso
```

Use `--header` multiple times for multiple headers.

### Use a Referrer Header

```bash
aria2c \
  --referer="https://example.com/download-page" \
  https://cdn.example.com/protected-file.zip
```

### Use Cookies From a File

Export cookies from your browser (Netscape/Mozilla format) and pass them:

```bash
aria2c --load-cookies=/home/user/.config/cookies.txt https://example.com/member-file.zip
```

Firefox exports cookies in the correct format. In Firefox, use the "Export Cookies" extension or copy `cookies.sqlite` and convert it.

### Set a Cookie Directly

```bash
aria2c --header="Cookie: session=abc123; auth=xyz789" https://example.com/file.zip
```

---

## 15. Checksum Verification

aria2c can verify a completed download against a known checksum. If verification fails, the download is deleted automatically.

### SHA-256 Verification

```bash
aria2c \
  --checksum=sha-256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 \
  https://example.com/file.iso
```

### SHA-1 Verification

```bash
aria2c \
  --checksum=sha-1=da39a3ee5e6b4b0d3255bfef95601890afd80709 \
  https://example.com/file.iso
```

### MD5 Verification

```bash
aria2c \
  --checksum=md5=d41d8cd98f00b204e9800998ecf8427e \
  https://example.com/file.iso
```

### The Format

```
--checksum=TYPE=HASH
```

Supported types: `md5`, `sha-1`, `sha-224`, `sha-256`, `sha-384`, `sha-512`.

> **Tip:** For ISOs and large files, always use `sha-256` or better. MD5 is collision-vulnerable and should only be used when that is the only hash the source provides.

### What Happens on Mismatch

If the checksum does not match:

```
Download Results:
gid   |stat|avg speed  |path/URI
======+====+===========+=======================================================
abcdef|ERR |  10MiB/s  |/home/user/file.iso
```

The file is **removed**. The `.aria2` control file remains so you can retry.

---

## 16. The aria2c Configuration File

Putting your preferred options on the command line every time is repetitive. aria2c supports a persistent config file.

### Location

```
~/.config/aria2/aria2.conf
```

Create the directory if it does not exist:

```bash
mkdir -p ~/.config/aria2
```

### A Practical Config File

```ini
# ~/.config/aria2/aria2.conf

# ─── Connections ───────────────────────────────────────────────────────────────
# Open up to 16 connections per server
max-connection-per-server=16
# Split each file into 16 segments
split=16
# Minimum segment size — don't split smaller than this
min-split-size=1M

# ─── Resume ────────────────────────────────────────────────────────────────────
# Always attempt to resume partial downloads
continue=true

# ─── Parallel Downloads ─────────────────────────────────────────────────────────
# Max simultaneous downloads when using -i or multiple URIs
max-concurrent-downloads=5

# ─── Output ────────────────────────────────────────────────────────────────────
# Default download directory (override with -d on the command line)
dir=/data/itachi/downloads

# ─── File Allocation ───────────────────────────────────────────────────────────
# prealloc: allocates disk space before downloading (fast seek, slow start)
# none: no preallocation (fastest start, may fragment)
# falloc: fastest preallocation on filesystems that support fallocate()
file-allocation=falloc

# ─── Disk Cache ────────────────────────────────────────────────────────────────
# Buffer writes in memory before flushing to disk
# Reduces write amplification on SSDs
disk-cache=64M

# ─── Retry ─────────────────────────────────────────────────────────────────────
max-tries=5
retry-wait=3

# ─── Console ───────────────────────────────────────────────────────────────────
# Show a summary on completion
summary-interval=0
```

### Using a Non-Default Config File

```bash
aria2c --conf-path=/path/to/custom.conf https://example.com/file.iso
```

### Disabling the Config File for One Run

```bash
aria2c --no-conf https://example.com/file.iso
```

---

## 17. aria2c as a Daemon — RPC Mode

aria2c can run as a background daemon exposing a JSON-RPC interface. This is how GUI frontends (like `uget`, `aria2-webui`, `Motrix`) communicate with it.

### Start aria2c in Daemon Mode

```bash
aria2c \
  --enable-rpc \
  --rpc-listen-all=true \
  --rpc-listen-port=6800 \
  --rpc-secret=your_secret_token \
  --daemon=true \
  --log=/var/log/aria2.log
```

> `--daemon=true` forks aria2c to the background. `--log` writes output to a file instead of the terminal.

### Start With Your Config

Put the RPC options in your config file and run:

```bash
aria2c --enable-rpc --daemon=true
```

### Send Downloads to the Daemon From the Terminal

Once the daemon is running, you can add downloads to it using `curl` and the JSON-RPC API:

```bash
curl http://localhost:6800/jsonrpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "aria2.addUri",
    "id": "1",
    "params": [
      "token:your_secret_token",
      ["https://example.com/file.iso"],
      {"dir": "/data/itachi/isos", "out": "file.iso"}
    ]
  }'
```

### Stop the Daemon

```bash
curl http://localhost:6800/jsonrpc \
  -d '{"jsonrpc":"2.0","method":"aria2.shutdown","id":"1","params":["token:your_secret_token"]}'
```

### A systemd User Unit for Auto-Start

Create `~/.config/systemd/user/aria2.service`:

```ini
[Unit]
Description=aria2 Download Daemon
After=network.target

[Service]
Type=forking
ExecStart=aria2c \
  --enable-rpc \
  --rpc-listen-port=6800 \
  --rpc-secret=your_secret_token \
  --rpc-listen-all=true \
  --daemon=true \
  --log=%h/.local/share/aria2/aria2.log \
  --save-session=%h/.local/share/aria2/session.gz \
  --input-file=%h/.local/share/aria2/session.gz \
  --conf-path=%h/.config/aria2/aria2.conf
ExecStop=/usr/bin/killall -s TERM aria2c
Restart=on-failure

[Install]
WantedBy=default.target
```

Enable and start it:

```bash
systemctl --user enable aria2.service
systemctl --user start aria2.service
systemctl --user status aria2.service
```

---

## 18. Practical Real-World Examples

### Download a Linux ISO With Full Speed and Verification

```bash
aria2c \
  -x 16 -s 16 -k 1M \
  -d /data/itachi/isos/ \
  -o arch-2026.06.iso \
  --checksum=sha-256=PASTE_HASH_HERE \
  -c \
  "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
```

### Download an AppImage to Your AppImage Folder

```bash
aria2c \
  -x 16 -s 16 \
  -d /data/itachi/AppImages/ \
  -o zen-browser.AppImage \
  "https://github.com/zen-browser/desktop/releases/latest/download/zen-x86_64.AppImage"
```

### Download a GitHub Release Binary

```bash
aria2c \
  -x 8 -s 8 \
  -d /data/itachi/AppImages/ \
  --header="Accept: application/octet-stream" \
  "https://github.com/localsend/localsend/releases/download/v1.15.0/LocalSend-1.15.0-linux-x86-64.AppImage"
```

### Batch Download Distro ISOs From a Mirror List File

```bash
# isos.txt
https://mirror1.example.com/arch.iso
https://mirror2.example.com/arch.iso
  dir=/data/itachi/isos
  out=arch-latest.iso

https://mirror1.example.com/fedora.iso
  dir=/data/itachi/isos
  out=fedora-41.iso
  checksum=sha-256=HASH_HERE
```

```bash
aria2c -j 2 -c -i isos.txt
```

### Download and Immediately Verify an OBS Build Artifact

```bash
aria2c \
  -x 16 -s 16 \
  -d /tmp/obs-build/ \
  --checksum=sha-256=$(curl -sL https://obs.example.com/file.sha256 | awk '{print $1}') \
  "https://obs.example.com/file.rpm"
```

### Mirror an Entire FTP Directory (Recursive)

aria2c does not do recursive downloads natively. Use `lftp` for that, or combine with `wget --spider` to generate the URL list and pipe to aria2c:

```bash
wget --spider --recursive --no-parent --quiet \
  -o /tmp/wget-spider.log \
  ftp://ftp.example.com/pub/packages/

grep "^--" /tmp/wget-spider.log | awk '{print $3}' > /tmp/ftp-urls.txt

aria2c -j 5 -x 4 -d /data/itachi/mirror/ -i /tmp/ftp-urls.txt
```

### Throttled Background Download (Polite to Other Traffic)

```bash
aria2c \
  -x 4 -s 4 \
  --max-download-limit=2M \
  -d /data/itachi/downloads/ \
  -c \
  "https://example.com/large-file.tar.gz" &
```

The `&` puts it in the background. Use `fg` to bring it back.

### Download With a Session File for True Persistence

```bash
aria2c \
  --save-session=/tmp/aria2-session.gz \
  --save-session-interval=30 \
  -i downloads.txt
```

If killed, resume everything from where it left off:

```bash
aria2c \
  --save-session=/tmp/aria2-session.gz \
  --save-session-interval=30 \
  --input-file=/tmp/aria2-session.gz
```

---

## 19. Exit Codes and What They Mean

| Code | Meaning |
|---|---|
| `0` | All downloads completed successfully |
| `1` | Unknown error |
| `2` | Timeout |
| `3` | Resource not found (404 etc.) |
| `4` | Too many redirects or auth failures |
| `5` | Not enough disk space |
| `6` | Piece length mismatch (torrent/metalink) |
| `7` | Too many redirects |
| `8` | Resume not supported by server |
| `9` | Not enough memory |
| `10` | Piece checksum failed |
| `11` | BitTorrent metadata failed |
| `12` | Torrent file already exists |
| `13` | File already exists |
| `14` | File rename failed |
| `15` | Failed to open existing file |
| `16` | Failed to create new file/truncate |
| `17` | File I/O error |
| `18` | Failed to create directory |
| `19` | Name resolution failed (DNS) |
| `20` | Failed to parse metalink |
| `21` | FTP command failed |
| `22` | HTTP response header not OK |
| `23` | Too many redirects |
| `24` | HTTP authorization failed |
| `25` | Failed to parse bencoded data (torrent) |
| `26` | Torrent is corrupted |
| `27` | Magnet URI corrupted |
| `28` | Bad option / invalid option |
| `29` | Server returned redirect to already-trying URI |
| `30` | No URIs to download |
| `31` | Checksum mismatch |
| `32` | Parsing BitTorrent Extended Message failed |

Check the exit code in a script:

```bash
aria2c https://example.com/file.iso
EXIT=$?
if [ $EXIT -ne 0 ]; then
  echo "Download failed with exit code $EXIT"
fi
```

---

## 20. Troubleshooting

### "HTTP response header was not OK"

The server returned a non-2xx status. Check:
- The URL is correct and accessible in a browser
- You have the right credentials
- Try with `--user-agent` to mimic a browser

### "Cannot determine the filename from the URI"

The URL does not have a clear filename (e.g., ends in `/` or has query parameters). Use `-o` to set one:

```bash
aria2c -o output-filename.zip "https://example.com/download?id=123&format=zip"
```

### "File already exists"

aria2c refuses to overwrite by default. Options:
- Use `-c` to resume it if it is a partial download
- Use `--allow-overwrite=true` to overwrite
- Delete the existing file manually

### "Name resolution failed"

DNS issue. Check your network:

```bash
ping -c 2 8.8.8.8         # check raw connectivity
dig example.com           # check DNS resolution
```

### "Connection refused" on RPC mode

- Check if the daemon is actually running: `pgrep -a aria2c`
- Check the port: `ss -tlnp | grep 6800`
- Check the secret token matches
- Check `--rpc-listen-all=true` if connecting from a non-localhost address

### Slow Speed Despite `-x 16`

- The server may enforce a per-IP connection limit. Try `-x 4` or `-x 8`.
- The server may simply be slow. Use a mirror list.
- Your disk write speed may be the bottleneck. Check with `iostat -x 1`.

### Downloads Always Restart Instead of Resuming

The `.aria2` control file is missing. This happens if:
- You moved the partial file without moving the `.aria2` file
- Something deleted the `.aria2` file

If you still want to try resuming without the control file, use `--always-resume=false`. aria2c will do a partial content check where possible.

---

## 21. Quick Reference Cheatsheet

```bash
# ─── Basic ────────────────────────────────────────────────────────────────────
aria2c URL                                    # Download URL to current dir
aria2c -o name.ext URL                        # Custom filename
aria2c -d /path/to/dir/ URL                   # Custom directory
aria2c -d /path/to/dir/ -o name.ext URL       # Both

# ─── Speed ───────────────────────────────────────────────────────────────────
aria2c -x 16 -s 16 -k 1M URL                 # Max connections + segments
aria2c --max-download-limit=5M URL            # Cap speed at 5MB/s

# ─── Resume ──────────────────────────────────────────────────────────────────
aria2c -c URL                                 # Resume from partial file

# ─── Multiple Files ───────────────────────────────────────────────────────────
aria2c -j 4 URL1 URL2 URL3                    # 4 parallel downloads
aria2c -i downloads.txt                       # From input file

# ─── Mirrors ─────────────────────────────────────────────────────────────────
aria2c URL1 URL2 URL3                         # 3 mirrors = same file

# ─── Verification ────────────────────────────────────────────────────────────
aria2c --checksum=sha-256=HASH URL            # Verify after download

# ─── Torrent ─────────────────────────────────────────────────────────────────
aria2c file.torrent                           # From .torrent file
aria2c "magnet:?xt=urn:btih:HASH"            # From magnet link
aria2c --seed-time=0 file.torrent             # Download only, no seeding

# ─── Headers and Auth ─────────────────────────────────────────────────────────
aria2c --user-agent="Mozilla/5.0 ..." URL     # Custom user agent
aria2c --header="Referer: https://..." URL    # Custom header
aria2c --http-user=u --http-passwd=p URL      # HTTP auth
aria2c --http-proxy=http://proxy:8080 URL     # Proxy

# ─── RPC Daemon ──────────────────────────────────────────────────────────────
aria2c --enable-rpc --rpc-secret=TOKEN --daemon=true    # Start daemon
```

---

## The Problem This Guide Solves

You knew `wget` and `curl` existed. You did not know there was a single tool that handled everything from multi-mirror ISO downloads to BitTorrent seeding to batch file input with per-file directory control — all from the terminal, with no daemon required for basic use.

Now you do.

---

*Part of the [Clean System Guide](./README.md) — guides born from real problems.*
