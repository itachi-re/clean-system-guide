# GNU Stow — Dotfile Management Without Mess

> One tool. One rule. Zero symlink guesswork.

---

## The Problem

Config files on Linux are scattered by design:

- `~/.zshrc` — shell config
- `~/.config/nvim/` — editor config
- `~/.config/haruna/haruna.conf` — media player config
- `~/.config/kate/katerc` — text editor config

When you want to version-control these, the naive approach is copying them into a Git repo. But now you have two copies — the real one the app reads, and the "backup" in your repo. They diverge. You forget to sync. You add a new machine and can't remember which copy is current.

The standard fix is symlinks: point the real config location to a file inside your Git repo. Apps read the symlink as if it were a real file; changes go directly into the repo. But managing dozens of symlinks by hand is tedious, error-prone, and invisible — you forget which ones exist, where they point, and how to cleanly remove them.

**GNU Stow solves this.** It is a symlink farm manager: you organize your configs into a consistent directory structure, and Stow creates, maintains, and removes all symlinks automatically — completely, consistently, and reversibly.

---

## What GNU Stow Is

GNU Stow is not a framework, not a package manager, and not a configuration management system. It is a single-purpose tool that creates symbolic links from a **target directory** to files inside a **stow directory**, following exactly one rule:

> **The directory structure inside a package mirrors the directory structure starting at the target.**

If a file lives at `~/.dotfiles/zsh/.zshrc`, Stow knows it belongs at `~/.zshrc`.
If a file lives at `~/.dotfiles/haruna/.config/haruna/haruna.conf`, Stow knows it belongs at `~/.config/haruna/haruna.conf`.

No extra configuration. The path is the configuration.

---

## Core Terminology

Every term used in Stow's documentation and error messages has a precise meaning. Confusion with Stow almost always comes from not knowing which directory is which. Learn these before anything else.

---

### Stow Directory

The directory that contains all your packages. Everything Stow manages originates here. Nothing in this directory is a config file that an app reads directly — everything here exists only to be symlinked somewhere else.

**In a typical dotfiles setup:** `~/.dotfiles/`

**Default behavior:** When you run `stow`, it treats the **current working directory** as the stow directory. This is why you run `stow` from inside `~/.dotfiles/`.

---

### Target Directory

The directory where Stow creates symlinks. This is where apps actually look for their config files.

**In a typical dotfiles setup:** `~/` (your home directory)

When Stow processes a package, it walks the package's directory tree and creates symlinks in the target that point back to the corresponding files in the stow directory.

**Default behavior:** Stow uses the **parent of the stow directory** as the target. If your stow directory is `~/.dotfiles/`, the default target is `~/`. You don't need to specify `-t ~/` every time because this is inferred automatically.

---

### Package

A direct subdirectory of the stow directory. Each package represents one application or one logical group of related config files.

**Examples:** `haruna/`, `zsh/`, `nvim/`, `kate/`, `konsole/`, `atuin/`, `btop/` — each is a package.

**The fundamental rule:** The directory structure inside a package mirrors the path structure relative to the target root. A file at:

```
~/.dotfiles/<package>/<some/path/to/file>
```

gets symlinked to:

```
~/<some/path/to/file>
```

---

### Symlink Farm

The collection of symbolic links Stow creates inside the target directory. After stowing a package, the target contains symlinks pointing back into the stow directory. Applications follow these symlinks transparently — to an app, the symlink looks identical to a real file.

---

### Stowing

The act of creating symlinks for a package. Running `stow haruna` reads every file in the `haruna` package and creates corresponding symlinks in the target. Stow will refuse to stow if a real file (not a symlink) already exists at any of the target paths.

---

### Unstowing

The act of removing symlinks for a package. Running `stow -D haruna` removes all symlinks that point into the `haruna` package. The real files inside `~/.dotfiles/haruna/` are completely untouched — only the symlinks in the target disappear.

---

### Restowing

