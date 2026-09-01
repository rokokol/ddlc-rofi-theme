#!/usr/bin/env bash
# The fast suite for install.sh: flag surface, the manifest contract, the declarative
# sweep, staging, and the refusal path — everything that needs no container.
# tests/run.sh drives the switch; tests/distro.sh covers what a real distribution
# provides; this covers what the installer promises
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO="${1:-$(dirname "$HERE")}"

fails=0
say() { printf -- '-- %s\n' "$1"; }
die() {
  printf '!! %s\n' "$1" >&2
  fails=$((fails + 1))
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

prefix="$tmp/prefix"
manifest="$prefix/share/ddlc-rofi-theme/install-manifest"
run() { "$REPO/install.sh" --prefix "$prefix" "$@"; }

say "--help names every flag the case parses, and -v matches VERSION"
mapfile -t flags < <(
  sed -n 's/^ *\(-[-a-zA-Z0-9 |]*\))$/\1/p' "$REPO/install.sh" |
    tr '|' '\n' | tr -d ' ' | sort -u
)
((${#flags[@]})) || die "found no flags in install.sh — the extractor is broken"
help_out=$("$REPO/install.sh" --help)
for flag in "${flags[@]}"; do
  grep -qF -- "$flag" <<<"$help_out" || die "--help does not mention $flag"
done
[[ "$("$REPO/install.sh" -v)" == "ddlc-rofi-theme $(cat "$REPO/VERSION")" ]] ||
  die "-v does not print 'ddlc-rofi-theme \$(cat VERSION)'"

say "bad arguments are refused"
if run --prefix relative/path >/dev/null 2>&1; then die "a relative PREFIX was accepted"; fi
if run --no-such-flag >/dev/null 2>&1; then die "an unknown flag was accepted"; fi

say "an install lands the theme, the switch and the manifest"
run >/dev/null 2>&1
[[ -f "$prefix/share/rofi/themes/ddlc-light.rasi" ]] || die "light variant missing"
[[ -f "$prefix/share/rofi/themes/ddlc-dark.rasi" ]] || die "dark variant missing"
[[ -f "$prefix/share/rofi/themes/ddlc-polka-light.svg" ]] || die "light background missing"
[[ -f "$prefix/share/rofi/themes/ddlc-polka-dark.svg" ]] || die "dark background missing"
[[ -x "$prefix/bin/ddlc-rofi-theme" ]] || die "switch missing from bin"
[[ ! -L "$prefix/bin/ddlc-rofi-theme" ]] ||
  die "the switch is a symlink — it must be a copy to find the theme from its location"
[[ -f "$manifest" ]] || die "no manifest after install"
[[ -f "$prefix/share/ddlc-rofi-theme/VERSION" ]] || die "no installed VERSION copy"

say "the installed switch finds the installed theme with nothing set"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" "$prefix/bin/ddlc-rofi-theme" dark ||
  die "the switch failed against its own install"
[[ "$(readlink "$tmp/home/.config/rofi/themes/ddlc.rasi")" == "$prefix/share/rofi/themes/ddlc-dark.rasi" ]] ||
  die "the switch linked the wrong variant"

say "re-running sweeps a stale path the previous install wrote"
stale="$prefix/share/rofi/themes/ddlc-old.rasi"
touch "$stale"
echo "$stale" >>"$manifest"
run >/dev/null 2>&1
[[ ! -e "$stale" ]] || die "the sweep left a stale file behind"
if grep -qF "ddlc-old" "$manifest"; then die "manifest still lists the stale file"; fi

say "--uninstall takes everything out and is idempotent"
run --uninstall >/dev/null
[[ ! -e "$prefix/share/ddlc-rofi-theme" ]] || die "uninstall left the share dir"
[[ ! -e "$prefix/share/rofi" ]] || die "uninstall left the theme files"
[[ ! -e "$prefix/bin/ddlc-rofi-theme" ]] || die "uninstall left the switch"
out=$(run --uninstall)
[[ "$out" == *"nothing to uninstall"* ]] || die "a second uninstall was not quiet: $out"

say "a pre-manifest install is still uninstallable (fallback layout)"
install -D -m644 "$REPO/dist/ddlc-light.rasi" "$prefix/share/rofi/themes/ddlc-light.rasi"
install -D -m755 "$REPO/ddlc-rofi-theme.sh" "$prefix/bin/ddlc-rofi-theme"
run --uninstall >/dev/null
[[ ! -e "$prefix/share/rofi" && ! -e "$prefix/bin/ddlc-rofi-theme" ]] ||
  die "legacy uninstall missed the pre-manifest layout"

say "DESTDIR stages the tree and the manifest records runtime paths"
stage="$tmp/stage"
run --destdir "$stage" >/dev/null 2>&1
[[ -f "$stage$prefix/share/rofi/themes/ddlc-light.rasi" ]] || die "staged file not under DESTDIR"
staged_manifest="$stage$prefix/share/ddlc-rofi-theme/install-manifest"
[[ -f "$staged_manifest" ]] || die "no staged manifest"
if grep -v '^#' "$staged_manifest" | grep -qF "$stage"; then
  die "the staged manifest leaks DESTDIR into a recorded path"
fi

say "the preflight refuses completely when an install dep is missing"
stub="$tmp/bin"
mkdir -p "$stub"
for tool in bash cat dirname readlink sed tr grep rm rmdir; do
  ln -s "$(command -v "$tool")" "$stub/$tool"
done
echo "ID=debian" >"$tmp/os-release" # the flake-check sandbox has no /etc/os-release
rc=0
out=$(OS_RELEASE="$tmp/os-release" PATH="$stub" bash "$REPO/install.sh" \
  --prefix "$tmp/refused" 2>&1) || rc=$?
((rc != 0)) || die "the preflight accepted a system without install(1)"
grep -q 'missing dependencies' <<<"$out" || die "the refusal did not say what is missing"
grep -q ' - install$' <<<"$out" || die "the refusal did not name install(1)"
grep -qE '^  \$ ' <<<"$out" || die "the refusal printed no runnable guidance"
[[ ! -e "$tmp/refused" ]] || die "a refused install wrote files"

say "the guidance is per-distro and printed as runnable lines"
for pair in "debian:  \$ sudo apt install coreutils" \
  "ubuntu:  \$ sudo apt install coreutils" \
  "arch:  \$ sudo pacman -S --needed coreutils" \
  "fedora:  \$ sudo dnf install coreutils"; do
  id="${pair%%:*}"
  line="${pair#*:}"
  echo "ID=$id" >"$tmp/os-release"
  out=$(OS_RELEASE="$tmp/os-release" PATH="$stub" bash "$REPO/install.sh" \
    --prefix "$tmp/refused" 2>&1) || true
  grep -qxF "$line" <<<"$out" || die "no '$line' in the $id refusal"
done

say "install.sh and its completions agree"
bash "$HERE/check-completions.sh" "$REPO" >/dev/null || die "completions drift"

echo
if ((fails)); then
  echo "$fails failure(s)"
  exit 1
fi
echo "all install.sh checks passed"
