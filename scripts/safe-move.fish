#!/usr/bin/env fish
# safe-move.fish — native fish port of safe-move.sh (same pipeline, same exit codes).
#   PREFLIGHT -> DRY-RUN -> CONFIRM -> COPY -> VERIFY -> TRASH SOURCE -> LOG
# fish has no `set -e`, so every step checks $status explicitly and stops with `return`.
# Needs: rsync, find, sort, xargs, sha256sum, cmp, df, du (and trash-put or gio for a real trash).
#
# Usage: safe-move.fish [-n|--dry-run] [-y|--yes] [-k|--keep-source] SRC DEST_DIR
# Env:   SAFE_MOVE_RSYNC_FLAGS (default "-aHAX"; use "-aH" for FAT/exFAT/NTFS), SAFE_MOVE_LOG
# Exit:  0 ok | 1 usage/refused | 2 preflight failed | 3 copy failed | 4 verify FAILED (source untouched)
#        5 could not trash source | 130 not confirmed

function __sm_log
    set -l f $argv[1]
    mkdir -p (dirname -- $f) 2>/dev/null
    printf '%s safe-move.fish pid=%s %s\n' (date '+%Y-%m-%dT%H:%M:%S%z') $fish_pid "$argv[2..-1]" >>$f 2>/dev/null
end

function __sm_manifest --argument-names root out
    if test -d $root
        pushd $root >/dev/null; or return 1
        find . -type f -print0 | sort -z | xargs -0 sha256sum >$out
        set -l rc $pipestatus[-1]
        popd >/dev/null
        return $rc
    else
        pushd (dirname -- $root) >/dev/null; or return 1
        sha256sum -- ./(basename -- $root) >$out
        set -l rc $status
        popd >/dev/null
        return $rc
    end
end

function __sm_paths --argument-names root out
    if test -d $root
        pushd $root >/dev/null; or return 1
        find . -print0 | sort -z >$out
        popd >/dev/null
    else
        printf './%s\0' (basename -- $root) >$out
    end
end

