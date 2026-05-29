# FFmpeg Complete Guide

> Encoding, decoding, converting, and processing video/audio — every flag explained.
> Covers codec trade-offs, quality settings, AMD hardware acceleration, and batch automation.
> No black boxes. No blind copy-paste.

---

## What Is This?

A command-by-command reference for FFmpeg 7.x. Every flag is explained so you know
what it does before running it. Covers CPU and AMD GPU (AMF) encoding, all major codecs,
container formats, and real-world use-case recipes.

**Philosophy:** Choose codecs with intent. Understand the quality/size/speed triangle.
Automate batch work. Keep audio and video decisions separate.

---

## Environment

| | |
|---|---|
| **FFmpeg Version** | 7.x (latest stable) |
| **Target System** | Linux (openSUSE) |
| **Hardware** | AMD CPU + AMD GPU (AMF hardware acceleration) |
| **Install Method** | Static binary — no package manager required |

---

## Getting FFmpeg (Portable, No Package Manager)

```bash
# Download latest static build (includes all codecs compiled in)
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar -xf ffmpeg-release-amd64-static.tar.xz

# Move to your AppImages directory
mv ffmpeg-7.*-amd64-static/ffmpeg   /data/itachi/AppImages/
mv ffmpeg-7.*-amd64-static/ffprobe  /data/itachi/AppImages/

# Add aliases in ~/.bashrc
alias ffmpeg='/data/itachi/AppImages/ffmpeg'
alias ffprobe='/data/itachi/AppImages/ffprobe'
```

Verify codecs and hardware support:

```bash
ffmpeg -encoders | grep -E "libx264|libx265|libsvtav1|libopus|amf"
ffmpeg -hwaccels                       # list hardware acceleration methods
ffmpeg -encoders | grep amf            # check AMD AMF availability
```

> The static build includes libx264, libx265, libsvtav1, libvpx-vp9, libopus, libmp3lame,
> and usually AMF. If AMF is missing, you need a build with `--enable-amf`.

---

## Quick Reference: Codec Decision Tree

```
What matters most?
│
├─ Compatibility first (must work on any device/player)
│   └── H.264 (libx264) + AAC  →  .mp4
│
├─ Best compression, modern players OK
│   ├── H.265 (libx265) + AAC  →  .mkv/.mp4   (~50% smaller than H.264)
│   └── AV1 (libsvtav1) + Opus  →  .mkv        (~30% smaller than H.265)
│
├─ Speed is critical (live, real-time, batch)
│   ├── CPU fast:  libx264 -preset veryfast
│   └── AMD GPU:   h264_amf / hevc_amf          (5–10× faster than CPU)
│
├─ Web delivery
│   ├── Broadest:  H.264 + AAC  →  .mp4
│   └── Modern:    AV1 + Opus   →  .webm
│
├─ Archival / lossless
│   └── libx265 -crf 18 + FLAC  →  .mkv
│
└─ Audio only
    ├── Lossless:  FLAC  →  .flac
    ├── Modern:    Opus  →  .opus / .ogg
    └── Legacy:    MP3   →  .mp3
```

---

## Part 1 — Core Concepts

### Streams, Containers, and Codecs

| Term | What It Is |
|---|---|
| **Container** | The file wrapper: MP4, MKV, WebM — holds video, audio, subtitles, metadata |
| **Codec** | The compression algorithm: H.264, H.265, AV1, AAC, Opus |
| **Stream** | One individual track — a video stream, an audio stream, a subtitle track |
| **Bitrate** | Data per second (kbps, Mbps) — higher = better quality + larger file |
| **CRF** | Constant Rate Factor — targets a visual quality level, not a specific bitrate |
| **Preset** | Speed/compression trade-off — slower = smaller file at same quality |

### Basic FFmpeg Syntax

```bash
ffmpeg [global options] [input options] -i INPUT [output options] OUTPUT
```

The order matters: options placed **before** `-i` apply to the input. Options placed
**after** `-i` apply to the output.

### Essential Flags

| Flag | What It Does |
|---|---|
| `-c:v CODEC` | Set video codec (`copy` = passthrough, no re-encode) |
| `-c:a CODEC` | Set audio codec (`copy` = passthrough) |
| `-c copy` | Copy ALL streams — fastest, no quality loss |
| `-crf N` | Quality target (lower = better quality + bigger file) |
| `-b:v RATE` | Video bitrate target (`5M` = 5 Mbps, `500k` = 500 kbps) |
| `-b:a RATE` | Audio bitrate target (`192k`, `128k`, etc.) |
| `-preset NAME` | Encoding speed preset (codec-specific) |
| `-vf FILTER` | Video filter chain (scale, crop, etc.) |
| `-af FILTER` | Audio filter chain (normalize, volume, etc.) |
| `-ss TIME` | Seek to timestamp (`00:01:30` or `90`) |
| `-to TIME` | End at timestamp |
| `-t DURATION` | Encode for a duration |
| `-map 0:v:0` | Select specific stream by type and index |
| `-threads N` | CPU thread count (`0` = auto, recommended) |
| `-movflags +faststart` | Move MP4 index to front (for web streaming) |
| `-pix_fmt yuv420p` | Force pixel format (required for broad compatibility) |

### Inspect Before You Encode

```bash
# Full stream info as JSON
ffprobe -v quiet -print_format json -show_streams input.mkv

# Quick human-readable summary
ffprobe -v error \
  -show_entries stream=codec_name,codec_type,width,height,r_frame_rate,bit_rate \
  -of default=noprint_wrappers=1 input.mkv

# File container/format info
ffprobe -v error -show_format input.mkv
```

---

## Part 2 — Video Codecs

### 2.1 H.264 — `libx264`

**Best for:** Maximum compatibility. Every device, browser, and player supports H.264.
Web delivery, streaming, general archival where file size isn't critical.

**Container:** MP4 (most common), MKV, MOV
**AMD GPU variant:** `h264_amf`

#### Basic Encode

```bash
ffmpeg -i input.mkv -c:v libx264 -crf 23 -preset slow -c:a copy output.mp4
```

#### CRF Quality Scale (0–51)

