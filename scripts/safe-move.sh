#!/bin/sh
# safe-move.sh — move a file or directory with the full safety pipeline:
#   PREFLIGHT -> DRY-RUN -> CONFIRM -> COPY -> VERIFY -> TRASH SOURCE -> LOG
# POSIX sh (dash/bash/busybox ash). Needs: rsync, find, sort, xargs, sha256sum, cmp, df, du.
# The source is trashed (recoverable) ONLY if verification passes. Nothing here calls rm.
#
# Usage: safe-move.sh [-n|--dry-run] [-y|--yes] [-k|--keep-source] [-l|--log FILE] SRC DEST_DIR
#   SRC       file or directory to move
#   DEST_DIR  existing directory; SRC ends up at DEST_DIR/<basename of SRC>
# Env: SAFE_MOVE_RSYNC_FLAGS (default "-aHAX"; use "-aH" for FAT/exFAT/NTFS targets)
#      SAFE_MOVE_LOG (log file), SAFE_MOVE_TRASH_DIR (fallback quarantine dir name)
# Exit: 0 ok | 1 usage/refused | 2 preflight failed | 3 copy failed | 4 verify FAILED (source untouched)
#       5 could not trash source (copy verified, source untouched) | 130 aborted by user
set -eu

PROG=safe-move
DRY=0 YES=0 KEEP=0
LOG=${SAFE_MOVE_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/safe-move/safe-move.log}
FLAGS=${SAFE_MOVE_RSYNC_FLAGS:--aHAX}
TMP=
STAGE=start