Remove all symlinks for a package, then recreate them. `stow -R haruna` is equivalent to `stow -D haruna && stow haruna`. Use this after adding new files to an existing package, after restructuring a package, or when symlinks are out of sync.

---

### Conflict

A situation where Stow needs to create a symlink but finds a **real file** (not a symlink) already at that target path. Stow will abort the entire operation rather than overwrite the real file.

**Example conflict message:**
```
WARNING! stowing atuin would cause conflicts:
  * cannot stow .dotfiles/atuin/.config/atuin/config.toml over existing
    target .config/atuin/config.toml since neither a link nor a directory
    and --adopt not specified
All operations aborted.
```

This means `~/.config/atuin/config.toml` exists as a real file. Stow sees it is not a symlink (`neither a link`) and not a directory it can descend into, so it refuses.

---

### Tree Folding

An optimization Stow uses when a directory in the package has no corresponding directory in the target yet. Instead of creating the real directory and symlinking individual files inside it, Stow creates **a single symlink to the entire directory subtree**.

**Example:** You stow `haruna`. Stow checks whether `~/.config/haruna/` exists:
- `~/.config/` exists as a real directory → Stow goes inside it
- `~/.config/haruna/` does not exist → Stow creates one symlink for the whole thing

```
~/.config/haruna  →  ../.dotfiles/haruna/.config/haruna
```

The entire `~/.dotfiles/haruna/.config/haruna/` tree is now reachable through one symlink. Any file you add to the package directory immediately appears through the link — no restow needed.

---

### Tree Unfolding

The reverse of tree folding. When a directory symlink that was folded needs to be shared between two packages (because a second package also has files that belong inside that same directory), Stow replaces the single directory symlink with a real directory, then creates individual file symlinks inside it for each file from both packages.

In practice: if you maintain one package per application and never have two packages that share the same `~/.config/<appname>/` subdirectory, you will rarely encounter unfolding. The one-package-per-app naming convention specifically prevents this.

---

## Your Dotfiles Layout, Explained

With a stow directory of `~/.dotfiles/` and a target of `~/`, your layout looks like this:

```
~/.dotfiles/                   ← Stow directory (the repo root)
├── haruna/                    ← Package
│   └── .config/
│       └── haruna/            ← Tree-folded: becomes ~/.config/haruna symlink
│           ├── haruna.conf
│           ├── shortcuts.conf
│           └── custom-commands.conf
│
├── zsh/                       ← Package
│   └── .zshrc                 ← File symlinked directly to ~/.zshrc
│
├── konsole/                   ← Package with files in two locations
│   ├── .config/
│   │   └── konsolerc
│   └── .local/
│       └── share/
│           └── konsole/
│               ├── Profile 1.profile
│               └── MaterialYou.colorscheme
│
├── okular/                    ← Package with single rc files (no subdir)
│   └── .config/
│       ├── okularrc
│       └── okularpartrc
│
├── .stowrc                    ← Stow default options
├── .stow-global-ignore        ← Patterns Stow should never symlink
└── install.sh                 ← Script to restow all packages at once
```

After stowing, the result in `~/.config/`:

```
~/.config/
├── haruna      →  ../.dotfiles/haruna/.config/haruna       (directory symlink)
├── nvim        →  ../.dotfiles/nvim/.config/nvim           (directory symlink)
├── atuin       →  ../.dotfiles/atuin/.config/atuin         (directory symlink)
├── btop        →  ../.dotfiles/btop/.config/btop           (directory symlink)
├── okularrc    →  ../.dotfiles/okular/.config/okularrc     (file symlink)
├── okularpartrc→  ../.dotfiles/okular/.config/okularpartrc (file symlink)
└── (real directories for apps not managed by Stow)
```

---

## The `.stowrc` File

Located at `~/.dotfiles/.stowrc`, this file sets default options so you don't need to type them with every command. Stow reads it automatically when you run `stow` from inside the stow directory.