| CRF | Quality | File Size | Use Case |
|---|---|---|---|
| 0 | Lossless | Enormous | Not useful in practice |
| 18 | Visually lossless | Very large | Source/master archival |
| 20–22 | Excellent | Large | High-quality archival |
| **23** | **Good — default** | **Medium** | **General use** |
| 26–28 | Acceptable | Small | Web, streaming |
| 30+ | Noticeable degradation | Very small | Avoid unless size is critical |

> Rule of thumb: +6 CRF ≈ double the file size (or half, going the other way).

#### Presets (Speed ↔ Compression Efficiency)

```bash
-preset ultrafast   # Fastest encode — worst compression ratio
-preset veryfast    # Good for screen recording, real-time
-preset fast        # Good balance for batch work
-preset medium      # Default — reasonable speed
-preset slow        # Better compression, takes more time  ← recommended
-preset veryslow    # Best compression, significantly slower
```

> On AMD Ryzen (8–16+ cores), `slow` and `veryslow` make use of parallelism effectively.
> Always pair with `-threads 0` for auto thread allocation.

#### Web-Ready MP4 (Broadest Compatibility)

```bash
ffmpeg -i input.mkv \
  -c:v libx264 -crf 23 -preset slow \
  -profile:v high -level:v 4.1 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  -c:a aac -b:a 192k \
  output.mp4
```

- `-profile:v high -level:v 4.1` — supports older TVs and phones
- `-pix_fmt yuv420p` — required for older players (eliminates 4:2:2 compatibility issues)
- `-movflags +faststart` — moves the MP4 index to the front; browser can start playing
  before fully downloaded

#### Two-Pass (Precise Bitrate / File Size Control)

When you need a specific file size (e.g. upload limits):

```bash
# Pass 1 — analysis run (no output file, writes stats)
ffmpeg -i input.mkv -c:v libx264 -b:v 4M -pass 1 -an -f null /dev/null

# Pass 2 — actual encode using analysis data
ffmpeg -i input.mkv -c:v libx264 -b:v 4M -pass 2 -c:a aac -b:a 192k output.mp4
```

---

### 2.2 H.265 / HEVC — `libx265`

**Best for:** Archival, 4K, situations where file size matters.
~40–50% smaller than H.264 at equivalent visual quality.

**Tradeoff:** 2–4× slower encode than libx264. Less compatible with older hardware.
**Container:** MKV (preferred), MP4
**AMD GPU variant:** `hevc_amf`

#### Basic Encode

```bash
ffmpeg -i input.mkv -c:v libx265 -crf 28 -preset slow -c:a copy output.mkv
```

#### CRF Equivalence to H.264

| x265 CRF | Equivalent x264 CRF | Visual Quality |
|---|---|---|
| 20 | ~14 | Near-lossless |
| 24 | ~18 | Visually lossless |
| **28** | **~23 (x264 default)** | **General use** |
| 32 | ~28 | Acceptable |

> Same perceived quality at ~50% smaller file vs H.264.

#### Tuning for Content Type

```bash
# Film/live-action with natural grain — preserve it
ffmpeg -i input.mkv -c:v libx265 -crf 22 -preset slow -tune grain output.mkv

# Animation / anime — flat colors, different characteristics
ffmpeg -i input.mkv -c:v libx265 -crf 22 -preset slow -tune animation output.mkv

# Fast decode priority (e.g. for slow playback devices)
ffmpeg -i input.mkv -c:v libx265 -crf 28 -preset slow -tune fastdecode output.mkv
```

#### 4K HDR Content

```bash
ffmpeg -i input_4k_hdr.mkv \
  -c:v libx265 -crf 20 -preset slow \
  -color_primaries bt2020 \
  -color_trc smpte2084 \
  -colorspace bt2020nc \
  -x265-params "hdr-opt=1:repeat-headers=1" \
  -c:a copy \
  output_4k_hdr.mkv
```

---

### 2.3 AV1

AV1 is the next-generation royalty-free codec. Three CPU encoder implementations exist —
they are **not interchangeable** and use different syntax.

| Encoder | Flag | Speed | Quality | Verdict |
|---|---|---|---|---|
| SVT-AV1 | `libsvtav1` | Fast (near x265) | Near-reference | **Use this** |
| libaom | `libaom-av1` | Very slow | Reference ceiling | Benchmarking only |
| rav1e | `librav1e` | Slow | Good | Alternative to SVT |

**AMD GPU variant:** `av1_amf` (requires RDNA 3 / RX 7000 series or newer)

---

#### AV1 via SVT-AV1 — `libsvtav1` ← Recommended

```bash
ffmpeg -threads 0 -i input.mkv \
  -c:v libsvtav1 -crf 28 -preset 5 \
  -c:a libopus -b:a 128k \
  output.mkv
```

SVT-AV1 uses numeric presets (NOT names like "slow"):

| Preset | Quality | Speed | Use For |
|---|---|---|---|
| 0–2 | Highest | Extremely slow | Ultra-quality archival |
| 3–5 | Excellent | Slow | High-quality archival |
| **5–6** | **Very good** | **Moderate** | **General use** |
| 7–9 | Good | Fast | Batch conversion |
| 10–12 | Acceptable | Very fast | Preview / draft |

CRF scale for SVT-AV1:

| CRF | Quality Level |
|---|---|
| 20–24 | Visually lossless |
| 25–30 | High quality (general use) |
| 31–38 | Acceptable (size priority) |
| 39+ | Noticeable degradation |

Film grain synthesis (recommended for live-action — strips, re-adds at decode):

```bash
ffmpeg -threads 0 -i input.mkv \
  -c:v libsvtav1 -crf 28 -preset 5 \
  -svtav1-params "tune=0:film-grain=8:film-grain-denoise=1" \
  -c:a libopus -b:a 128k \
  output.mkv
```

- `tune=0` — PSNR-optimized (default). `tune=1` = SSIM. `tune=2` = subjective quality
- `film-grain=0` off, `8` moderate, `15` heavy — matches real film sources well
- `film-grain-denoise=1` — denoise before synthesizing grain (better compression)

AMD multi-core SVT-AV1 tuning:

