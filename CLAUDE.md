# CLAUDE.md

## What this repo is

The DDLC rofi theme in a light and a dark variant, plus `ddlc-rofi-theme`, the command that switches between them by moving a symlink. The layout is one pure function in `nix/theme.nix`; the two variants share it and differ only in which palette keys fill it. `dist/` holds the rendered `.rasi` files, committed for consumers without Nix

The seam in `rokokol/huix` is `home-manager/programs/rofi.nix`: `ddlc.rofi.enable` plus the fonts its defaults do not match. The module sets `programs.rofi.theme = "ddlc"` and lays both variants into `~/.config/rofi/themes` itself; `scripts/toggle-theme.sh` calls the switch command

## Build / check

```sh
nix build                # the rendered theme
nix flake check          # dist/ current, real rofi parses both variants, module wiring, scripts-lint, both suites
./tests/run.sh           # the switch, against a throwaway config tree
./tests/installer.sh     # install.sh: manifest, sweep, staging, refusal path
./tests/distro.sh fedora # the full cycle in a real container (docker/podman; deliberate, images are large)
nix fmt -- --ci
```

`VERSION` is the one source of version: `nix/package.nix` reads it, `install.sh -v` prints it, CI asserts `CHANGELOG.md` has a matching heading. `install.sh` follows the huix-standard grammar; one local deviation — the switch goes into `bin/` as a **copy**, not the standard's relative symlink into `share/<name>/`, because it resolves the theme directory relative to its own location (`../share/rofi/themes`), same as the Nix package installs it. New installer flags update both `completions/` files in the same commit, or `check-sh.sh -c` fails the flake check

## Layout

```
nix/theme.nix        the layout and the two colour sets, as one pure function
nix/                 package.nix, module.nix, module-test.nix
ddlc-rofi-theme.sh   the light/dark switch
dist/                the rendered theme, committed for consumers without Nix
install.sh           for systems without Nix, VERSION its one source of version
completions/         tab completion for install.sh, drift-checked against it
check-sh.sh          vendored from bash-best-practices, holds install.sh's help
                     and completions to its parser
tests/               run.sh (the switch), installer.sh, distro.sh
```

## Changing a colour

It comes from `ddlc-palette` through `flake.nix`, never a literal in `nix/theme.nix`. The paper and the message window read the roles of `ddlc-themes` instead, `lib.roles` there, and a role this theme lacks is added there first. After editing, regenerate `dist/` — `dist-is-current` fails otherwise

## What about rofi is easy to get wrong

- a background image repeats over the widget: `rofi_theme_get_image_inside` in `source/theme.c` sets `CAIRO_EXTEND_REPEAT`, which the man page never mentions. So the paper ships as one row of tiles that repeats down the window
- the scale decides the size on a scaled screen. `none` loads the image at its own pixel size and then divides it by rofi's display scale, an integer on Wayland, 2 under a fractional 1.33, so the dots and the title bar come out at half size. `width` renders it at the widget's logical width times that scale, keeping its aspect. So both images are exactly as wide as their widget, from `windowWidth`, `windowBorder` and `windowPadding` in `nix/theme.nix`, and use `width`. `both` fits the image inside the widget, so a canvas of another aspect shrinks to the widget's height
- to look at the theme at a scale, run it in a headless sway (`WLR_BACKENDS=headless`) and set `output HEADLESS-1 scale 1.33` through `swaymsg`; keep `XDG_RUNTIME_DIR` short, or sway exits on an IPC socket path too long for `sun_path`
- the repeated image starts at the outer edge of the widget's margin and is painted inside its border. The message window's image is drawn from `msgMargin` in `nix/theme.nix` for that reason, and the rasi reads the same margin
- `-theme-str` with two `url("…")` values in one string reads them as one string from the first quote to the last, and loads nothing. To try overrides with images, put them in a theme file that `@import`s the variant
- an image named as `url("x.svg")` is **not** looked up next to the theme that named it: the name goes to the same resolver as `@theme` with `parent_file = NULL`, so it resolves against `$XDG_CONFIG_HOME/rofi/themes/` and the data dirs
- `rofi -no-config -theme <file> -dump-theme` parses without a display, but exits zero on a broken theme — the criterion is `Failed to parse` on stderr. In the dump `url()` prints as `(null)` and `#FFFFFF` as `White`, so neither identifies the theme

## CHANGELOG

Every user-visible change adds a bullet under `## [Unreleased]` in `CHANGELOG.md`. A release moves those bullets under a new version heading with the date, tags `v<x.y.z>` and cuts a `gh release` whose notes are that section. Dates belong in this file and nowhere else — the no-dates rule holds everywhere but here, because Keep a Changelog asks for them