log()  { mkdir -p -- "$(dirname -- "$LOG")" 2>/dev/null || true
         printf '%s %s pid=%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$PROG" "$$" "$*" >>"$LOG" 2>/dev/null || true; }
say()  { printf '%s\n' "$*"; }
die()  { code=$1; shift; printf '%s: %s\n' "$PROG" "$*" >&2; log "ABORT stage=$STAGE code=$code $*"; exit "$code"; }

cleanup() {
  rc=$?
  [ -n "$TMP" ] && [ -d "$TMP" ] && { rm -f -- "$TMP"/*.list "$TMP"/*.sha "$TMP"/*.out 2>/dev/null || true; rmdir -- "$TMP" 2>/dev/null || true; }
  if [ "$rc" -ne 0 ]; then
    printf '%s: stopped at stage "%s" (exit %s). Source was NOT removed.\n' "$PROG" "$STAGE" "$rc" >&2
    case $STAGE in
      copy|verify) printf '%s: a partial/unverified copy may exist at %s - inspect it, nothing was deleted.\n' "$PROG" "${TARGET:-?}" >&2 ;;
    esac
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# ---- arguments ---------------------------------------------------------------
while [ $# -gt 0 ]; do
  case $1 in
    -n|--dry-run)  DRY=1 ;;
    -y|--yes)      YES=1 ;;
    -k|--keep-source) KEEP=1 ;;
    -l|--log)      [ $# -ge 2 ] || usage; LOG=$2; shift ;;
    -h|--help)     usage ;;
    --)            shift; break ;;
    -*)            die 1 "unknown option: $1" ;;
    *)             break ;;
  esac
  shift
done
[ $# -eq 2 ] || usage
SRC_IN=$1 DEST_IN=$2
[ -n "$SRC_IN" ]  || die 1 "SRC is empty"
[ -n "$DEST_IN" ] || die 1 "DEST_DIR is empty"

# ---- 1. PREFLIGHT (read-only) -----------------------------------------------
STAGE=preflight
[ -e "$SRC_IN" ] || [ -L "$SRC_IN" ] || die 2 "source does not exist: $SRC_IN"
[ -d "$DEST_IN" ] || die 2 "destination directory does not exist: $DEST_IN"
[ -w "$DEST_IN" ] || die 2 "destination directory is not writable: $DEST_IN"
[ -L "$SRC_IN" ] && die 2 "source is a symlink; pass the real path (this tool will not guess)"

DEST=$(cd -- "$DEST_IN" && pwd -P)
if [ -d "$SRC_IN" ]; then
  SRC=$(cd -- "$SRC_IN" && pwd -P); KIND="dir"
else
  SRC_PARENT=$(cd -- "$(dirname -- "$SRC_IN")" && pwd -P)
  SRC="$SRC_PARENT/$(basename -- "$SRC_IN")"; KIND="file"
fi
NAME=$(basename -- "$SRC")
TARGET=$DEST/$NAME
HOME_REAL=$(cd -- "$HOME" && pwd -P)

[ "$SRC" != / ]               || die 1 "refusing to move /"
[ "$SRC" != "$HOME_REAL" ]    || die 1 "refusing to move your entire home directory ($HOME_REAL)"
[ "$SRC" != "$DEST" ]         || die 1 "source and destination are the same"
[ "$SRC" != "$TARGET" ]       || die 1 "source and target are the same path"
case $DEST/ in "$SRC"/*) die 1 "destination is inside the source" ;; esac
case $HOME_REAL/ in "$SRC"/*) die 1 "source contains your home directory" ;; esac
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then die 2 "target already exists: $TARGET (refusing to merge; pick another DEST_DIR)"; fi
[ -r "$SRC" ] || die 2 "source is not readable"
command -v rsync >/dev/null 2>&1 || die 2 "rsync not found (Alpine: apk add rsync)"
command -v sha256sum >/dev/null 2>&1 || die 2 "sha256sum not found"
if [ "$KIND" = dir ]; then
  # unreadable entries would make the copy silently incomplete: look for them now
  UNREAD=$(find "$SRC" ! -readable -print 2>/dev/null | head -n 3 || true)
  [ -z "$UNREAD" ] || die 2 "unreadable entries inside source, e.g. $UNREAD"
fi

need_kb=$(du -sk -- "$SRC" | awk '{print $1}')
free_kb=$(df -Pk -- "$DEST" | awk 'NR==2{print $4}')
[ "$free_kb" -gt "$need_kb" ] || die 2 "not enough free space: need ${need_kb} KiB, have ${free_kb} KiB"

say "PREFLIGHT ok"
say "  source : $SRC ($KIND, ${need_kb} KiB)"
say "  target : $TARGET (free: ${free_kb} KiB)"
log "start src=$SRC target=$TARGET flags=$FLAGS"

# ---- 2. DRY-RUN (read-only) ---------------------------------------------------
STAGE=dry-run
TMP=$(mktemp -d "${TMPDIR:-/tmp}/safe-move.XXXXXX")
if [ "$KIND" = dir ]; then RS_SRC="$SRC/" RS_DST="$TARGET/"; else RS_SRC=$SRC RS_DST=$TARGET; fi
say; say "DRY-RUN (nothing written yet):"
# shellcheck disable=SC2086  # FLAGS is intentionally word-split
rsync $FLAGS -n --itemize-changes -- "$RS_SRC" "$RS_DST" >"$TMP/dry.out" 2>&1 || die 2 "rsync dry-run failed (see output above); try SAFE_MOVE_RSYNC_FLAGS=-aH for FAT/NTFS targets"
grep -v '^created directory' "$TMP/dry.out" | head -n 20 || true
total=$(grep -vc '^created directory' "$TMP/dry.out" || true)
[ "$total" -le 20 ] || say "  ... $((total - 20)) more lines"
say "  $total item(s) would be created"
[ "$DRY" -eq 0 ] || { say; say "--dry-run: stopping here. Nothing was changed."; log "dry-run only"; exit 0; }

# ---- 3. CONFIRM --------------------------------------------------------------
STAGE=confirm
if [ "$YES" -eq 0 ]; then
  printf '\nCopy, verify, then move the source to the trash? Type yes to continue: '
  read -r ans || ans=
  [ "$ans" = yes ] || { say "not confirmed."; log "declined by user"; exit 130; }
fi

# ---- 4. COPY ------------------------------------------------------------------
STAGE=copy
say; say "COPY:"
# shellcheck disable=SC2086
rsync $FLAGS -h --info=progress2 -- "$RS_SRC" "$RS_DST" || die 3 "rsync copy failed (exit $?)"
log "copy done"

# ---- 5. VERIFY (never skipped, not even with --yes) -----------------------------
STAGE=verify
say; say "VERIFY:"
manifest() {  # $1=root  $2=outfile ; sorted, NUL-safe, relative paths
  if [ -d "$1" ]; then
    ( cd -- "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum ) >"$2"
  else
    ( cd -- "$(dirname -- "$1")" && sha256sum -- "./$(basename -- "$1")" ) >"$2"
  fi
}
paths() {     # every path (files, dirs, symlinks), NUL-separated, sorted
  if [ -d "$1" ]; then ( cd -- "$1" && find . -print0 | sort -z ) >"$2"; else printf './%s\0' "$(basename -- "$1")" >"$2"; fi
}
ok=1
# (a) rsync checksum compare: any output line means a difference
# shellcheck disable=SC2086
rsync $FLAGS -n -c --itemize-changes -- "$RS_SRC" "$RS_DST" >"$TMP/rsverify.out" 2>&1 || ok=0
if [ -s "$TMP/rsverify.out" ]; then ok=0; say "  FAIL  rsync -c reports differences:"; head -n 10 "$TMP/rsverify.out"; else say "  ok    rsync -n -c: no differences"; fi
# (b) same set of paths
paths "$SRC" "$TMP/src.list"; paths "$TARGET" "$TMP/dst.list"
if cmp -s "$TMP/src.list" "$TMP/dst.list"; then say "  ok    path lists identical"; else ok=0; say "  FAIL  path lists differ"; fi
# (c) independent SHA-256 manifests
manifest "$SRC" "$TMP/src.sha"; manifest "$TARGET" "$TMP/dst.sha"
nfiles=$(wc -l <"$TMP/src.sha" | tr -d ' ')
if cmp -s "$TMP/src.sha" "$TMP/dst.sha"; then say "  ok    sha256 manifests identical ($nfiles files)"; else ok=0; say "  FAIL  sha256 manifests differ:"; diff "$TMP/src.sha" "$TMP/dst.sha" | head -n 10 || true; fi

if [ "$ok" -ne 1 ]; then
  log "VERIFY FAILED target=$TARGET — source kept"
  die 4 "VERIFY FAILED. Source left untouched at $SRC. Bad copy left at $TARGET for inspection."
fi
MAN_DIR=$(dirname -- "$LOG"); mkdir -p -- "$MAN_DIR" 2>/dev/null || true
MAN_FILE=$MAN_DIR/manifest-$(date +%Y%m%d-%H%M%S)-$$.sha256
cp -- "$TMP/src.sha" "$MAN_FILE" 2>/dev/null || MAN_FILE="(not saved)"
log "verify ok files=$nfiles manifest=$MAN_FILE"

# ---- 6. REMOVE ORIGINAL — recoverably ------------------------------------------
STAGE=trash
if [ "$KEEP" -eq 1 ]; then
  say; say "--keep-source: verified copy made, source left in place."; log "kept source"; exit 0
fi
say; say "TRASH SOURCE:"
trash_source() {
  if command -v trash-put >/dev/null 2>&1; then trash-put -- "$SRC" && { say "  moved to trash with trash-put"; return 0; }; fi
  if command -v gio >/dev/null 2>&1; then gio trash -- "$SRC" 2>/dev/null && { say "  moved to trash with gio trash"; return 0; }; fi
  # last resort: same-filesystem quarantine (rename, no data copy, never rm)
  q=$(dirname -- "$SRC")/${SAFE_MOVE_TRASH_DIR:-.safe-move-trash}
  mkdir -p -- "$q" && mv -- "$SRC" "$q/$(date +%Y%m%d-%H%M%S)-$NAME" && { say "  quarantined in $q (install trash-cli for a real trash)"; return 0; }
  return 1
}
trash_source || die 5 "copy verified but the source could not be trashed; it is still at $SRC"
log "source trashed src=$SRC"

# ---- 7. LOG ------------------------------------------------------------------
STAGE=finished
say; say "DONE. Verified copy: $TARGET"
say "Log: $LOG"
say "Manifest: $MAN_FILE"
