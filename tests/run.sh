#!/usr/bin/env bash
# Drives the switch against a throwaway config tree. Both HOME and XDG_CONFIG_HOME are
# redirected: a session that exports XDG_CONFIG_HOME would otherwise take the test
# straight into the live rofi config
#
#   tests/run.sh   check the switch

set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname "$HERE")
SWITCH="${DDLC_ROFI_THEME:-$REPO/ddlc-rofi-theme.sh}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$WORK/home/.config"
THEMES="$XDG_CONFIG_HOME/rofi/themes"
PACKAGED="$WORK/packaged"
export DDLC_ROFI_THEME_DIR="$PACKAGED"

mkdir -p "$THEMES" "$PACKAGED"
printf 'packaged light\n' >"$PACKAGED/ddlc-light.rasi"
printf 'packaged dark\n' >"$PACKAGED/ddlc-dark.rasi"

fails=0

ok() { printf '  ✓ %s\n' "$1"; }

fail() {
  printf '  ✗ %s\n' "$1"
  fails=$((fails + 1))
}

# Compares against a full path rather than a name, so a variant picked out of the wrong
# directory shows up as one
links() {
  local want="$2" got
  got="$(readlink "$THEMES/${3:-ddlc}.rasi" || true)"
  if [[ "$got" == "$want" ]]; then ok "$1"; else fail "$1: $got"; fi
}

says() {
  local want="$2" got
  got="$("$SWITCH" status)"
  if [[ "$got" == "$want" ]]; then ok "$1"; else fail "$1: $got"; fi
}

refuses() {
  if "$SWITCH" "${@:2}" >/dev/null 2>&1; then fail "$1"; else ok "$1"; fi
}

echo "switching"

"$SWITCH" light
links "light points at the light variant" "$PACKAGED/ddlc-light.rasi"

"$SWITCH" dark
links "dark repoints the same link" "$PACKAGED/ddlc-dark.rasi"

"$SWITCH" toggle
links "toggle comes back from dark" "$PACKAGED/ddlc-light.rasi"

"$SWITCH" toggle
links "toggle goes the other way too" "$PACKAGED/ddlc-dark.rasi"

echo "status"

says "status names the live variant" dark

ln -sfn /nowhere/else.rasi "$THEMES/ddlc.rasi"
says "a foreign target is unknown, not a variant" unknown

rm "$THEMES/ddlc.rasi"
says "no link, no variant" none

echo "deployed variants win"

# The whole point of the preference: a link into a Nix store path dangles after the next
# garbage collection, so a copy sitting next to the link has to be chosen over it
printf 'deployed light\n' >"$THEMES/ddlc-light.rasi"
printf 'deployed dark\n' >"$THEMES/ddlc-dark.rasi"
"$SWITCH" light
links "a variant next to the link beats the packaged one" "$THEMES/ddlc-light.rasi"
rm "$THEMES/ddlc-light.rasi" "$THEMES/ddlc-dark.rasi"

echo "naming"

DDLC_ROFI_THEME_NAME=doki refuses "an unknown name fails instead of linking to nothing" light

printf 'packaged light\n' >"$PACKAGED/doki-light.rasi"
DDLC_ROFI_THEME_NAME=doki "$SWITCH" light
links "the name reaches both the link and the variant" "$PACKAGED/doki-light.rasi" doki

echo "refusals"

# rm first: the link is still there from the run above, and a redirection through it
# would write the variant it points at instead of the file the check is about
rm -f "$THEMES/ddlc.rasi"
printf 'a theme of my own\n' >"$THEMES/ddlc.rasi"
refuses "a real file at the link path is not overwritten" light
if [[ "$(cat "$THEMES/ddlc.rasi")" == "a theme of my own" ]]; then
  ok "…and is left as it was"
else
  fail "the real file was clobbered anyway"
fi
rm "$THEMES/ddlc.rasi"

refuses "an unknown command fails" nonsense
refuses "no argument is a usage error"

echo "usage"

if "$SWITCH" --help | grep -q DDLC_ROFI_THEME_DIR; then
  ok "--help names the settings"
else
  fail "--help: the settings are undocumented"
fi

if ((fails)); then
  printf '\n%d failed\n' "$fails"
  exit 1
fi
printf '\nall passed\n'
