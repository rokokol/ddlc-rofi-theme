#!/usr/bin/env bash
# Distro tests for ddlc-rofi-theme: run install.sh for real, as root, inside a container of an
# actual distribution — the one thing the stub-based suite cannot do. Asserts the whole
# contract: the preflight refuses and its printed guidance actually works, the install
# lands, the tool answers, --uninstall takes everything back out.
#
#   tests/distro.sh              every distribution below
#   tests/distro.sh debian       just one
#
# Needs docker or podman. In CI this runs on push to master, weekly, and by hand — never
# on pull requests: a flaky mirror must not redden someone's change. Images are :latest
# on purpose — the weekly run is the upstream-drift detector, so no assertion may depend
# on what an image happens to carry already.
#
# From the huix-standard template
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname "$HERE")

declare -A IMAGE=(
  [debian]=docker.io/library/debian:latest
  [ubuntu]=docker.io/library/ubuntu:latest
  [arch]=docker.io/library/archlinux:latest
  [fedora]=docker.io/library/fedora:latest
)

INSTALL_FLAGS=()
# Bootstrap: only what the harness itself needs to run in a minimal image — never a
# dependency the preflight's guidance is supposed to provide, or the guidance test would
# pass because the answer was planted
declare -A BOOTSTRAP=(
  [debian]='apt-get update -qq && apt-get install -y -qq bash'
  [ubuntu]='apt-get update -qq && apt-get install -y -qq bash'
  [arch]='pacman -Sy --noconfirm --needed bash'
  [fedora]='dnf install -y -q bash'
)

smoke() { # runs inside the container after a successful install
  # The switch must find its own install's theme with nothing set, and write the link
  local cfg="$HOME/.config/rofi/themes"
  "$1/bin/ddlc-rofi-theme" status >/dev/null
  "$1/bin/ddlc-rofi-theme" dark
  [[ "$(readlink "$cfg/ddlc.rasi")" == "$1/share/rofi/themes/ddlc-dark.rasi" ]]
}

# ======================================================================================
# host half: find an engine, pull fresh, re-execute this script inside the container
# ======================================================================================

