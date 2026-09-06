# The Brave Browser Linux Troubleshooting Handbook

A distribution-agnostic guide to diagnosing crashes, freezes, startup failures, rendering bugs, GPU problems, and performance regressions in Brave Browser on Linux — across Stable, Beta, Nightly, and the Origin (de-Chromium-branded, no-Rewards/no-Wallet) channels.

This is not a list of "try these ten fixes." It is a method: isolate the failing layer first (Brave → Chromium → GPU driver → Mesa → Wayland/X11 → compositor → profile → extension → sandbox → kernel → packaging), then apply the narrowest fix that addresses that layer, then verify it actually worked.

> **Scope note on channels.** Brave Origin, Origin Beta, and Origin Nightly are Brave's de-branded builds intended for environments that don't want Brave Rewards/Wallet/VPN code paths built in. Under the hood they are the same Chromium/Brave engine as Stable/Beta/Nightly respectively, so everything in this guide — flags, `brave://` pages, GPU pipeline, sandboxing — applies identically. Where Origin differs (binary name, profile directory, default flags), it is called out explicitly.

---

## Table of Contents

1. [Introduction: How Brave and Chromium Actually Work](#1-introduction-how-brave-and-chromium-actually-work)
2. [Common Symptoms and What They Usually Mean](#2-common-symptoms-and-what-they-usually-mean)
3. [Information Collection](#3-information-collection)
4. [GPU Troubleshooting](#4-gpu-troubleshooting)
5. [Hardware Acceleration](#5-hardware-acceleration)
6. [Wayland vs. X11](#6-wayland-vs-x11)
7. [Graphics Drivers (AMD / Intel / NVIDIA)](#7-graphics-drivers-amd--intel--nvidia)
8. [VA-API (Video Acceleration)](#8-va-api-video-acceleration)
9. [ANGLE](#9-angle)
10. [Vulkan](#10-vulkan)
11. [Browser Profiles](#11-browser-profiles)
12. [Extensions](#12-extensions)
13. [Command-Line Flags Reference](#13-command-line-flags-reference)
14. [Logging](#14-logging)
15. [Linux Packaging (deb/rpm/Flatpak/Snap)](#15-linux-packaging-debrpmflatpaksnap)
16. [Distribution-Specific Issues](#16-distribution-specific-issues)
17. [Case Studies](#17-case-studies)
18. [Troubleshooting Flowcharts](#18-troubleshooting-flowcharts)
19. [Best Practices](#19-best-practices)
20. [Cheat Sheets](#20-cheat-sheets)

---

## 1. Introduction: How Brave and Chromium Actually Work

Brave is a Chromium fork. It reuses Chromium's process model, rendering engine (Blink + Skia), sandbox, and GPU pipeline almost unchanged, and layers Brave-specific features on top (ad/tracker blocking in the network stack, Brave Shields, Rewards/Wallet in Stable/Beta/Nightly, and their absence in Origin builds). This matters for troubleshooting because **the vast majority of crash/freeze/rendering bugs you'll hit are Chromium bugs or driver bugs, not Brave bugs** — Brave inherits Chromium's `content/`, `gpu/`, `ui/ozone/` layers wholesale. When in doubt, a bug that reproduces in `google-chrome` or `chromium` with the same flags almost certainly isn't Brave-specific, and should be checked against the [Chromium issue tracker](https://issues.chromium.org/issues?q=) rather than Brave's.

### Multi-process architecture

Chromium (and therefore Brave) splits work across OS processes rather than threads, so that a crash in one tab doesn't take down the whole browser:

```
                     ┌────────────────────┐
                     │   Browser Process   │  (1 per browser instance)
                     │  UI, networking,    │
                     │  profile, extension │
                     │  management, IPC    │
                     └─────────┬───────────┘
                               │ Mojo IPC
        ┌──────────────┬───────┼───────┬──────────────┐
        │              │       │       │              │
┌───────▼──────┐ ┌─────▼────┐ │ ┌──────▼─────┐ ┌──────▼──────┐
│   Renderer    │ │ Renderer │ │ │    GPU     │ │  Utility     │
│  (per site/   │ │ (per     │ │ │  Process   │ │  Processes   │
│   tab, sand-  │ │  tab)    │ │ │ (1, shared)│ │ (network,    │
│   boxed)      │ │          │ │ │            │ │  audio,      │
│  Blink+V8+CSS │ │          │ │ │ Skia/GL/   │ │  storage,    │
└───────────────┘ └──────────┘ │ │ Vulkan/    │ │  print, ...) │
                                │ │ VA-API     │ └──────────────┘
                          ┌─────▼─┴────┐
                          │ Zygote (Linux│
                          │ process      │
                          │ forker)      │
                          └──────────────┘
```

- **Browser process** — the only process with full OS privileges. Owns the window, tab strip, profile on disk, bookmarks, history, and talks to every other process over Mojo IPC. If *this* process crashes, the whole browser disappears; `brave://crashes` and `coredumpctl` are your primary evidence sources.
- **Renderer processes** — one per site-isolated origin (roughly one per tab/site, subject to process-per-site-instance rules). Sandboxed with seccomp-bpf + Linux namespaces so a compromised or buggy renderer cannot touch the filesystem or other processes directly. Runs Blink (layout/DOM), V8 (JavaScript), and produces compositor frames.
- **GPU process** — exactly one, shared by all tabs. Owns the connection to the actual graphics driver (via EGL/GLX/Vulkan), does rasterization and compositing of frames produced by renderers, and handles WebGL/WebGPU/video decode. **This is the single most common source of "whole browser freezes" and "black screen" bugs on Linux**, because a driver-level hang inside the GPU process can block every tab's compositor output simultaneously.
- **Utility processes** — sandboxed helpers for network service, audio service, storage service, print preview, etc. Isolating these means a bug in, say, the audio service doesn't crash tabs.
- **Zygote process** — Linux-specific. A pre-sandboxed "template" process that Chromium forks new renderer/utility processes from, to make sandbox setup fast and consistent.

### Why this matters for debugging

When you see a symptom, your first job is to figure out *which process* is at fault:

| Symptom | Process most likely at fault |
|---|---|
| Single tab crashes, rest of browser fine | Renderer |
| Whole browser window goes black/white, other apps fine | GPU process / compositor |
| Entire desktop freezes, mouse still moves | GPU driver kernel-level hang (not Chromium's fault directly) |
| Browser won't start at all | Browser process (often profile or sandbox) |
| Video won't play / high CPU during video | GPU process (VA-API) or renderer (software decode fallback) |
| Extension popup broken, rest fine | Renderer (extension's own process/isolated world) |

### How Brave differs from Chromium and Google Chrome

- **No Google API keys / no Google sync** — Brave uses its own sync and doesn't ship Chrome's proprietary Widevine-adjacent Google integrations the same way; this occasionally changes which `chrome://`-equivalent flags exist under `brave://`.
- **Shields (ad/tracker blocking) sits in the network stack** — implemented as a `net::URLRequest`-layer filter, not an extension. This means Shields can be a factor in "page won't load / partially loads" symptoms that look like rendering bugs but are network-layer.
- **Different default flag set** — Brave disables some Chromium field trials and Google-specific experiments by default, and manages its own `brave://flags` (a superset that includes all upstream `chrome://flags` entries plus Brave-only ones).
- **Own update channel, own crash reporting endpoint** — `brave://crashes` reports to Brave's crash server, not Google's, but the underlying Breakpad/Crashpad mechanism and minidump format used to *collect* the crash are unchanged from Chromium.
- **Origin builds** — Origin/Origin Beta/Origin Nightly strip Rewards, Wallet, VPN, and Brave-specific ad-serving code paths at compile time. This has zero effect on the GPU/rendering pipeline; a GPU bug reproduces identically on Origin and Stable.

Because Brave sits so close to upstream Chromium, this guide treats **Chromium's own documentation and bug tracker as the primary authority** for anything below the "Brave features" layer (Shields, Rewards, Wallet), and Brave's own docs/support as authoritative only for Brave-specific behavior.

---

## 2. Common Symptoms and What They Usually Mean

For each symptom: likely causes (roughly ordered by frequency), how to tell them apart, and where to go next in this guide.

### Browser freezes (window stops responding, rest of desktop fine)

- **Causes:** GPU process hang waiting on driver call; a renderer stuck in a long-running/synchronous JS loop; disk I/O stall while writing to profile (e.g., full disk, slow network filesystem).
- **Diagnose:** Open `xkill`/`wmctrl` from a terminal on another workspace, or check `ps -T -p <brave-pid>` for a thread stuck in `D` state (uninterruptible sleep = usually I/O or a driver ioctl). Check `journalctl -k -f` for GPU driver messages appearing at the same time as the freeze.
- **Go to:** [§4 GPU Troubleshooting](#4-gpu-troubleshooting), [§11 Browser Profiles](#11-browser-profiles).

### Entire desktop freezes (mouse frozen too, or compositor stops redrawing)

- **Causes:** This is almost never "Brave's fault" in the sense of a bug in Brave's code — it means something downstream (kernel DRM/KMS driver, GPU firmware, Mesa) locked up the GPU, and Brave was simply the process issuing the command that triggered it. Common with WebGL/WebGPU-heavy pages on immature Mesa driver versions (RADV, ANV) or with GPU compositing enabled on a system where the specific GPU generation has known Wayland compositor bugs.
- **Diagnose:** `journalctl -k -b` after reboot and look for `amdgpu: ... GPU reset`, `i915 ... GPU HANG`, or `nvidia: Xid` messages timestamped at the freeze. A GPU reset message *confirms* driver/kernel fault, not a Chromium bug.
- **Go to:** [§7 Graphics Drivers](#7-graphics-drivers-amd--intel--nvidia), [§17 Case Studies](#17-case-studies) (Case 1).

### Black window / white window / blank tabs

- **Causes:** GPU compositing failing silently and falling back to an unpainted surface; ANGLE backend mismatch; Wayland buffer format the compositor rejects; a crashed GPU process that hasn't yet triggered a visible "Aw, Snap."
- **Diagnose:** `brave://gpu` → check "Graphics Feature Status" for anything marked "Disabled" or "Software only, hardware acceleration unavailable." A black *window* (titlebar present, content black) usually means compositing; a white window usually means the renderer painted but the compositor never received/displayed a frame.
- **Go to:** [§4](#4-gpu-troubleshooting), [§5](#5-hardware-acceleration), [§9 ANGLE](#9-angle).

### Startup crash (closes immediately, no window)

- **Causes:** Corrupted `Local State` or `Preferences` file in the profile; sandbox setup failure (missing `CAP_SYS_ADMIN`/unprivileged user namespaces disabled at kernel level); a broken extension set to auto-load; incompatible GPU driver crashing the GPU process before any window paints, tearing down the browser process with it in edge cases; disk full.
- **Diagnose:** Run from a terminal, read stderr directly — this is the single highest-value first step for any startup crash (see [§3](#3-information-collection)).
- **Go to:** [§11 Browser Profiles](#11-browser-profiles), [§13 Sandbox flags](#13-command-line-flags-reference).

### Browser won't launch at all (no process, no window, no error)

- **Causes:** Missing shared library after a partial update (common with distro packages that lag Brave's own release cadence); PATH/binary permissions issue; Wayland session variables set but no Wayland socket reachable (e.g., launched from an SSH session).
- **Diagnose:** `echo $?` after running the binary directly; `ldd $(which brave-browser)` for missing `.so` files.
- **Go to:** [§15 Linux Packaging](#15-linux-packaging-debrpmflatpaksnap).

### Slow startup

- **Causes:** Large profile (huge History/Cookies SQLite databases, thousands of extensions/bookmarks); disk contention; "restore previous session" re-opening dozens of tabs; antivirus/EDR on managed Linux systems scanning the binary on every launch; unnecessary `--enable-logging` left on permanently, which adds I/O overhead.
- **Go to:** [§11](#11-browser-profiles), [§19 Best Practices](#19-best-practices).

### High CPU usage (idle, no obvious tab activity)

- **Causes:** A background tab running an uncapped `requestAnimationFrame`/timer loop; VA-API not active, so video decode falls back to software (CPU) decode; a misbehaving extension; GPU rasterization disabled, pushing rasterization work onto CPU threads.
- **Diagnose:** `brave://gpu` first, then `top -H -p $(pgrep -f Renderer)` to see whether it's a renderer or the GPU/browser process burning CPU, then `brave://histograms` search `Media.` for decode-path histograms.
- **Go to:** [§8 VA-API](#8-va-api-video-acceleration), [§12 Extensions](#12-extensions).

### High RAM usage / memory leaks

- **Causes:** Chromium's per-site-isolation model is inherently RAM-hungry by design (each renderer has its own V8 heap) — this is expected behavior at scale, not automatically a "leak." A genuine leak shows *monotonically increasing* RSS in a single long-lived renderer or the GPU process over hours with no new tabs opened.
- **Diagnose:** `brave://system` memory section, or `ps -o rss,cmd -p <pid>` sampled over time for a specific process; `chrome://tracing`-style memory-infra dumps for deep dives (advanced, matches upstream Chromium's [memory-infra docs](https://chromium.googlesource.com/chromium/src/+/main/docs/memory-infra/README.md)).
- **Go to:** [§12 Extensions](#12-extensions), [§17 Case Studies](#17-case-studies).

### Browser hangs after updates

- **Causes:** Stale GPU shader cache built against the previous binary's Skia/ANGLE version; a Field Trial config cached from the old version conflicting with new code; distro package updated Mesa/driver independently and the combination is untested.
- **Fix path:** Clear GPU shader cache (`~/.config/BraveSoftware/Brave-Browser/ShaderCache` and `GrShaderCache` — see [§11](#11-browser-profiles)) before assuming it's a regression.

### Frequent tab crashes ("Aw, Snap!")

- **Causes:** Renderer OOM-killed by the kernel (check `dmesg` for `oom-kill... comm=Renderer`), a specific site triggering a Blink/V8 bug, GPU process instability propagating to every renderer that depends on it for compositing.
- **Go to:** [§3](#3-information-collection), [§4](#4-gpu-troubleshooting).

### Video playback issues (stutter, no video, audio-only)

- **Causes:** VA-API not enabled/working (falls back to software decode → stutter on high-res video); codec not available in the distro's Mesa/ffmpeg build (common on Debian/Ubuntu without proprietary codec packages); DRM (Widevine) plugin missing for protected content.
- **Go to:** [§8 VA-API](#8-va-api-video-acceleration).

### WebGL / WebGPU issues

- **Causes:** ANGLE backend selecting a code path the driver handles poorly; WebGPU (Dawn) blocklist entry for the specific GPU/driver combination; outdated Mesa lacking required Vulkan extensions for WebGPU's Vulkan backend.
- **Go to:** [§9 ANGLE](#9-angle), [§10 Vulkan](#10-vulkan).

### Extension crashes

- **Causes:** Manifest V3 service worker crashing (check `brave://extensions` → Errors), extension incompatible with current Brave version, conflicting content scripts.
- **Go to:** [§12 Extensions](#12-extensions).

### Clipboard issues

- **Causes:** Wayland clipboard requires the compositor to support `wl_data_device_manager` correctly; XWayland clipboard bridging bugs between native Wayland apps and XWayland apps; `wl-clipboard`/`xclip` conflicts with browser-held clipboard ownership.
- **Diagnose:** Test with `wl-paste`/`xclip -o` immediately after copying from Brave to see whether the compositor even received the offer.

### Wayland rendering glitches / flickering / screen tearing / stuttering / input lag

- **Causes:** Ozone/Wayland backend immaturity for the specific compositor (KWin vs. Mutter vs. wlroots-based) and GPU combination; VRR/tearing-control protocol not implemented by the compositor; explicit sync (`linux-drm-syncobj`) not yet supported by an older Mesa or compositor version, causing visible tearing/flicker that was fixed upstream in later Mesa releases.
- **Go to:** [§6 Wayland vs X11](#6-wayland-vs-x11).

---

## 3. Information Collection

Before changing anything, gather evidence. This section is the toolbox the rest of the guide points back to.

### Brave/Chromium internal pages

| Page | What it tells you | How to read it |
|---|---|---|
| `brave://gpu` | Full GPU status report: active GPU, driver version, ANGLE backend, and a per-feature table ("Graphics Feature Status") showing Enabled / Disabled / Software only for compositing, rasterization, WebGL, WebGL2, WebGPU, video decode/encode, Vulkan | The feature status table is the single most important diagnostic artifact for any rendering/GPU bug. Anything not "Hardware accelerated" is a red flag worth investigating. Also shows the exact command-line switches active. |
| `brave://version` | Exact Brave version, Chromium version, executable path, profile path, command-line flags actually in effect | Confirms which channel/binary you're actually running, and whether flags you set in a launcher actually reached the process. |
| `brave://flags` | Every experimental flag, current override state | Use to check whether a previously-set experimental flag is the cause. `brave://flags#<flag-name>` deep-links to one flag. |
| `brave://crashes` | List of local crash reports (if crash reporting/`about:crashes` recording is enabled) with upload status | Requires `--enable-crash-reporter` in some minimal builds; on standard Brave builds it's on by default. Click a crash ID for the local report; `Report ID` correlates with what Brave's crash server received if uploaded. |
| `brave://histograms` | Live UMA histograms — search e.g. `GPU.` or `Media.` to see counted events (context lost, decode fallbacks, etc.) | Requires `--enable-logging` in some cases; mostly useful for spotting *counts* of specific internal events, e.g. `GPU.ContextLost` incrementing during a session confirms GPU context loss is happening even if the UI didn't show an obvious crash. |
| `brave://sandbox` | Per-process sandbox status (SUID sandbox, namespace sandbox, seccomp-bpf) | "Sandboxed: No" for the renderer indicates a sandbox setup failure — a very common startup-crash cause on hardened kernels or containers (see [§13](#13-command-line-flags-reference)). |

### Linux command-line tools

| Command | Purpose |
|---|---|
| `journalctl -b --user -u <session>` / `journalctl -k -f` | System and kernel logs; run `-f` (follow) *while reproducing* a freeze to catch driver messages (`amdgpu`, `i915`, `nvidia`, `Xid`) at the exact timestamp of the hang. |
| `dmesg -T \| tail -100` | Kernel ring buffer with human-readable timestamps; fastest way to check for OOM kills (`Out of memory: Killed process ... (Renderer)`) or GPU resets right after a crash. |
| `coredumpctl list brave` / `coredumpctl gdb <PID>` | If `systemd-coredump` is enabled, lists and lets you inspect core dumps for crashed processes — gives a real backtrace even without Brave's own crash reporter. |
| `glxinfo -B` | Summarizes the active OpenGL renderer, driver, and whether direct rendering is active (via GLX/X11). Confirms whether Mesa's seeing your GPU at all, independent of the browser. |
| `vulkaninfo --summary` | Lists available Vulkan devices/drivers and API versions — confirms whether the Vulkan ICD (RADV/ANV/NVIDIA) is correctly installed and loadable before blaming Brave's Vulkan backend. |
| `vainfo` | Lists VA-API profiles/entrypoints exposed by the installed driver (`mesa-va-drivers`, `intel-media-driver`, `nvidia-vaapi-driver`) — the ground truth for whether hardware video decode is even possible on this system. |
| `inxi -Gxx` | One-shot summary of GPU hardware, driver in use, and display server — useful when filing bug reports since it's a widely recognized format. |
| `lspci -k \| grep -A3 VGA` | Confirms which kernel driver is bound to the GPU (`amdgpu`, `i915`, `nvidia`, `nouveau`) at the PCI level, independent of any userspace tool. |
| `lsmod \| grep -E 'amdgpu\|i915\|nvidia\|nouveau'` | Confirms the kernel module is actually loaded (catches cases where a driver is installed but not active, e.g. after a kernel update without a matching DKMS rebuild for proprietary NVIDIA). |
| `loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type` | Confirms whether the current session is `wayland`, `x11`, or `tty` — needed before assuming which backend Brave picked. |
| `env \| grep -E 'WAYLAND|XDG_SESSION|DISPLAY|GDK_BACKEND|QT_QPA|OZONE'` | Shows the environment Brave actually inherits, including any manually-set Ozone/backend overrides. |
| `ps -T -p $(pgrep -f 'brave.*type=gpu-process')` | Lists threads inside the GPU process; a thread stuck in state `D` (uninterruptible sleep) at the moment of a freeze points at a blocking driver ioctl, not a Chromium logic bug. |
| `top -H` / `htop` (tree view, `H` to show threads) | Live view of which process/thread is consuming CPU — first triage step for "high CPU" symptoms. |

### A minimal, repeatable collection routine

```bash
# 1. Launch from terminal so stderr is visible directly
brave-browser --enable-logging=stderr --v=1 2>&1 | tee ~/brave-debug.log

# 2. In another terminal, start following kernel + systemd logs
journalctl -k -f | tee ~/kernel-debug.log &

# 3. Reproduce the issue

# 4. Immediately after, snapshot GPU state and recent kernel messages
brave-browser --headless=old --dump-dom about:gpu >/dev/null 2>&1  # optional headless probe
dmesg -T | tail -200 > ~/dmesg-snapshot.log
coredumpctl list brave --since "10 min ago" > ~/coredump-list.log
```

Attach `brave-debug.log`, `kernel-debug.log`, `dmesg-snapshot.log`, and (if relevant) the `brave://gpu` "Graphics Feature Status" text to any bug report — this is the same baseline Chromium's own [bug reporting guidelines](https://www.chromium.org/for-testers/bug-reporting-guidelines/) ask for.

---

## 4. GPU Troubleshooting

Chromium's GPU pipeline has several independently-toggleable subsystems. A bug in one doesn't necessarily implicate the others, so test them in isolation.

```
Web content
    │
    ▼
Blink layout → Skia (CPU or GPU-backed "Ganesh"/"Graphite" canvas)
    │
    ▼
Compositor (cc/) — builds a frame from layers
    │
    ▼
Viz service (in GPU process) — GPU compositing, merges frames from all processes
    │
    ├── GPU Rasterization (Skia GPU backend, if enabled)
    ├── Out-of-process rasterization (raster work done in GPU process, not renderer)
    ├── ANGLE (translates GL ES calls → native GL/Vulkan/Metal)
    ├── WebGL / WebGPU (Dawn) contexts
    ├── Video decode/encode (VA-API on Linux)
    ▼
Native graphics API (OpenGL via Mesa, or Vulkan via Mesa/NVIDIA)
    │
    ▼
Kernel DRM/KMS driver → GPU hardware
```

| Subsystem | What it does | How to test in isolation |
|---|---|---|
| **GPU compositing** | Composites layers (tabs, UI chrome) using the GPU instead of CPU (software) painting | Toggle with `--disable-gpu-compositing`; if the freeze/glitch disappears, the compositor→driver path is implicated |
| **GPU rasterization** | Converts vector paint commands (text, shapes) into pixels on the GPU rather than CPU | Toggle with `--disable-gpu-rasterization`; isolates Skia GPU backend bugs |
| **ANGLE** | Translates ES2/ES3 GL calls into the platform's native graphics API | Switch backend via `--use-angle=gl` / `--use-angle=vulkan` (see [§9](#9-angle)) |
| **Skia** | The 2D graphics library Chromium uses for all painting, GPU or CPU | Rarely toggled directly; its behavior is a function of the rasterization/compositing flags above |
| **WebGL** | Web-exposed 3D graphics API, implemented over ANGLE | `brave://gpu` "WebGL" status row; test at `webglreport.com`-style pages or `chrome://gpu` sample WebGL demo |
| **WebGPU** | Newer, lower-level web graphics/compute API, implemented via Dawn (Vulkan or GL backend on Linux) | `brave://gpu` "WebGPU" status row; check for blocklist entries in the same page |
| **Canvas acceleration** | 2D `<canvas>` acceleration via GPU rasterization | Same toggle as GPU rasterization; disable to test |
| **Video decode** | Hardware-accelerated video decode via VA-API | See [§8](#8-va-api-video-acceleration) |
| **Video encode** | Hardware-accelerated encode (e.g., for WebRTC/screen share) | Less commonly hit; same VA-API driver stack as decode |
| **Out-of-process rasterization (OOP-R)** | Moves raster work from renderer into the GPU process for better isolation/perf | `--disable-oop-rasterization` to test |
| **GPU sandbox** | Restricts what the GPU process can do at the OS level, separate from the renderer sandbox | `brave://sandbox`; `--disable-gpu-sandbox` as a diagnostic-only flag |

### Isolation method

1. Open `brave://gpu`. Screenshot or copy the "Graphics Feature Status" table — this is your baseline.
2. Reproduce the bug with defaults. Note exactly what fails.
3. Relaunch with **one** flag changed at a time from [§5](#5-hardware-acceleration)/[§13](#13-command-line-flags-reference), in this order of narrowing scope:
   `--disable-gpu-rasterization` → `--disable-gpu-compositing` → `--use-angle=gl` (or swap to `vulkan`) → `--disable-gpu` (last resort, kills acceleration entirely).
4. Re-check `brave://gpu` after each relaunch to confirm the flag actually took effect (some flags are overridden by driver blocklists — see below).
5. Once you find the flag that resolves the symptom, you've identified the subsystem at fault. Treat the flag as a **diagnostic result**, not a permanent fix — then look for the underlying driver/Mesa bug and update, or leave the narrowest working flag as a documented workaround (see [§17 Case Studies](#17-case-studies)).

> **Note — GPU blocklisting.** Chromium ships a built-in GPU driver blocklist (`gpu_data_manager`) that can silently disable features for known-buggy driver/GPU combinations, independent of anything you set. `brave://gpu` shows "Disabled Features: ... (GPU access is blocked)" when this triggers. You can override it for testing with `--ignore-gpu-blocklist`, but this is a diagnostic flag only — if a combination is blocklisted, it's blocklisted for a documented reason (usually a Chromium bug tracker entry); don't leave the override on permanently in production use.

---

## 5. Hardware Acceleration

Chromium enables GPU hardware acceleration by default on Linux when the GPU driver passes its internal capability checks and isn't on the blocklist. Acceleration moves rasterization and compositing work off the CPU and onto the GPU, which is faster and more power-efficient — but it also means bugs in the GPU driver/Mesa stack become browser-visible bugs.

**Disabling acceleration is a diagnostic tool, not a fix.** If disabling it resolves your symptom, you've confirmed the bug lives in the GPU/driver/Mesa/compositor layer, not in Brave/Chromium's own logic — but running long-term without acceleration means falling back to software rendering, which is slower, uses more CPU/power, and degrades WebGL/video/canvas-heavy sites significantly. Only leave it disabled permanently if updating the driver/Mesa/kernel doesn't resolve the underlying bug and you need a stable browser now.

| Flag | What it disables | When to use | When NOT to use |
|---|---|---|---|
| `--disable-gpu` | All GPU process functionality — compositing, rasterization, WebGL, video decode all fall back to CPU/software paths | Broadest diagnostic step: confirms whether *any* GPU involvement is the cause of a crash/freeze | Long-term daily use — very high CPU load, WebGL/WebGPU sites will be crippled or broken |
| `--disable-gpu-compositing` | GPU-based layer compositing; falls back to software compositing while still allowing GPU rasterization in some configurations | Narrower than `--disable-gpu` — use when you suspect the compositor/Viz service specifically (e.g., freezes tied to tab switching, tearing, flicker) | If the bug is actually in rasterization or ANGLE, this flag won't help and you'll needlessly lose compositing performance |
| `--disable-gpu-rasterization` | GPU-accelerated Skia rasterization of paint operations; falls back to CPU raster | Use when symptoms are tied to painting (text/shape rendering glitches, canvas corruption) rather than compositing | Won't help WebGL/video-specific bugs, which don't go through this path |
| `--disable-software-rasterizer` | Prevents Chromium from falling back to SwiftShader (software GL implementation) when hardware acceleration fails | Use only when you specifically want the browser to *fail loudly* (blank/broken rendering) rather than silently degrade to software rendering — useful when diagnosing whether SwiftShader fallback is masking a driver problem | Never for normal use — without this fallback, a GPU init failure can mean broken rendering with no fallback at all |

### Verifying whether a flag change had any effect

Always re-check `brave://gpu` after relaunching with a flag:

- The "Command Line" section at the bottom of `brave://gpu` shows the exact flags the running process received — confirms your launcher/`.desktop` file/alias actually passed the flag.
- The "Graphics Feature Status" table should show the corresponding feature as "Disabled" or "Software only" after the flag takes effect. If it still shows "Hardware accelerated," the flag didn't apply (check for typos, or a `flags` config file being overridden — see [§13](#13-command-line-flags-reference) for the `--user-data-dir`/config precedence notes).

---

## 6. Wayland vs. X11

Chromium's Linux windowing/graphics abstraction layer is called **Ozone**. It has backends for both X11 and native Wayland; which one Brave picks depends on the session type and flags.

| Aspect | X11 backend | Native Wayland backend (Ozone/Wayland) |
|---|---|---|
| Maturity | Very mature; Chromium's original and long-time-default Linux backend | Newer; became default-eligible only in recent Chromium versions, still catching up in edge cases (window decorations, global menus, some IME/input protocols) |
| How it's selected | Default when `XDG_SESSION_TYPE=x11`, or when running under XWayland without Ozone/Wayland flags | Selected automatically on a Wayland session in current Brave/Chromium versions via `--ozone-platform-hint=auto` (the modern default), or forced with `--ozone-platform=wayland` |
| Screen sharing/PipeWire | Works via legacy X11 capture (can capture windows on XWayland, but not native-Wayland-only surfaces properly) | Uses `xdg-desktop-portal` + PipeWire for screen sharing — this is the *correct* modern path and generally more reliable for Wayland sessions |
| Fractional scaling | Works via Xft/X11 DPI settings, sometimes blurry due to X11's integer-only scaling model requiring compositor-side workarounds | Native fractional scaling support is better and sharper when both Chromium and the compositor support `wp_fractional_scale` |
| Known issue classes | Screen tearing on some compositors without a compositing WM; less an issue since XWayland/X11 sessions typically run a dedicated X compositor | Occasional flicker/tearing tied to explicit sync (`linux-drm-syncobj-v1`) protocol support maturity in both Mesa and the compositor; clipboard edge cases between native Wayland and XWayland apps; global shortcuts/window positioning APIs Chromium hasn't fully ported |
| XWayland | N/A (this *is* X11, just running under a Wayland session's XWayland compatibility layer) | Fallback path when native Wayland isn't explicitly selected even on a Wayland session — indicated in `brave://gpu` by "Ozone platform: x11" *despite* `XDG_SESSION_TYPE=wayland* |

### Debugging which backend is active

```bash
# Check the session type
echo $XDG_SESSION_TYPE

# Check what Brave actually picked
brave-browser --version   # doesn't show this; use brave://gpu instead:
# open brave://gpu and look for "Ozone platform" in the "Info" section
```

Or from the command line at launch, force explicit behavior for testing:

```bash
# Force native Wayland
brave-browser --ozone-platform=wayland

# Force X11 (i.e., run via XWayland even inside a Wayland session)
brave-browser --ozone-platform=x11

# Let Chromium auto-detect (modern default, recommended baseline)
brave-browser --ozone-platform-hint=auto
```

### When switching backends helps

If you see Wayland-specific glitches (flicker, tearing, wrong window decorations, broken screen share), forcing `--ozone-platform=x11` (running through XWayland) is a valid **diagnostic and short-term workaround** — it isolates whether the bug is in Ozone's Wayland backend specifically. If the glitch disappears under X11/XWayland, file/search the issue against Chromium's Ozone/Wayland component rather than Brave, since this is upstream Chromium code Brave doesn't modify.

Conversely, if you're on X11 and experiencing screen tearing, that's typically a compositor/window-manager configuration issue (e.g., no compositing WM active) rather than a Chromium bug — check your WM's compositing settings first.

---

## 7. Graphics Drivers (AMD / Intel / NVIDIA)

Chromium/Brave talk to the GPU through Mesa (for AMD/Intel/Nouveau) or NVIDIA's proprietary driver, via OpenGL (GLX/EGL) and/or Vulkan. Driver bugs are the single most common root cause of desktop-freezing GPU issues, because Chromium is one of the heaviest consumers of GPU driver code paths on a typical Linux desktop (WebGL, WebGPU, video decode, and compositing all exercise different, sometimes under-tested driver paths).

### AMD

- **Kernel driver:** `amdgpu` (modern GPUs) or `radeon` (older GPUs, largely legacy at this point).
- **Userspace OpenGL driver:** Mesa's `radeonsi` (Gallium driver).
- **Userspace Vulkan driver:** **RADV** (Mesa's open-source Vulkan driver) is the default on most distros; AMD's official **AMDVLK** is an alternative, less commonly used for desktop browsing.
- **Common failure pattern:** WebGPU/Vulkan-heavy pages triggering a GPU reset (`amdgpu: ... GPU reset` in `dmesg`) on specific Mesa versions, particularly around new GPU generations shortly after launch when RADV support is still stabilizing. This is a Mesa/kernel bug, not Brave's.
- **Diagnose:** `glxinfo -B` should report `OpenGL renderer string: AMD Radeon ... (radeonsi, ...)`; `vulkaninfo --summary` should list `radv` as the driver. If either shows `llvmpipe` (software rasterizer) instead, the hardware driver isn't being picked up at all — check `lsmod | grep amdgpu` and `dmesg | grep amdgpu` for load failures.
- **Fix path:** Update Mesa first (this is where AMD's open driver fixes land); a kernel update may also be required for new hardware support. Downgrading Mesa is a valid temporary workaround if a *specific* Mesa version introduced a regression (verify via distro changelog/Mesa release notes before assuming).

### Intel

- **Kernel driver:** `i915`.
- **Userspace OpenGL driver:** Mesa's `iris` (modern, Gen8+) or legacy `i965` (older GPUs).
- **Userspace Vulkan driver:** **ANV** (Mesa's Intel Vulkan driver).
- **Common failure pattern:** Video decode (VA-API) failures on newer Intel iGPUs when the distro still ships the older `intel-media-driver` package version that predates support for the specific GPU, or when the legacy `libva-intel-driver` (for very old GPUs) is installed instead of the modern one and conflicts.
- **Diagnose:** `glxinfo -B` should show `Mesa Intel(R) ...` as renderer; `vainfo` should list H.264/HEVC/AV1 profiles depending on GPU generation, using driver `iHD` (intel-media-driver, modern) rather than `i965` (legacy) for anything Broadwell/Gen8 or newer.
- **Fix path:** Ensure `intel-media-driver` (not just `libva-intel-driver`) is installed for anything from roughly Broadwell (2014+) onward; update Mesa for OpenGL/Vulkan-side bugs.

### NVIDIA

- **Proprietary driver:** NVIDIA's own kernel module + userspace OpenGL/EGL/Vulkan driver (not Mesa). Most reliable path on Linux for GPU acceleration in Chromium, but historically had rockier Wayland support than AMD/Intel's Mesa stack.
- **Open-source alternative:** **Nouveau** (Mesa-based), reverse-engineered — functional for 2D/basic compositing but historically far behind for 3D/video-decode performance and not recommended for GPU-accelerated browsing if avoidable, particularly on newer GPUs.
- **Common failure pattern:** `Xid` errors in `dmesg`/`journalctl -k` (NVIDIA's own GPU-fault reporting mechanism, distinct from `amdgpu`/`i915` messages) coinciding with browser freezes, often tied to VRAM pressure from many GPU-composited tabs, or to Wayland/explicit-sync support gaps in specific driver branches. NVIDIA's Wayland `GBM`/EGLStreams transition has historically been a major source of Chromium-specific Wayland bugs on NVIDIA, improving substantially with modern GBM-based driver releases.
- **Diagnose:** `nvidia-smi` (if installed) for driver/GPU status; `journalctl -k | grep -i xid` for fault codes (cross-reference the Xid number against NVIDIA's own Xid error documentation); `glxinfo -B` should show `NVIDIA Corporation` as vendor, not `nouveau` (if you intended to use the proprietary driver).
- **Fix path:** Keep the proprietary driver updated to a recent branch — NVIDIA's Wayland/GBM support has improved substantially version over version. If forced onto an older driver branch, X11/XWayland is often the more stable path for NVIDIA in the interim; test with `--ozone-platform=x11` per [§6](#6-wayland-vs-x11).

### General principle across all three vendors

Chromium's own GPU driver blocklist (mentioned in [§4](#4-gpu-troubleshooting)) exists precisely because driver bugs are common and vendor/version-specific. Before assuming a fix is needed on Brave's side, check:

1. Is this GPU/driver combination in Chromium's blocklist (`brave://gpu` will say so)?
2. Is there an open Chromium bug for this driver+feature combination? Search [issues.chromium.org](https://issues.chromium.org/issues?q=) with terms like `"amdgpu" "GPU reset"` or `"ANV" "WebGPU"`.
3. Is there a Mesa merge request or issue at [gitlab.freedesktop.org/mesa/mesa](https://gitlab.freedesktop.org/mesa/mesa) already tracking it?

---

## 8. VA-API (Video Acceleration)

VA-API (Video Acceleration API) is the Linux standard interface for hardware video decode/encode, implemented by driver-specific backends (`radeonsi`/`nouveau` for AMD/older-NVIDIA via Mesa, `iHD`/`i965` for Intel, `nvidia-vaapi-driver` for NVIDIA proprietary).

### How to verify VA-API is working, independent of the browser

```bash
vainfo
```

Expected output lists a driver name (e.g., `Mesa Gallium driver ... for AMD` or `Intel iHD driver`) and a table of supported `VAProfile`/`VAEntrypoint` pairs (e.g., `VAProfileH264Main : VAEntrypointVLD`). If this command fails or returns "no VA display found," the problem is at the system driver level, not Chromium — fix this first before touching browser flags.

### Enabling VA-API in Brave

Chromium's Linux VA-API video decode support has historically been feature-flagged rather than on-by-default (unlike Windows/macOS hardware decode paths), because of the wide variance in driver quality across distros. Check current status and enable via:

- `brave://flags/#enable-vaapi-video-decoder` — enables the VA-API-backed hardware decode path (name may vary slightly by Chromium version; search "VA-API" in `brave://flags` if not found under this exact ID).
- Command-line equivalent: `--enable-features=VaapiVideoDecodeLinuxGL` or `--enable-features=VaapiVideoDecoder` (the specific feature flag name has changed across Chromium versions — verify the current one for your version via `brave://version`'s Chromium version number cross-referenced against [Chromium's `about://flags` source](https://source.chromium.org/chromium/chromium/src/+/main:chrome/browser/flag-descriptions.cc)).

### Verifying it's actually being used (not just enabled)

1. Play a video (YouTube at 1080p+ is a good stress test).
2. Check `brave://gpu` — under "Video Acceleration Information" it should list active decode profiles, not say "Disabled."
3. Check `brave://media-internals` (Chromium standard internal page) — look at the player's log for `VaapiVideoDecoder` or similar entries indicating the hardware path was selected, vs. `FFmpegVideoDecoder`/software fallback.
4. Confirm CPU usage during playback is low relative to software decode (use `top`/`htop` — a 4K video decoding on CPU alone will typically peg one or more cores; hardware decode should show only modest CPU use for compositing/UI).

### Common failures

| Symptom | Cause |
|---|---|
| `vainfo` fails entirely | Driver package not installed (`mesa-va-drivers` / `intel-media-driver` / `nvidia-vaapi-driver` missing), or `LIBVA_DRIVER_NAME` env var pointing at the wrong backend |
| `vainfo` works but Brave still uses software decode | VA-API flag not enabled in `brave://flags`, or the specific codec (e.g., AV1, HEVC) isn't in the driver's supported profile list even though H.264 is |
| Video decode works but tears/glitches visually | Separate from decode — likely a compositing issue; see [§6](#6-wayland-vs-x11) tearing guidance |
| High CPU despite hardware decode enabled | Codec/profile mismatch — e.g., site serves VP9 or AV1 but only H.264 hardware decode is supported by the driver, forcing software fallback for that specific stream |

---

## 9. ANGLE

**ANGLE** (Almost Native Graphics Layer Engine) is the translation layer Chromium uses on all platforms to implement OpenGL ES (which WebGL and much of Chromium's internal rendering target) on top of whatever native graphics API the platform actually provides. On Linux, ANGLE can target multiple native backends:

- **OpenGL backend** (`--use-angle=gl`) — translates GL ES calls to desktop OpenGL via Mesa/NVIDIA's GL driver. Historically the long-standing default on Linux.
- **Vulkan backend** (`--use-angle=vulkan`) — translates GL ES calls to Vulkan. Increasingly the default/recommended path on modern Chromium versions where the Vulkan driver (RADV/ANV/NVIDIA) is mature, since it gives Chromium more direct control over synchronization and can avoid classes of OpenGL-driver-specific bugs.
- **EGL** is the context/surface management API ANGLE uses underneath both backends on Linux (as opposed to GLX, which is X11-specific) — this is largely internal but relevant when debugging context-creation failures, which show up as `eglCreateContext` errors in verbose logs.

### Checking and switching the active ANGLE backend

`brave://gpu` → "ANGLE backend" (under Info) shows the current backend. Switch with:

```bash
brave-browser --use-angle=gl        # force OpenGL backend
brave-browser --use-angle=vulkan    # force Vulkan backend
brave-browser --use-angle=swiftshader  # force software (diagnostic only, very slow)
```

### Compatibility and when to switch

If WebGL/WebGPU-specific glitches or crashes appear and you've already ruled out compositing/rasterization (per [§4](#4-gpu-troubleshooting)'s isolation order), switching the ANGLE backend is the next-most-targeted diagnostic step:

- If defaulting to Vulkan and seeing crashes → try `--use-angle=gl` to check whether it's a Vulkan-driver-specific ANGLE bug.
- If defaulting to GL and seeing poor performance or synchronization glitches (tearing specifically inside WebGL canvases) → try `--use-angle=vulkan` if the Vulkan driver is confirmed working via `vulkaninfo` first.

As with all backend-switching flags, this narrows the diagnosis; the durable fix is either a driver/Mesa update or, if the bug is in ANGLE itself, a Chromium version update (ANGLE ships bundled with Chromium and is versioned/updated alongside it, not independently upgradable by the distro).

---

## 10. Vulkan

### When Brave uses Vulkan

Vulkan is used in the Chromium/Brave GPU pipeline in three places, and it's worth distinguishing them when debugging:

1. **As an ANGLE backend** for GL ES emulation (see [§9](#9-angle)).
2. **As WebGPU's native backend** on Linux (via Dawn, Chromium's WebGPU implementation) — WebGPU on Linux essentially always goes through Vulkan.
3. Experimentally, for parts of **Skia's GPU rendering backend** ("Graphite"), which is being rolled out progressively in newer Chromium versions as a Vulkan/Metal/D3D12-based successor to the older "Ganesh" GL-based Skia backend.

### Common Vulkan-related issues

- **Missing/broken Vulkan ICD:** if `vulkaninfo --summary` fails or shows no devices, no Chromium Vulkan path can work regardless of flags — this is a system driver installation issue (missing `mesa-vulkan-drivers`/`vulkan-radeon`/`vulkan-intel` package, or NVIDIA's Vulkan ICD JSON not being found by the loader).
- **Validation layer noise:** if you have `VK_LAYER_KHRONOS_validation` installed system-wide (common on dev machines) and Vulkan validation layers are active, Chromium may run measurably slower or hit validation-only warnings unrelated to real bugs. Confirm with `VK_LOADER_DEBUG=all vulkaninfo` whether validation layers are being auto-loaded, and if so, whether `VK_INSTANCE_LAYERS` env vars are forcing them on globally.
- **WebGPU blocklist entries:** even with a working Vulkan driver, `brave://gpu`'s WebGPU status may show "blocklisted" for specific driver versions known to have WebGPU-relevant bugs upstream — this is intentional and version-specific, not a misconfiguration.

### Debugging

```bash
# Confirm the system-level Vulkan driver works at all
vulkaninfo --summary

# Run Brave with Vulkan validation/debug output
brave-browser --enable-logging=stderr --v=1 --use-angle=vulkan --use-vulkan=native 2>&1 | grep -i vulkan
```

### Disabling / enabling

```bash
# Force Vulkan off for Skia/ANGLE (fall back to GL) — diagnostic
brave-browser --use-angle=gl --disable-features=Vulkan

# Explicitly enable Chromium's native Vulkan usage (where supported/default-off in a given version)
brave-browser --use-vulkan=native
```

Treat `--disable-features=Vulkan` the same way as the hardware-acceleration flags in [§5](#5-hardware-acceleration): a diagnostic isolation step, not something to leave on permanently unless you've confirmed a persistent Vulkan driver bug with no near-term fix.

---

## 11. Browser Profiles

A Brave profile (default location `~/.config/BraveSoftware/Brave-Browser/Default/` on Stable; see the table below for other channels) holds SQLite databases (History, Cookies, Web Data), `Preferences`/`Local State` JSON files, extension data, and cached compiled shaders. Corruption in any of these can cause crashes, freezes, or slow startup that look like GPU or Chromium bugs but aren't.

### Profile directories by channel

| Channel | Default profile base path (native Linux package) |
|---|---|
| Brave Stable | `~/.config/BraveSoftware/Brave-Browser/` |
| Brave Beta | `~/.config/BraveSoftware/Brave-Browser-Beta/` |
| Brave Nightly | `~/.config/BraveSoftware/Brave-Browser-Nightly/` |
| Brave Origin | `~/.config/BraveSoftware/Brave-Browser/` (or a distinct Origin-specific dir depending on packaging — check `brave://version` "Profile Path" to confirm rather than assuming) |
| Brave Origin Beta / Nightly | Analogous `-Beta`/`-Nightly` suffixed directories; again, confirm via `brave://version` rather than assuming, since Origin packaging is newer and less standardized across distros |
| Flatpak (any channel) | `~/.var/app/com.brave.Browser/config/BraveSoftware/...` (sandboxed home) |
| Snap (any channel) | `~/snap/brave/current/.config/BraveSoftware/...` |

> Always confirm the actual path via `brave://version` → "Profile Path" rather than assuming — packaging varies enough between distros/Flatpak/Snap/Origin builds that hardcoding a path is a common source of "I fixed the wrong profile" confusion.

### Symptoms of profile corruption

- Crash/freeze only on startup, specifically only for one profile (test with `--user-data-dir=/tmp/brave-test-profile` to launch a throwaway clean profile — if the problem disappears, it's profile-specific, not system-wide).
- `Preferences` or `Local State` JSON files that fail to parse (rare, but can happen after a crash mid-write or a full disk) — Chromium will often reset to defaults silently if invalid, but partial corruption can cause more confusing hangs.
- Slow startup correlating with very large `History`/`Favicons`/`Cookies` SQLite files (multi-GB after years of use without ever being vacuumed).

### Safe profile reset methods without data loss

**Never delete the whole profile directory as a first step** — that destroys bookmarks, saved passwords, history, and extension data. Work from narrowest to broadest:

1. **Clear GPU shader cache only** (safe, no user data affected — fixes the "hangs after update" pattern from [§2](#2-common-symptoms-and-what-they-usually-mean)):
   ```bash
   rm -rf ~/.config/BraveSoftware/Brave-Browser/ShaderCache
   rm -rf ~/.config/BraveSoftware/Brave-Browser/GrShaderCache
   ```
2. **Test with a throwaway profile** to confirm it's profile-related at all, without touching your real profile:
   ```bash
   brave-browser --user-data-dir=/tmp/brave-clean-test
   ```
3. **Reset just Preferences (keeps bookmarks/history/passwords, which live in separate SQLite files)**:
   ```bash
   cd ~/.config/BraveSoftware/Brave-Browser/Default
   cp Preferences Preferences.bak
   # Chromium will regenerate Preferences with defaults if it's missing/invalid on next launch
   ```
4. **Compact/vacuum the SQLite databases** if size is the suspected slow-startup cause (requires `sqlite3` CLI, and Brave must be fully closed):
   ```bash
   sqlite3 ~/.config/BraveSoftware/Brave-Browser/Default/History "VACUUM;"
   ```
5. **Create a new profile via the browser's own Profile menu** (Brave menu → profile icon → Add Profile) rather than editing files at all, if you just need a clean slate to compare against — this is the safest possible isolation test since it doesn't touch the original profile.

Only as an absolute last resort, after confirming via step 2 that the issue is profile-specific and steps 3–4 didn't help, consider renaming (not deleting) the profile directory so Brave regenerates a fresh one, keeping the old one available to manually recover bookmarks/passwords from via `brave://bookmarks`/password export tools if needed.

---

## 12. Extensions

### Debugging extensions

- `brave://extensions` — enable "Developer mode" (toggle, top right) to see extension IDs, inspect views (background pages/service workers), and reload individual extensions without restarting the browser.
- Each extension with an error shows an "Errors" button on its card in `brave://extensions` — click through for the actual JS exception/stack trace, which is far more actionable than guessing.
- For Manifest V3 extensions, background logic runs as a **service worker** rather than a persistent background page; a common failure mode is the service worker terminating (by design, to save resources) and failing to properly wake up on the next event — visible as "Inactive" status or errors referencing the service worker lifecycle in `brave://extensions`.

### Safe mode / isolating extension-caused issues

Chromium/Brave don't have a single "safe mode" flag, but the equivalent is:

```bash
# Launch with all extensions disabled
brave-browser --disable-extensions
```

If the symptom disappears, the cause is extension-related. Then bisect:

1. Disable all extensions manually via `brave://extensions` (toggle each off).
2. Re-enable them one at a time (or in halves, for a faster binary search if you have many), relaunching and testing between each, until the symptom reappears.
3. The last-enabled extension before recurrence is the culprit.

### Identifying broken extensions without manual bisection

- Check `brave://extensions` for any extension flagged as **not from the Chrome/Brave Web Store** or **corrupted** — Chromium actively warns about these, and they're disproportionately likely to cause instability.
- Check for extensions that haven't been updated to Manifest V3 — Manifest V2 extensions are being phased out across the Chromium ecosystem, and continuing to run old, unmaintained MV2 extensions correlates with more crashes/errors than actively maintained MV3 ones.
- High-permission extensions (content scripts on `<all_urls>`, especially ones injecting on every page) are more likely to conflict with page rendering than narrowly-scoped ones — worth suspecting first during bisection.

---

## 13. Command-Line Flags Reference

All flags below are launched as `brave-browser --flag-name[=value]`. For a one-off test without changing your default launcher, run this directly from a terminal.

> **Persisting flags.** To make flags persistent across launches without editing every launcher shortcut, Chromium-family browsers on Linux read a `BRAVE_FLAGS` (or generically, `CHROME_USER_FLAGS`-style, distro-dependent) environment variable in some packaging setups, or you can wrap the binary. The most broadly reliable method is a small wrapper script placed earlier in `PATH`:
> ```bash
> #!/bin/sh
> exec /usr/bin/brave-browser --disable-gpu-compositing "$@"
> ```
> Avoid editing `brave://flags` for things that are properly command-line switches (like `--user-data-dir` or sandbox flags) — `brave://flags` is for *experimental features*, not general CLI switches, and its settings are stored in `Local State` (profile-scoped), not globally.

### GPU

| Flag | Purpose | Risk | Use when | Avoid when |
|---|---|---|---|---|
| `--disable-gpu` | Disables GPU process acceleration entirely | High performance cost | Isolating whether *any* GPU involvement causes a crash | Daily use |
| `--disable-gpu-compositing` | Falls back to software compositing | Moderate performance cost | Isolating compositor-specific freezes/tearing | Rasterization/ANGLE-specific bugs |
| `--disable-gpu-rasterization` | Falls back to CPU rasterization | Moderate performance cost | Isolating paint/canvas corruption | Compositor/WebGL-specific bugs |
| `--ignore-gpu-blocklist` | Overrides Chromium's built-in driver blocklist | Can re-enable known-buggy combinations | Confirming whether a blocklist entry (vs. a real independent bug) is the cause | Any non-diagnostic use |
| `--disable-gpu-sandbox` | Disables the GPU process's OS-level sandbox | Security-relevant — reduces isolation | Diagnosing whether the sandbox itself is causing GPU init failure (rare, mostly relevant on restrictive kernels/containers) | Normal browsing |

### Rendering / ANGLE / Vulkan

| Flag | Purpose |
|---|---|
| `--use-angle=gl` / `--use-angle=vulkan` / `--use-angle=swiftshader` | Selects ANGLE's native backend |
| `--use-vulkan=native` | Enables Chromium's native Vulkan usage path where applicable |
| `--disable-features=Vulkan` | Disables Vulkan feature flag entirely (forces GL paths) |
| `--disable-oop-rasterization` | Disables out-of-process rasterization |
| `--disable-software-rasterizer` | Prevents SwiftShader software fallback (fail loudly instead of silently degrading) |

### Wayland / Ozone

| Flag | Purpose |
|---|---|
| `--ozone-platform=wayland` | Force native Wayland backend |
| `--ozone-platform=x11` | Force X11/XWayland backend |
| `--ozone-platform-hint=auto` | Let Chromium auto-select based on session type (recommended default baseline) |
| `--enable-features=WaylandWindowDecorations` | Enables Chromium-drawn window decorations under Wayland where server-side decorations aren't provided by the compositor |

### Debugging / Logging

| Flag | Purpose |
|---|---|
| `--enable-logging=stderr` | Sends Chromium's internal logging to stderr instead of (or in addition to) the default log file |
| `--v=1` (or higher, e.g. `--v=2`) | Verbose logging level; higher numbers = more detail, diminishing returns above 2–3 for most troubleshooting |
| `--vmodule=<pattern>=<level>` | Per-module verbose logging (e.g., `--vmodule=*gpu*=2` for GPU-subsystem-only verbosity, useful to avoid drowning in unrelated log noise) |
| `--enable-crash-reporter` | Forces crash reporting on if a minimal/self-built environment has it off by default |
| `--no-crash-upload` | Collects crash dumps locally without uploading them (useful when you want `coredumpctl`/`brave://crashes`-equivalent local artifacts without network transmission) |

### Sandbox

| Flag | Purpose | Risk |
|---|---|---|
| `--no-sandbox` | Fully disables the OS-level sandbox for all processes | **Significant security risk** — only ever use in a disposable/throwaway test environment (e.g., a container specifically for reproducing a bug) to determine whether the sandbox setup itself (not the sandboxed code) is the cause of a startup crash. Never use for normal daily browsing. |
| `--disable-setuid-sandbox` | Disables the SUID-root sandbox helper specifically, while other sandbox layers may remain | Narrower than `--no-sandbox`; still meaningfully reduces isolation — diagnostic use only |

### Networking

| Flag | Purpose |
|---|---|
| `--disable-http-cache` | Forces every request to bypass the disk HTTP cache — useful for isolating whether a stale/corrupted cache is causing incorrect page behavior |
| `--host-resolver-rules` | Overrides DNS resolution for specific hosts — useful for testing against a known-good vs. suspect endpoint |

### Performance

| Flag | Purpose |
|---|---|
| `--disable-background-timer-throttling` | Prevents Chromium from throttling JS timers in background tabs — useful to rule out throttling as the explanation for "background tab seems stuck," as opposed to a real hang |
| `--renderer-process-limit=<N>` | Caps the number of renderer processes, forcing more site-sharing per process — useful for testing whether excessive process count (RAM pressure) is contributing to slowdown on memory-constrained systems |

### Security (diagnostic-only, do not leave enabled)

| Flag | Purpose | Risk |
|---|---|---|
| `--disable-web-security` | Disables same-origin policy enforcement | **Severe** — only for isolated, throwaway, network-disconnected testing of whether a CORS-related symptom is being misdiagnosed as a rendering bug; never for real browsing |
| `--allow-running-insecure-content` | Allows mixed active content to load | Meaningful security downgrade — diagnostic use only, on non-sensitive test pages |

---

## 14. Logging

### Verbose logging

```bash
brave-browser --enable-logging=stderr --v=1 2>&1 | tee brave.log
```

`--v=1` gives general verbosity across all modules; increasing to `--v=2` or `--v=3` produces substantially more output and is best combined with `--vmodule` to scope it to the subsystem you care about (otherwise the log becomes too noisy to read):

```bash
# GPU-subsystem-focused verbose logging only
brave-browser --enable-logging=stderr --vmodule="*gpu*=2,*viz*=2" 2>&1 | tee gpu-debug.log
```

### GPU-specific logging

`brave://gpu` itself is usually sufficient for a snapshot, but for live GPU process logging during a reproduction:

```bash
brave-browser --enable-logging=stderr --vmodule="*gpu*=2" --gpu-startup-dialog
```

(`--gpu-startup-dialog` pauses the GPU process at startup with its PID printed, letting you attach `gdb`/`strace` before it proceeds — an advanced technique for catching init-time GPU process crashes.)

### Renderer logging

Individual renderer process crashes/console errors are visible via DevTools (`F12` or right-click → Inspect → Console) for JS-level issues, or via the same `--enable-logging=stderr --v=1` global flags for renderer-process-level (not page-JS-level) problems.

### Startup logging

```bash
brave-browser --enable-logging=stderr --v=1 2>&1 | head -200
```

The first ~100–200 lines cover profile load, sandbox setup, and GPU process initialization in sequence — a startup crash's actual cause is almost always visible in this window rather than requiring full verbosity throughout a session.

### Crash dumps and symbolized stack traces

- **Brave's built-in reporter:** `brave://crashes` lists local minidumps; if crash upload is enabled, "Report ID" values correlate with Brave's crash server for engineers to symbolize server-side. As a user you generally cannot symbolize these yourself without Brave's private symbol server access.
- **`systemd-coredump`:** if enabled at the OS level (`systemctl status systemd-coredump.socket`), gives you locally-inspectable core dumps:
  ```bash
  coredumpctl list brave
  coredumpctl gdb <PID or MATCH>
  ```
  Inside `gdb`, `bt` (backtrace) gives a stack trace — often unsymbolized for Brave's own stripped release binaries (function names may show as offsets), but still useful to identify *which shared library* (e.g., `libGL.so`, `libvulkan_radeon.so`, Brave's own binary) the crash occurred in, which tells you whether to keep debugging in Chromium/Mesa territory or Brave's own code.
- **`ulimit -c unlimited`** before launching, if `systemd-coredump` isn't configured, to get raw core files in the working directory instead.

---

## 15. Linux Packaging (deb/rpm/Flatpak/Snap)

| Packaging | Update cadence | Sandbox behavior | Notes |
|---|---|---|---|
| **Official Brave `.deb`/`.rpm`** (from Brave's own apt/yum repo) | Matches Brave's own release schedule directly | Standard Chromium SUID/namespace sandbox against the host system | Generally the most predictable and closest to "upstream Brave behavior" — recommended baseline for troubleshooting since it removes a packaging-lag variable |
| **Flatpak** (`com.brave.Browser`) | Depends on the Flathub maintainer's update cadence, can lag official releases by hours to a few days | Runs inside a Flatpak sandbox *in addition to* Chromium's own internal sandbox — effectively double-sandboxed, which occasionally causes extra friction with things like GPU device access (`/dev/dri`), portal-based screen sharing, and native messaging hosts (some browser extensions that talk to native apps need explicit Flatpak permission grants via `flatpak override`) | If a bug reproduces only in Flatpak and not the native package, suspect Flatpak sandbox permissions (`flatpak permission-list`, `flatpak override --show com.brave.Browser`) before assuming it's a Brave bug |
| **Snap** | Similar lag potential to Flatpak, cadence depends on the snap maintainer | Uses AppArmor + its own confinement model layered with Chromium's sandbox | Historically had more friction than Flatpak with GPU acceleration and VA-API passthrough on some distros due to stricter default confinement; check `snap connections brave` for granted interfaces (e.g., `opengl`, `desktop`, `wayland`) if GPU features behave differently than the native package |
| **Distribution package** (distro's own repo build, e.g., some distros ship a community or distro-maintained Brave-adjacent build) | Often the least predictable cadence, sometimes significantly behind upstream | Standard sandbox, but built against the distro's own (possibly older or newer) system libraries rather than Brave's bundled ones | If a bug is distro-package-specific and doesn't reproduce with the official Brave repo package on the same system, suspect a library version mismatch (e.g., a bundled vs. system `libffmpeg` build affecting codec support) |

### Diagnosing packaging-specific bugs

1. **Confirm the exact package source:**
   ```bash
   # Debian/Ubuntu-family
   apt-cache policy brave-browser
   # RPM-family (Fedora/openSUSE)
   rpm -qi brave-browser
   # Flatpak
   flatpak info com.brave.Browser
   # Snap
   snap info brave
   ```
2. **Compare against the official Brave repo build** if you're not already using it — this isolates whether the bug is Brave-general or specific to this particular packaging/build.
3. For Flatpak/Snap GPU issues specifically, verify device access:
   ```bash
   # Flatpak: confirm DRI device is exposed
   flatpak run --command=sh com.brave.Browser -c 'ls -la /dev/dri'
   # Snap: confirm opengl interface is connected
   snap connections brave | grep opengl
   ```

---

## 16. Distribution-Specific Issues

| Distro | Notes |
|---|---|
| **openSUSE Tumbleweed** | Rolling release — Mesa/kernel versions are typically very current, which means you're more likely to hit *newly introduced* Mesa/kernel regressions than *outdated-driver* problems. If a GPU bug appears right after a `zypper dup`, checking Mesa's changelog for the specific version bump is a high-value first step; `zypper install --oldpackage` can pin back a specific Mesa version if a regression is confirmed and not yet fixed upstream. Official Brave repo is available directly via `zypper addrepo`/`rpm` per Brave's own Linux install docs. |
| **Fedora** | Also a fast-moving release cadence (roughly 6-month major versions with frequent package updates within a release). Fedora ships fully open-source codec/VA-API stacks by default due to licensing policy — for some proprietary codecs (certain H.264/AAC paths) you may need RPM Fusion packages for full hardware decode coverage depending on the specific codec and GPU. |
| **Arch Linux** | Rolling release, generally very current packages, minimal patching relative to upstream — a good environment for confirming whether a bug is a genuine upstream Chromium/Mesa bug (since Arch's packages are close to vanilla) versus a distro-patching artifact. The AUR may host additional Brave-related packages (e.g., alternate channels) not available in the official Brave repo; these carry the usual AUR trust/maintenance caveats and should be compared against the official repo package if troubleshooting. |
| **Debian** | Conservative, slow-moving stable releases mean Mesa/kernel versions can be significantly older than upstream by the time you hit a bug — many "this is broken on Debian" reports are actually "this was fixed in a newer Mesa than Debian stable ships." Backports or Debian testing/sid can be used to test against a newer Mesa version if you suspect this. Non-free codec packages may be required for full hardware video decode. |
| **Ubuntu** | Similar update-lag considerations to Debian, somewhat less conservative depending on release (LTS vs. interim). Snap is Ubuntu's default packaging channel for many apps but Brave is typically installed via its own apt repo or as a `.deb`, not as Ubuntu's default snap store offering — verify which you actually have installed per [§15](#15-linux-packaging-debrpmflatpaksnap)'s diagnosis commands, since behavior can differ. |
| **Linux Mint** | Debian/Ubuntu-based, inherits the same Mesa/kernel-lag considerations as its base. Mint's own Software Manager may offer Brave via Flatpak by default in some configurations — again, confirm actual packaging source before troubleshooting. |
| **Pop!_OS** | Ubuntu-based with System76's own kernel/driver patches, particularly relevant for NVIDIA (System76 ships a customized NVIDIA driver integration and hybrid graphics tooling). GPU-switching (`system76-power graphics` / hybrid graphics setups) is a Pop!_OS-specific variable to check when Brave picks an unexpected GPU (e.g., integrated instead of discrete) — verify via `brave://gpu`'s reported GPU vendor/model against `system76-power graphics` output. |
| **EndeavourOS** | Arch-based, effectively inherits Arch's package currency and troubleshooting characteristics; the main EndeavourOS-specific variable is whichever desktop environment/compositor was chosen at install (varies per user), which matters for the Wayland-vs-X11 guidance in [§6](#6-wayland-vs-x11). |

---

## 17. Case Studies

### Case 1: Hard freezes isolated with `--disable-gpu-compositing`

**Symptoms:** Brave Stable freezes the entire window (not the whole desktop — other apps remain responsive) roughly every 20–40 minutes during normal browsing with 10+ tabs open, on a system with an AMD GPU. No crash dialog appears; the window simply stops repainting and must be killed via `xkill`/`kill -9`.

**Investigation:**
1. `brave://gpu` at a healthy moment showed GPU compositing and rasterization both "Hardware accelerated," ANGLE backend "Vulkan (RADV)."
2. `journalctl -k -f` was left running across two freeze occurrences. Both times, kernel log showed `amdgpu: [gfxhub] ... GPU fault detected` followed a few seconds later by `amdgpu: GPU reset(...) succeeded` — indicating the *kernel driver itself* recovered from a fault, but Chromium's GPU process did not gracefully recover its own state afterward, leaving the compositor stuck.
3. `coredumpctl list brave` showed no crash — consistent with the finding that the browser *process* never died; only the GPU→compositor pipeline stalled.

**Reasoning:** A GPU reset event is a kernel/driver-level fault recovery, not a Chromium logic bug — but whether Chromium's GPU process *recovers cleanly* from a reset (rather than deadlocking against a driver context that's mid-recovery) is exactly the kind of thing the compositor path can fail at. Isolating whether the compositor specifically (as opposed to rasterization or ANGLE broadly) was implicated meant testing the narrowest applicable flag first.

**Diagnosis:** Relaunching with:
```bash
brave-browser --disable-gpu-compositing
```
eliminated the freezes entirely over several days of equivalent usage, while `brave://gpu` confirmed GPU rasterization remained active (only compositing fell back to software) — narrower, and less of a performance sacrifice, than `--disable-gpu` outright.

**Root cause:** A RADV/Mesa-level GPU reset recovery gap interacting with Chromium's Vulkan-backed GPU compositing path on this specific Mesa version — a known class of issue tracked upstream between Mesa's RADV component and Chromium's `gpu/` compositor code, not a defect introduced by Brave.

**Final fix:** Two-part — (1) apply `--disable-gpu-compositing` immediately as a stability workaround via a wrapper script (see [§13](#13-command-line-flags-reference)), accepting the modest performance cost; (2) track the corresponding Mesa release notes for the fix, and remove the flag once an updated Mesa package confirmed to include the relevant RADV reset-handling fix was installed, re-verifying stability over an equivalent usage window before considering it resolved.

**Lessons learned:** A hard freeze without a crash dialog is a strong signal to check kernel/driver logs *before* touching browser flags — the flag is a diagnostic tool to confirm the hypothesis (compositor-specific) formed from the kernel log evidence, not a blind first move. `--disable-gpu-compositing` should be understood here as isolating a driver-recovery interaction bug, not as "fixing GPU compositing" in general — it was a temporary, targeted workaround pending an upstream Mesa fix, not a permanent configuration choice.

### Case 2: "Aw, Snap" tab crashes traced to a memory-hungry extension

**Symptoms:** Individual tabs crash with "Aw, Snap!" seemingly at random, more frequently as a browsing session goes on, across multiple unrelated websites.

**Investigation:** `dmesg | grep -i "oom-kill"` after a crash showed `Out of memory: Killed process ... (Renderer) total-vm:... rss:...`, confirming the kernel OOM-killer, not a Chromium-internal bug, was terminating renderers under system memory pressure. `htop`'s tree view during a long session showed one particular renderer process's RSS climbing steadily over hours without plateauing, well beyond what the visible page content would explain, while other renderers behaved normally.

**Reasoning:** Site-isolated architecture means one misbehaving tab's renderer growing unboundedly can starve system memory enough to get *other*, unrelated tabs' renderers OOM-killed too — explaining why crashes appeared "random" across different sites rather than always on the one actually leaking.

**Diagnosis:** Relaunched with `--disable-extensions`; the same long browsing session no longer showed unbounded RSS growth in any renderer. Bisecting extensions one at a time (per [§12](#12-extensions)) identified a specific content-script-injecting extension active on every page.

**Root cause:** The extension's content script held references preventing garbage collection of DOM nodes across page navigations within the same renderer process (a classic JS memory leak pattern), compounding over a session.

**Final fix:** Extension removed/replaced with an alternative; reported to the extension's own developer with the reproduction steps, since this was the extension's bug, not Brave's or Chromium's.

**Lessons learned:** Not every crash is a browser bug — checking `dmesg` for OOM-kill evidence early prevents misattributing memory-pressure symptoms to the GPU/renderer pipeline, and extension bisection is cheap relative to deeper Chromium-level debugging, so it belongs early in the triage order for anything with a plausible extension angle.

---

## 18. Troubleshooting Flowcharts

### Browser won't launch at all

```
Brave won't launch
        │
        ▼
Run from terminal: brave-browser
Any error printed?
        │
   ┌────┴─────┐
  YES         NO (silent failure)
   │           │
   ▼           ▼
Read error   Check: ps aux | grep brave
directly.    (did it start and immediately
Missing .so? die with no output?)
  → ldd $(which brave-browser)      │
Permission error?                    ▼
  → check binary permissions    Check exit code: echo $?
Profile lock error?             127 = binary not found (PATH issue)
  → another instance running?   Other non-zero = check dmesg for
    pkill -f brave-browser        OOM-kill or SIGSEGV at that PID
```

### Browser starts but freezes/crashes during use

```
Symptom occurs during use
        │
        ▼
Does the WHOLE DESKTOP freeze (not just Brave)?
        │
   ┌────┴─────┐
  YES          NO — only Brave's window
   │            │
   ▼            ▼
journalctl -k -f during repro   Single tab, or whole window?
Look for GPU reset / Xid errors     │
→ This is a driver/kernel fault   ┌─┴──┐
  See §7 Graphics Drivers      Single  Whole window
                                tab     │
                                 │      ▼
                                 ▼   brave://gpu — any
                          Extension?  feature "Disabled"/
                          §12          "Software only"?
                          Renderer          │
                          crash?       ┌────┴────┐
                          §3 logging  YES         NO
                                       │           │
                                       ▼           ▼
                                  §4 GPU        Profile issue?
                                  isolation     Test with
                                  order         --user-data-dir=
                                                /tmp/test
                                                 → §11
```

### Rendering glitch (flicker / tearing / black-white window)

```
Rendering glitch observed
        │
        ▼
Wayland or X11 session? (echo $XDG_SESSION_TYPE)
        │
   ┌────┴─────┐
Wayland        X11
   │            │
   ▼            ▼
Try --ozone-      Check WM compositor
platform=x11      is active (tearing
Glitch gone?       usually = no
   │               compositing WM)
 ┌─┴──┐
YES    NO
 │      │
 ▼      ▼
Ozone/  §4 GPU isolation
Wayland order (compositing →
backend  rasterization → ANGLE)
bug,
§6
```

---

## 19. Best Practices

### Updating Mesa safely

- On rolling-release distros (Tumbleweed, Arch, EndeavourOS), don't blindly assume the newest Mesa is always best for stability — it's the newest *feature-wise*, but new GPU-generation support and new code paths (RADV/ANV Vulkan features, new ANGLE integration points) are exactly where regressions cluster. If you hit a fresh regression right after an update, check the Mesa version's own release notes/merge history before assuming it's unfixable, and know how to pin/downgrade a single package on your distro as a temporary measure.
- On slower-moving distros (Debian stable, Ubuntu LTS), the opposite risk applies: you may be carrying a known-fixed-upstream bug for a long time. If official Brave/Chromium or Mesa upstream documentation confirms a bug was fixed in a specific Mesa version newer than what your distro ships, that's useful evidence to include in a distro bug report, or justification to test via backports/testing repos.

### Managing Brave flags

- Keep a personal log of every non-default flag you've applied and *why* (the diagnostic finding that justified it) — flags accumulated over time without documentation become impossible to safely remove later, and can mask new, unrelated bugs.
- Revisit standing flags after every Brave/Mesa/kernel update — a workaround for a driver bug that's since been fixed upstream is pure downside (lost performance/features) with no remaining benefit.

### Keeping profiles healthy

- Periodically check profile SQLite database sizes (`du -sh ~/.config/BraveSoftware/Brave-Browser/Default/*`) — very large History/Favicons files are a legitimate, if uncommon, contributor to slow startup and are safe to `VACUUM` (browser closed) per [§11](#11-browser-profiles).
- Clear the shader cache after major Brave version jumps or Mesa/driver updates as routine maintenance, not just as a crash-response step.

### Reporting bugs

- Chromium's own [bug reporting guidelines](https://www.chromium.org/for-testers/bug-reporting-guidelines/) apply to anything below the Brave-specific feature layer — include Chromium version (not just Brave version), `brave://gpu` feature status text, exact repro steps, and whether the bug reproduces in stock `chromium`/`google-chrome` with equivalent flags (this single data point massively speeds up correct triage, since it tells maintainers immediately whether to route the report upstream).
- File Brave-specific bugs (Shields, Rewards/Wallet on non-Origin channels, Brave-only UI) against Brave's own GitHub issue tracker; file everything else (rendering, GPU, sandbox, Wayland/X11, extensions API) with awareness that it's very likely a shared Chromium/Mesa/kernel issue, and check the relevant upstream tracker first.

### Bisecting regressions

- Brave Nightly exists specifically to make Chromium-version bisection possible before a bug ships to Stable — if a regression appears after a Stable update, check whether it also reproduces on the currently released Nightly (further ahead) and whether older Nightly archives (if you keep them, or via the version history) let you narrow the exact version that introduced it.
- For driver-side bisection, distro package archives (e.g., Arch's package archive, openSUSE's `zypper install --oldpackage`) let you pin to a specific prior Mesa version to confirm/deny a Mesa-version-introduced regression concretely, rather than guessing from changelogs alone.

### Avoiding placebo fixes

- A flag "fixing" a symptom once, without repeated verification across multiple reproduction attempts, is not confirmed — GPU driver bugs are frequently intermittent/timing-dependent, and a single non-recurrence after a change can be coincidence. Re-test the *specific* symptom multiple times, ideally across more than one session, before concluding a flag change was the actual fix.
- Prefer the narrowest flag that resolves the symptom (per the isolation order in [§4](#4-gpu-troubleshooting)) over reaching straight for `--disable-gpu` — a broad flag "working" doesn't tell you which subsystem was actually at fault, which matters both for reporting the bug correctly and for eventually removing the workaround once it's fixed upstream.

### Creating reproducible bug reports

Minimum useful bug report checklist:

- [ ] Brave version + Chromium version (from `brave://version`)
- [ ] Channel (Stable/Beta/Nightly/Origin variant)
- [ ] Distro + version, packaging source (native repo/Flatpak/Snap — see [§15](#15-linux-packaging-debrpmflatpaksnap))
- [ ] Display server (X11/Wayland) and compositor/DE
- [ ] GPU vendor/model + driver version (`inxi -Gxx` output)
- [ ] `brave://gpu` "Graphics Feature Status" text
- [ ] Exact repro steps, and whether it reproduces with a clean profile (`--user-data-dir=/tmp/test`)
- [ ] Whether it reproduces with extensions disabled (`--disable-extensions`)
- [ ] Whether it reproduces in stock `chromium`/`google-chrome` with equivalent flags
- [ ] Relevant `journalctl -k`/`dmesg` output from the time of the issue

---

## 20. Cheat Sheets

### Linux commands

| Command | Use |
|---|---|
| `journalctl -k -f` | Live kernel log during reproduction |
| `dmesg -T \| tail -100` | Recent kernel messages, human-readable timestamps |
| `coredumpctl list brave` | List crash core dumps |
| `coredumpctl gdb <PID>` | Inspect a core dump |
| `glxinfo -B` | OpenGL renderer/driver summary |
| `vulkaninfo --summary` | Vulkan device/driver summary |
| `vainfo` | VA-API supported profiles |
| `inxi -Gxx` | Full GPU hardware/driver/display-server summary |
| `lspci -k \| grep -A3 VGA` | Kernel driver bound to GPU |
| `lsmod \| grep -E 'amdgpu\|i915\|nvidia\|nouveau'` | Confirm GPU kernel module loaded |
| `ps -T -p <pid>` | Thread states (look for `D` = blocked on I/O/driver) |
| `top -H` / `htop` | Live per-thread CPU usage |

### Brave internal pages

| Page | Use |
|---|---|
| `brave://gpu` | GPU feature status, active driver/ANGLE backend |
| `brave://version` | Version, profile path, active flags |
| `brave://flags` | Experimental feature toggles |
| `brave://crashes` | Local crash report list |
| `brave://histograms` | Live internal event counters |
| `brave://sandbox` | Per-process sandbox status |
| `brave://media-internals` | Per-video decode-path diagnostics |
| `brave://extensions` | Extension management, errors, dev mode |

### GPU flags

| Flag | Effect |
|---|---|
| `--disable-gpu` | All acceleration off |
| `--disable-gpu-compositing` | Software compositing |
| `--disable-gpu-rasterization` | Software rasterization |
| `--use-angle=gl` / `vulkan` / `swiftshader` | ANGLE backend selection |
| `--use-vulkan=native` | Native Vulkan path |
| `--ignore-gpu-blocklist` | Override driver blocklist (diagnostic only) |

### Debug flags

| Flag | Effect |
|---|---|
| `--enable-logging=stderr --v=1` | Verbose logging to stderr |
| `--vmodule=*gpu*=2` | Scoped verbose logging |
| `--disable-extensions` | Extension bisection baseline |
| `--user-data-dir=/tmp/test` | Throwaway clean profile |
| `--no-sandbox` | **Diagnostic only, disposable environments** |

### Graphics troubleshooting quick map

| Symptom | Start here |
|---|---|
| Whole desktop freezes | `journalctl -k` for GPU reset/Xid → §7 |
| Only Brave window freezes/blacks out | §4 GPU isolation order |
| Video stutters, high CPU | §8 VA-API |
| WebGL/WebGPU broken | §9 ANGLE, §10 Vulkan |
| Wayland flicker/tearing | §6, try `--ozone-platform=x11` |
| Random tab crashes | `dmesg` OOM check → §12 extensions |
| Slow/failed startup | §11 profile |
| Won't launch at all | §15 packaging, `ldd` |

### Common log locations

| Log | Path/command |
|---|---|
| Kernel log | `journalctl -k` |
| Crash core dumps | `coredumpctl list brave` |
| Brave local crash reports | `brave://crashes` |
| Profile | `~/.config/BraveSoftware/Brave-Browser/Default/` (see §11 for other channels) |
| Shader cache | `~/.config/BraveSoftware/Brave-Browser/ShaderCache`, `GrShaderCache` |

### Common symptoms → common fixes (summary — see full sections for reasoning)

| Symptom | First diagnostic step | Common resolution |
|---|---|---|
| Hard freeze, GPU reset in kernel log | `--disable-gpu-compositing` | Mesa/driver update once upstream fix lands |
| Video stutter | `vainfo` | Install/enable correct VA-API driver package |
| Startup crash | Run from terminal, read stderr | Clean profile test, sandbox check |
| Extension-related crash | `--disable-extensions` | Bisect and remove/replace extension |
| Wayland tearing/flicker | `--ozone-platform=x11` | Mesa/compositor update, or stay on X11 short-term |
| Slow startup | Check profile DB sizes | `VACUUM` databases, clear shader cache |

---

*This guide covers Brave Stable, Beta, Nightly, Origin, Origin Beta, and Origin Nightly on Linux. Because Brave inherits Chromium's rendering/GPU/sandbox architecture almost unchanged, most of the diagnostic methodology here — process isolation, GPU subsystem isolation, driver log correlation — applies equally to any Chromium-based browser on Linux.*
