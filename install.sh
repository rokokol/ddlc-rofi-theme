#!/usr/bin/env bash

set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"

usage() {
  cat <<EOF
install.sh — install the DDLC rofi theme

  PREFIX=$PREFIX (override with PREFIX=... or --prefix DIR)

The rendered theme goes to \$PREFIX/share/rofi/themes and the switch to \$PREFIX/bin.
rofi searches that share directory itself, so the backgrounds resolve by name and
nothing has to be pathed

Then name the theme in your rofi config and pick a variant:

  rofi.theme: ddlc          in ~/.config/rofi/config.rasi
  ddlc-rofi-theme light
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="${2:?directory required}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
themes="$PREFIX/share/rofi/themes"

install -d "$themes"
install -m644 "$here"/dist/*.rasi "$here"/dist/*.svg "$themes"

# A copy rather than a symlink: the switch finds the theme relative to its own location,
# and a symlink in bin would put it one directory off
install -Dm755 "$here/ddlc-rofi-theme.sh" "$PREFIX/bin/ddlc-rofi-theme"

echo "installed to $themes, switch in $PREFIX/bin"