**Typical content:**

```
--target=/home/youruser
--dir=/home/youruser/.dotfiles
```

With this in place, running `stow haruna` from anywhere is equivalent to:

```bash
stow --target=/home/youruser --dir=/home/youruser/.dotfiles haruna
```

**Where Stow looks for `.stowrc` (in order):**
1. `/usr/local/etc/stow/stowrc` — system-wide defaults
2. `~/.stowrc` — user-level defaults
3. `.stowrc` inside the stow directory — per-repo defaults (this is where yours lives)

Later files override earlier ones. Options on the command line override all files.

---

## The Ignore Files

Stow needs to know which files inside your dotfiles repo should **not** be symlinked into the target. Without ignore rules, Stow would try to link `README.md`, `LICENSE`, `install.sh`, and `.git/` into your home directory.

### Syntax: Perl Regular Expressions

**Critical detail:** Ignore files use **Perl regular expressions**, not shell glob patterns. This is a common source of mistakes.

| You might write | You should write | Why |
|---|---|---|
| `*.md` | `\.md$` | `*` means "repeat previous char" in Perl regex, not "any string" |
| `*.bak` | `\.bak$` | `$` anchors to end of filename |
| `.git` | `\.git` | `.` matches any character in regex; `\.` matches a literal dot |

---

### `.stow-global-ignore`

Located at `~/.dotfiles/.stow-global-ignore`. Patterns here apply to **every package** in the stow directory.

```perl
# Version control
\.git
\.gitignore
\.gitmodules
\.gitattributes

# Documentation
README.*
LICENSE.*
COPYING
CHANGELOG.*

# Scripts (shouldn't be symlinked into ~/)
install\.sh
setup\.sh
Makefile

# Editor artifacts
.*~
.*\.bak
.*\.swp
.*\.orig

# macOS artifacts
\.DS_Store

# Stow's own files
\.stow-local-ignore
\.stow-global-ignore
\.stowrc
```

---

### `.stow-local-ignore`

Located inside a specific package directory (e.g., `~/.dotfiles/nvim/.stow-local-ignore`). Patterns here apply only to that package. Use this when one package has files that should not be linked but that don't warrant a global rule.

---

### Built-in Stow Defaults

Stow has built-in patterns it always ignores, regardless of your ignore files. These include version control directories (`.git`, `.svn`, `.hg`, `CVS`, `_darcs`, `.bzr`), Stow's own config files (`.stow-local-ignore`, `.stow-global-ignore`, `.stowrc`), and some legacy source control artifacts. You do not need to add these manually — but adding them explicitly does no harm and makes your ignore file self-documenting.

---

## Directory Naming Convention

This is the single most important thing to keep consistent across your packages. Every package should follow the same structural rule so the relationship between dotfiles and their symlinks is immediately obvious.

---

### Rule 1: App with a config directory under `~/.config/`

```
~/.dotfiles/<PACKAGE>/.config/<PACKAGE>/
```

The package name matches the app's config directory name.

| App | Path in dotfiles | Symlink created |
|---|---|---|
| `haruna` | `haruna/.config/haruna/` | `~/.config/haruna →  ../.dotfiles/haruna/.config/haruna` |
| `nvim` | `nvim/.config/nvim/` | `~/.config/nvim → ../.dotfiles/nvim/.config/nvim` |
| `atuin` | `atuin/.config/atuin/` | `~/.config/atuin → ../.dotfiles/atuin/.config/atuin` |
| `btop` | `btop/.config/btop/` | `~/.config/btop → ../.dotfiles/btop/.config/btop` |
| `flameshot` | `flameshot/.config/flameshot/` | `~/.config/flameshot → ../.dotfiles/flameshot/.config/flameshot` |

---

### Rule 2: App with a single rc file under `~/.config/`

```
~/.dotfiles/<PACKAGE>/.config/<FILENAME>
```

The package name is the app name. Related files for the same app go in the same package.