function safe_move
    set -l dry 0
    set -l yes 0
    set -l keep 0
    set -l args
    for a in $argv
        switch $a
            case -n --dry-run
                set dry 1
            case -y --yes
                set yes 1
            case -k --keep-source
                set keep 1
            case '-*'
                echo "safe-move: unknown option: $a" >&2
                return 1
            case '*'
                set -a args $a
        end
    end
    test (count $args) -eq 2; or begin
        echo "usage: safe-move.fish [-n] [-y] [-k] SRC DEST_DIR" >&2
        return 1
    end
    set -l src_in $args[1]
    set -l dest_in $args[2]
    test -n "$src_in"; or begin; echo "safe-move: SRC is empty" >&2; return 1; end
    test -n "$dest_in"; or begin; echo "safe-move: DEST_DIR is empty" >&2; return 1; end

    set -l flags -aHAX
    set -q SAFE_MOVE_RSYNC_FLAGS; and set flags (string split ' ' -- $SAFE_MOVE_RSYNC_FLAGS)
    set -l state (test -n "$XDG_STATE_HOME"; and echo $XDG_STATE_HOME; or echo $HOME/.local/state)
    set -l logf $state/safe-move/safe-move.log
    set -q SAFE_MOVE_LOG; and set logf $SAFE_MOVE_LOG

    # ---- 1. PREFLIGHT ----
    test -e $src_in -o -L $src_in; or begin; echo "safe-move: source does not exist: $src_in" >&2; return 2; end
    test -d $dest_in; or begin; echo "safe-move: destination directory does not exist: $dest_in" >&2; return 2; end
    test -w $dest_in; or begin; echo "safe-move: destination not writable: $dest_in" >&2; return 2; end
    test -L $src_in; and begin; echo "safe-move: source is a symlink; pass the real path" >&2; return 2; end
    command -q rsync; or begin; echo "safe-move: rsync not found" >&2; return 2; end
    command -q sha256sum; or begin; echo "safe-move: sha256sum not found" >&2; return 2; end

    set -l dest (builtin realpath -- $dest_in)
    set -l src (builtin realpath -- $src_in)
    set -l kind file
    test -d $src; and set kind dir
    set -l name (basename -- $src)
    set -l target $dest/$name
    set -l home_real (builtin realpath -- $HOME)

    test "$src" != /; or begin; echo "safe-move: refusing to move /" >&2; return 1; end
    test "$src" != "$home_real"; or begin; echo "safe-move: refusing to move your entire home directory" >&2; return 1; end
    test "$src" != "$dest"; or begin; echo "safe-move: source and destination are the same" >&2; return 1; end
    test "$src" != "$target"; or begin; echo "safe-move: source and target are the same path" >&2; return 1; end
    string match -q -- "$src/*" "$dest/"; and begin; echo "safe-move: destination is inside the source" >&2; return 1; end
    string match -q -- "$src/*" "$home_real/"; and begin; echo "safe-move: source contains your home directory" >&2; return 1; end
    if test -e $target -o -L $target
        echo "safe-move: target already exists: $target (refusing to merge)" >&2
        return 2
    end
    if test $kind = dir
        set -l unread (find $src ! -readable -print 2>/dev/null | head -n 3)
        test -z "$unread"; or begin; echo "safe-move: unreadable entries inside source: $unread[1]" >&2; return 2; end
    end
    set -l need_kb (du -sk -- $src | awk '{print $1}')
    set -l free_kb (df -Pk -- $dest | awk 'NR==2{print $4}')
    test $free_kb -gt $need_kb; or begin; echo "safe-move: not enough free space ($need_kb KiB needed, $free_kb free)" >&2; return 2; end
    echo "PREFLIGHT ok"
    echo "  source : $src ($kind, $need_kb KiB)"
    echo "  target : $target (free: $free_kb KiB)"
    __sm_log $logf "start src=$src target=$target"

    # ---- 2. DRY-RUN ----
    set -l tmp (mktemp -d)
    set -l rs_src $src
    set -l rs_dst $target
    if test $kind = dir
        set rs_src $src/
        set rs_dst $target/
    end
    echo; echo "DRY-RUN (nothing written yet):"
    rsync $flags -n --itemize-changes -- $rs_src $rs_dst >$tmp/dry.out 2>&1
    or begin; cat $tmp/dry.out >&2; echo "safe-move: rsync dry-run failed (FAT/NTFS target? try SAFE_MOVE_RSYNC_FLAGS=-aH)" >&2; return 2; end
    set -l items (string match -v 'created directory*' < $tmp/dry.out)
    printf '%s\n' $items[1..20]
    echo "  "(count $items)" item(s) would be created"
    if test $dry -eq 1
        echo; echo "--dry-run: stopping here. Nothing was changed."
        return 0
    end

    # ---- 3. CONFIRM ----
    if test $yes -eq 0
        read -l -P 'Copy, verify, then move the source to the trash? Type yes to continue: ' ans
        test "$ans" = yes; or begin; echo "not confirmed."; return 130; end
    end

    # ---- 4. COPY ----
    echo; echo "COPY:"
    rsync $flags -h --info=progress2 -- $rs_src $rs_dst
    or begin; echo "safe-move: rsync copy failed. Source untouched; partial copy may be at $target" >&2; return 3; end

    # ---- 5. VERIFY (never skipped) ----
    echo; echo "VERIFY:"
    set -l ok 1
    rsync $flags -n -c --itemize-changes -- $rs_src $rs_dst >$tmp/rsverify.out 2>&1; or set ok 0
    if test -s $tmp/rsverify.out
        set ok 0
        echo "  FAIL  rsync -c reports differences:"; head -n 10 $tmp/rsverify.out
    else
        echo "  ok    rsync -n -c: no differences"
    end
    __sm_paths $src $tmp/src.list; __sm_paths $target $tmp/dst.list
    if cmp -s $tmp/src.list $tmp/dst.list
        echo "  ok    path lists identical"
    else
        set ok 0; echo "  FAIL  path lists differ"
    end
    __sm_manifest $src $tmp/src.sha; __sm_manifest $target $tmp/dst.sha
    if cmp -s $tmp/src.sha $tmp/dst.sha
        echo "  ok    sha256 manifests identical ("(count (cat $tmp/src.sha))" files)"
    else
        set ok 0; echo "  FAIL  sha256 manifests differ"; diff $tmp/src.sha $tmp/dst.sha | head -n 10
    end
    if test $ok -ne 1
        __sm_log $logf "VERIFY FAILED target=$target - source kept"
        echo "safe-move: VERIFY FAILED. Source left untouched at $src. Bad copy left at $target." >&2
        return 4
    end
    set -l manf (dirname -- $logf)/manifest-(date +%Y%m%d-%H%M%S)-$fish_pid.sha256
    mkdir -p (dirname -- $logf); cp -- $tmp/src.sha $manf
    __sm_log $logf "verify ok manifest=$manf"

    # ---- 6. REMOVE ORIGINAL (recoverably) ----
    if test $keep -eq 1
        echo; echo "--keep-source: verified copy made, source left in place."
        return 0
    end
    echo; echo "TRASH SOURCE:"
    set -l done_trash 0
    if command -q trash-put
        trash-put -- $src; and set done_trash 1; and echo "  moved to trash with trash-put"
    end
    if test $done_trash -eq 0; and command -q gio
        gio trash -- $src 2>/dev/null; and set done_trash 1; and echo "  moved to trash with gio trash"
    end
    if test $done_trash -eq 0
        set -l q (dirname -- $src)/.safe-move-trash
        mkdir -p -- $q; and mv -- $src $q/(date +%Y%m%d-%H%M%S)-$name; and set done_trash 1; and echo "  quarantined in $q"
    end
    test $done_trash -eq 1; or begin; echo "safe-move: copy verified but source could not be trashed; still at $src" >&2; return 5; end
    __sm_log $logf "source trashed src=$src"

    # ---- 7. LOG ----
    echo; echo "DONE. Verified copy: $target"; echo "Log: $logf"
end

safe_move $argv
exit $status