if [[ "${1:-}" != "--inside" ]]; then
  engine=""
  for candidate in "${CONTAINER_ENGINE:-}" docker podman; do
    [[ -n "$candidate" ]] || continue
    if command -v "$candidate" >/dev/null && "$candidate" info >/dev/null 2>&1; then
      engine="$candidate"
      break
    fi
  done
  if [[ -z "$engine" ]]; then
    echo "tests/distro.sh: needs a working docker or podman" >&2
    exit 1
  fi

  wanted=("$@")
  ((${#wanted[@]})) || wanted=(debian ubuntu arch fedora)

  fails=0
  for distro in "${wanted[@]}"; do
    image="${IMAGE[$distro]:-}"
    if [[ -z "$image" ]]; then
      echo "tests/distro.sh: no such distribution: $distro" >&2
      exit 1
    fi
    printf '\n== %s (%s)\n' "$distro" "$image"
    # One retry on the pull: a mirror hiccup is not a verdict on anything
    "$engine" pull -q "$image" >/dev/null || "$engine" pull -q "$image" >/dev/null
    # The checkout goes in read-only — the run must not be able to edit it
    if ! "$engine" run --rm -v "$REPO:/src:ro" "$image" \
      bash /src/tests/distro.sh --inside "$distro"; then
      printf '  %s: FAILED\n' "$distro"
      fails=$((fails + 1))
    else
      printf '  %s: passed\n' "$distro"
    fi
  done
  ((fails)) && exit 1
  echo
  echo "all distributions passed"
  exit 0
fi

# ======================================================================================
# container half
# ======================================================================================

distro="$2"

say() { printf '\n  -- %s\n' "$1"; }
die() {
  printf '  !! %s\n' "$1" >&2
  exit 1
}

say "bootstrap ($distro)"
bash -c "${BOOTSTRAP[$distro]}" >/dev/null

# The checkout is mounted read-only; work on a copy a package manager cannot be blamed for
cp -r /src /work
cd /work

prefix=/usr/local
bin_path="$prefix/bin/ddlc-rofi-theme"
share_dir="$prefix/share/ddlc-rofi-theme"

say "a relative PREFIX is rejected"
! PREFIX=usr ./install.sh "${INSTALL_FLAGS[@]}" >/dev/null 2>&1 ||
  die "install.sh accepted a relative PREFIX"

say "install, running the printed guidance when the preflight refuses"
rc=0
out=$(./install.sh "${INSTALL_FLAGS[@]}" 2>&1) || rc=$?
if ((rc != 0)); then
  # The refusal must be complete and clean: name what is missing, write nothing
  printf '%s\n' "$out" | grep -q 'missing dependencies' ||
    die "the refusal did not say what is missing: $out"
  [[ ! -e "$bin_path" && ! -e "$share_dir" ]] ||
    die "a refused install left files behind"
  printf '%s\n' "$out" | grep -qE 'command not found|: line [0-9]' &&
    die "the preflight listed what is missing and then carried on: $out"

  # Runnable guidance lines are `  $ command`; they are run exactly as printed.
  # Non-interactivity is arranged around the command — DEBIAN_FRONTEND, yes on stdin —
  # never inside it: the printed line has no -y because a human reads it
  commands=$(printf '%s\n' "$out" | sed -n 's/^  \$ //p')
  if [[ -z "$commands" ]]; then
    # A required dep with no scriptable official method on this distribution: visible
    # skip, green job. Red is reserved for the standard's promise breaking
    echo "::notice title=ddlc-rofi-theme distro test::SKIP on $distro — guidance is manual-only"
    printf '  SKIP: no runnable guidance on %s\n' "$distro"
    exit 0
  fi
  # The container is root and none of these images ships sudo. Answered with a shim, not
  # by editing the line: a sudo can sit mid-pipeline (| sudo tee) where stripping a
  # prefix cannot reach, and an edited line is no longer the line the reader was given.
  # exec env, not exec: a printed line may carry VAR=value assignments after sudo
  # (GOBIN=... go install), and env is what gives those effect
  if ! command -v sudo >/dev/null; then
    printf '#!/bin/sh\nexec env "$@"\n' >/usr/local/bin/sudo
    chmod +x /usr/local/bin/sudo
  fi
  export DEBIAN_FRONTEND=noninteractive
  while IFS= read -r cmd; do
    printf '  running printed guidance: %s\n' "$cmd"
    case "$cmd" in
      "paru -S "*)
        # AUR counts as official on Arch, but paru itself lives in the AUR, so a base
        # container has no way to have it — the one arm whose printed line cannot run.
        # Its documented equivalent: base-devel, a throwaway builder (makepkg refuses
        # root, and its own sudo calls would hit our shim), the package's depends read
        # from its PKGBUILD and installed by pacman, makepkg without -si, pacman -U
        pacman -S --noconfirm --needed base-devel git >/dev/null
        id builder >/dev/null 2>&1 || useradd -m builder
        read -ra aur_pkgs <<<"${cmd#paru -S }"
        for pkg in "${aur_pkgs[@]}"; do
          runuser -u builder -- git clone --depth 1 \
            "https://aur.archlinux.org/$pkg.git" "/home/builder/$pkg"
          deps=$(runuser -u builder -- bash -c \
            "cd /home/builder/$pkg && source PKGBUILD >/dev/null 2>&1; echo \"\${makedepends[*]:-} \${depends[*]:-}\"")
          read -ra dep_list <<<"$deps"
          if ((${#dep_list[@]})); then
            pacman -S --noconfirm --needed "${dep_list[@]}" >/dev/null
          fi
          runuser -u builder -- bash -c "cd /home/builder/$pkg && makepkg --noconfirm" >/dev/null
          pacman -U --noconfirm "/home/builder/$pkg"/*.pkg.tar* >/dev/null
        done
        ;;
      *)
        # yes answers "y" to [Y/n]-style prompts; dnf treats an empty answer as No. Fed
        # by process substitution, not a pipe: pipefail would turn yes's own SIGPIPE
        # death — normal for a command that never reads stdin — into a failed pipeline
        bash -c "$cmd" < <(yes 2>/dev/null) || die "printed guidance failed: $cmd"
        ;;
    esac
  done <<<"$commands"

  say "install succeeds once the guidance has been followed"
  ./install.sh "${INSTALL_FLAGS[@]}" || die "install failed after following the guidance"
else
  echo "  (every dependency was already present — the refusal path ran elsewhere)"
fi

say "the installed tool answers"
[[ -e "$bin_path" ]] || die "no $bin_path after install"
[[ -f "$share_dir/install-manifest" ]] || die "no install-manifest after install"
version_out=$("$bin_path" --version 2>/dev/null || ./install.sh --version)
[[ "$version_out" == *"$(cat VERSION)"* ]] ||
  die "--version does not match VERSION: $version_out"
./install.sh --help >/dev/null || die "--help failed"
smoke "$prefix" || die "smoke test failed"

say "uninstall removes exactly what the manifest names"
mapfile -t manifest_paths < <(grep -v '^#' "$share_dir/install-manifest")
./install.sh --uninstall "${INSTALL_FLAGS[@]}" || die "--uninstall failed"
for path in "${manifest_paths[@]}"; do
  [[ ! -e "$path" && ! -L "$path" ]] || die "uninstall left $path behind"
done
[[ ! -e "$share_dir" ]] || die "uninstall left $share_dir behind"

say "a second uninstall is quiet and succeeds"
./install.sh --uninstall "${INSTALL_FLAGS[@]}" >/dev/null || die "uninstall is not idempotent"

echo
echo "  $distro: full cycle passed"