| File | Path in dotfiles | Symlink created |
|---|---|---|
| `okularrc` | `okular/.config/okularrc` | `~/.config/okularrc → ../.dotfiles/okular/.config/okularrc` |
| `okularpartrc` | `okular/.config/okularpartrc` | `~/.config/okularpartrc → ../.dotfiles/okular/.config/okularpartrc` |

Both Okular files belong in the `okular` package — one package per application, not one package per file.

---

### Rule 3: Dotfile directly in `~/`

```
~/.dotfiles/<PACKAGE>/.<FILENAME>
```

| File | Path in dotfiles | Symlink created |
|---|---|---|
| `.zshrc` | `zsh/.zshrc` | `~/.zshrc → .dotfiles/zsh/.zshrc` |
| `.vimrc` | `vim/.vimrc` | `~/.vimrc → .dotfiles/vim/.vimrc` |
| `.bashrc` | `bash/.bashrc` | `~/.bashrc → .dotfiles/bash/.bashrc` |

---

### Rule 4: App with files in multiple XDG locations

Some apps use both `~/.config/` and `~/.local/share/`. Both sets of files go in the same package — Stow handles multiple paths from a single `stow <package>` command.

```
~/.dotfiles/konsole/
├── .config/
│   └── konsolerc          →  ~/.config/konsolerc
└── .local/
    └── share/
        └── konsole/       →  ~/.local/share/konsole/  (tree-folded)
            ├── Profile 1.profile
            └── MaterialYou.colorscheme
```

One `stow konsole` links everything.

---

### What NOT to do

```
# Wrong: package name doesn't match config dir
~/.dotfiles/media-player/.config/haruna/haruna.conf

# Wrong: one package per file instead of per app
~/.dotfiles/okularrc/.config/okularrc
~/.dotfiles/okularpartrc/.config/okularpartrc

# Wrong: files dumped at the package root with no path structure
~/.dotfiles/zsh/zshrc          # would create ~/.dotfiles/zsh/zshrc, not ~/.zshrc
```

---

## All Commands

### Stow a package

```bash
stow <package>
```

Creates symlinks in the target for every file in `<package>`. Fails immediately if any real (non-symlink) file exists at a target path.

---

### Unstow a package

```bash
stow -D <package>
```

Removes all symlinks in the target that point into `<package>`. Files inside `~/.dotfiles/<package>/` are never touched. Empty directories left in the target after removing symlinks are also cleaned up.

---

### Restow a package

```bash
stow -R <package>
```

Equivalent to `stow -D <package> && stow <package>`. Use this when:
- You added new files to an existing package
- You restructured a package's directory layout
- Symlinks seem out of sync for any reason

Restow is safe to run on any package at any time. If everything is already correct, it just removes and recreates the same symlinks.

---

### Dry run

```bash
stow -n <package>
```

Simulates the stow operation without creating or removing any symlinks. Use this to check for conflicts before acting.

---

### Verbose output

```bash
stow -v <package>
```

Prints each action as it happens. Without `-v`, successful stowing produces no output (Unix philosophy: silence means success).

---

### Dry run with verbose — the safe preview

```bash
stow -nv <package>
```

Shows exactly what Stow would do without doing it. **Run this before every stow on a package you haven't touched before.** It's the one command you should make a habit of.

Example output:
```
LINK: .config/atuin => ../.dotfiles/atuin/.config/atuin
LINK: .config/btop => ../.dotfiles/btop/.config/btop
```

---

### Adopt existing files

```bash
stow --adopt <package>
```

**Use with extreme caution and only after committing your dotfiles.**

`--adopt` resolves conflicts by physically **moving files from the target into the stow package**, then creating symlinks back. It is the opposite of what the name implies to most people.

**What it does, step by step:**
1. Finds a conflict: `~/.config/app/config` is a real file, not a symlink
2. Moves `~/.config/app/config` INTO `~/.dotfiles/app/.config/app/config` (overwriting whatever was there)
3. Creates a symlink: `~/.config/app/config → ../.dotfiles/app/.config/app/config`

