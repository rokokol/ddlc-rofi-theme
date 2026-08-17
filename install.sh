#!/usr/bin/env bash

set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
DESTDIR="${DESTDIR:-}"

usage() {
  cat <<EOF
install.sh — install the DDLC rofi theme

  PREFIX=$PREFIX (override with PREFIX=... or --prefix DIR)
  DESTDIR=${DESTDIR:-<empty>} (override with DESTDIR=... or --destdir DIR for staging)

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
    --destdir)
      DESTDIR="${2:?directory required}"
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

if [[ -n "$DESTDIR" && "$PREFIX" != /* ]]; then
  echo "install.sh: PREFIX must be absolute when DESTDIR is set: $PREFIX" >&2
  exit 1
fi

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
root="${DESTDIR%/}$PREFIX"
themes="$root/share/rofi/themes"

install -d "$themes"
install -m644 "$here"/dist/*.rasi "$here"/dist/*.svg "$themes"

# A copy rather than a symlink: the switch finds the theme relative to its own location,
# and a symlink in bin would put it one directory off
install -Dm755 "$here/ddlc-rofi-theme.sh" "$root/bin/ddlc-rofi-theme"

echo "installed to $themes, switch in $root/bin"
