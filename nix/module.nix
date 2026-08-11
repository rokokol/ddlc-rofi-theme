# Home Manager module. It deploys both variants next to each other, names the theme in
# the rofi config, and lets the switch decide which one is live — so the light/dark
# choice stays a runtime one and a rebuild does not drag it back to the default
{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ddlc.rofi;
  themes = "rofi/themes";

  # The variants are deployed into ~/.config rather than linked from the store, so the
  # switch's symlink survives a garbage collection
  deploy = name: {
    "${themes}/${name}".source = "${cfg.package}/share/${themes}/${name}";
  };
in
{
  options.ddlc.rofi = {
    enable = lib.mkEnableOption "the DDLC rofi theme, light and dark";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.ddlc-rofi-theme.override {
        themeName = cfg.name;
        inherit (cfg)
          width
          font
          promptFont
          monoFont
          placeholder
          ;
      };
      defaultText = lib.literalExpression "ddlc-rofi-theme carrying the settings below";
      description = "The package to install; it carries the generated theme and its settings";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "ddlc";
      description = ''
        What the theme is called: `<name>.rasi` is the link rofi resolves, and
        `<name>-light.rasi` / `<name>-dark.rasi` are the variants it points at
      '';
    };

    default = lib.mkOption {
      type = lib.types.enum [
        "light"
        "dark"
      ];
      default = "light";
      description = ''
        The variant the first activation picks. Later ones leave the link alone —
        which one is live is a runtime choice, made by `ddlc-rofi-theme`
      '';
    };

    width = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "720px";
      description = "Window width, in any unit rofi takes. Defaults to `720px`";
    };

    font = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.programs.rofi.font;
      defaultText = lib.literalExpression "config.programs.rofi.font";
      example = "Doki 12";
      description = "The font the window is set in. Defaults to `sans-serif 12`";
    };

    promptFont = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Doki 13";
      description = "The font of the prompt alone, which is usually an emoji. Defaults to `font`";
    };

    monoFont = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "DepartureMono Nerd Font Mono 12";
      description = "The font the rows and messages are set in. Defaults to `monospace 12`";
    };

    placeholder = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Okay, everyone!";
      description = "What the empty search line says";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile =
      deploy "${cfg.name}-light.rasi"
      // deploy "${cfg.name}-dark.rasi"
      # rofi resolves a bare image name against this directory, so the backgrounds
      # have to land in it too
      // deploy "ddlc-polka-light.svg"
      // deploy "ddlc-polka-dark.svg";

    programs.rofi.theme = lib.mkDefault cfg.name;

    # After linkGeneration, or the variants it points at are not in ~/.config yet
    home.activation.ddlc-rofi-theme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ ! -e "${config.xdg.configHome}/${themes}/${cfg.name}.rasi" ]; then
        run ${lib.getExe cfg.package} ${cfg.default}
      fi
    '';
  };
}