```bash
ffmpeg -threads 0 -i input.mkv \
  -c:v libsvtav1 -crf 28 -preset 5 \
  -svtav1-params "lp=0:pin=0:film-grain=8" \
  -c:a libopus -b:a 128k \
  output.mkv
```

- `lp=0` — auto logical processor count (lets SVT-AV1 use all cores)
- `pin=0` — disable thread pinning (important on AMD Ryzen multi-CCX chips; avoids NUMA
  bottlenecks between CCD clusters on Ryzen 9 etc.)

---

#### AV1 via libaom — `libaom-av1` (Reference Only, Very Slow)

```bash
# DO NOT use for regular encoding — use only to measure quality ceiling
ffmpeg -i input.mkv -c:v libaom-av1 -crf 30 -b:v 0 -cpu-used 4 output.mkv
```

- `-b:v 0` is **required** for CRF mode with libaom
- `-cpu-used 0` (slowest/best) to `8` (fastest)
- At `cpu-used 0`, encoding 1 hour of 1080p can take many hours

---

#### AV1 via rav1e — `librav1e`

```bash
ffmpeg -i input.mkv -c:v librav1e -qp 80 -speed 6 -c:a copy output.mkv
```

- `-qp` 0–255 (lower = better quality). 80–100 ≈ SVT-AV1 CRF 30
- `-speed` 0 (slowest) to 10 (fastest)

---

### 2.4 VP9 — `libvpx-vp9`

**Best for:** WebM delivery, YouTube uploads. Royalty-free, good browser support.
AV1 is the better choice for new work; VP9 still has broader hardware decode support.

```bash
# CRF mode (recommended — quality-based, not bitrate-based)
ffmpeg -i input.mkv \
  -c:v libvpx-vp9 -crf 31 -b:v 0 \
  -deadline good -cpu-used 2 \
  -c:a libopus -b:a 128k \
  output.webm
```

| Flag | Values | Notes |
|---|---|---|
| `-crf` | 15–44 | Lower = better. 31 is a typical general-purpose value |
| `-b:v 0` | Must be 0 | Required when using CRF mode |
| `-deadline` | `good` / `best` / `realtime` | `good` is the practical default |
| `-cpu-used` | 0–5 | 0 = slowest/best quality, 5 = fastest |

Two-pass VP9 for target bitrate (e.g. YouTube upload):

```bash
ffmpeg -i input.mkv -c:v libvpx-vp9 -b:v 4M -pass 1 -an -f null /dev/null
ffmpeg -i input.mkv -c:v libvpx-vp9 -b:v 4M -pass 2 \
  -c:a libopus -b:a 192k output.webm
```

---

### 2.5 AMD Hardware Encoding — AMF

AMD's Advanced Media Framework (AMF) uses the Video Core Next (VCN) engine on the GPU.
Encoding speed is 5–10× faster than CPU, with a modest quality trade-off at equivalent
bitrate. Best used when speed matters more than absolute quality (batch jobs, streaming).

**GPU requirements:**
- H.264 AMF: GCN 2+ (Radeon HD 7000 and newer)
- H.265 AMF: GCN 4+ (Polaris / RX 400 series and newer)
- AV1 AMF: RDNA 3 (RX 7000 series and newer only)

**Verify AMF is available:**

```bash
ffmpeg -encoders | grep amf
# Expected output:
#  V..... h264_amf         AMD AMF H.264 Encoder
#  V..... hevc_amf         AMD AMF HEVC Encoder
#  V..... av1_amf          AMD AMF AV1 Encoder   ← only on RX 7000+
```

If nothing appears, your FFmpeg build doesn't have AMF support. Get a build with
`--enable-amf`, or install `amf-amdgpu-pro` headers and recompile.

---

#### AMF Rate Control Modes

| Mode | Flag | Notes |
|---|---|---|
| **Constant QP** | `-rc cqp` | Closest to CPU CRF — quality-based. **Recommended** |
| Variable Bitrate | `-rc vbr_latency` | Targets a bitrate, allows fluctuation |
| Constant Bitrate | `-rc cbr` | Strict bitrate — for streaming protocols (RTMP) |
| Peak VBR | `-rc vbr_peak` | VBR with a peak cap |

For `-rc cqp`, use `-qp_i`, `-qp_p`, `-qp_b` to set QP per frame type:
- `-qp_i 20` — I-frames (keyframes) — set lower for better quality
- `-qp_p 22` — P-frames (forward predicted)
- `-qp_b 24` — B-frames (bidirectional) — can be slightly higher

Lower QP = better quality = larger file. Typical useful range: 18–30.

#### AMF Quality Presets

```bash
-quality speed      # Fastest GPU encode, lowest quality
-quality balanced   # Default
-quality quality    # Best quality, still much faster than CPU
```

#### H.264 via AMD GPU — `h264_amf`

```bash
# CQP mode (quality-based)
ffmpeg -i input.mkv \
  -c:v h264_amf -rc cqp -qp_i 20 -qp_p 22 -qp_b 24 \
  -quality quality \
  -c:a aac -b:a 192k \
  output.mp4

# CBR for streaming (e.g. OBS, RTMP)
ffmpeg -i input.mkv \
  -c:v h264_amf -rc cbr -b:v 6M \
  -quality speed \
  -c:a aac -b:a 128k \
  output.mp4
```

#### H.265 via AMD GPU — `hevc_amf`

```bash
# CQP mode — good quality 4K encode
ffmpeg -i input_4k.mkv \
  -c:v hevc_amf -rc cqp -qp_i 22 -qp_p 24 \
  -quality quality \
  -c:a aac -b:a 192k \
  output_4k.mkv
```

#### AV1 via AMD GPU — `av1_amf` (RX 7000 only)

```bash
ffmpeg -i input.mkv \
  -c:v av1_amf -rc cqp -qp_i 22 -qp_p 24 \
  -quality quality \
  -c:a libopus -b:a 128k \
  output.mkv
```

#### AMD Hybrid Pipeline: VAAPI Decode + AMF Encode

Offload decode to the GPU as well (reduces CPU load significantly on large files):

