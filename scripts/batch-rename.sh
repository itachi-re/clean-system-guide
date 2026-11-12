#!/usr/bin/env bash
#
# batch-rename.sh v2 — safe batch renaming: dry-run, collision protection,
# rule chaining, recursion, an undo log, and sane handling of dotfiles.
#
# Usage:
#   batch-rename.sh [options] [DIR]
#
# Options:
#   -n, --dry-run        Preview only; change nothing, write no log
#   -r, --recursive      Descend into subdirectories (files only; see guide §9 for dirs)
#   -a, --all            Include hidden files and hidden directories (default: skip them)
#   -R, --rules LIST     Comma-separated rules, applied in order (default: spaces)
#                          spaces    whitespace  -> _
#                          dash      whitespace  -> -
#                          nospace   remove all whitespace
#                          lower     lowercase name and extension
#                          upper     uppercase name and extension
#                          sanitize  replace < > : " \ | ? * and control chars with _,
#                                    strip trailing dots/spaces (Windows/exFAT safe)
#   -l, --log FILE       Where to write the undo log
#                          (default: ~/.local/state/batch-rename/rename-<timestamp>.tsv)
#   -u, --undo FILE      Reverse the renames recorded in a log (combine with -n to preview)
#   -h, --help           Show this help
#
# Examples:
#   batch-rename.sh -n                       # preview spaces -> underscores in .
#   batch-rename.sh -R sanitize,lower -r ~/Downloads
#   batch-rename.sh --undo ~/.local/state/batch-rename/rename-20261112-101500.tsv
#
# Nothing is ever overwritten: a name that is already taken gets _(1), _(2), ...

set -uo pipefail

((BASH_VERSINFO[0] >= 4)) || { echo "error: Bash 4+ required (macOS ships 3.2 — brew install bash)" >&2; exit 2; }

DRY_RUN=false
RECURSIVE=false
ALL=false
RULES="spaces"
LOGFILE=""
UNDO=""
TARGET="."
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/batch-rename"

die()   { echo "error: $*" >&2; exit 2; }
usage() { sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; }

while (($#)); do
    case "$1" in
        -n|--dry-run)   DRY_RUN=true ;;
        -r|--recursive) RECURSIVE=true ;;
        -a|--all)       ALL=true ;;
        -R|--rules)     shift; RULES="${1:?--rules needs a value}" ;;
        -l|--log)       shift; LOGFILE="${1:?--log needs a file}" ;;
        -u|--undo)      shift; UNDO="${1:?--undo needs a log file}" ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
        -*)             die "unknown option: $1 (try --help)" ;;
        *)              TARGET="$1" ;;
    esac
    shift
done
(($#)) && TARGET="$1"

# ---------- undo mode ----------------------------------------------------------
if [[ -n "$UNDO" ]]; then
    [[ -r "$UNDO" ]] || die "cannot read log: $UNDO"
    done_n=0; fail_n=0
    while IFS=$'\t' read -r old new; do
        if [[ ! -e "$new" ]]; then
            echo "SKIP (missing now): $new"; ((fail_n++)); continue
        elif [[ -e "$old" ]]; then
            echo "SKIP (original name taken): $old"; ((fail_n++)); continue
        fi
        if $DRY_RUN; then
            echo "[dry-run] undo '$new' -> '$old'"
        elif mv -n -- "$new" "$old" && [[ ! -e "$new" ]]; then
            echo "Restored: '$new' -> '$old'"; ((done_n++))
        else
            echo "FAILED: '$new'"; ((fail_n++))
        fi
    done < <(tac -- "$UNDO")
    echo "Undo finished: $done_n restored, $fail_n skipped/failed."
    exit 0
fi

# ---------- validate rules -----------------------------------------------------
IFS=, read -ra RULE_LIST <<< "$RULES"
for r in "${RULE_LIST[@]}"; do
    case "$r" in
        spaces|dash|nospace|lower|upper|sanitize) ;;
        *) die "unknown rule: '$r'" ;;
    esac
done

cd -- "$TARGET" || die "cannot enter directory: $TARGET"

# ---------- helpers ------------------------------------------------------------
# Split "name.ext" -> SPLIT_BASE / SPLIT_EXT.
# Dotfiles, extensionless files, trailing dots, and "extensions" that contain
# whitespace (e.g. "v2.final notes") are treated as having no extension.
split_ext() {
    local f="$1" e
    SPLIT_BASE="$f"; SPLIT_EXT=""
    if [[ "$f" != .* && "$f" == *.* ]]; then
        e="${f##*.}"
        if [[ -n "$e" && "$e" != *[[:space:]]* ]]; then
            SPLIT_BASE="${f%.*}"; SPLIT_EXT="$e"
        fi
    fi
}

sanitize() {   # $1 = text; prints cleaned text
    local s="$1" bad='[<>:"\\|?*[:cntrl:]]'
    s="${s//$bad/_}"
    printf '%s' "$s"
}

