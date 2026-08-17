# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by [semver](https://semver.org/spec/v2.0.0.html)

## [Unreleased]

### Changed

- `install.sh` accepts `DESTDIR` independently of `PREFIX`, so package recipes can stage its canonical layout

## [1.0.0] - 2026-08-13

Split out of [rokokol/huix](https://github.com/rokokol/huix), where the layout and the two colour sets lived in `programs/rofi/`

### Added

- the theme in a light and a dark variant, one layout in `nix/theme.nix` filled from `ddlc-palette`
- `ddlc-rofi-theme`, the switch between them, and `dist/` for consumers without Nix
- `homeModules.default` (`ddlc.rofi`), which lays both variants out and sets `programs.rofi.theme`, plus `overlays.default`
- checks: `dist/` is current, real rofi parses both variants without a display, the module wires up and leaks nothing while disabled