**The risk:** If your stow package had newer or different content than the target file, that content is now gone. The target file won — unconditionally.

**Safe adopt workflow:**

```bash
# Step 1: save current state of dotfiles
cd ~/.dotfiles
git add -A && git commit -m "snapshot before adopting"

# Step 2: adopt (overwrites stow package with target files)
stow --adopt <package>

# Step 3: review what changed
git diff

# Step 4: decide if you want to keep these changes or restore
git add -A && git commit -m "adopt: <package>"
# or: git checkout -- .  (restore the dotfiles to pre-adopt state)
```

---

### Multiple packages at once

```bash
# Stow several packages in one command
stow zsh nvim haruna kate konsole mpv atuin btop

# Unstow several at once
stow -D zsh nvim haruna

# Restow several at once
stow -R zsh nvim haruna
```

---

### Explicit directory overrides

```bash
# Specify both directories explicitly (overrides .stowrc for this invocation)
stow -d ~/.dotfiles -t ~ haruna

# Run from any directory, not just the stow directory
stow -d /path/to/dotfiles -t /path/to/target <package>
```

---

## Tree Folding and Unfolding: A Deep Dive

Understanding this is what makes Stow's behavior predictable instead of surprising. Almost every unexpected behavior from Stow can be explained by whether a directory is folded, unfolded, or needs to be unfolded.

---

### How Stow Decides: The Algorithm

When stowing a package, Stow walks the package's directory tree and at each directory level asks:

**Does this directory exist in the target?**

- **No** → Create a single symlink pointing to this entire directory subtree. Stop descending here. **(Tree folding)**
- **Yes, as a real directory** → Go inside and repeat the process for its contents recursively.
- **Yes, as a symlink to another Stow package's directory** → This folded symlink needs to become a real directory so both packages can coexist inside it. Replace the symlink with a real directory, create individual file symlinks for the original package's files, then continue stowing the new package's files. **(Tree unfolding)**

---

### Concrete Folding Example

Stowing `haruna` in a fresh `~/.config/`:

1. `~/.config/` exists as a real directory → descend into it
2. `~/.config/haruna/` does not exist → **fold**: create one symlink

```
~/.config/haruna  →  ../.dotfiles/haruna/.config/haruna
```

Result: the entire `~/.dotfiles/haruna/.config/haruna/` directory is reachable through one link. Add `haruna.conf.new` to the dotfiles package, and it immediately appears at `~/.config/haruna/haruna.conf.new` — no Stow action needed.

---

### Why the Symlink Target Uses `../.dotfiles/`

The symlink is created at `~/.config/haruna`. Its target is `../.dotfiles/haruna/.config/haruna`.

Resolving this path from `~/.config/haruna`:
- `..` → go up from `~/.config/` to `~/`
- `.dotfiles/haruna/.config/haruna` → go down into the stow package

Final resolution: `/home/youruser/.dotfiles/haruna/.config/haruna`

This is a **relative symlink**. It works as long as the relative path between `~/.config/` and `~/.dotfiles/` doesn't change. If you move your dotfiles repo to a different location, you'll need to restow everything.

---

### Concrete Unfolding Example

Suppose `~/.config/haruna` is a folded symlink pointing to the `haruna` package. Now you try to stow a hypothetical `haruna-extra` package that also has a file under `~/.config/haruna/`:

1. Stow checks `~/.config/haruna/` → it's a symlink (to `haruna` package)
2. Can't fold again — this is a conflict unless unfolded
3. **Unfold**: remove the `~/.config/haruna` directory symlink
4. Create a real `~/.config/haruna/` directory
5. Inside it, create individual symlinks for every file from the `haruna` package
6. Inside it, create individual symlinks for every file from the `haruna-extra` package

