# The two rasi variants, the two backgrounds they name, and the switch between them.
# rofi is deliberately NOT a runtime input: the theme is read by the rofi of the running
# session, and pinning a second one here would shadow it
{
  lib,
  stdenvNoCC,
  makeWrapper,
  writeText,
  bash,
  coreutils,
  # ddlc-palette's flat attrset plus its rgba helper — the flake passes it in
  palette,
  # Baked into the generated rasi rather than read at runtime: rofi has no variables,
  # so every setting is a rebuild either way
  themeName ? "ddlc",
  width ? null,
  font ? null,
  promptFont ? null,
  monoFont ? null,
  placeholder ? null,
}:

let
  script = builtins.path {
    name = "ddlc-rofi-theme.sh";
    path = ../ddlc-rofi-theme.sh;
  };

  # Left out when unset, so theme.nix's own defaults stay the single source of them
  settings = lib.filterAttrs (_: v: v != null) {
    inherit
      width
      font
      promptFont
      monoFont
      placeholder
      ;
  };

  theme = import ./theme.nix ({ inherit palette; } // settings);

  files = {
    "${themeName}-light.rasi" = theme.light;
    "${themeName}-dark.rasi" = theme.dark;
    # Named after the theme it came with rather than after the variant that uses it:
    # rofi resolves a bare image name in the same flat directory every theme shares
    "ddlc-polka-light.svg" = theme.polkaLight;
    "ddlc-polka-dark.svg" = theme.polkaDark;
  };
in

stdenvNoCC.mkDerivation {
  pname = "ddlc-rofi-theme";
  version = "1.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];

  installPhase = ''
    runHook preInstall

    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: text: ''
        install -Dm644 ${writeText name text} $out/share/rofi/themes/${name}
      '') files
    )}

    install -Dm755 ${script} $out/bin/ddlc-rofi-theme
    patchShebangs $out/bin

    # --set-default, not --set: an override from the caller's environment still wins
    wrapProgram $out/bin/ddlc-rofi-theme \
      --prefix PATH : ${lib.makeBinPath [ coreutils ]} \
      --set-default DDLC_ROFI_THEME_NAME ${themeName} \
      --set-default DDLC_ROFI_THEME_DIR $out/share/rofi/themes

    runHook postInstall
  '';

  meta = {
    description = "The Doki Doki Literature Club rofi theme, light and dark";
    homepage = "https://github.com/rokokol/ddlc-rofi-theme";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "ddlc-rofi-theme";
  };
}
