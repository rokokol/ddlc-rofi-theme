#!/usr/bin/env bash
# Installer for ddlc-rofi-theme on systems without Nix. Projects what nix/package.nix
# installs onto a plain prefix: the rendered theme into share/rofi/themes (a directory
# rofi searches itself), the switch into bin as a real copy — it finds the theme
# relative to its own location — and an install-manifest that --uninstall consumes
set -euo pipefail

here="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
VERSION=$(cat "$here/VERSION")

PREFIX="${PREFIX:-/usr/local}"
DESTDIR="${DESTDIR:-}"
OS_RELEASE="${OS_RELEASE:-/etc/os-release}"

usage() {
  cat <<EOF
install ddlc-rofi-theme $VERSION into a prefix

The rendered theme goes to \$PREFIX/share/rofi/themes and the switch to \$PREFIX/bin.
rofi searches that share directory itself, so the backgrounds resolve by name and
nothing has to be pathed. Then name the theme in ~/.config/rofi/config.rasi
("rofi.theme: ddlc") and pick a variant: ddlc-rofi-theme light

usage: ./install.sh [options]
  -h, --help        show this help and exit
  -v, --version     print the version and exit
      --prefix DIR  install prefix (default: $PREFIX; env PREFIX)
      --destdir DIR staging root: files land under DESTDIR/PREFIX (env DESTDIR)
      --uninstall   remove everything a previous install wrote, by its manifest

Runtime environment (read by the installed switch, not this script):
  DDLC_ROFI_THEME_NAME  the theme's name: <name>.rasi is the link it writes (default: ddlc)
  DDLC_ROFI_THEME_DIR   where the variants live, when not next to the link
EOF
}

UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -v | --version)
      echo "ddlc-rofi-theme $VERSION"
      exit 0
      ;;
    --prefix)
      PREFIX="${2:?directory required by $1}"
      shift 2
      ;;
    --destdir)
      DESTDIR="${2:?directory required by $1}"
      shift 2
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$PREFIX" != /* ]]; then
  echo "install.sh: PREFIX must be absolute: $PREFIX" >&2
  exit 1
fi

root="${DESTDIR%/}$PREFIX"
share_runtime="$PREFIX/share/ddlc-rofi-theme"
share="${DESTDIR%/}$share_runtime"
manifest="$share/install-manifest"

# --- manifest helpers ------------------------------------------------------------------
# Every path the install creates is recorded as its final runtime path (no DESTDIR): the
# manifest ships inside a staged tree and stays correct wherever the tree ends up.
# Paths a previous install wrote that this run does not are swept before the new
# manifest lands

old_paths=()
if [[ -f "$manifest" ]]; then
  mapfile -t old_paths < <(grep -v '^#' "$manifest")
fi

installed=()

put() { # put MODE SRC RUNTIME_DST — install one file and record it
  install -D -m "$1" "$2" "${DESTDIR%/}$3"
  installed+=("$3")
}

