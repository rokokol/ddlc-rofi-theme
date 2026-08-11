# Evaluates the Home Manager module against stubs for the option paths it writes to, so
# the wiring is checked without pulling home-manager in as an input. Produces the values
# it would emit; flake.nix turns them into assertions
{
  lib,
  pkgs,
  module,
}:

let
  # The module orders its activation entry, which is the one piece of home-manager's lib
  # it uses. The stub keeps what it was handed, so the ordering can be asserted on
  hmLib = lib.extend (
    _: _: {
      hm.dag.entryAfter = after: data: { inherit after data; };
    }
  );

  stubs =
    { lib, ... }:
    {
      options = {
        home.packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
        };
        home.activation = lib.mkOption {
          type = lib.types.attrsOf lib.types.unspecified;
          default = { };
        };
        xdg.configHome = lib.mkOption {
          type = lib.types.str;
          default = "/home/test/.config";
        };
        xdg.configFile = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.source = lib.mkOption {
                type = lib.types.either lib.types.str lib.types.path;
              };
            }
          );
          default = { };
        };
        programs.rofi.font = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        programs.rofi.theme = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    };

  eval =
    user:
    (lib.evalModules {
      modules = [
        stubs
        module
        user
      ];
      specialArgs = {
        inherit pkgs;
        lib = hmLib;
      };
    }).config;

  on = eval { ddlc.rofi.enable = true; };
  named = eval {
    ddlc.rofi = {
      enable = true;
      name = "doki";
    };
  };
  tuned = eval {
    ddlc.rofi = {
      enable = true;
      placeholder = "Just Monika";
    };
  };
  off = eval { ddlc.rofi.enable = false; };
in
{
  # Joined rather than indexed, so "installed nothing" fails the assertion instead of
  # blowing up during evaluation with an unhelpful list error
  package = lib.concatMapStringsSep " " toString on.home.packages;
  # A setting rides in the generated theme, so changing it has to move the store path
  tunedPackage = lib.concatMapStringsSep " " toString tuned.home.packages;

  files = lib.attrNames on.xdg.configFile;
  namedFiles = lib.attrNames named.xdg.configFile;
  # Every deployed file has to come out of the package, or the link points at nothing
  sources = lib.mapAttrsToList (_: v: toString v.source) on.xdg.configFile;

  theme = on.programs.rofi.theme;
  namedTheme = named.programs.rofi.theme;

  # After linkGeneration, or the variants it points at are not in ~/.config yet
  activation = lib.attrNames on.home.activation;
  activationAfter = on.home.activation.ddlc-rofi-theme.after or [ ];

  offPackages = off.home.packages;
  offFiles = lib.attrNames off.xdg.configFile;
  offTheme = off.programs.rofi.theme;
}
