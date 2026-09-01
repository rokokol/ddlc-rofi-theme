# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by [semver](https://semver.org/spec/v2.0.0.html)

## [1.1.0] - 2026-09-01

### Changed

- `install.sh` accepts `DESTDIR` independently of `PREFIX`, so package recipes can stage its canonical layout
- `install.sh` reworked onto the [huix-standard](https://github.com/rokokol/huix-standard) grammar: `-h`/`-v` short flags, `--prefix`/`--destdir` as flags and env alike, a preflight that installs nothing and prints exact per-distro guidance (rofi itself is a session dependency — a warning, not a refusal), and a declarative sweep — a re-run removes what the previous install wrote and this one did not

### Added

- `VERSION` at the repo root as the one source of version: the package reads it (it used to say `1.0` while the tag said `v1.0.0` — exactly the drift this ends), `install.sh -v|--version` prints it, CI asserts the changelog heading matches
- `./install.sh --uninstall` removes an install by its manifest at `share/ddlc-rofi-theme/install-manifest`; installs made before the manifest existed fall back to the known layout for this one release
- tab completion for the installer, `source completions/install.sh.{bash,zsh}`, drift-checked against `install.sh` by `tests/check-completions.sh`
- `tests/installer.sh` — the installer's contract as a fast suite, also run by `nix flake check`: manifest, sweep, staging, the refusal path per distro, and the installed switch finding its own theme
- `tests/distro.sh` — the full preflight→guidance→install→switch→uninstall cycle inside real `debian`, `ubuntu`, `arch` and `fedora` containers, with four per-distro CI badges (push, weekly cron, never pull requests)

## [1.0.0] - 2026-08-13

Split out of [rokokol/huix](https://github.com/rokokol/huix), where the layout and the two colour sets lived in `programs/rofi/`

### Added

- the theme in a light and a dark variant, one layout in `nix/theme.nix` filled from `ddlc-palette`
- `ddlc-rofi-theme`, the switch between them, and `dist/` for consumers without Nix
- `homeModules.default` (`ddlc.rofi`), which lays both variants out and sets `programs.rofi.theme`, plus `overlays.default`
- checks: `dist/` is current, real rofi parses both variants without a display, the module wires up and leaks nothing while disabled