prune() { # remove now-empty parents of RUNTIME_PATH, stopping at the prefix root
  local dir stop
  dir="$(dirname "${DESTDIR%/}$1")"
  stop="$root"
  while [[ "$dir" == "$stop"/* ]]; do
    rmdir "$dir" 2>/dev/null || break
    dir="$(dirname "$dir")"
  done
}

# --- uninstall -------------------------------------------------------------------------

if ((UNINSTALL)); then
  if [[ ! -f "$manifest" ]]; then
    # Installs made before the manifest existed (<= 1.0.0) left no record; this is
    # their layout, kept for exactly one release after the manifest arrived — delete
    # this arm in the release after that
    removed=0
    for path in \
      "$PREFIX/share/rofi/themes/ddlc-light.rasi" \
      "$PREFIX/share/rofi/themes/ddlc-dark.rasi" \
      "$PREFIX/share/rofi/themes/ddlc-polka-light.svg" \
      "$PREFIX/share/rofi/themes/ddlc-polka-dark.svg" \
      "$PREFIX/bin/ddlc-rofi-theme"; do
      if [[ -e "${DESTDIR%/}$path" ]]; then
        rm -f "${DESTDIR%/}$path"
        removed=$((removed + 1))
      fi
      prune "$path"
    done
    if ((removed)); then
      echo "uninstalled ddlc-rofi-theme from $root ($removed files, pre-manifest install)"
    else
      echo "ddlc-rofi-theme: nothing to uninstall under $root"
    fi
    exit 0
  fi
  while IFS= read -r path; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    rm -f "${DESTDIR%/}$path"
    prune "$path"
  done <"$manifest"
  rm -f "$manifest"
  rmdir "$share" 2>/dev/null || true
  echo "uninstalled ddlc-rofi-theme from $root"
  exit 0
fi

# --- preflight: refuse loudly, install nothing ----------------------------------------
# install deps: the copy itself cannot happen without them — any missing means collect
# them all, print the report, exit 1 having written nothing.
# session deps: rofi comes from the user's live session — a theme for a launcher you
# have not installed yet is still a valid install, so a warning and the install proceeds

missing=()
absent=()

need() { command -v "$1" >/dev/null 2>&1 || missing+=("$1"); }
want() { command -v "$1" >/dev/null 2>&1 || absent+=("$1"); }

need install
want rofi

distro_id() {
  sed -n 's/^ID\(_LIKE\)\?=//p' "$OS_RELEASE" 2>/dev/null | tr -d '"' | tr '\n' ' '
}

guidance() {
  # One recommended method per distro. Runnable lines are printed as `  $ command` —
  # two spaces, dollar, space — and the distro tests run exactly those lines, so this
  # text cannot rot silently. No -y/--noconfirm: a human is reading; the tests arrange
  # non-interactivity around the command, never inside it
  case " $(distro_id) " in
    *" arch "*)
      echo "Install them on Arch:"
      echo '  $ sudo pacman -S --needed coreutils'
      ;;
    *" debian "* | *" ubuntu "*)
      echo "Install them on Debian/Ubuntu:"
      echo '  $ sudo apt install coreutils'
      ;;
    *" fedora "*)
      echo "Install them on Fedora:"
      echo '  $ sudo dnf install coreutils'
      ;;
    *)
      echo "Install coreutils with your package manager"
      ;;
  esac
}

if ((${#missing[@]})); then
  {
    echo "install.sh: missing dependencies:"
    printf '  - %s\n' "${missing[@]}"
    echo
    guidance
  } >&2
  exit 1
fi
if ((${#absent[@]})); then
  printf 'install.sh: not found (comes from your session, install proceeds): %s\n' \
    "${absent[@]}" >&2
fi

# --- install ---------------------------------------------------------------------------

for f in "$here"/dist/*.rasi "$here"/dist/*.svg; do
  put 644 "$f" "$PREFIX/share/rofi/themes/${f##*/}"
done

# A copy rather than a symlink: the switch finds the theme relative to its own location,
# and a symlink into share/ddlc-rofi-theme would put it one directory off
put 755 "$here/ddlc-rofi-theme.sh" "$PREFIX/bin/ddlc-rofi-theme"

put 644 "$here/VERSION" "$share_runtime/VERSION"

# The declarative sweep: whatever the previous install wrote and this one did not
for path in "${old_paths[@]}"; do
  keep=0
  for now in "${installed[@]}"; do
    [[ "$path" == "$now" ]] && keep=1
  done
  ((keep)) || {
    rm -f "${DESTDIR%/}$path"
    prune "$path"
  }
done

{
  echo "# ddlc-rofi-theme $VERSION install manifest"
  printf '%s\n' "${installed[@]}"
} >"$manifest"

echo "installed ddlc-rofi-theme $VERSION into $root (manifest: $manifest)"