```bash
ffmpeg \
  -hwaccel vaapi \
  -hwaccel_device /dev/dri/renderD128 \
  -hwaccel_output_format vaapi \
  -i input.mkv \
  -c:v hevc_amf -rc cqp -qp_i 22 -quality quality \
  -c:a copy \
  output.mkv
```

If VAAPI decode fails (driver issues), fall back to CPU decode + AMF encode:

```bash
# CPU decode is fine — AMF still does the heavy encode work
ffmpeg -threads 0 -i input.mkv \
  -c:v hevc_amf -rc cqp -qp_i 22 -quality quality \
  -c:a copy output.mkv
```

---

### 2.6 Video Codec Comparison

| Codec | Compression vs H.264 | CPU Encode Speed | Compatibility | Best For |
|---|---|---|---|---|
| `libx264` | Baseline | ⚡⚡⚡⚡ | Universal | Web, general, streaming |
| `libx265` | ~50% smaller | ⚡⚡ | Good (modern) | 4K, archival, space-saving |
| `libsvtav1` | ~65% smaller | ⚡⚡⚡ | Growing fast | Future-proof archival, web |
| `libaom-av1` | ~65% smaller | ⚡ (very slow) | Growing | Reference quality benchmark |
| `libvpx-vp9` | ~50% smaller | ⚡⚡ | Good (browsers) | YouTube, WebM delivery |
| `h264_amf` | H.264 level | ⚡⚡⚡⚡⚡ | Universal | Fast AMD GPU encode |
| `hevc_amf` | H.265 level | ⚡⚡⚡⚡⚡ | Good | Fast AMD GPU, 4K |
| `av1_amf` | AV1 level | ⚡⚡⚡⚡⚡ | Growing | RDNA3 fast AV1 |

---

## Part 3 — Audio Codecs

### 3.1 AAC — `aac` / `libfdk_aac`

**Best for:** MP4 containers, broad device compatibility. The default choice when making
files for phones, TVs, or streaming platforms.

The built-in FFmpeg `aac` encoder is always available and good enough for most use.
`libfdk_aac` produces better quality at the same bitrate but requires a separately
compiled FFmpeg (not in the standard static build due to licensing).

```bash
# Built-in AAC at 192k (good general quality)
ffmpeg -i input.mkv -c:a aac -b:a 192k output.mp4

# AAC 256k (high quality, suitable for music)
ffmpeg -i input.mkv -c:a aac -b:a 256k output.mp4

# VBR AAC (quality-based, recommended over fixed bitrate)
ffmpeg -i input.mkv -c:a aac -q:a 2 output.mp4
# -q:a 1 (best, ~256 kbps) to 5 (worst, ~96 kbps)

# libfdk_aac (if available — better quality at same bitrate)
ffmpeg -i input.mkv -c:a libfdk_aac -b:a 192k -profile:a aac_low output.mp4
```

AAC Bitrate Reference:

| Bitrate | Quality | Suitable For |
|---|---|---|
| 64–96k | Acceptable | Speech, podcasts |
| 128k | Good | General music, streaming |
| 192k | Very good | Standard high quality |
| 256k | Near-transparent | Music archival |
| 320k | Diminishing returns | Use FLAC instead |

---

### 3.2 Opus — `libopus`

**Best for:** Any modern use case. Best lossy audio codec available — 96k Opus ≈ 192k AAC
in perceived quality. Ideal for WebM, MKV, OGG containers.

```bash
# Standard quality (128k is very good for Opus)
ffmpeg -i input.mkv -c:a libopus -b:a 128k output.webm

# High quality music in OGG
ffmpeg -i input.mkv -c:a libopus -b:a 192k output.ogg

# VBR mode (default — enabled by default, explicitly set it)
ffmpeg -i input.mkv -c:a libopus -b:a 128k -vbr on output.mkv

# Low-bitrate speech (calls, commentary)
ffmpeg -i input.mkv -c:a libopus -b:a 48k -vbr on output.ogg

# Application hint (improves encoding decisions for content type)
ffmpeg -i input.mkv -c:a libopus -b:a 128k -application audio output.mkv
# -application audio    = music/general (default)
# -application voip     = optimized for speech
# -application lowdelay = minimum latency
```

Opus Bitrate Reference:

| Bitrate | Quality | Use |
|---|---|---|
| 32k | Speech only | VoIP |
| 64k | Good speech | Podcasts |
| 96k | Good music | General streaming |
| 128k | Very good | Standard HQ |
| 192k | Excellent | High-quality music |

---

### 3.3 MP3 — `libmp3lame`

**Best for:** Legacy compatibility only. For new content, Opus or AAC is always better.
Use MP3 only when the target device/platform genuinely can't handle AAC.

```bash
# VBR MP3 (recommended over fixed bitrate — better quality/size ratio)
ffmpeg -i input.mkv -c:a libmp3lame -q:a 2 output.mp3
# -q:a 0 (best, ~245 kbps avg) to 9 (worst, ~65 kbps avg)

# CBR MP3 (specific bitrate — only when required)
ffmpeg -i input.mkv -c:a libmp3lame -b:a 320k output.mp3

# Extract audio track to MP3
ffmpeg -i input.mkv -vn -c:a libmp3lame -q:a 2 output.mp3
```

---

### 3.4 FLAC — Lossless

**Best for:** Archival, editing source files, lossless quality. ~40–60% size reduction vs
WAV/PCM with zero quality loss.

```bash
# Standard FLAC (lossless)
ffmpeg -i input.wav -c:a flac output.flac

# FLAC compression level (0–12, default 5)
# Higher level = smaller file but slower encode — quality is IDENTICAL at all levels
ffmpeg -i input.wav -c:a flac -compression_level 8 output.flac

# FLAC audio in MKV alongside video
ffmpeg -i input.mkv -c:v copy -c:a flac output.mkv
```

---

### 3.5 Other Audio Codecs