apply_rules() {   # reads/writes NEW_BASE, NEW_EXT
    local r trailing='*[. ]'
    for r in "${RULE_LIST[@]}"; do
        case "$r" in
            spaces)   NEW_BASE="${NEW_BASE//[[:space:]]/_}" ;;
            dash)     NEW_BASE="${NEW_BASE//[[:space:]]/-}" ;;
            nospace)  NEW_BASE="${NEW_BASE//[[:space:]]/}" ;;
            lower)    NEW_BASE="${NEW_BASE,,}"; NEW_EXT="${NEW_EXT,,}" ;;
            upper)    NEW_BASE="${NEW_BASE^^}"; NEW_EXT="${NEW_EXT^^}" ;;
            sanitize)
                NEW_BASE="$(sanitize "$NEW_BASE")"; NEW_EXT="$(sanitize "$NEW_EXT")"
                # shellcheck disable=SC2053  # $trailing is meant to be a glob
                while [[ -n "$NEW_BASE" && "$NEW_BASE" == $trailing ]]; do NEW_BASE="${NEW_BASE%?}"; done ;;
        esac
    done
}

declare -A PLANNED=()   # targets claimed during this run (matters for --dry-run)
taken() { [[ -e "$1" || -L "$1" || -n "${PLANNED[$1]:-}" ]]; }

# unique_path DIR BASE EXT -> prints a path that does not exist yet
unique_path() {
    local dir="$1" base="$2" ext="$3" suffix="" i=0 cand
    while :; do
        cand="$dir/${base}${suffix}${ext:+.$ext}"
        taken "$cand" || { printf '%s' "$cand"; return; }
        ((i++)); suffix="_($i)"
    done
}

ts="$(date +%Y%m%d-%H%M%S)"
if ! $DRY_RUN; then
    [[ -n "$LOGFILE" ]] || LOGFILE="$LOG_DIR/rename-$ts.tsv"
    mkdir -p -- "$(dirname -- "$LOGFILE")" || die "cannot create log directory"
fi

# ---------- main loop ----------------------------------------------------------
find_args=(. -type f)
$RECURSIVE || find_args+=(-maxdepth 1)
$ALL       || find_args+=(-not -path '*/.*')

renamed=0; unchanged=0; skipped=0; collided=0

while IFS= read -r -d '' src; do
    src="${src#./}"
    [[ "$src" -ef "$0" ]] && continue                      # never rename this script
    [[ -n "$LOGFILE" && -e "$LOGFILE" && "$src" -ef "$LOGFILE" ]] && continue

    dir="."; name="$src"
    [[ "$src" == */* ]] && { dir="${src%/*}"; name="${src##*/}"; }

    if [[ "$name" == *$'\t'* || "$name" == *$'\n'* ]]; then
        echo "SKIP (tab/newline in name, can't be logged safely): ${name//[$'\t\n']/?}"; ((skipped++)); continue
    fi

    split_ext "$name"
    NEW_BASE="$SPLIT_BASE"; NEW_EXT="$SPLIT_EXT"
    apply_rules

    if [[ -z "$NEW_BASE" ]]; then
        echo "SKIP (rules would empty the name): $src"; ((skipped++)); continue
    fi

    newname="${NEW_BASE}${NEW_EXT:+.$NEW_EXT}"
    [[ "$newname" == "$name" ]] && { ((unchanged++)); continue; }

    dst="$dir/$newname"
    if taken "$dst"; then
        if [[ -e "$dst" && "$src" -ef "$dst" ]]; then
            echo "SKIP (same file — case-insensitive filesystem or hard link): $src"; ((skipped++)); continue
        fi
        dst="$(unique_path "$dir" "$NEW_BASE" "$NEW_EXT")"; ((collided++))
    fi
    PLANNED["$dst"]=1

    if $DRY_RUN; then
        echo "[dry-run] '$src' -> '${dst#./}'"
    elif mv -n -- "$src" "$dst" && [[ ! -e "$src" ]]; then
        printf '%s\t%s\n' "$PWD/$src" "$PWD/${dst#./}" >> "$LOGFILE"
        echo "Renamed: '$src' -> '${dst#./}'"; ((renamed++))
    else
        echo "FAILED (left untouched): $src"; ((skipped++))
    fi
done < <(find "${find_args[@]}" -print0 | sort -z)

echo "---"
if $DRY_RUN; then
    echo "Dry run: ${#PLANNED[@]} would be renamed, $unchanged already fine, $collided would get a _(n) suffix, $skipped skipped."
else
    echo "Done: $renamed renamed, $unchanged already fine, $collided got a _(n) suffix, $skipped skipped."
    ((renamed > 0)) && echo "Undo with: $0 --undo '$LOGFILE'"
fi
exit 0
