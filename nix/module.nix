# Home Manager module. It deploys both variants next to each other, names the theme in
# the rofi config, and lets the switch decide which one is live — so the light/dark
# choice stays a runtime one and a rebuild does not drag it back to the default
{ self }:
{
  config,
  lib,
  pkgs,
  # The system's configuration when Home Manager runs as a NixOS module, null otherwise
  osConfig,
  ...
}:

let
  cfg = config.ddlc.rofi;
  themes = "rofi/themes";

  host = if osConfig == null then null else osConfig.networking.hostName or null;

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
          headingFont
          promptFont
          rowFont
          monoFont
          placeholder
          title
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
      description = "The font the window is set in. Defaults to `Nunito Medium 12`";
    };

    headingFont = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Doki 13";
      description = ''
        The font of the search line and its placeholder, and of the prompt unless
        `promptFont` is set. Defaults to Doki where it is installed and Nunito Black
        otherwise, at 13
      '';
    };

    promptFont = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Doki 13";
      description = "The font of the prompt alone, which is usually an emoji. Defaults to `headingFont`";
    };

    rowFont = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "DepartureMono Nerd Font Mono 12";
      description = "The font the rows are set in. Defaults to `font`";
    };

    monoFont = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "DepartureMono Nerd Font Mono 12";
      description = "The font of the message under the search line. Defaults to `monospace 12`";
    };

    placeholder = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Okay, everyone!";
      description = "What the empty search line says";
    };

    title = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if host == null then config.home.username else "${config.home.username}@${host}";
      defaultText = lib.literalExpression ''"''${config.home.username}@''${osConfig.networking.hostName}"'';
      example = "monika@club";
      description = ''
        What the message's title bar says after its prompt. Defaults to user@host, or the
        user alone when Home Manager does not run as a NixOS module. Null leaves the prompt
        alone on the bar
      '';
    };
  };

  config = lib.mkMerge [
    # The module system looks a missing argument up here and ignores its default, so a
    # standalone Home Manager needs this. Under NixOS the real osConfig takes precedence
    { _module.args.osConfig = lib.mkDefault null; }

    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];

      # Every file the package ships, the variants and the images they name, since rofi
      # resolves a bare image name against this directory. Recursive links each file on
      # its own, so the directory stays open to other themes and to the switch's symlink.
      # That symlink points at these files in ~/.config rather than into the store, so it
      # survives a garbage collection
      xdg.configFile.${themes} = {
        source = "${cfg.package}/share/${themes}";
        recursive = true;
      };

      programs.rofi.theme = lib.mkDefault cfg.name;

      # After linkGeneration, or the variants it points at are not in ~/.config yet
      home.activation.ddlc-rofi-theme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -e "${config.xdg.configHome}/${themes}/${cfg.name}.rasi" ]; then
          run ${lib.getExe cfg.package} ${cfg.default}
        fi
      '';
    })
  ];
}
