# ⏱️ Timed Shutdown, Reboot & Hibernate on Linux

> Schedule a **power-off**, **reboot**, **hibernate** or **suspend-then-hibernate** after *N* seconds, minutes or hours, straight from the terminal.
>
> Part of [`clean-system-guide`](https://github.com/itachi-re/clean-system-guide). Written for **openSUSE Tumbleweed (KDE Plasma 6)**, and valid on any **systemd**-based distro.

---

## 📑 Table of Contents

- [⚡ Cheat sheet](#-cheat-sheet)
- [🧭 Which tool should I use?](#-which-tool-should-i-use)
- [🕒 Time formats](#-time-formats)
- [🔴 Shutdown (power off) after N minutes/hours](#-shutdown-power-off-after-n-minuteshours)
- [🔄 Reboot after N minutes/hours](#-reboot-after-n-minuteshours)
- [🛌 Hibernate after N minutes/hours](#-hibernate-after-n-minuteshours)
- [🌓 Suspend now, hibernate later](#-suspend-now-hibernate-later)
- [🔍 Check and cancel pending actions](#-check-and-cancel-pending-actions)
- [💤 Hibernate only when idle](#-hibernate-only-when-idle)
- [🧰 Handy shell function](#-handy-shell-function)
- [🩺 Troubleshooting](#-troubleshooting)
- [📚 References](#-references)

---

## ⚡ Cheat sheet

| Goal | Command |
| :--- | :--- |
| Power off in 30 min | `sudo shutdown -P +30` |
| Power off in 2 hours | `sudo shutdown -P +120` |
| Reboot in 15 min | `sudo shutdown -r +15` |
| Hibernate in 30 min | `sudo systemd-run --on-active=30m systemctl hibernate` |
| Suspend now, hibernate after 30 min | `sudo systemd-run --on-active=30m systemctl suspend-then-hibernate` *(see [details](#-suspend-now-hibernate-later))* |
| Cancel a pending shutdown/reboot | `sudo shutdown -c` |
| Show a pending shutdown/reboot | `shutdown --show` *(systemd 250+)* |
| Cancel a pending timer | `sudo systemctl stop <name>.timer` |

> [!IMPORTANT]
> `shutdown` can only **power off, halt or reboot**. It cannot hibernate. For hibernate, use `systemd-run` (or `at`) as shown below.

---

## 🧭 Which tool should I use?

```mermaid
flowchart TD
    A([Do something later]) --> B{What action?}
    B -->|Power off or reboot| C["shutdown -P +N or shutdown -r +N"]
    B -->|Hibernate or suspend| D["systemd-run --on-active=Nm systemctl hibernate"]
    B -->|Only after inactivity| E["Desktop power settings or logind IdleAction"]
    C --> F["Cancel: shutdown -c"]
    D --> G["Cancel: systemctl stop unit.timer"]
```

| Tool | Power off / Reboot | Hibernate | Notes |
| :--- | :---: | :---: | :--- |
| `shutdown` | ✅ | ❌ | Minutes only (`+m`), simple, sends a warning to logged-in users |
| `systemctl poweroff --when=` | ✅ | ❌ | Newer systemd only, takes systemd timestamps |
| `systemd-run --on-active=` | ✅ | ✅ | Most flexible, accepts `s`, `m`, `h` units |
| `at` | ✅ | ✅ | Classic job scheduler, needs the `atd` service |
| `sleep N && cmd` | ✅ | ✅ | Quick and dirty, dies if the terminal closes |

---

## 🕒 Time formats

### `shutdown`

| Format | Meaning |
| :--- | :--- |
| `now` | Immediately (same as `+0`) |
| `+m` | `m` **minutes** from now |
| `hh:mm` | A clock time in 24h format (see warning below) |
| *(nothing)* | Defaults to `+1` (one minute) |

> [!WARNING]
> `shutdown` only understands **minutes** after the `+`. `shutdown +1h` is **not valid**. Convert hours to minutes: 1 h = `+60`, 2 h = `+120`, 90 min = `+90`.

> [!CAUTION]
> The behavior of `hh:mm` when that time has **already passed today** differs between systemd versions. Some treat it as the next occurrence (tomorrow), newer man pages say it results in an **immediate** shutdown. Prefer `+m`, or check your version's `man shutdown`.

### `systemd-run`, `systemctl --when`, `sleep`

systemd time spans accept these units:

| Unit | Accepted spellings |
| :--- | :--- |
| seconds | `s`, `sec`, `second`, `seconds` |
| minutes | `m`, `min`, `minute`, `minutes` |
| hours | `h`, `hr`, `hour`, `hours` |
| days | `d`, `day`, `days` |

Units can be combined: `1h30m`, `2h 15min`, `90min`. A bare number means **seconds**: `--on-active=1800` is 30 minutes.

> [!TIP]
> Validate any time span or timestamp before using it:
> ```bash
> systemd-analyze timespan 1h30m
> systemd-analyze timestamp "+30min"
> ```

---

## 🔴 Shutdown (power off) after N minutes/hours

```bash
# Power off in 30 minutes
sudo shutdown -P +30

# Power off in 2 hours (120 minutes)
sudo shutdown -P +120

# Same thing, shorter. Power off is the default action
sudo shutdown +30

# With a message for logged-in users
sudo shutdown -P +10 "Powering off for maintenance"

# Power off immediately
sudo shutdown -P now
```

<details>
<summary>📌 Other options worth knowing</summary>

| Option | Effect |
| :--- | :--- |
| `-P`, `--poweroff` | Power off the machine (default) |
| `-H`, `--halt` | Halt the machine but leave the power on |
| `-r`, `--reboot` | Reboot |
| `-c` | Cancel a pending shutdown |
| `-k` | Do not shut down, **only send the warning message** (a safe way to test) |
| `--no-wall` | Do not send the warning message |
| `--show` | Show a pending action (systemd 250+) |

When you give a time, new logins are blocked during the final 5 minutes before the shutdown.

Dry run:

```bash
sudo shutdown -k +5 "This is only a test"
```

</details>

### Alternative: `systemctl poweroff --when`

On recent systemd versions:

```bash
sudo systemctl poweroff --when=+30min
```

> [!CAUTION]
> With `--when`, a **time-only** value such as `06:00` means *today at 06:00*. If that moment has already passed, the machine powers off **immediately**. Use a relative value like `+30min` or a full date-time such as `2026-11-08T06:00:00`. `--when` is not available on older systemd (for example the one in Ubuntu 22.04). Check with `systemctl --version`.

---

## 🔄 Reboot after N minutes/hours

```bash
# Reboot in 15 minutes
sudo shutdown -r +15

# Reboot in 1 hour
sudo shutdown -r +60

# Reboot with a message
sudo shutdown -r +5 "Rebooting to apply updates"

# Reboot immediately
sudo shutdown -r now

# Recent systemd, relative time
sudo systemctl reboot --when=+15min
```

Using `systemd-run` works too, and it accepts hours directly:

```bash
sudo systemd-run --on-active=1h systemctl reboot
```

---

## 🛌 Hibernate after N minutes/hours

Hibernate saves your RAM contents to swap, powers off completely and restores your session on the next boot.

### ✅ Step 1. Prerequisites

> [!CAUTION]
> If hibernate is not fully set up, the machine will still power off, but the next boot starts a **fresh session and everything unsaved is lost**. Always run `systemctl hibernate` manually once and confirm it restores before relying on a timer.

**1. You need a real swap partition or swap file** (zram alone does not work), big enough to hold your memory image. A swap at least as large as your RAM is the safe choice.

```bash
swapon --show
free -h
```

**2. The kernel must know where the hibernation image lives** (`resume=`):

```bash
cat /proc/cmdline | grep -o 'resume=[^ ]*'
```

If nothing prints, add it. First get your swap UUID:

```bash
lsblk -f
```

Then add `resume=UUID=<swap-uuid>` to the kernel options. Pick the method that matches your bootloader:

| Bootloader setup | Where to edit | Apply with |
| :--- | :--- | :--- |
| GRUB2 | `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` (or YaST → Bootloader → Kernel Parameters) | `sudo grub2-mkconfig -o /boot/grub2/grub.cfg` |
| GRUB2-BLS / systemd-boot | `/etc/kernel/cmdline` | `sudo sdbootutil update-all-entries` |
| rEFInd launching the kernel directly | the matching `options` line in `refind.conf` or `/boot/refind_linux.conf` | save the file |

Example kernel option:

```text
resume=UUID=19bd024f-76bd-4162-ac37-4d0d51e02c25
```

> [!NOTE]
> UUIDs change when you recreate or reformat a swap partition. Update `resume=` if that happens.

**3. Confirm after a reboot:**

```bash
cat /proc/cmdline | grep -o 'resume=[^ ]*'
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate
```

The second command should answer `s "yes"`.

> [!WARNING]
> **Secure Boot / kernel lockdown** can block hibernation on some setups. If everything else is correct and hibernate still fails, test with Secure Boot disabled.

**4. Test it manually (save your work first):**

```bash
systemctl hibernate
```

### ⏲️ Step 2. Schedule it

```bash
# Hibernate in 30 minutes
sudo systemd-run --on-active=30m systemctl hibernate

# In 1 hour 30 minutes
sudo systemd-run --on-active=1h30m systemctl hibernate

# In 45 seconds
sudo systemd-run --on-active=45s systemctl hibernate

# With a name, so it is easy to inspect and cancel
sudo systemd-run --unit=hibernate-later --on-active=30m systemctl hibernate
```

`systemd-run` prints something like this:

```text
Running timer as unit: run-p157689-i176593.timer
Will run service as unit: run-p157689-i176593.service
```

Timers created this way are **transient**. They live in `/run` and disappear on reboot.

### 🕰️ At a specific clock time

Use a full date and time so the timer fires **once**:

```bash
sudo systemd-run --on-calendar="2026-11-08 23:30:00" systemctl hibernate
```

> [!WARNING]
> A time-only calendar value such as `--on-calendar=23:30` is a **recurring daily** schedule, not a one-shot. Use the full date form above for a single run.

### Alternative: `at`

```bash
# One-time setup on openSUSE
sudo zypper install at
sudo systemctl enable --now atd

# Schedule (runs as root because of sudo)
echo "systemctl hibernate" | sudo at now + 30 minutes
echo "systemctl hibernate" | sudo at 23:30

# List and remove jobs
sudo atq
sudo atrm <job-number>
```

### Alternative: plain `sleep`

```bash
sleep 30m && systemctl hibernate
```

Press `Ctrl+C` to cancel. It stops if you close the terminal, so use `nohup` or `systemd-run` if you need it to survive:

```bash
nohup sh -c 'sleep 1800 && systemctl hibernate' >/dev/null 2>&1 &
```

---

## 🌓 Suspend now, hibernate later

`suspend-then-hibernate` suspends to RAM first (fast resume), then wakes briefly and hibernates to disk if you have not come back within a delay. It saves battery and protects your session from a power loss.

**Set the delay** in `/etc/systemd/sleep.conf` (or a drop-in in `/etc/systemd/sleep.conf.d/`):

```ini
[Sleep]
HibernateDelaySec=30min
```

**Trigger it:**

```bash
systemctl suspend-then-hibernate
```

If `HibernateDelaySec=` is not set, the default is 2 hours on current systemd versions.

> [!NOTE]
> This is different from "do something in 30 minutes". `suspend-then-hibernate` suspends **immediately**, then hibernates after the delay. To suspend-then-hibernate at a later time, combine it with a timer:
> ```bash
> sudo systemd-run --on-active=30m systemctl suspend-then-hibernate
> ```

---

## 🔍 Check and cancel pending actions

### `shutdown` / reboot

```bash
shutdown --show        # show the pending action (systemd 250+)
sudo shutdown -c       # cancel it
```

### `systemd-run` timers

```bash
systemctl list-timers --all                 # all timers, pending ones show their trigger time
systemctl status hibernate-later.timer      # a named timer, shows the "Trigger:" line
sudo systemctl stop hibernate-later.timer   # cancel it
```

For an unnamed timer, use the generated name that `systemd-run` printed:

```bash
sudo systemctl stop run-p157689-i176593.timer
```

### `at` jobs

```bash
sudo atq
sudo atrm <job-number>
```

---

## 💤 Hibernate only when idle

A timer fires after a fixed delay **regardless of what you are doing**. If you want "hibernate after 30 minutes of no keyboard or mouse activity", use one of these.

### KDE Plasma (recommended)

**System Settings → Power Management → Energy Saving.** Set the inactivity action to **Hibernate** after **30 min**. If Hibernate is not offered in the list, Plasma thinks hibernate is unavailable, so go back to [Step 1](#-step-1-prerequisites).

### systemd-logind

Edit `/etc/systemd/logind.conf` (or add a drop-in under `/etc/systemd/logind.conf.d/`):

```ini
[Login]
IdleAction=hibernate
IdleActionSec=30min
```

Apply:

```bash
sudo systemctl restart systemd-logind
```

> [!WARNING]
> Restarting `systemd-logind` can disrupt active sessions on some setups. Rebooting is the safer way to apply the change.

> [!NOTE]
> Desktop environments such as Plasma and GNOME manage idle behavior themselves, so `IdleAction=` is unreliable there. On a desktop, prefer the desktop's own power settings.

---

## 🧰 Handy shell function

Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
# usage: after <time> <poweroff|reboot|hibernate|suspend-then-hibernate>
after() {
  if [ $# -ne 2 ]; then
    echo "usage: after <time> <poweroff|reboot|hibernate|suspend-then-hibernate>"
    return 1
  fi
  sudo systemd-run --on-active="$1" --description="after $1: $2" systemctl "$2"
}
```

Reload your shell, then:

```bash
after 30m hibernate
after 2h poweroff
after 15m reboot
after 45s suspend-then-hibernate
```

---

## 🩺 Troubleshooting

| Symptom | Likely cause | Fix |
| :--- | :--- | :--- |
| `shutdown +1h` is rejected | `+m` only accepts minutes | Use `+60` |
| `systemctl poweroff --when=06:00` shut down instantly | Time-only value in the past means "now" | Use `+30min` or a full date-time |
| `Hibernate` missing in Plasma | Swap or `resume=` not set up, or lockdown | Complete [Step 1](#-step-1-prerequisites) |
| Machine powers off but boots a fresh session | `resume=` is wrong, missing, or points at the wrong UUID | Fix `resume=`, regenerate boot entries, test again |
| "Not enough swap space" on hibernate | Swap smaller than the memory image | Free memory, or enlarge swap |
| `systemd-run` timer never fires | Timer was stopped, or the system rebooted | Transient timers do not survive reboots, recreate it |
| `at: command not found` | `at` is not installed | `sudo zypper install at`, then `sudo systemctl enable --now atd` |

<details>
<summary>🛠️ If resume still fails: dracut initramfs</summary>

On openSUSE with systemd in the initramfs, `systemd-hibernate-resume` normally handles resuming without extra setup. If you still have trouble, force the dracut `resume` module and rebuild:

```bash
echo 'add_dracutmodules+=" resume "' | sudo tee /etc/dracut.conf.d/99-resume.conf
sudo dracut -f
```

Then reboot and test again. With an **encrypted swap**, the resume device and initramfs setup differ, so follow the openSUSE encrypted-root documentation.

</details>

---

## 📚 References

- [`shutdown(8)`](https://man7.org/linux/man-pages/man8/shutdown.8.html) — time formats and options
- [`systemd-run(1)`](https://man7.org/linux/man-pages/man1/systemd-run.1.html) — transient timers, `--on-active`, `--on-calendar`
- [`systemd.time(7)`](https://man7.org/linux/man-pages/man7/systemd.time.7.html) — time spans, timestamps, calendar events
- [`systemd-sleep.conf(5)`](https://man7.org/linux/man-pages/man5/systemd-sleep.conf.5.html) — `HibernateDelaySec=` and sleep modes
- [`logind.conf(5)`](https://man7.org/linux/man-pages/man5/logind.conf.5.html) — `IdleAction=` and `IdleActionSec=`
- [openSUSE Tumbleweed power management docs](https://doc.opensuse.org/documentation/tumbleweed/power/) — swap and `resume=`

---

<sub>Maintained in [itachi-re/clean-system-guide](https://github.com/itachi-re/clean-system-guide). Suggestions and fixes welcome.</sub>