After unfolding:
```
~/.config/haruna/              (now a real directory)
├── haruna.conf        →  ../../../../.dotfiles/haruna/.config/haruna/haruna.conf
├── shortcuts.conf     →  ../../../../.dotfiles/haruna/.config/haruna/shortcuts.conf
└── extra.conf         →  ../../../../.dotfiles/haruna-extra/.config/haruna/extra.conf
```

**In practice:** You will never trigger this if you follow the one-package-per-app convention. The convention exists precisely to keep directories folded.

---

## Conflict Types and Resolution

### Type 1: Real file where a symlink should go

**Message:**
```
cannot stow package/.config/app/config over existing target .config/app/config
since neither a link nor a directory and --adopt not specified
```

**Cause:** A real file exists at the symlink target path. Stow will not overwrite real files.

**Resolution — choose one:**

```bash
# Option A: The target file and dotfiles file are identical — safe to delete target
rm ~/.config/app/config
stow <package>

# Option B: The target file has newer content you want to keep
# Adopt it (moves target into dotfiles, creates symlink)
cd ~/.dotfiles && git add -A && git commit -m "pre-adopt snapshot"
stow --adopt <package>
git diff  # review what changed

# Option C: The target file is being regenerated by an app (e.g., atuin)
# Remove and stow atomically — no gap for the app to recreate the file
rm -rf ~/.config/app && stow <package>
```

---

### Type 2: Symlink exists but points to the wrong place

**Message:**
```
cannot stow package/.config/app over existing target .config/app
since it is a symlink to some other target
```

**Cause:** A symlink already exists at the target path, but it points somewhere other than your stow package (e.g., a broken symlink, or one left from a different dotfiles system).

**Resolution:**
```bash
ls -la ~/.config/app          # check where it points
rm ~/.config/app              # remove the wrong symlink
stow <package>                # create the correct one
```

---

### Type 3: Directory exists as real but package expects a fold

**Cause:** `~/.config/appname/` exists as a real directory (created by the app before you started managing it with Stow). Stow descends into it and tries to create individual file symlinks, but the files already exist as real files.

**Resolution:**
```bash
mv ~/.config/appname ~/.config/appname.bak    # back it up
stow <package>                                 # now it can create the directory symlink
diff -r ~/.config/appname ~/.config/appname.bak  # verify nothing was lost
rm -rf ~/.config/appname.bak                  # clean up
```

---

## The Full Workflow: Adding a New Config to Stow

This is the complete, correct sequence for every new config you bring under Stow management.

---

### Step 1: Identify what you're bringing in

```bash
# Is it a directory config?
ls ~/.config/newapp

# Is it a single rc file?
ls ~/.config/newapprc

# Is it a home dotfile?
ls ~/.newapprc
```

---

### Step 2: Create the package structure in dotfiles

```bash
cd ~/.dotfiles

# For a directory config:
mkdir -p newapp/.config

# For a single file:
mkdir -p newapp/.config

# For a home dotfile:
mkdir -p newapp
```

---

### Step 3: Move (not copy) the real config into the package

**Move, not copy.** Copying leaves the original in place, which causes a conflict when Stow tries to create the symlink. Moving removes the original so Stow can put the symlink there.

```bash
# Directory config:
mv ~/.config/newapp ~/.dotfiles/newapp/.config/newapp

# Single file:
mv ~/.config/newapprc ~/.dotfiles/newapp/.config/newapprc

# Home dotfile:
mv ~/.newapprc ~/.dotfiles/newapp/.newapprc
```

---

### Step 4: Dry run first — always

```bash
stow -nv newapp
```

Expected output:
```
LINK: .config/newapp => ../.dotfiles/newapp/.config/newapp
```

If you see a conflict here, resolve it before proceeding (see the conflict section above). Never skip the dry run.

---

### Step 5: Stow the package

```bash
stow newapp
```

No output means success.

---

### Step 6: Verify the symlink