```bash
# PCM — uncompressed (for editing, source files)
ffmpeg -i input.mkv -vn -c:a pcm_s16le output.wav   # 16-bit WAV
ffmpeg -i input.mkv -vn -c:a pcm_s24le output.wav   # 24-bit WAV

# AC3 / Dolby Digital (surround sound — Blu-ray, home theatre)
ffmpeg -i input.mkv -c:a ac3 -b:a 640k output.mkv

# EAC3 / Dolby Digital Plus
ffmpeg -i input.mkv -c:a eac3 -b:a 768k output.mkv

# Vorbis in OGG (legacy open-source format)
ffmpeg -i input.mkv -c:a libvorbis -q:a 6 output.ogg
# -q:a 0–10, 6 ≈ 192 kbps variable
```

---

### 3.6 Audio Codec Comparison

| Codec | Type | Efficiency | Compatibility | Use Case |
|---|---|---|---|---|
| FLAC | Lossless | N/A | Very good | Archival, editing |
| PCM | Lossless | N/A (uncompressed) | Universal | Source/editing only |
| **Opus** | Lossy | Best per bit | Modern | **General modern use** |
| AAC | Lossy | Very good | Universal | MP4, phone, TV |
| Vorbis | Lossy | Good | OGG players | Legacy open-source |
| MP3 | Lossy | Good (legacy) | Universal | Legacy compat only |
| AC3 | Lossy | Good (surround) | Blu-ray / TV | 5.1 surround |

---

## Part 4 — Container Formats

| Container | Ext | Video Support | Audio Support | Subtitles | Use Case |
|---|---|---|---|---|---|
| **MP4** | `.mp4` | H.264, H.265, AV1 | AAC, MP3, AC3 | SRT (basic) | Web, phones, streaming |
| **MKV** | `.mkv` | Any codec | Any codec | SRT, ASS, PGS, VOBSUB | Archival, home media |
| **WebM** | `.webm` | VP8, VP9, AV1 | Vorbis, Opus | WebVTT | Web delivery |
| **MOV** | `.mov` | H.264, H.265, ProRes | AAC, PCM | Basic | Apple ecosystem |
| **OGG** | `.ogg` | Theora | Vorbis, Opus | None | Audio-only |
| **AVI** | `.avi` | H.264 (limited) | MP3, PCM | External only | Legacy only |

### Remuxing (Change Container Without Re-Encoding)

```bash
# MKV → MP4 (no re-encode — instant)
ffmpeg -i input.mkv -c copy output.mp4

# MP4 → MKV
ffmpeg -i input.mp4 -c copy output.mkv

# WARNING: Not all codec+container combinations are valid.
# e.g. Opus audio cannot go into MP4 — re-encode to AAC:
ffmpeg -i input.mkv -c:v copy -c:a aac -b:a 192k output.mp4
```

---

## Part 5 — Common Operations

### 5.1 Cutting and Trimming

```bash
# Fast cut (no re-encode — seeks to nearest keyframe, may be slightly imprecise)
# -ss BEFORE -i = fast keyframe seek
ffmpeg -ss 00:01:30 -to 00:05:00 -i input.mkv -c copy output.mkv

# Accurate cut (re-encodes — precise to the frame)
# -ss AFTER -i = accurate, decodes from start
ffmpeg -i input.mkv -ss 00:01:30 -to 00:05:00 -c:v libx264 -crf 23 -c:a copy output.mp4

# Cut using duration instead of end time
ffmpeg -ss 00:01:30 -t 00:03:30 -i input.mkv -c copy output.mkv
```

> For most cases, fast cut (`-ss` before `-i`) is fine and the imprecision
> (a fraction of a second) is rarely noticeable. Use accurate cut only when
> you need frame-perfect results.

---

### 5.2 Merging and Concatenating

```bash
# Concatenate multiple files of the same format (instant, no re-encode)
cat > concat.txt << 'EOF'
file 'part1.mp4'
file 'part2.mp4'
file 'part3.mp4'
EOF

ffmpeg -f concat -safe 0 -i concat.txt -c copy output.mp4

# Merge separate video and audio files
ffmpeg -i video.mp4 -i audio.aac \
  -map 0:v -map 1:a -c copy \
  output.mp4

# Mix two audio streams into one
ffmpeg -i video.mkv -i extra_audio.aac \
  -filter_complex "[0:a][1:a]amix=inputs=2:duration=first" \
  -c:v copy output.mkv
```

---

### 5.3 Extracting Streams

```bash
# Extract audio — copy stream (no re-encode, fastest)
ffmpeg -i input.mkv -vn -c:a copy output.aac

# Extract audio — re-encode to Opus
ffmpeg -i input.mkv -vn -c:a libopus -b:a 192k output.opus

# Extract video only (drop all audio)
ffmpeg -i input.mkv -an -c:v copy output.mkv

# Extract a specific audio track by index (0 = first, 1 = second)
ffmpeg -i input.mkv -map 0:a:0 -c copy audio_track1.aac
ffmpeg -i input.mkv -map 0:a:1 -c copy audio_track2.aac

# Extract frames as image files
ffmpeg -i input.mkv -vf "fps=1" frame_%04d.png            # 1 frame per second
ffmpeg -i input.mkv -vf "fps=0.1" frame_%04d.png          # 1 frame per 10 seconds
ffmpeg -ss 00:01:30 -i input.mkv -frames:v 1 screenshot.png  # single frame at timestamp
```

---

### 5.4 Scaling and Resizing

```bash
# Scale to width — auto-calculate height to preserve aspect ratio
# -2 means: auto-calculate AND ensure the value is divisible by 2 (required by most codecs)
ffmpeg -i input.mkv -vf "scale=1280:-2" -c:a copy output.mkv

# Downscale 4K (3840×2160) to 1080p (1920×1080)
ffmpeg -i input_4k.mkv -vf "scale=1920:-2" -c:v libx265 -crf 22 -c:a copy output_1080p.mkv

# Scale to exact dimensions (may distort aspect ratio)
ffmpeg -i input.mkv -vf "scale=1920:1080" output.mkv

# Letterbox: scale to 1080p preserving aspect ratio, add black bars
ffmpeg -i input.mkv \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
  output.mkv

# Crop a region (w:h:x:y — top-left origin)
ffmpeg -i input.mkv -vf "crop=1280:720:320:180" output.mkv
```

---

### 5.5 Subtitles

