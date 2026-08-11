#!/usr/bin/env bash
# Switches rofi between the light and the dark variant by pointing one symlink at one of
# them. rofi reads its theme on every launch, so there is nothing to reload — the next
# window is already the other variant
#
#   DDLC_ROFI_THEME_NAME   the theme's name: <name>.rasi is the link, <name>-light.rasi
#                          and <name>-dark.rasi are the variants it points at
#   DDLC_ROFI_THEME_DIR    where those variants live, when they are not next to the link

set -euo pipefail

NAME="${DDLC_ROFI_THEME_NAME:-ddlc}"
THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/themes"
LINK="$THEMES/$NAME.rasi"

# A variant deployed next to the link comes first, and for a reason: a link into a Nix
# store path dangles after the next garbage collection. Last resort is the install's own
# share directory, which is what makes the switch work without anything set
if [[ -e "$THEMES/$NAME-light.rasi" ]]; then
  SOURCE="$THEMES"
elif [[ -n "${DDLC_ROFI_THEME_DIR:-}" ]]; then
  SOURCE="$DDLC_ROFI_THEME_DIR"
else
  SOURCE="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/share/rofi/themes"
fi

usage() {
  cat <<EOF
ddlc-rofi-theme — the DDLC rofi theme's light/dark switch

  light     point rofi at the light variant
  dark      point rofi at the dark variant
  toggle    switch to the other one
  status    print the current variant: light, dark, none or unknown

  DDLC_ROFI_THEME_NAME=$NAME
  DDLC_ROFI_THEME_DIR=$SOURCE   where the variants are taken from
  $LINK   the link it writes
EOF
}

die() {
  printf 'ddlc-rofi-theme: %s\n' "$1" >&2
  exit 1
}

set_variant() {
  local variant="$1" path="$SOURCE/$NAME-$1.rasi"
  [[ -e "$path" ]] || die "no $variant variant at $path"
  # -f would happily delete a theme of the user's own that happens to sit there
  [[ ! -e "$LINK" || -L "$LINK" ]] || die "$LINK is a real file, not the switch's link"
  mkdir -p "$THEMES"
  ln -sfn "$path" "$LINK"
}

current() {
  local target
  target="$(readlink "$LINK" 2>/dev/null)" || {
    echo none
    return
  }
  case "${target##*/}" in
    "$NAME-light.rasi") echo light ;;
    "$NAME-dark.rasi") echo dark ;;
    *) echo unknown ;;
  esac
}

case "${1:-}" in
  light | dark) set_variant "$1" ;;
  toggle)
    if [[ "$(current)" == dark ]]; then
      set_variant light
    else
      set_variant dark
    fi
    ;;
  status) current ;;
  -h | --help) usage ;;
  "") usage >&2 && exit 1 ;;
  *) die "unknown command \"$1\" — try --help" ;;
esac