```bash
# For a directory:
ls -la ~/.config/newapp
# Expected: ~/.config/newapp -> ../.dotfiles/newapp/.config/newapp

# For a file:
ls -la ~/.config/newapprc
# Expected: ~/.config/newapprc -> ../.dotfiles/newapp/.config/newapprc

# You can also use readlink to check the target directly:
readlink ~/.config/newapp
# Expected: ../.dotfiles/newapp/.config/newapp
```

---

### Step 7: Commit to Git

```bash
cd ~/.dotfiles
git add newapp/
git commit -m "feat: add newapp to stow"
```

---

## Common Gotchas

### Apps that regenerate their config instantly

Some apps — particularly those with shell hooks — detect a missing config and recreate it before the next shell prompt. Atuin is the classic example: it has a zsh hook that fires on every command. When `~/.config/atuin/config.toml` disappears, the hook recreates it before your next command runs.

This is why the sequence `rm ~/.config/atuin` followed by `stow atuin` (two separate commands) fails: the `rm` runs, atuin's zsh hook fires during the prompt draw between commands, recreates the file, and then `stow` hits a conflict.

**Solution: remove and stow in a single shell expression**

```bash
rm -rf ~/.config/atuin && stow atuin
```

The `&&` chains both commands without returning to an interactive prompt, giving atuin's hook no opportunity to fire in between.

---

### Stow directory is inside the target — this is fine

`~/.dotfiles/` lives inside `~/` (the target). This seems like it should cause Stow to try to link the dotfiles directory into itself, but it doesn't. Stow automatically ignores the stow directory itself when scanning for things to symlink.

---

### Forgetting to run from the right directory

If you run `stow haruna` from `~/` instead of `~/.dotfiles/`, Stow treats `~/` as the stow directory and tries to find a `haruna` package there. It won't find it. Always run Stow from `~/.dotfiles/`, or rely on a properly configured `.stowrc` that sets `--dir` explicitly.

---

### Adding files to an already-stowed package

If `~/.config/haruna` is a folded symlink (pointing to the whole directory), any file you add to `~/.dotfiles/haruna/.config/haruna/` immediately appears at `~/.config/haruna/` through the symlink. No restow needed.

If `~/.config/haruna/` is a real directory (because Stow unfolded it at some point), new files in the package do not appear automatically. Run `stow -R haruna` to restow.

**When in doubt: `stow -R <package>` is always safe.** It is idempotent — running it when everything is already correct just removes and recreates the same symlinks.

---

### Relative vs absolute symlinks

Stow creates relative symlinks by default (e.g., `../.dotfiles/haruna/.config/haruna`). These are relative to the symlink's own location. They work correctly as long as the relative path relationship between the target and the stow directory does not change. If you move your dotfiles repo to a different path, all symlinks will break. The fix is to restow all packages after the move.

---

### The `--adopt` flag does not do what the name implies

`--adopt` does not gently "adopt" existing files while leaving them where they are. It **moves files from the target into your stow package**, replacing whatever was there. The target file wins. If your stow package had different (or newer) content, it is gone.

Always commit your dotfiles before running `--adopt`.

---

## Verifying Your Setup

### List all symlinks in `~/.config`

```bash
find ~/.config -maxdepth 1 -type l -exec ls -la {} \;
```

Shows every top-level symlink in `~/.config/`, including where each points.

---

### Check for broken symlinks

```bash
find ~/ -maxdepth 3 -type l ! -e 2>/dev/null
```

Prints any symlinks whose targets don't exist. This catches cases where a file was deleted from your dotfiles repo but the symlink in the target was not cleaned up (because you forgot to `stow -D` first).

---

### Verify a specific package

```bash
# Check the symlink target for a directory package
readlink ~/.config/haruna
# Expected: ../.dotfiles/haruna/.config/haruna

# Check a file symlink
readlink ~/.config/okularrc
# Expected: ../.dotfiles/okular/.config/okularrc
```

---

### Preview what a restow would do