```bash
# Add soft subtitles to MKV (as a separate track — user can toggle on/off)
ffmpeg -i input.mkv -i subtitles.srt \
  -c copy -c:s srt \
  output.mkv

# Burn subtitles into video (hard subs — permanent, no separate track)
ffmpeg -i input.mkv -vf "subtitles=subtitles.srt" \
  -c:v libx264 -crf 23 output.mp4

# Burn styled ASS/SSA subtitles (preserves styling, fonts, positioning)
ffmpeg -i input.mkv -vf "ass=subtitles.ass" \
  -c:v libx264 -crf 23 output.mp4

# Extract subtitle track to SRT
ffmpeg -i input.mkv -map 0:s:0 output.srt   # first subtitle stream
```

---

### 5.6 Video Filters

```bash
# Rotate 90° clockwise
ffmpeg -i input.mkv -vf "transpose=1" output.mkv
# transpose=0: 90° CCW + flip  |  1: 90° CW  |  2: 90° CCW  |  3: 90° CW + flip

# Deinterlace (old broadcast/DVD content)
ffmpeg -i input.mkv -vf "yadif=1" -c:v libx264 -crf 23 output.mkv
# yadif=0: frame-based  |  1: field-based (smoother motion, double framerate)

# Denoise (useful for noisy sources — reduces encoder bitrate requirements)
ffmpeg -i input.mkv -vf "hqdn3d=4:3:6:4.5" -c:v libx264 -crf 23 output.mkv
# hqdn3d=luma_spatial:chroma_spatial:luma_temporal:chroma_temporal

# Sharpen slightly
ffmpeg -i input.mkv -vf "unsharp=5:5:1.0:5:5:0.0" -c:v libx264 -crf 23 output.mkv

# Increase framerate using motion interpolation
ffmpeg -i input.mkv -vf "minterpolate=fps=60:mi_mode=mci" -c:v libx264 -crf 23 output.mkv

# Chain filters with commas
ffmpeg -i input.mkv \
  -vf "scale=1920:-2,unsharp=5:5:0.8:5:5:0.0,hqdn3d=2:1.5:3:2.5" \
  -c:v libx264 -crf 23 output.mp4
```

---

### 5.7 Audio Filters

```bash
# Normalize loudness to EBU R128 standard (broadcast-safe)
ffmpeg -i input.mkv -af "loudnorm=I=-16:TP=-1.5:LRA=11" -c:v copy output.mkv

# Boost volume (1.5 = 150% volume)
ffmpeg -i input.mkv -af "volume=1.5" -c:v copy output.mkv

# Remove silence from audio
ffmpeg -i input.mkv -af "silenceremove=start_periods=1:start_silence=0.1:start_threshold=-50dB" output.mkv

# High-pass filter (remove low rumble — good for voice recordings)
ffmpeg -i input.mkv -af "highpass=f=80" -c:v copy output.mkv

# Audio fade in/out
ffmpeg -i input.mkv -af "afade=t=in:ss=0:d=3,afade=t=out:st=57:d=3" -c:v copy output.mkv
# fade in: 0–3s  |  fade out: 57s–60s

# Combine video + audio filters
ffmpeg -i input.mkv \
  -vf "scale=1920:-2" \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
  -c:v libx264 -crf 23 \
  output.mp4
```

---

### 5.8 Screen Recording

```bash
# Record screen at 1080p 60fps (X11)
ffmpeg -video_size 1920x1080 -framerate 60 -f x11grab -i :0.0 \
  -c:v libx264 -preset ultrafast -crf 23 \
  recording.mkv

# Screen + microphone audio (PulseAudio)
ffmpeg \
  -video_size 1920x1080 -framerate 60 -f x11grab -i :0.0 \
  -f pulse -ac 2 -i default \
  -c:v libx264 -preset ultrafast -crf 23 \
  -c:a aac -b:a 128k \
  recording.mkv

# Screen recording via AMD GPU (much lower CPU usage)
ffmpeg -video_size 1920x1080 -framerate 60 -f x11grab -i :0.0 \
  -c:v h264_amf -rc cqp -qp_i 22 -quality speed \
  recording.mkv
```

---

### 5.9 GIF

```bash
# Optimized GIF from video (palette generation pass)
ffmpeg -i input.mp4 \
  -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  output.gif

# GIF to MP4 (for sharing where GIF is too large)
ffmpeg -i input.gif -c:v libx264 -pix_fmt yuv420p output.mp4
```

The palette filter generates a color palette tuned to the specific content, then applies
it — this produces much smaller, higher-quality GIFs than a simple conversion.

---

### 5.10 Image Sequence to Video

```bash
# Numbered image sequence (frame_0001.png, frame_0002.png, …)
ffmpeg -framerate 24 -i frame_%04d.png \
  -c:v libx264 -pix_fmt yuv420p output.mp4

# Glob pattern
ffmpeg -framerate 30 -pattern_type glob -i '*.png' \
  -c:v libx264 -pix_fmt yuv420p -crf 18 output.mp4
```

---

## Part 6 — AMD CPU Optimization

### Threading

```bash
# Always use auto threading on AMD Ryzen (many cores, use them all)
ffmpeg -threads 0 -i input.mkv -c:v libx265 -crf 28 -preset slow output.mkv
```

`-threads 0` tells FFmpeg to auto-select based on available cores. On a Ryzen 7 (8c/16t)
or Ryzen 9 (12c/24t), this has a significant impact on encode speed.

### AMD Ryzen Multi-CCX / NUMA Consideration

Ryzen 9 5900X/5950X and Ryzen 9 7900X/7950X have two CCDs (Core Complex Dies). Memory
accesses between the two CCDs incur higher latency. For libsvtav1 specifically, disabling
thread pinning prevents the encoder from binding threads to specific cores in a way that
increases cross-CCD communication:

```bash
# For Ryzen 9 with 2 CCDs (5900X, 5950X, 7900X, 7950X, etc.)
ffmpeg -threads 0 -i input.mkv \
  -c:v libsvtav1 -crf 28 -preset 5 \
  -svtav1-params "pin=0:lp=0" \
  -c:a libopus -b:a 128k output.mkv
```

