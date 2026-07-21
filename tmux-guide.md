# The Complete Guide to tmux

*A beginner-to-advanced guide to the terminal multiplexer, covering tmux 3.6+ (also compatible with earlier 2.x/3.x releases where noted).*

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Core Concepts](#2-core-concepts)
3. [Installation](#3-installation)
4. [First Session](#4-first-session)
5. [Windows](#5-windows)
6. [Panes](#6-panes)
7. [Navigation](#7-navigation)
8. [Essential Keybindings (Cheat Sheet)](#8-essential-keybindings-cheat-sheet)
9. [Copy Mode](#9-copy-mode)
10. [Layouts](#10-layouts)
11. [Configuration (.tmux.conf)](#11-configuration-tmuxconf)
12. [Mouse Support](#12-mouse-support)
13. [Clipboard Integration](#13-clipboard-integration)
14. [Custom Keybindings](#14-custom-keybindings)
15. [Plugins](#15-plugins)
16. [Productivity Workflows](#16-productivity-workflows)
17. [Advanced Features](#17-advanced-features)
18. [Automation](#18-automation)
19. [Troubleshooting](#19-troubleshooting)
20. [Best Practices](#20-best-practices)
21. [Common Mistakes](#21-common-mistakes)
22. [Learning Roadmap](#22-learning-roadmap)
23. [Exercises](#23-exercises)
24. [Cheat Sheets](#24-cheat-sheets)
25. [Further Reading](#25-further-reading)

---

## 1. Introduction

### What is tmux?

**tmux** ("terminal multiplexer") is a program that lets you create, manage, and switch between multiple terminal sessions from within a single terminal window. Instead of opening ten terminal tabs for ten tasks, you run one terminal, start tmux inside it, and tmux gives you an arbitrary number of independent shells — organized into **sessions**, **windows**, and **panes** — that all live inside that one terminal.

Crucially, tmux runs as a background **server** process that is completely separate from the terminal emulator you're looking at. Your shells keep running even if you close the terminal window, lose your SSH connection, or reboot your desktop environment (as long as the underlying machine keeps running). You can walk away, come back — even from a different computer — and reattach to exactly where you left off.

### History

tmux was created by **Nicholas Marriott** and first released in 2007 as a modern, BSD-licensed (ISC license) alternative to the older terminal multiplexer **GNU Screen** (first released in 1987). tmux was designed with a cleaner internal architecture (a true client-server model), more consistent scripting via its `tmux` command interface, and a more active, standards-friendly development process. It is part of the OpenBSD base system and is packaged for virtually every Unix-like operating system.

### Why Developers Love tmux

- **Persistence** — your work survives disconnects, crashes, and closed terminal windows.
- **Remote workflows** — one SSH connection can host an entire multi-pane development environment.
- **Scriptability** — sessions, windows, and panes can be created, resized, and controlled entirely from shell scripts.
- **Consistency** — the same environment behaves identically on a local laptop, a remote server, or inside a Docker container.
- **Keyboard-driven speed** — once memorized, tmux's keybindings are faster than reaching for a mouse to manage tabs and windows.
- **Free and open source**, actively maintained, tiny resource footprint.

### Benefits Over Multiple Terminal Tabs

| Terminal Tabs | tmux |
|---|---|
| Tied to one terminal emulator process | Runs as an independent server; survives terminal closure |
| Lost on disconnect (SSH drop, crash) | Session persists; reattach anytime |
| Cannot be scripted easily | Fully scriptable via `tmux` CLI |
| Usually one shell per tab | Multiple panes per window, tiled arbitrarily |
| Not shareable | Multiple people can attach to the same session (pair programming) |
| Config is terminal-emulator-specific | Config (`.tmux.conf`) is portable across machines |

### Why tmux is Essential for SSH and Remote Servers

When you SSH into a remote machine and run a long build, a database migration, or a training job directly in that shell, losing the connection (Wi-Fi drop, laptop sleep, VPN hiccup) kills the process. If you instead SSH in, start (or attach to) a tmux session, and run your work *inside* tmux, the process keeps running on the server regardless of what happens to your local connection. You simply reconnect and reattach later. This single property is why tmux is considered mandatory knowledge for anyone doing serious remote Linux/server work.

### Common Misconceptions

- **"tmux is just a window manager for terminals."** It's more precisely a *session* manager — the persistence and client/server separation matter more than the window-splitting.
- **"I need tmux to have split panes."** Some terminal emulators (e.g., Konsole, iTerm2, WezTerm) offer their own native splits, but those splits die when the terminal closes. tmux's panes are independent of any GUI terminal.
- **"tmux replaces my shell."** No — tmux hosts your existing shell (bash, zsh, fish, etc.) unchanged; it does not replace or wrap shell functionality.
- **"Detaching closes my programs."** Detaching (`prefix d`) leaves everything running; it only disconnects the *client* (your view), not the *session*.
- **"tmux and GNU Screen are basically the same, so it doesn't matter which I learn."** They share the multiplexer concept, but tmux's scripting model, plugin ecosystem, and active development make it the more common modern choice.

---

## 2. Core Concepts

Understanding tmux requires learning five key building blocks and how they nest inside one another.

```text
tmux SERVER (one background process, holds all state)
│
├── SESSION "main"                     ← a named group of windows
│   ├── WINDOW 0: "editor"             ← like a browser tab
│   │   ├── PANE 0 (left)              ← a rectangular subdivision
│   │   └── PANE 1 (right)
│   ├── WINDOW 1: "server-logs"
│   │   └── PANE 0
│   └── WINDOW 2: "shell"
│       ├── PANE 0
│       ├── PANE 1
│       └── PANE 2
│
└── SESSION "deploy"
    └── WINDOW 0: "ssh-prod"
        └── PANE 0
```

### Server

The tmux **server** is a single background process (`tmux` runs one server per Unix socket) that owns all sessions, windows, panes, and their running programs. It starts automatically the first time you run `tmux`, and keeps running even after every client detaches. It only stops when you explicitly kill it or the machine shuts down.

### Client

A **client** is the thing you actually look at — a terminal window/tab running the `tmux attach` process that talks to the server over a socket. You can have many clients attached to the *same* session simultaneously (useful for pair programming/screen-sharing), and one server can serve many clients across many sessions at once.

### Session

A **session** is a named collection of windows — think of it as one whole "workspace" (e.g., "work", "personal-project", "server-monitoring"). Sessions are the unit you attach to and detach from. Closing your terminal or losing your SSH connection does not destroy a session; only explicitly killing it does.

### Window

A **window** occupies the full terminal area at one time and can contain one or more panes. Windows are analogous to tabs in a browser: each window has an index number and (usually) a short label, shown in the **status bar** at the bottom of the screen.

### Pane

A **pane** is a rectangular division of a window, each running its own independent shell or program. Panes let you view multiple running programs side-by-side within a single window — e.g., an editor on the left, a build log on the right.

### Prefix Key

Because tmux is controlled entirely from the keyboard, nearly every command begins with a **prefix key** combination — by default **`Ctrl-b`** — which tells tmux "the next key is a tmux command, not input for the program in the pane." For example, to create a new window you press `Ctrl-b` then `c` (`prefix c`). Without a prefix key, tmux would have no way to distinguish your commands to itself from ordinary keystrokes meant for the shell or editor inside the pane.

### Status Bar

The **status bar** is the (by default) single line at the bottom of the tmux screen. It shows the session name, a list of windows with their indices and names, and can be configured to show the time, hostname, battery level, git branch, and more. It is fully customizable via `.tmux.conf`.

### Copy Mode

**Copy mode** is a special scrollback/selection mode you enter to scroll up through a pane's history, search text, and select/copy text into a tmux **buffer**. It behaves like a modal text viewer, with `vi`-style or `emacs`-style keybindings depending on configuration.

### Buffers

A **buffer** is tmux's internal clipboard — text you copy while in copy mode is stored in a numbered buffer inside tmux itself (separate from, but optionally synced with, your system/OS clipboard). tmux keeps a history of buffers you can paste from.

### Layouts

A **layout** is the arrangement algorithm tmux uses to size and position panes within a window (e.g., panes stacked evenly in columns, or one large pane with several stacked beside it). tmux ships several built-in layouts you can cycle through instantly, or you can resize panes manually for a custom layout.

---

## 3. Installation

> **Tip:** Always check your distribution's version against the [tmux version history](https://github.com/tmux/tmux/wiki) if a specific feature (e.g., `pane-scrollbars`, added in tmux 3.6) is important to you.

### openSUSE (Tumbleweed / Leap)

```bash
sudo zypper install tmux
```

### Arch Linux

```bash
sudo pacman -S tmux
```

### Debian

```bash
sudo apt update
sudo apt install tmux
```

### Ubuntu

```bash
sudo apt update
sudo apt install tmux
```

### Fedora

```bash
sudo dnf install tmux
```

### macOS

Using [Homebrew](https://brew.sh):

```bash
brew install tmux
```

Using MacPorts:

```bash
sudo port install tmux
```

### Building from Source

Useful when you need the very latest release or a version not yet packaged by your distribution.

```bash
# Install build dependencies (example: Debian/Ubuntu)
sudo apt install -y build-essential libevent-dev libncurses-dev pkg-config bison

# Clone and build
git clone https://github.com/tmux/tmux.git
cd tmux
sh autogen.sh
./configure
make
sudo make install
```

> **Note:** Package names for the build dependencies differ by distribution (`libevent-devel`/`ncurses-devel` on Fedora/openSUSE, `libevent`/`ncurses` via Homebrew on macOS). Consult the `README` in the tmux source tree for the exact list.

### Verifying Installation

```bash
tmux -V
```

This prints the installed version, e.g. `tmux 3.6a`. If the command is not found, re-check your `$PATH` or confirm the package installed successfully.

---

## 4. First Session

### Starting tmux

Simply running:

```bash
tmux
```

starts the server (if not already running) and creates a new, unnamed session (tmux numbers unnamed sessions `0`, `1`, `2`, …), then attaches you to it.

### Creating a Named Session

Naming sessions makes them far easier to manage once you have several running:

```bash
tmux new -s work
```

`new` is short for `new-session`; `-s work` names it `work`.

### Detaching

To leave a session running in the background and return to your normal shell:

```
prefix d
```

(By default: `Ctrl-b` then `d`.) The session and everything running inside it keeps running.

### Listing Sessions

From outside tmux (or in another pane):

```bash
tmux ls
```

Example output:

```text
work: 3 windows (created Mon Jul 21 10:03:00 2026)
deploy: 1 windows (created Mon Jul 21 10:15:22 2026) (attached)
```

### Attaching (Reattaching)

```bash
tmux attach -t work
```

`-t work` targets the session named `work`. If you only have one session, `tmux attach` alone is enough. To attach *and* share a session another client is already viewing, this command also works (multi-client attach is allowed by default).

### Killing a Session

```bash
tmux kill-session -t work
```

This terminates every window and pane in that session — all running programs inside it are stopped. Use with care.

To kill *every* session and the tmux server entirely:

```bash
tmux kill-server
```

### Practical Example

```bash
# Start a named session for a project
tmux new -s api-project

# ... work for a while, then detach ...
prefix d

# Later, from the same or a different terminal:
tmux attach -t api-project

# When completely done with the project:
tmux kill-session -t api-project
```

---

## 5. Windows

### Creating a Window

```
prefix c
```

Creates a new window (numbered after the highest existing index by default) and switches to it.

### Renaming a Window

```
prefix ,
```

Prompts at the bottom of the screen for a new name — useful for keeping track of what each window is for (`editor`, `logs`, `tests`).

### Closing a Window

```
prefix &
```

Prompts for confirmation, then kills the window and every pane inside it. (Equivalently, exiting every shell inside the window's panes closes it automatically.)

### Switching Between Windows

| Keys | Action |
|---|---|
| `prefix 0`–`9` | Jump directly to window number 0–9 |
| `prefix n` | Go to the **n**ext window |
| `prefix p` | Go to the **p**revious window |
| `prefix l` | Go to the **l**ast (previously selected) window |
| `prefix w` | Open an interactive window **list** to choose from |

### Moving a Window

```
prefix .
```

Prompts for a new index number, letting you reorder windows (e.g., move window `4` to position `1`).

You can also swap two windows without leaving the keyboard-driven prompt using `swap-window` from the command prompt (see [Section 17](#17-advanced-features)):

```
prefix :
swap-window -s 3 -t 1
```

### Numbering

Windows are numbered starting at `0` by default. Many users change the base index to `1` (see [Section 11](#11-configuration-tmuxconf)) so window numbers line up with the physical `1`–`9` keys on a keyboard.

### Best Practices

- Name windows by *purpose*, not by program (`backend` rather than `nvim`).
- Keep related work in one window's multiple panes rather than spawning excessive windows.
- Use `prefix w` once you have more than 5–6 windows — jumping by number stops scaling.

---

## 6. Panes

Panes subdivide a single window into multiple visible regions, each an independent shell.

```text
┌─────────────────────┬───────────────────────┐
│                      │                       │
│      Pane 0          │       Pane 1          │
│      (nvim)          │     (npm run dev)     │
│                      │                       │
├──────────────────────┴───────────────────────┤
│                Pane 2 (logs / git)            │
└────────────────────────────────────────────────┘
```

### Splitting

| Keys | Action |
|---|---|
| `prefix %` | Split **vertically** — creates a new pane to the **right** |
| `prefix "` | Split **horizontally** — creates a new pane **below** |

> **Note on terminology:** tmux names splits by the orientation of the **dividing line**, which is the opposite of how many people intuitively think about it. `%` draws a *vertical* line (left/right panes); `"` draws a *horizontal* line (top/bottom panes). This trips up almost every beginner at least once.

### Closing a Pane

```
prefix x
```

Prompts for confirmation, then kills the pane (equivalent to exiting the shell running inside it, e.g. typing `exit` or pressing `Ctrl-d`).

### Resizing

| Keys | Action |
|---|---|
| `prefix Ctrl-Up/Down/Left/Right` | Resize the active pane by one cell in that direction |
| `prefix Alt-Up/Down/Left/Right` | Resize by five cells at a time |

You can also resize using the mouse if [mouse mode](#12-mouse-support) is enabled by dragging pane borders.

### Zoom

```
prefix z
```

Temporarily expands the active pane to fill the entire window (hiding the other panes without closing them). Pressing `prefix z` again restores the original layout. This is extremely useful for briefly focusing on one pane's output (e.g., reading a long log) without permanently rearranging your layout.

### Swapping Panes

```
prefix Ctrl-o   # rotate all panes forward within the window
prefix Alt-o    # rotate backward
```

Or explicitly with the command prompt:

```
prefix :
swap-pane -s 1 -t 2
```

### Moving Panes

To move a pane into its own window:

```
prefix !
```

("break-pane" — pulls the active pane out into a brand-new window.)

To join a pane from one window into another:

```
prefix :
join-pane -s <window>.<pane> -t <window>
```

### Synchronizing Panes

Synchronize-panes broadcasts your keystrokes to *every* pane in the current window simultaneously — invaluable for running the same command across several SSH connections at once (e.g., updating five servers in parallel).

```
prefix :
setw synchronize-panes on
```

Turn it back off the same way with `off`. Many configs bind this to a dedicated key (see [Section 14](#14-custom-keybindings)).

> **Warning:** Always double-check synchronize-panes is off before typing anything sensitive (like a password) — it will be sent to every pane, which is both a workflow hazard and a security concern if any of those panes are on different hosts.

### Selecting Panes

| Keys | Action |
|---|---|
| `prefix o` | Cycle to the next pane |
| `prefix ;` | Jump to the **last** active pane |
| `prefix q` | Briefly display pane numbers; press a number to jump directly |
| `prefix Up/Down/Left/Right` | Move to the pane in that direction |

### Common Workflows

- **Editor + shell**: `prefix %` to split, edit code on the left, run commands on the right.
- **Editor + build/test + logs**: split into three panes — editor (large), test runner, log tail.
- **Multi-server admin**: one pane per SSH connection, synchronize-panes on for bulk commands.

---

## 7. Navigation

Efficient navigation is what separates a tmux beginner from a proficient daily user — the goal is to almost never touch the mouse.

### Prefix Usage Recap

Every navigation command below is a *prefix* command unless stated otherwise: press `Ctrl-b`, release both keys, then press the next key.

### Window Navigation

| Keys | Action |
|---|---|
| `prefix 0-9` | Jump to window by index |
| `prefix n` / `prefix p` | Next / previous window |
| `prefix l` | Last active window |
| `prefix w` | Interactive window chooser |
| `prefix f` | Find window by searching pane content |

### Pane Navigation

| Keys | Action |
|---|---|
| `prefix Up/Down/Left/Right` | Move focus one pane in that direction |
| `prefix o` | Cycle through panes |
| `prefix q` | Show pane numbers overlay, then press number |

### Session Switching

| Keys | Action |
|---|---|
| `prefix s` | Interactive session chooser (list all sessions, pick one) |
| `prefix (` | Switch to previous session |
| `prefix )` | Switch to next session |
| `prefix $` | Rename the current session |

### Mouse Support

When enabled (`set -g mouse on`), you can click a pane to focus it, click-drag a border to resize, click a window name in the status bar to switch windows, and scroll the mouse wheel to enter copy mode and scroll back through history. See [Section 12](#12-mouse-support) for full detail and caveats.

### Command Prompt

```
prefix :
```

Opens tmux's internal command line at the bottom of the screen, where you can type any tmux command directly (e.g., `rename-window logs`, `split-window -h`, `set -g mouse on`). This is the same command language used inside `.tmux.conf`, so anything you learn here is directly transferable to your config file.

---

## 8. Essential Keybindings (Cheat Sheet)

All bindings below assume the **default prefix `Ctrl-b`**, written as `prefix` for brevity.

### Session

| Keybinding | Action |
|---|---|
| `prefix d` | Detach from session |
| `prefix s` | List/switch sessions |
| `prefix $` | Rename session |
| `prefix (` / `)` | Previous / next session |
| `prefix D` | Choose a client to detach |

### Window

| Keybinding | Action |
|---|---|
| `prefix c` | Create window |
| `prefix ,` | Rename window |
| `prefix &` | Kill window |
| `prefix 0-9` | Select window by index |
| `prefix n` / `p` | Next / previous window |
| `prefix l` | Last window |
| `prefix w` | Window list |
| `prefix .` | Move window (reindex) |
| `prefix f` | Find window |

### Pane

| Keybinding | Action |
|---|---|
| `prefix %` | Split vertically (side by side) |
| `prefix "` | Split horizontally (stacked) |
| `prefix x` | Kill pane |
| `prefix z` | Zoom / unzoom pane |
| `prefix o` | Next pane |
| `prefix ;` | Last active pane |
| `prefix q` | Show pane numbers |
| `prefix {` / `}` | Swap pane left / right |
| `prefix Ctrl-Arrow` | Resize pane (1 cell) |
| `prefix Alt-Arrow` | Resize pane (5 cells) |
| `prefix !` | Break pane into new window |
| `prefix Space` | Cycle through layouts |

### Copy Mode

| Keybinding | Action |
|---|---|
| `prefix [` | Enter copy mode |
| `prefix ]` | Paste most recent buffer |
| `q` | Quit copy mode |
| `Space` (vi) | Start selection |
| `Enter` (vi) | Copy selection, exit copy mode |
| `v` (vi, in copy mode) | Toggle selection (alternative to Space) |
| `y` (vi, in copy mode) | Copy selection (yank) |

### Search (inside copy mode)

| Keybinding | Action |
|---|---|
| `/` | Search forward |
| `?` | Search backward |
| `n` | Next match |
| `N` | Previous match |

### Layout

| Keybinding | Action |
|---|---|
| `prefix Space` | Cycle through built-in layouts |
| `prefix Alt-1` … `Alt-5` | Jump directly to a specific built-in layout |

### Miscellaneous

| Keybinding | Action |
|---|---|
| `prefix :` | Open command prompt |
| `prefix ?` | List all current keybindings |
| `prefix t` | Show a large clock |
| `prefix r` (if configured) | Reload `.tmux.conf` (custom binding, see [Section 11](#11-configuration-tmuxconf)) |

---

## 9. Copy Mode

Copy mode is how you scroll back through a pane's output, search it, and select text to copy — since a pane has no traditional scrollbar and mouse selection interacts differently with a multiplexed terminal.

### Entering Copy Mode

```
prefix [
```

The pane freezes for interactive scrolling/selection; the terminal status area displays your position in the scrollback buffer.

### vi Mode vs. emacs Mode

tmux supports two keybinding "flavors" inside copy mode, configured via:

```tmux
# in ~/.tmux.conf
set -g mode-keys vi     # or: emacs
```

`vi` mode uses Vim-like keys (`h j k l`, `w`, `b`, `/`, `?`) and is by far the more common choice among developers already familiar with Vim/Neovim. `emacs` mode (the historical default) uses Emacs-style keys (`Ctrl-p`/`Ctrl-n`, `Ctrl-s`). If you don't set this explicitly, tmux infers a default from your `$EDITOR`/`$VISUAL` environment variables or falls back to `emacs`.

### Navigating in vi Copy Mode

| Key | Action |
|---|---|
| `h j k l` | Move left / down / up / right |
| `w` / `b` | Next / previous word |
| `0` / `$` | Start / end of line |
| `g` / `G` | Top / bottom of scrollback |
| `Ctrl-u` / `Ctrl-d` | Half-page up / down |
| `Ctrl-b` / `Ctrl-f` | Full page up / down |

### Searching

| Key | Action |
|---|---|
| `/pattern` | Search forward for `pattern` |
| `?pattern` | Search backward |
| `n` | Jump to next match |
| `N` | Jump to previous match |

### Selecting and Copying (vi mode)

1. Move the cursor to the start of the text you want.
2. Press `Space` (or `v`) to begin a selection.
3. Move the cursor to extend the selection.
4. Press `Enter` (or `y`) to copy the selection into a tmux buffer and exit copy mode.

For rectangular (column) selection, press `Ctrl-v` while a selection is active before extending it.

### Selecting and Copying (emacs mode)

| Key | Action |
|---|---|
| `Ctrl-Space` | Start selection |
| `Alt-w` | Copy selection |
| `Ctrl-w` | Cut selection |

### Pasting

```
prefix ]
```

Pastes the most recently copied tmux buffer into the active pane. To choose among multiple stored buffers:

```
prefix =
```

opens an interactive buffer list.

### Scrolling Without Entering "Search Mode" Explicitly

If [mouse mode](#12-mouse-support) is enabled, simply scrolling the mouse wheel inside a pane automatically enters copy mode and scrolls; scrolling back down to the bottom automatically exits copy mode.

### Integration with the Terminal (System) Clipboard

By default, tmux buffers are internal to tmux and are *not* automatically synced with your OS clipboard. Getting text out to other applications requires either:

- The `tmux-yank` plugin (see [Section 15](#15-plugins)), which automates this, or
- Manually piping a buffer to a clipboard utility (see [Section 13](#13-clipboard-integration)), or
- Enabling OSC 52 clipboard passthrough for terminals that support it, so `copy-pipe` commands can reach the system clipboard even over SSH.

---

## 10. Layouts

tmux ships five built-in layouts you can cycle through with `prefix Space`, or select directly.

| Layout | Description | Best For |
|---|---|---|
| `even-horizontal` | Panes arranged in a single row, equal width | Comparing a few wide outputs side by side |
| `even-vertical` | Panes arranged in a single column, equal height | Stacking logs/consoles of similar importance |
| `main-horizontal` | One large pane on top, remaining panes in a row below | Big editor/output on top, small helper shells below |
| `main-vertical` | One large pane on the left, remaining panes in a column on the right | Editor on the left, logs/tests stacked on the right (a very common dev layout) |
| `tiled` | All panes sized as evenly as possible in a grid | Many equally-important panes (e.g., monitoring several servers) |

```text
even-horizontal          main-vertical              tiled
┌───┬───┬───┐          ┌────────┬─────┐          ┌────┬────┐
│   │   │   │          │        │  A  │          │ 1  │ 2  │
│ A │ B │ C │          │   A    ├─────┤          ├────┼────┤
│   │   │   │          │        │  B  │          │ 3  │ 4  │
└───┴───┴───┘          └────────┴─────┘          └────┴────┘
```

To select a layout directly from the command prompt:

```
prefix :
select-layout main-vertical
```

Layouts can also be adjusted manually afterward (dragging borders with the mouse, or `prefix Ctrl/Alt-Arrow`); tmux remembers your manual tweaks until you explicitly re-select a built-in layout.

---

## 11. Configuration (.tmux.conf)

tmux reads its configuration from `~/.tmux.conf` (or, on systems following the XDG convention, `~/.config/tmux/tmux.conf`) when the server starts.

### Basic Syntax

Each line is a tmux command — the exact same commands you can type after `prefix :`. Lines beginning with `#` are comments.

```tmux
# This is a comment
set -g <option> <value>      # set a global option
setw -g <option> <value>      # set a window option (setw = set-window-option)
bind <key> <command>          # create a keybinding
```

### Comments

```tmux
# Everything after a hash on its own is ignored by tmux.
set -g mouse on   # inline comments are also fine
```

### Options: `set` vs `setw`

- `set -g` (`set-option -g`) sets a **global session-level** option (applies to all sessions unless overridden), e.g. `mouse`, `prefix`, `status-bar` styling.
- `setw -g` (`set-window-option -g`) sets a **window-level** option, e.g. `mode-keys`, `synchronize-panes`, `automatic-rename`.

Whether an option is a `set` or `setw` option is defined by tmux itself — check `man tmux` if unsure.

### Example: A Well-Explained Starter Config

```tmux
# ── Prefix key ───────────────────────────────────────────
# Change prefix from the default Ctrl-b to Ctrl-a (closer to
# GNU Screen's default, and arguably easier to reach).
unbind C-b
set -g prefix C-a
bind C-a send-prefix   # allow Ctrl-a to reach the shell when pressed twice

# ── General behavior ─────────────────────────────────────
set -g base-index 1           # windows start numbering at 1, not 0
setw -g pane-base-index 1     # panes start numbering at 1, not 0
set -g renumber-windows on    # automatically renumber windows when one closes
set -g mouse on               # enable mouse: click to select, drag to resize/scroll
set -g history-limit 10000    # keep more scrollback than the tiny default
set -g escape-time 10         # reduce delay after pressing Escape (helps Vim/Neovim)

# ── Copy mode ─────────────────────────────────────────────
setw -g mode-keys vi          # use vi-style keys in copy mode

# ── Splitting (more intuitive keys, keep current directory) ─
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# ── Reloading config without restarting tmux ─────────────
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# ── Status bar appearance ────────────────────────────────
set -g status-style bg=black,fg=white
set -g status-left "#[bold]#S "                 # show session name on the left
set -g status-right "%Y-%m-%d %H:%M"             # show date/time on the right
set -g status-interval 5                          # refresh status bar every 5s
```

### Variables and Formats

tmux exposes dozens of dynamic **format** variables you can reference inside status-bar strings and messages using `#{variable_name}` (or `#S`, `#W` shorthand for a few common ones). Common examples:

| Variable | Meaning |
|---|---|
| `#S` | Current session name |
| `#W` | Current window name |
| `#I` | Current window index |
| `#P` | Current pane index |
| `#{pane_current_path}` | Filesystem path of the active pane's shell |
| `#{pane_current_command}` | Name of the process currently running in the pane |
| `#H` | Local hostname |

A full list is documented under `FORMATS` in `man tmux`.

### Reloading Config

After editing `.tmux.conf`, apply changes without restarting the server (which would kill your sessions) with:

```
prefix :
source-file ~/.tmux.conf
```

Most users bind this to a memorable key, as shown in the example config above (`prefix r`).

### Plugins in Configuration

Plugin declarations (via TPM) also live in `.tmux.conf` — see [Section 15](#15-plugins) for the full syntax and workflow.

---

## 12. Mouse Support

### Enabling the Mouse

```tmux
set -g mouse on
```

With this single option, tmux enables an entire bundle of mouse behaviors: pane focus on click, pane/window selection from the status bar, border dragging to resize, and wheel-scroll to enter copy mode.

### Scrolling

Scrolling the wheel over a pane automatically enters copy mode and scrolls the scrollback buffer; scrolling back down to the live output automatically exits copy mode. No manual `prefix [` needed when the mouse is enabled.

### Selecting Text

Click-and-drag with the mouse to select text in a pane. Depending on your terminal emulator, releasing the mouse button may automatically copy the selection into a tmux buffer (and, on some terminals with OSC 52 support, into the system clipboard too).

### Resizing

Click and drag a pane border to resize panes interactively, exactly like resizing panes in a GUI window manager.

### Limitations

- Mouse reporting is a terminal-protocol feature; not every terminal emulator implements it identically, so behavior can vary slightly (e.g., some older terminals don't support drag events).
- Native terminal-emulator text selection (e.g., using it to open a URL) is intercepted by tmux's own mouse handling once `mouse on` is set — see the **Shift behavior** note below to work around this.
- Copying via mouse-drag copies into a *tmux* buffer by default, not automatically your system clipboard, unless you've configured a copy-pipe command (see [Section 13](#13-clipboard-integration)) or your terminal supports OSC 52 passthrough.

### Shift Behavior (Bypassing tmux's Mouse Handling)

Most terminal emulators let you hold **Shift** while dragging the mouse to fall back to the terminal's own native selection/copy behavior, bypassing tmux entirely. This is useful for quickly grabbing a URL to open, without needing to touch tmux's copy mode at all.

---

## 13. Clipboard Integration

Getting text out of tmux and into your operating system's clipboard (so you can paste it into a browser, chat app, etc.) depends on your display server and platform, because tmux itself only manages its own internal buffers.

### The Core Problem

tmux buffers (Section 9) live *inside* tmux. Your OS clipboard (used by `Ctrl-v`/`Cmd-v` in GUI apps) is a separate thing. Bridging them requires piping tmux's buffer content through a small command-line clipboard utility.

### Linux — X11

The classic X11 clipboard tools are `xclip` and `xsel`.

```bash
# Install (Debian/Ubuntu example)
sudo apt install xclip
```

Bind a key to copy the tmux buffer to the X11 clipboard:

```tmux
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "xclip -selection clipboard -in"
```

`xsel` works equivalently:

```tmux
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "xsel --clipboard --input"
```

### Linux — Wayland

X11 tools do not work under native Wayland sessions. Use `wl-clipboard`'s `wl-copy` instead:

```bash
# Install (Debian/Ubuntu example)
sudo apt install wl-clipboard
```

```tmux
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"
```

> **Tip:** If you're unsure whether your session is X11 or Wayland, check `echo $XDG_SESSION_TYPE`.

### macOS

macOS ships `pbcopy`/`pbpaste` natively — no installation needed.

```tmux
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"
```

### WSL (Windows Subsystem for Linux)

WSL provides `clip.exe` (a Windows binary reachable from within WSL) for copying to the Windows clipboard:

```tmux
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "clip.exe"
```

For pasting *from* Windows into WSL's tmux, PowerShell's `Get-Clipboard` piped into `tmux load-buffer -` is a common pattern, or simply relying on your terminal emulator's native paste (`Shift-Insert` in many Linux terminals) to inject text directly into the active pane.

### Over SSH (OSC 52)

If you're inside tmux over an SSH connection to a remote machine, none of the above local clipboard tools exist on the *remote* side. The common solution is **OSC 52**, an escape sequence supported by many modern terminal emulators (e.g., iTerm2, kitty, WezTerm, Windows Terminal, recent GNOME Terminal releases) that lets a remote program set the *local* clipboard directly, without needing a clipboard binary at all. tmux can be configured to forward OSC 52 sequences from the remote pane through to your local terminal:

```tmux
set -g set-clipboard on
```

Consult your terminal emulator's documentation to confirm OSC 52 support and any security settings around it (some terminals require it be explicitly enabled, since it lets remote programs write to your local clipboard).

### Summary Table

| Environment | Tool |
|---|---|
| Linux + X11 | `xclip` or `xsel` |
| Linux + Wayland | `wl-copy` (from `wl-clipboard`) |
| macOS | `pbcopy` / `pbpaste` |
| WSL | `clip.exe` |
| Any + SSH | OSC 52 (`set -g set-clipboard on`) |

---

## 14. Custom Keybindings

### Remapping the Prefix Key

Many users find `Ctrl-b` awkward and remap it to `Ctrl-a` (Screen's traditional prefix) or another combination:

```tmux
unbind C-b
set -g prefix C-a
bind C-a send-prefix
```

`bind C-a send-prefix` is important — it lets you send a literal `Ctrl-a` through to the program in the pane (e.g., for `readline`'s "start of line") by pressing the prefix twice.

### Vim-Style Pane Navigation

Replace the arrow-key pane navigation with `h j k l`, matching Vim muscle memory:

```tmux
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
```

For seamless navigation *between* tmux panes and Vim/Neovim splits with the same keys, the community plugin `vim-tmux-navigator` (installed on both the Vim and tmux sides) is the standard solution — see [Section 15](#15-plugins).

### Custom Shortcuts

Examples of useful custom bindings:

```tmux
# Toggle pane synchronization with a single key
bind y setw synchronize-panes

# Quickly split panes while preserving the current working directory
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Maximize/zoom with a more ergonomic key
bind m resize-pane -Z
```

### Best Practices for Custom Keybindings

- Prefer bindings that don't collide with default tmux commands you still use, or intentionally `unbind` the default first.
- Keep a comment next to every non-obvious binding in `.tmux.conf` — six months later you *will* forget why `bind y` does what it does.
- Avoid rebinding keys your terminal emulator or window manager already intercepts globally.
- Test a new binding immediately with `prefix r` (reload config) rather than batching many untested changes together.

---

## 15. Plugins

### TPM (Tmux Plugin Manager)

**TPM** is the de facto standard plugin manager for tmux. It clones plugins from Git repositories into `~/.tmux/plugins/` and sources them automatically.

#### Installing TPM

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Add the following to the **bottom** of `~/.tmux.conf` (TPM's initialization line must be last):

```tmux
# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
```

Reload tmux config (`prefix r`, or `tmux source ~/.tmux.conf`), then press:

```
prefix I
```

(capital **I**, for **I**nstall) to fetch and activate every plugin listed.

#### Updating Plugins

```
prefix U
```

#### Removing Plugins

Delete or comment out the plugin's `set -g @plugin '...'` line, reload the config, then press:

```
prefix alt-u
```

TPM will uninstall any plugin no longer present in the list.

### Recommended Plugins

| Plugin | Purpose |
|---|---|
| **tmux-sensible** | A collection of well-reasoned default settings (bigger history, faster escape-time, etc.) most users want anyway. |
| **tmux-resurrect** | Saves the exact layout of every session, window, and pane — and restores it after a reboot or crash. Save with `prefix Ctrl-s`, restore with `prefix Ctrl-r`. |
| **tmux-continuum** | Builds on `tmux-resurrect` to **automatically** save your environment periodically and optionally restore it when tmux starts, so you never have to remember to save manually. |
| **tmux-yank** | Streamlines copying tmux selections into the system clipboard across Linux/macOS/WSL without hand-writing `copy-pipe` bindings yourself. |
| **catppuccin/tmux** | A popular, actively maintained, highly configurable status-bar theme (part of the wider Catppuccin theme family used across many developer tools). |
| **tmux-plugins/tmux-fzf** | Adds `fzf`-powered fuzzy pickers for sessions, windows, panes, and more — much faster than tmux's built-in choosers for large numbers of items. |

#### Why Each Plugin Matters

- `tmux-sensible` removes an entire category of "why doesn't tmux do X by default" annoyances in one line.
- `tmux-resurrect` + `tmux-continuum` together solve tmux's one real weakness: a full server crash or reboot otherwise loses everything, since sessions live only in server memory.
- `tmux-yank` saves you from manually reasoning about X11 vs. Wayland vs. macOS clipboard tools for every new machine you set up (Section 13 shows how to do it manually if you'd rather not add a plugin).
- Theme plugins like `catppuccin/tmux` make the status bar genuinely useful (git branch, CPU, battery, clock) instead of the plain default, without you hand-writing complex format strings.
- `tmux-fzf` integrations meaningfully speed up navigation once you regularly run more than a handful of sessions/windows.

---

## 16. Productivity Workflows

### Software Development

A common layout: one large pane for your editor, smaller panes for auxiliary tools.

```text
┌─────────────────────────┬─────────────┐
│                         │  git status  │
│      Neovim / editor    ├─────────────┤
│                         │  test runner │
│                         ├─────────────┤
│                         │  compiler /  │
│                         │  build logs  │
└─────────────────────────┴─────────────┘
```

- **Git**: a dedicated pane running `watch git status` or `lazygit` alongside your editor.
- **Neovim/editor**: the main working pane; combine with `vim-tmux-navigator` for seamless `Ctrl-hjkl` movement between Vim splits and tmux panes.
- **Compiler/build**: a pane running your build watcher (`cargo watch`, `webpack --watch`, etc.).
- **Logs**: `tail -f` your application log in its own pane, possibly with `synchronize-panes` off but positioned so you can glance at it.
- **Tests**: a pane running your test runner in watch mode, giving instant feedback as you edit.

### System Administration

- One tmux session per infrastructure "area" (e.g., `prod-web`, `db-cluster`).
- Panes for `htop`/`btop` monitoring, `journalctl -f`, and an interactive shell, all visible at once.
- `tmux-resurrect`/`tmux-continuum` ensure long-lived monitoring layouts survive a server reboot.

### DevOps

- A window per environment (staging, production), each with panes for `docker ps`, `docker logs -f <container>`, and a live shell.
- For Kubernetes, panes running `kubectl get pods -w`, `kubectl logs -f <pod>`, and a shell for `kubectl exec`.
- Synchronize-panes is particularly powerful here for issuing the same `kubectl`/`ssh` command across multiple clusters/hosts simultaneously.

### Remote Work

Start a persistent tmux session on a bastion or personal remote server, and treat it as your "always-on desk": attach from your laptop in the morning, detach at night, and reattach from a different network or device the next day without losing any state.

### Pair Programming

Because multiple clients can attach to the same session (`tmux attach -t <session>` from two different terminals/machines, assuming shared SSH access to the host), two people can literally see and control the same panes in real time — a lightweight, terminal-native alternative to screen-sharing tools for CLI-heavy pairing sessions.

### Teaching

An instructor can share a read-only or read-write tmux session with students (via `tmux -S <socket-path> attach` and appropriate file permissions or tmux's `server-access`/ACL commands, available since tmux 3.3), letting everyone watch commands execute live in a terminal, which is often clearer than screen-sharing video.

---

## 17. Advanced Features

### Command Mode

Every tmux keybinding is ultimately a wrapper around a **tmux command** you can also type directly via `prefix :`. This is the same syntax used inside `.tmux.conf`, making tmux fully self-documenting: anything you can bind, you can also run ad hoc.

```
prefix :
new-window -n scratch
```

### Scripting

Because the `tmux` binary itself accepts subcommands non-interactively, entire environments can be built from shell scripts:

```bash
#!/usr/bin/env bash
tmux new-session -d -s dev -n editor
tmux send-keys -t dev:editor 'nvim .' C-m
tmux split-window -t dev:editor -h -c "$PWD"
tmux send-keys -t dev:editor.1 'npm run dev' C-m
tmux attach -t dev
```

`-d` starts the session **detached** (in the background) so the script can keep configuring it before you ever look at it; `send-keys` types text into a target pane, and `C-m` sends Enter.

### Hooks

tmux can run arbitrary commands automatically when internal events occur, using `set-hook`:

```tmux
set-hook -g after-new-session 'display-message "New session created!"'
set-hook -g client-attached 'run-shell "notify-send tmux attached"'
```

Hooks are useful for logging, notifications, or automatically running setup commands whenever a particular event (new window, client attach/detach, pane died, etc.) occurs. The full list of hookable events is documented under `HOOKS` in `man tmux`.

### Formats

Introduced earlier in [Section 11](#11-configuration-tmuxconf), **formats** are tmux's expression language for embedding dynamic values (`#{session_name}`, `#{pane_pid}`, conditionals, arithmetic) into status lines, key bindings, and scripts. Recent tmux versions (3.6+) extended formats with boolean expressions and sorting operators for more expressive status-bar logic.

### Environment Variables

tmux maintains its own per-session environment, separate from (but initially inherited from) the shell that started the server:

```bash
tmux set-environment -g MY_VAR "value"
tmux show-environment
```

New windows/panes inherit this session environment, which is particularly useful for keeping variables like `SSH_AUTH_SOCK` correctly updated across long-lived sessions.

### Multiple Servers / Socket Files

By default, all `tmux` invocations for a given user talk to one server via a default Unix socket. You can run entirely separate, isolated tmux servers using the `-L` (named socket) or `-S` (explicit socket path) flags:

```bash
tmux -L work new -s project     # a completely separate server named "work"
tmux -L work attach -t project
```

This is useful for isolating unrelated environments (e.g., a "personal" server vs. a "teaching" server you might share access to).

### Session Groups

Session groups let multiple *named* sessions share the exact same set of windows, so they always display identically, while retaining independent window/session state elsewhere:

```bash
tmux new-session -t existing-session -s new-session-name
```

This is a lighter-weight alternative to multiple clients attaching to one literal session, when you specifically want separately-named sessions that nonetheless track the same windows.

### Nested tmux

Running tmux inside a pane that is itself already inside tmux (e.g., an SSH session into a remote machine that also runs tmux) requires distinguishing which prefix goes to the outer vs. inner tmux. The common convention is pressing the prefix twice (`prefix prefix key`) to send it through to the inner tmux, or using a different prefix key for local vs. remote tmux configs entirely.

### Popup Windows

`display-popup` (introduced in tmux 3.2) opens a temporary floating window on top of the current pane without disturbing your layout — handy for a quick calculator, a scratch note, or a fuzzy-finder session:

```
prefix :
display-popup -E "lazygit"
```

Many users bind this to a key for instant access to a tool without leaving their current layout:

```tmux
bind g display-popup -E "lazygit"
```

### Broadcast Input

Covered as **synchronize-panes** in [Section 6](#6-panes) — sends identical keystrokes to every pane in the current window simultaneously.

### Pipe-pane

`pipe-pane` streams a pane's output to an external command or file in real time — useful for logging a session's entire output to disk:

```
prefix :
pipe-pane -o "cat >> ~/tmux-#{pane_index}.log"
```

Running the same command again with no argument turns logging off.

### Capture-pane

`capture-pane` dumps the current visible content (or scrollback) of a pane to a tmux buffer or file — useful in scripts that need to inspect what's currently displayed:

```bash
tmux capture-pane -t mysession -p > pane-snapshot.txt
```

`-p` prints directly to stdout instead of storing in a buffer.

---

## 18. Automation

### Startup Scripts

A simple shell script (shown in [Section 17](#17-advanced-features)) can fully define a project's tmux layout. Save it as an executable, e.g. `~/scripts/dev-session.sh`, and run it whenever you start work on that project.

### Automatic Session Creation (Idempotent Scripts)

Guard your startup script so re-running it attaches to an existing session instead of erroring out:

```bash
#!/usr/bin/env bash
SESSION="dev"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n editor -c ~/projects/myapp
  tmux send-keys -t "$SESSION:editor" 'nvim .' C-m
  tmux split-window -t "$SESSION:editor" -h -c ~/projects/myapp
  tmux send-keys -t "$SESSION:editor.1" 'npm run dev' C-m
fi

tmux attach -t "$SESSION"
```

### Project Templates with tmuxinator / tmuxp

For more elaborate, repeatable, per-project layouts, dedicated session-management tools built on top of tmux's scripting interface are popular:

- **tmuxinator** (Ruby) — define sessions in YAML.
- **tmuxp** (Python) — define sessions in YAML/JSON, supports loading and saving current layouts.

Example `tmuxp` YAML:

```yaml
session_name: myapp
start_directory: ~/projects/myapp
windows:
  - window_name: editor
    panes:
      - nvim .
      - npm run dev
  - window_name: logs
    panes:
      - tail -f logs/app.log
```

```bash
tmuxp load myapp.yaml
```

### Shell Aliases

Small aliases in `~/.bashrc`/`~/.zshrc` remove friction from everyday tmux use:

```bash
alias ta='tmux attach -t'
alias tls='tmux ls'
alias tns='tmux new-session -s'
alias tkill='tmux kill-session -t'
```

---

## 19. Troubleshooting

| Symptom | Likely Cause | Solution |
|---|---|---|
| Colors look wrong / washed out inside tmux | `$TERM` is not set to a 256-color (or truecolor) value inside tmux | Set `set -g default-terminal "tmux-256color"` in `.tmux.conf`; ensure your terminal emulator's `$TERM` outside tmux is itself something like `xterm-256color`. For true 24-bit color, additionally add `set -ga terminal-overrides ",*256col*:Tc"`. |
| Mouse mode doesn't select/copy as expected | Terminal emulator mouse-reporting quirks, or `mouse` option not enabled | Confirm `set -g mouse on`; hold **Shift** while dragging to use the terminal's native selection instead. |
| Clipboard copy inside tmux doesn't reach the OS clipboard | tmux buffers are internal by default; no clipboard bridge configured | Configure `xclip`/`wl-copy`/`pbcopy`/`clip.exe` bindings (Section 13), install `tmux-yank`, or enable `set -g set-clipboard on` for OSC 52 over SSH. |
| Losing tmux sessions when SSH connection drops unexpectedly | This is actually the *opposite* of tmux's purpose — check that you started work **inside** tmux, not before starting it | Always `tmux attach` (or `tmux new`) immediately after SSH-ing in, then run long jobs inside that session. |
| Nested tmux prefix conflicts (SSH into a machine that itself runs tmux) | Both the outer and inner tmux share the same prefix key | Press the prefix **twice** to send it to the inner tmux, or configure a distinct prefix for one of them. |
| Custom keybindings "don't work" | Config not reloaded after editing, or binding placed in the wrong key table | Run `tmux source-file ~/.tmux.conf` (or `prefix r` if bound); verify with `prefix ?` that the binding is registered as expected. |
| TPM plugins fail to install (`prefix I` does nothing visible) | TPM not cloned correctly, or the `run '~/.tmux/plugins/tpm/tpm'` line isn't at the very bottom of `.tmux.conf` | Confirm `~/.tmux/plugins/tpm` exists and contains files; ensure the `run` line is the **last** line in the config; check for `git` availability. |
| tmux feels sluggish / high CPU usage | An overly complex, high-frequency status bar format, or a plugin polling too often | Increase `status-interval`; simplify status-bar formats; check `tmux-continuum`'s auto-save interval. |
| Pressing `Escape` in Vim/Neovim inside tmux feels delayed | tmux's default `escape-time` (500ms) waits to distinguish a lone `Esc` from the start of an escape sequence | Lower it: `set -g escape-time 10`. |
| `tmux: command not found` after installing from source | `make install` installed to a prefix not on `$PATH` | Check `./configure --prefix=...` output, or add the install location (often `/usr/local/bin`) to `$PATH`. |

---

## 20. Best Practices

- **Name everything.** Named sessions and windows are dramatically easier to manage than remembering numeric indices once you have more than two or three.
- **Keep `.tmux.conf` under version control**, ideally alongside your other dotfiles (e.g., via GNU Stow), so a new machine is one `git clone` and a `prefix I` away from your full setup.
- **Reload, don't restart, to test config changes** — `source-file` picks up changes live without destroying your running sessions.
- **Use `tmux-resurrect`/`tmux-continuum`** if you rely on tmux for long-running, hard-to-recreate layouts (multi-server monitoring, long build pipelines).
- **Prefer panes over excessive windows** for closely related work; prefer windows over excessive panes for loosely related work. Cramming everything into panes on one screen hurts readability just as much as scattering everything into ten windows hurts navigability.
- **Learn the command prompt (`prefix :`)** early — it's the fastest way to discover and test new tmux functionality without memorizing a keybinding first.
- **Turn off `synchronize-panes` immediately after using it** — leaving it on is a classic source of accidentally running a destructive command against the wrong host.
- **Set `escape-time` low** if you use Vim/Neovim, to avoid an annoying `Esc` delay.

---

## 21. Common Mistakes

- **Confusing `%` and `"` split directions.** Remember: the character visually resembles the *divider*, not the resulting pane arrangement — `%` looks like a diagonal split hinting vertical, `"` are two dots side by side hinting horizontal. If it never clicks, just remap them (Section 14).
- **Running important long jobs *before* starting tmux**, then wondering why an SSH drop killed it. tmux only protects processes started *inside* an active tmux pane.
- **Killing a session instead of detaching.** `prefix d` (detach) preserves everything; `kill-session` destroys everything. These are not interchangeable.
- **Forgetting the TPM init line must be the last line** in `.tmux.conf`, causing plugins declared after it to silently not load.
- **Assuming tmux copy-paste automatically syncs with the OS clipboard.** It doesn't, by default — see Section 13.
- **Leaving `synchronize-panes` on** after a bulk operation, then typing something host-specific (or a password) that gets sent everywhere.
- **Over-customizing before understanding defaults.** Copy-pasting a large, unexplained `.tmux.conf` from the internet before learning what each line does makes troubleshooting your own setup much harder later.
- **Not distinguishing outer vs. inner tmux prefixes** when nesting sessions over SSH, leading to confusing "my keybinding didn't work" moments.

---

## 22. Learning Roadmap

### Day 1
- Install tmux; verify with `tmux -V`.
- Learn: creating a session, detaching, reattaching, killing a session.
- Learn: creating/closing windows, switching between them.
- Learn: splitting panes both ways, closing a pane, and moving between panes with arrow keys.

### Week 1
- Comfortably use the full [Essential Keybindings cheat sheet](#8-essential-keybindings-cheat-sheet) from memory for sessions/windows/panes.
- Set up a basic `.tmux.conf`: remap the prefix (optional), enable mouse mode, set `base-index 1`, add a config-reload binding.
- Practice copy mode: entering it, searching, selecting, and copying/pasting text.
- Try at least one real multi-pane workflow (editor + shell + logs) for actual work.

### Week 2
- Install TPM and at least `tmux-sensible` and `tmux-resurrect`.
- Customize the status bar with session name, time, and one dynamic value (e.g., current path).
- Learn all five built-in layouts and when to reach for each.
- Write your first startup script that builds a project layout automatically.

### Month 1
- Add `tmux-continuum` for automatic session persistence.
- Learn synchronize-panes and use it for a real multi-host administration task.
- Configure OS clipboard integration appropriate to your platform (Section 13).
- Start using the command prompt (`prefix :`) routinely to explore tmux commands you haven't bound to a key yet.

### Month 2
- Explore hooks, formats, and `pipe-pane`/`capture-pane` for scripting/logging use cases.
- Set up `vim-tmux-navigator` (or equivalent) for seamless editor/pane navigation.
- Build a reusable project-template system (tmuxinator/tmuxp, or your own scripts) for spinning up consistent multi-pane environments.
- Practice nested tmux and popup windows (`display-popup`) for edge-case workflows.

### Advanced Mastery
- Comfortable running multiple isolated tmux servers via `-L`/`-S` for separate contexts (personal vs. shared/teaching servers).
- Comfortable using session groups and multi-client attach for pairing/teaching.
- Able to read and extend `.tmux.conf` confidently, including format expressions and hooks, without copying unexplained snippets from the internet.
- Treat tmux as an invisible part of your daily terminal muscle memory rather than a tool you consciously think about.

---

## 23. Exercises

Work through these in order; each builds on skills from the previous one.

1. **Build a development workspace.** Create a session named `dev` with three windows: `editor`, `server`, and `git`. In `editor`, split into two panes (editor on the left, a shell on the right). Detach, then reattach and confirm everything is exactly as you left it.

2. **SSH workflow.** SSH into any remote machine you have access to (or a local VM/container). Start a named tmux session there, run a long-running command (e.g., `sleep 300` or a real build), then deliberately close your terminal window. Reconnect via SSH and reattach — confirm the command is still running.

3. **Multi-pane monitoring.** Open four panes in a single window using the `tiled` layout. Run a different monitoring command in each (e.g., `htop`, `df -h --output=used,avail,target`, `journalctl -f`, `ping 1.1.1.1`). Practice cycling between them with `prefix o` and zooming one with `prefix z`.

4. **Copy mode practice.** Generate some long output (e.g., `ls -la /usr/bin` or `man bash`), enter copy mode, search for a specific term with `/`, select a block of text spanning several lines, copy it, and paste it into a different pane.

5. **Session management.** Create three differently named sessions. Practice switching between them with `prefix s` and `prefix (`/`)`. Rename one session, then kill another explicitly with `tmux kill-session -t <name>` (from outside tmux) and confirm it disappears from `tmux ls`.

6. **Configuration exercise.** Starting from a blank `.tmux.conf`, add: a remapped prefix, mouse support, `vi` copy-mode keys, and a config-reload keybinding. Reload it live and confirm each change takes effect without restarting tmux.

7. **Plugin exercise.** Install TPM, add `tmux-resurrect`, save your current layout (`prefix Ctrl-s`), fully kill the tmux server (`tmux kill-server`), start a fresh tmux, and restore your layout (`prefix Ctrl-r`).

8. **Automation exercise.** Write a shell script that creates a named session with two windows and specific panes/commands already running, and make it idempotent (safe to re-run without erroring if the session already exists).

---

## 24. Cheat Sheets

### Sessions

| Command | Action |
|---|---|
| `tmux new -s name` | Create named session |
| `tmux ls` | List sessions |
| `tmux attach -t name` | Attach to session |
| `tmux kill-session -t name` | Kill a session |
| `tmux kill-server` | Kill the entire server (all sessions) |
| `prefix d` | Detach |
| `prefix s` | Interactive session list |
| `prefix $` | Rename session |

### Windows

| Keybinding | Action |
|---|---|
| `prefix c` | New window |
| `prefix ,` | Rename window |
| `prefix &` | Kill window |
| `prefix n` / `p` | Next / previous |
| `prefix 0-9` | Jump to index |
| `prefix w` | Window list |

### Panes

| Keybinding | Action |
|---|---|
| `prefix %` | Split vertical (side by side) |
| `prefix "` | Split horizontal (stacked) |
| `prefix x` | Kill pane |
| `prefix z` | Zoom toggle |
| `prefix o` | Next pane |
| `prefix Space` | Cycle layout |
| `prefix Ctrl/Alt-Arrow` | Resize |

### Navigation

| Keybinding | Action |
|---|---|
| `prefix Arrow` | Move focus between panes |
| `prefix l` | Last window |
| `prefix ;` | Last pane |
| `prefix f` | Find window |

### Copy Mode

| Key | Action |
|---|---|
| `prefix [` | Enter copy mode |
| `/` `?` | Search forward / backward |
| `Space` / `Enter` | Start / finish selection (vi) |
| `prefix ]` | Paste buffer |
| `prefix =` | Choose buffer |

### Configuration Essentials

```tmux
set -g prefix C-a
set -g mouse on
set -g base-index 1
setw -g mode-keys vi
set -g escape-time 10
bind r source-file ~/.tmux.conf
```

### Commands (via `prefix :`)

| Command | Action |
|---|---|
| `rename-window <name>` | Rename current window |
| `split-window -h` / `-v` | Split pane |
| `swap-pane -s <a> -t <b>` | Swap two panes |
| `setw synchronize-panes on/off` | Broadcast keystrokes |
| `display-popup -E "<cmd>"` | Floating popup window |
| `capture-pane -p` | Print pane contents |
| `source-file ~/.tmux.conf` | Reload config |

---

## 25. Further Reading

- **Official tmux GitHub repository** — https://github.com/tmux/tmux (source, issue tracker, and the authoritative `CHANGES` file documenting every version's new features and fixes)
- **Official tmux Wiki** — https://github.com/tmux/tmux/wiki (installation notes, FAQ, and links to further documentation)
- **`man tmux`** — the canonical, complete reference for every command, option, and format variable; run `man tmux` on any machine with tmux installed
- **TPM (Tmux Plugin Manager)** — https://github.com/tmux-plugins/tpm
- **tmux-resurrect** — https://github.com/tmux-plugins/tmux-resurrect
- **tmux-continuum** — https://github.com/tmux-plugins/tmux-continuum
- **tmux-yank** — https://github.com/tmux-plugins/tmux-yank
- **Catppuccin for tmux** — https://github.com/catppuccin/tmux
- **tmuxinator** — https://github.com/tmuxinator/tmuxinator
- **tmuxp** — https://github.com/tmux-python/tmuxp

> **Tip:** Whenever you want to confirm a specific command's exact syntax or check which tmux version introduced a feature, `man tmux` and the official `CHANGES` file in the GitHub repository are the two most reliable sources — community blog posts and tutorials (including this one) can drift out of date as tmux evolves, but the manual page always reflects the exact version installed on your machine.

---

*This guide targets tmux 3.6 and later; nearly everything described also applies unchanged to tmux 2.x/3.0+, with the exceptions explicitly called out (e.g., `display-popup` requires 3.2+, `pane-scrollbars` requires 3.6+, the ACL/`server-access` commands require 3.3+). Always cross-check `tmux -V` against the feature you're relying on if something doesn't behave as documented here.*