```bash
stow -nv -R <package>
```

If everything is correctly stowed, this shows the symlinks being unlinked then re-linked. Any differences from what you expect indicate something is out of sync.

---

## Automating Stow for a Fresh Machine

The real payoff for all this structure is a repeatable, one-command setup on a new machine.

**`~/.dotfiles/install.sh`:**

```bash
#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
TARGET_DIR="$HOME"

PACKAGES=(
    alacritty
    atuin
    audacious
    btop
    cava
    easyeffects
    fastfetch
    flameshot
    ghostty
    gtk
    haruna
    kate
    kde
    konsole
    mangohud
    mpv
    neofetch
    nvim
    obs
    okular
    panel-colorizer
    qbittorrent
    starship
    tmux
    vim
    wal
    xsettingsd
    zsh
)

echo "Stowing dotfiles from $DOTFILES_DIR to $TARGET_DIR"
echo ""

for pkg in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        echo "  → stowing $pkg"
        stow -d "$DOTFILES_DIR" -t "$TARGET_DIR" -R "$pkg"
    else
        echo "  ⚠ skipping $pkg (directory not found)"
    fi
done

echo ""
echo "Done. Verify with: find ~/.config -maxdepth 1 -type l | xargs ls -la"
```

```bash
chmod +x ~/.dotfiles/install.sh
```

This uses `-R` (restow) for every package, which is safe to run multiple times on the same machine — it removes and recreates all symlinks cleanly. Running it again after adding a new package updates only what changed.

---

## Quick Reference

### Commands

| Command | What it does |
|---|---|
| `stow <pkg>` | Create symlinks for package |
| `stow -D <pkg>` | Remove symlinks for package |
| `stow -R <pkg>` | Restow: remove then recreate symlinks |
| `stow -n <pkg>` | Dry run — simulate without acting |
| `stow -v <pkg>` | Verbose — print each action |
| `stow -nv <pkg>` | Dry run + verbose — safe preview |
| `stow --adopt <pkg>` | Move target files into package, then link (dangerous) |
| `stow -d DIR <pkg>` | Override stow directory |
| `stow -t DIR <pkg>` | Override target directory |
| `stow p1 p2 p3` | Stow multiple packages at once |
| `stow -D p1 p2` | Unstow multiple packages at once |

### Naming Conventions

| Config type | Package path | Resulting symlink |
|---|---|---|
| Directory under `~/.config/` | `PKG/.config/PKG/` | `~/.config/PKG → ../.dotfiles/PKG/.config/PKG` |
| Single file under `~/.config/` | `PKG/.config/FILErc` | `~/.config/FILErc → ../.dotfiles/PKG/.config/FILErc` |
| Dotfile in `~/` | `PKG/.FILENAME` | `~/.FILENAME → .dotfiles/PKG/.FILENAME` |
| Mixed locations | `PKG/.config/...` + `PKG/.local/...` | Both symlinked from one `stow PKG` |

### Symlink Reading

| `ls -la` output | Meaning |
|---|---|
| `lrwxrwxrwx` | File type: symlink |
| `~/.config/haruna -> ../.dotfiles/...` | Correctly stowed (directory symlink, tree-folded) |
| `~/.config/okularrc -> ../.dotfiles/...` | Correctly stowed (file symlink) |
| `drwxr-xr-x  ~/.config/haruna` | Real directory — not managed by Stow, or unfolded |

### Conflict Quick Fix

| Situation | Command |
|---|---|
| Real file, safe to replace | `rm ~/.config/FILE && stow PKG` |
| Real dir, safe to replace | `rm -rf ~/.config/APPDIR && stow PKG` |
| App keeps recreating the file | `rm -rf ~/.config/APPDIR && stow PKG` (one line with `&&`) |
| Want to keep target file's content | `git commit -am "pre-adopt" && stow --adopt PKG && git diff` |
| Wrong symlink already there | `rm ~/.config/LINK && stow PKG` |