For single-CCD chips (Ryzen 5 5600X, Ryzen 7 5800X, etc.), this matters less but doesn't hurt.

### x265 on AMD Multi-Core

```bash
# libx265 with explicit parallelism settings
ffmpeg -threads 0 -i input.mkv \
  -c:v libx265 -crf 28 -preset slow \
  -x265-params "pools=*:frame-threads=4:wpp=1" \
  -c:a copy output.mkv
```

- `pools=*` — use all CPU cores
- `frame-threads=4` — parallel frame encoding (tune to core count)
- `wpp=1` — wavefront parallel processing (default on; significant parallelism gain)

### Full AMD CPU + GPU Workflow

```bash
# Large batch: CPU decodes, AMD GPU encodes
# -threads 0 ensures decode uses all cores fully
ffmpeg -threads 0 -i input.mkv \
  -c:v hevc_amf -rc cqp -qp_i 22 -qp_p 24 -quality quality \
  -c:a libopus -b:a 192k \
  output.mkv
```

---

## Part 7 — Best Recipes by Use Case

### Universal Web MP4 (Broadest Compatibility)

```bash
ffmpeg -i input.mkv \
  -c:v libx264 -crf 23 -preset slow \
  -profile:v high -level:v 4.1 -pix_fmt yuv420p \
  -movflags +faststart \
  -c:a aac -b:a 192k \
  output.mp4
```

### High-Quality Archival (CPU, Space Not a Concern)

```bash
ffmpeg -threads 0 -i input.mkv \
  -c:v libx265 -crf 18 -preset veryslow \
  -c:a flac \
  output.mkv
```

### High-Quality Archival (AMD GPU, Fast)

```bash
ffmpeg -i input.mkv \
  -c:v hevc_amf -rc cqp -qp_i 18 -quality quality \
  -c:a flac \
  output.mkv
```

### 4K HDR Archival

```bash
ffmpeg -threads 0 -i input_4k_hdr.mkv \
  -c:v libx265 -crf 20 -preset slow \
  -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
  -x265-params "hdr-opt=1:repeat-headers=1" \
  -c:a copy \
  output_4k_hdr.mkv
```

### Future-Proof AV1 (Quality Priority)

```bash
ffmpeg -threads 0 -i input.mkv \
  -c:v libsvtav1 -crf 26 -preset 4 \
  -svtav1-params "pin=0:lp=0:tune=0:film-grain=8:film-grain-denoise=1" \
  -c:a libopus -b:a 192k \
  output.mkv
```

### Smallest Possible File (AV1, Accept Long Encode)

```bash
ffmpeg -threads 0 -i input.mkv \
  -c:v libsvtav1 -crf 40 -preset 3 \
  -svtav1-params "pin=0:lp=0" \
  -c:a libopus -b:a 64k \
  output.mkv
```

### Fast AMD GPU Encode (Speed Priority)

```bash
ffmpeg -i input.mkv \
  -c:v h264_amf -rc cqp -qp_i 22 -quality balanced \
  -c:a aac -b:a 192k \
  output.mp4
```

### Screen Recording (Minimal CPU Impact)

```bash
ffmpeg -video_size 1920x1080 -framerate 60 -f x11grab -i :0.0 \
  -c:v h264_amf -rc cqp -qp_i 22 -quality speed \
  recording.mkv
```

### Audio Extraction

```bash
# Lossless
ffmpeg -i input.mkv -vn -c:a flac output.flac

# Modern/efficient
ffmpeg -i input.mkv -vn -c:a libopus -b:a 192k output.opus

# Legacy compatibility
ffmpeg -i input.mkv -vn -c:a libmp3lame -q:a 2 output.mp3
```

### Quick Trim (No Re-Encode)

```bash
ffmpeg -ss 00:01:00 -to 00:05:00 -i input.mkv -c copy output.mkv
```

### Downscale 4K → 1080p

```bash
ffmpeg -threads 0 -i input_4k.mkv \
  -vf "scale=1920:-2" \
  -c:v libx265 -crf 22 -preset slow \
  -c:a copy \
  output_1080p.mkv
```

---

## Part 8 — Batch Scripts

### Batch MKV → MP4 (H.264 + AAC)

```bash
#!/usr/bin/env bash
# batch-convert.sh — Convert all MKV in a directory to H.264 MP4

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./converted}"

mkdir -p "$OUTPUT_DIR"

for f in "$INPUT_DIR"/*.mkv; do
  [ -f "$f" ] || continue
  basename="${f##*/}"
  output="$OUTPUT_DIR/${basename%.mkv}.mp4"

  echo "► Converting: $basename"
  ffmpeg -i "$f" \
    -c:v libx264 -crf 23 -preset slow \
    -movflags +faststart -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    "$output" && echo "  ✓ Done: $output" || echo "  ✗ FAILED: $basename"
done

echo "All conversions complete."
```

---

### Batch AV1 Encode (AMD Ryzen Multi-Core)

```bash
#!/usr/bin/env bash
# batch-av1.sh — Encode directory to AV1 using SVT-AV1

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./av1_output}"
PRESET="${3:-5}"          # SVT-AV1 preset: 0 (slowest) to 12 (fastest)
CRF="${4:-30}"            # Quality: lower = better

mkdir -p "$OUTPUT_DIR"

for f in "$INPUT_DIR"/*.{mkv,mp4,avi,mov}; do
  [ -f "$f" ] || continue
  basename="${f##*/}"
  ext="${basename##*.}"
  output="$OUTPUT_DIR/${basename%.$ext}.mkv"

  echo "► AV1 Encoding: $basename (CRF=$CRF, preset=$PRESET)"

  ffmpeg -threads 0 -i "$f" \
    -c:v libsvtav1 -crf "$CRF" -preset "$PRESET" \
    -svtav1-params "pin=0:lp=0:film-grain=8:film-grain-denoise=1" \
    -c:a libopus -b:a 128k \
    "$output"

  orig_size=$(du -h "$f"      | cut -f1)
  new_size=$(du  -h "$output" | cut -f1)
  echo "  Original: $orig_size → AV1: $new_size"
done

echo "AV1 batch complete."
```

Usage: `./batch-av1.sh ./input ./output 5 28`

