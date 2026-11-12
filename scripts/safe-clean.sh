#!/bin/sh
# safe-clean.sh — preview-first system cleaning wrapper. Detects your distro family and
# shows what each cleaning step WOULD do. Nothing is changed unless you pass --apply,
# and even then every step asks first. Needs root only for the steps that say so.
#
# Usage: safe-clean.sh [--apply] [--family apt|dnf|pacman|zypper|apk]
# Exit:  0 ok | 1 usage | 2 unknown distro family
# Deliberately NOT automated here (review by hand): autoremove/orphans, old kernels,
# docker/podman prune, ~/.cache, deleting logs outside journald vacuum.
set -eu

APPLY=0 FAMILY=
while [ $# -gt 0 ]; do
  case $1 in
    --apply)  APPLY=1 ;;
    --family) [ $# -ge 2 ] || { echo "--family needs a value" >&2; exit 1; }; FAMILY=$2; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

detect() {
  [ -r /etc/os-release ] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  for id in ${ID:-} ${ID_LIKE:-}; do
    case $id in
      debian|ubuntu|linuxmint) echo apt; return 0 ;;
      fedora|rhel|centos|rocky|almalinux) echo dnf; return 0 ;;
      arch|manjaro|endeavouros) echo pacman; return 0 ;;
      opensuse*|suse|sles) echo zypper; return 0 ;;
      alpine) echo apk; return 0 ;;
    esac
  done
  return 1
}
[ -n "$FAMILY" ] || FAMILY=$(detect) || { echo "could not detect distro family; use --family" >&2; exit 2; }
echo "family: $FAMILY   mode: $([ "$APPLY" -eq 1 ] && echo APPLY-with-confirmation || echo PREVIEW-only)"

have() { command -v "$1" >/dev/null 2>&1; }
SUDO=; [ "$(id -u)" -eq 0 ] || { have sudo && SUDO=sudo; }

# step LABEL RISK PREVIEW_CMD APPLY_CMD
step() {
  label=$1 risk=$2 preview=$3 action=$4
  printf '\n== %s  [%s]\n' "$label" "$risk"
  printf '   preview: %s\n' "$preview"
  sh -c "$preview" 2>&1 | head -n 25 || true
  [ "$APPLY" -eq 1 ] || return 0
  [ -n "$action" ] || { echo "   (no automated action for this step)"; return 0; }
  printf '   run: %s\n   Type yes to run it: ' "$action"
  read -r ans || ans=
  if [ "$ans" = yes ]; then sh -c "$action" || echo "   step failed (exit $?)"; else echo "   skipped"; fi
}

case $FAMILY in
  apt)
    step "apt download cache" "🟡 safe to automate" "du -sh /var/cache/apt/archives 2>/dev/null" "$SUDO apt-get clean"
    step "unneeded packages (review!)" "🔴 review by hand" "apt-get -s autoremove" "" ;;
  dnf)
    step "dnf cache" "🟡 safe to automate" "du -sh /var/cache/libdnf5 /var/cache/dnf 2>/dev/null" "$SUDO dnf clean all"
    step "unneeded packages (review!)" "🔴 review by hand" "dnf autoremove --assumeno" "" ;;
  pacman)
    step "pacman cache (keeps 3 versions per package)" "🟡 safe to automate" "paccache -d" "$SUDO paccache -r"
    step "orphans (review!)" "🔴 review by hand" "pacman -Qtdq" "" ;;
  zypper)
    step "zypper cache" "🟡 safe to automate" "du -sh /var/cache/zypp 2>/dev/null" "$SUDO zypper clean"
    step "unneeded packages (review!)" "🔴 review by hand" "zypper packages --unneeded" "" ;;
  apk)
    step "apk cache" "🟡 safe to automate" "du -sh /var/cache/apk 2>/dev/null" "$SUDO apk cache clean" ;;
  *) echo "unsupported family: $FAMILY" >&2; exit 2 ;;
esac

if have journalctl; then
  step "systemd journal (keeps 2 weeks)" "🔴 old logs are gone for good" "journalctl --disk-usage" "$SUDO journalctl --vacuum-time=2weeks"
fi
if have flatpak; then
  step "unused flatpak runtimes" "🟡 review list first" "flatpak uninstall --unused --assumeno" "flatpak uninstall --unused"
fi
step "user cache size (never auto-deleted)" "🟢 read-only" "du -sh \"\${XDG_CACHE_HOME:-\$HOME/.cache}\" 2>/dev/null" ""
echo; echo "done. Preview only unless --apply was given."
