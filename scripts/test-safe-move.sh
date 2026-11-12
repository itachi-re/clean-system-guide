#!/bin/sh
# test-safe-move.sh — self-test for safe-move.sh. Uses ONLY a throw-away temp dir and a fake HOME.
# Proves: (1) a good move succeeds and trashes the source, (2) a silently corrupted copy
# (same size, same mtime) is caught and the source is NOT removed, (3) dangerous arguments are refused.
set -eu
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
SM="$HERE/safe-move.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/sm-test.XXXXXX")
trap 'rm -rf -- "${T:?}"' EXIT
export HOME="$T/home" XDG_DATA_HOME="$T/home/share" XDG_STATE_HOME="$T/home/state"
mkdir -p "$HOME" "$T/a" "$T/b" "$T/fakebin"
fail=0
check() { if [ "$1" = "$2" ]; then echo "PASS $3"; else echo "FAIL $3 (got $1, want $2)"; fail=1; fi; }

mk() { rm -rf -- "$T/a/notes"; mkdir -p "$T/a/notes/sub"; printf 'alpha\n' >"$T/a/notes/one.txt"; printf 'beta\n' >"$T/a/notes/sub/two.txt"; }

# 1. good move
mk; rm -rf -- "${T:?}/b/notes"
sh "$SM" -y "$T/a/notes" "$T/b" >/dev/null 2>&1; rc=$?
check "$rc" 0 "good move exits 0"
check "$([ -e "$T/a/notes" ] && echo kept || echo gone)" gone "good move: source gone (trashed)"
check "$(cat "$T/b/notes/sub/two.txt")" beta "good move: content arrived"

# 2. corrupted copy: fake rsync does the real copy, then flips bytes keeping size+mtime
REAL=$(command -v rsync)
cat >"$T/fakebin/rsync" <<EOS
#!/bin/sh
"$REAL" "\$@"; rc=\$?
case " \$* " in *" -n "*|*" --dry-run "*|*" -aHAXn "*) exit \$rc ;; esac
f=\$(find "$T/b/notes" -name two.txt 2>/dev/null | head -n 1)
if [ -n "\$f" ]; then touch -r "\$f" "$T/ref"; printf 'XXXX' | dd of="\$f" conv=notrunc 2>/dev/null; touch -r "$T/ref" "\$f"; fi
exit \$rc
EOS
chmod +x "$T/fakebin/rsync"
mk; rm -rf -- "${T:?}/b/notes"
set +e; PATH="$T/fakebin:$PATH" sh "$SM" -y "$T/a/notes" "$T/b" >"$T/out2.txt" 2>&1; rc=$?; set -e
check "$rc" 4 "corrupted copy: exit code 4"
check "$([ -f "$T/a/notes/sub/two.txt" ] && echo kept || echo gone)" kept "corrupted copy: SOURCE KEPT"
if grep -q 'VERIFY FAILED' "$T/out2.txt"; then echo "PASS corrupted copy: failure reported"; else echo "FAIL no failure message"; fail=1; fi

# 3. refusals
for bad in "/ $T/b" "$HOME $T/b" "$T/a $T/a" "'' $T/b"; do
  set +e; eval sh "$SM" -y "$bad" >/dev/null 2>&1; rc=$?; set -e
  check "$rc" 1 "refuses: $bad"
done
if [ "$fail" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; exit 1; fi