---

### Batch AMD GPU Encode (hevc_amf)

```bash
#!/usr/bin/env bash
# batch-amf.sh — Fast batch encode using AMD GPU (HEVC)

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./amf_output}"
QP="${3:-24}"   # Quality: lower = better (18–28 typical range)

mkdir -p "$OUTPUT_DIR"

for f in "$INPUT_DIR"/*.{mkv,mp4}; do
  [ -f "$f" ] || continue
  basename="${f##*/}"
  ext="${basename##*.}"
  output="$OUTPUT_DIR/${basename%.$ext}.mkv"

  echo "► AMF Encoding: $basename (QP=$QP)"
  ffmpeg -i "$f" \
    -c:v hevc_amf -rc cqp -qp_i "$QP" -qp_p $((QP+2)) -quality quality \
    -c:a aac -b:a 192k \
    "$output" && echo "  ✓ Done" || echo "  ✗ FAILED"
done

echo "AMF batch complete."
```

---

### Audio Bulk Extractor

```bash
#!/usr/bin/env bash
# extract-audio.sh — Extract audio from all videos in a directory
# Usage: ./extract-audio.sh [input_dir] [format: opus|flac|mp3|aac]

INPUT_DIR="${1:-.}"
FORMAT="${2:-opus}"

for f in "$INPUT_DIR"/*.{mkv,mp4,avi,mov}; do
  [ -f "$f" ] || continue
  basename="${f##*/}"
  ext="${basename##*.}"
  name="${basename%.$ext}"

  echo "► Extracting audio ($FORMAT): $basename"
  case "$FORMAT" in
    opus) ffmpeg -i "$f" -vn -c:a libopus   -b:a 192k       "$INPUT_DIR/$name.opus" ;;
    flac) ffmpeg -i "$f" -vn -c:a flac                       "$INPUT_DIR/$name.flac" ;;
    mp3)  ffmpeg -i "$f" -vn -c:a libmp3lame -q:a 2          "$INPUT_DIR/$name.mp3"  ;;
    aac)  ffmpeg -i "$f" -vn -c:a aac        -b:a 192k       "$INPUT_DIR/$name.aac"  ;;
    *)    echo "Unknown format: $FORMAT. Use: opus, flac, mp3, aac"; exit 1 ;;
  esac
done
```

---

## Part 9 — Troubleshooting

### Check Available Encoders and Hardware

```bash
# Check specific codecs
ffmpeg -encoders | grep -E "libx264|libx265|libsvtav1|libvpx|amf|libopus"
ffmpeg -decoders | grep -E "h264|hevc|av1|vp9"

# Check available hardware acceleration methods
ffmpeg -hwaccels

# Test AMF encoder (quick check — 1 second of null output)
ffmpeg -f lavfi -i nullsrc=s=1920x1080 -c:v h264_amf -t 1 -f null - 2>&1 | tail -5
```

---

### Common Errors and Fixes

| Error Message | Cause | Fix |
|---|---|---|
| `Encoder libsvtav1 not found` | FFmpeg not compiled with SVT-AV1 | Use the static build from johnvansickle.com |
| `amf: driver version too old` | AMD driver too old for AMF | Update amdgpu driver |
| `Encoder hevc_amf not found` | No AMF in this FFmpeg build | Redownload or compile with `--enable-amf` |
| `Error initializing output stream` | Codec not compatible with container | Change container (e.g. use MKV instead of MP4) |
| `moov atom not found` | MP4 file truncated or corrupted | Use `-c copy -f matroska` to save as MKV |
| `height not divisible by 2` | Odd pixel dimensions | Add scale filter: `scale=trunc(iw/2)*2:trunc(ih/2)*2` |
| `Too many packets buffered` | Audio/video sync issue in complex filter | Add `-max_muxing_queue_size 9999` |
| `Invalid option -qp` (AMF) | Wrong syntax for AMF | Use `-qp_i`, `-qp_p` instead of `-qp` for AMF |

### Fix Non-Divisible-by-2 Dimensions

```bash
ffmpeg -i input.mkv \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  -c:v libx264 -crf 23 output.mp4
```

### Verbose Logging for Debugging

```bash
ffmpeg -v verbose -i input.mkv -c:v libx264 -crf 23 output.mp4 2>&1 | tee encode.log
```

---

## Summary: Quick Reference Table

| Goal | Command Skeleton |
|---|---|
| Universal web MP4 | `-c:v libx264 -crf 23 -preset slow -movflags +faststart -pix_fmt yuv420p -c:a aac -b:a 192k` |
| HQ archival (CPU) | `-c:v libx265 -crf 18 -preset veryslow -c:a flac` |
| HQ archival (AMD GPU) | `-c:v hevc_amf -rc cqp -qp_i 18 -quality quality -c:a flac` |
| Future-proof AV1 | `-threads 0 -c:v libsvtav1 -crf 28 -preset 5 -svtav1-params "pin=0:lp=0:film-grain=8" -c:a libopus -b:a 192k` |
| Fast AMD GPU H.264 | `-c:v h264_amf -rc cqp -qp_i 22 -quality quality -c:a aac -b:a 192k` |
| Fast AMD GPU H.265 | `-c:v hevc_amf -rc cqp -qp_i 24 -quality quality -c:a aac -b:a 192k` |
| Extract audio lossless | `-vn -c:a flac` → `.flac` |
| Extract audio (small) | `-vn -c:a libopus -b:a 192k` → `.opus` |
| Quick trim (no encode) | `-ss 00:01:00 -to 00:05:00 -i input -c copy` |
| Remux to different container | `-i input -c copy output.mkv` |
| Downscale 4K → 1080p | `-vf scale=1920:-2 -c:v libx265 -crf 22 -c:a copy` |
| Burn subtitles | `-vf "subtitles=sub.srt" -c:v libx264 -crf 23` |

---

*FFmpeg 7.x — Tested on openSUSE Linux with AMD hardware.*
*Static build: [johnvansickle.com/ffmpeg](https://johnvansickle.com/ffmpeg)*
*AMF requires amdgpu drivers and FFmpeg compiled with `--enable-amf`.*
