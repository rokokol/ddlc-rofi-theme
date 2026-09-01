{
  description = "The Doki Doki Literature Club rofi theme, light and dark";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ddlc-palette = {
      url = "github:rokokol/ddlc-palette";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ddlc-palette,
    }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # The colours and the one helper the theme spells them with — GTK-CSS has no
      # #RRGGBBAA, so ddlc-palette hands out rgba() and every consumer shares it
      palette = ddlc-palette.lib.palette // {
        inherit (ddlc-palette.lib) rgba;
      };

      # Each piece isolated, so a README edit doesn't rebuild anything
      switch = builtins.path {
        name = "ddlc-rofi-theme.sh";
        path = ./ddlc-rofi-theme.sh;
      };
      testsDir = builtins.path {
        name = "ddlc-rofi-theme-tests";
        path = ./tests;
      };
      dist = builtins.path {
        name = "ddlc-rofi-theme-dist";
        path = ./dist;
      };
      installer = builtins.path {
        name = "install.sh";
        path = ./install.sh;
      };
      versionFile = builtins.path {
        name = "VERSION";
        path = ./VERSION;
      };
      completionsDir = builtins.path {
        name = "ddlc-rofi-theme-completions";
        path = ./completions;
      };
    in
    {
      packages = forAllSystems (pkgs: rec {
        default = ddlc-rofi-theme;
        ddlc-rofi-theme = pkgs.callPackage ./nix/package.nix { inherit palette; };
      });

      # homeModules is the name the flake schema knows; homeManagerModules is what most
      # consumers still write, so both point at the same module
      homeModules.default = import ./nix/module.nix { inherit self; };
      homeManagerModules.default = self.homeModules.default;

      # The theme as plain data, for a consumer that wants to render it itself
      lib = {
        theme = import ./nix/theme.nix;
        inherit palette;
      };

      # For a consumer who reaches for pkgs rather than this flake's packages directly
      overlays.default = final: _prev: {
        inherit (self.packages.${final.stdenv.hostPlatform.system}) ddlc-rofi-theme;
      };

      checks = forAllSystems (
        pkgs:
        let
          ddlc-rofi-theme = self.packages.${pkgs.stdenv.hostPlatform.system}.ddlc-rofi-theme;
          themes = "${ddlc-rofi-theme}/share/rofi/themes";
        in
        {
          # The switch's own suite: a throwaway config tree in, one symlink out
          tests =
            pkgs.runCommand "tests"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gnugrep
                ];
              }
              ''
                mkdir -p repo/tests
                cp ${switch} repo/ddlc-rofi-theme.sh
                cp -r ${testsDir}/. repo/tests
                chmod -R +w repo
                patchShebangs repo
                bash repo/tests/run.sh
                touch $out
              '';

          # dist/ is committed so a consumer without Nix just copies files; this proves
          # it is what the package would have generated
          dist-is-current = pkgs.runCommand "dist-is-current" { } ''
            diff -r ${dist} ${themes}
            touch $out
          '';

          # rofi exits 0 on a theme it could not parse and only warns, so the warning is
          # the check. -dump-theme needs no display, which is what makes this possible
          theme-parses =
            pkgs.runCommand "theme-parses"
              {
                nativeBuildInputs = [
                  pkgs.rofi
                  pkgs.gnugrep
                ];
              }
              ''
                export HOME=$PWD

                # …and it has to be our theme that came back out, not rofi's default, so
                # each variant is recognised by the pink border it wears it at its own
                # alpha. Not by the background image: -dump-theme prints url() as
                # "(null)", and not by the ground: rofi dumps paper white as "White"
                check() {
                  rofi -no-config -theme ${themes}/ddlc-$1.rasi -dump-theme >dump 2>err || true
                  if grep -q "Failed to parse" err; then
                    echo "the $1 variant does not parse:"
                    cat err
                    exit 1
                  fi
                  grep -qF "$2" dump || { echo "the $1 dump is not our theme"; exit 1; }
                }

                check light "border-color:     rgba ( 221, 119, 187, 96 % )"
                check dark "border-color:     rgba ( 221, 119, 187, 72 % )"
                touch $out
              '';

          # Enabling the module has to be enough: package, both variants, both
          # backgrounds, the theme named in the rofi config and the switch run once
          module-wiring =
            let
              wiring = import ./nix/module-test.nix {
                inherit lib pkgs;
                module = self.homeManagerModules.default;
              };
            in
            pkgs.runCommand "module-wiring"
              {
                nativeBuildInputs = [ pkgs.jq ];
                dump = builtins.toJSON wiring;
                passAsFile = [ "dump" ];
              }
              ''
                want() { jq -e "$1" "$dumpPath" >/dev/null || { echo "module wiring: $2"; exit 1; }; }

                want '.package | test("ddlc-rofi-theme")' "no package installed"
                # A setting rides in the generated theme, so changing it has to move the path
                want '.package != .tunedPackage' "the placeholder does not reach the package"

                want '.files | index("rofi/themes/ddlc-light.rasi")' "the light variant is not deployed"
                want '.files | index("rofi/themes/ddlc-dark.rasi")' "the dark variant is not deployed"
                # rofi resolves a bare image name against this directory, not against the
                # theme file, so the backgrounds have to be deployed next to the variants
                want '.files | index("rofi/themes/ddlc-polka-light.svg")' "the light background is not deployed"
                want '.files | index("rofi/themes/ddlc-polka-dark.svg")' "the dark background is not deployed"
                want '[.sources[] | select(test("/nix/store/.*ddlc-rofi-theme"))] | length == 4' \
                  "a deployed file does not come from the package"

                want '.theme == "ddlc"' "the theme is not named in the rofi config"
                want '.namedFiles | index("rofi/themes/doki-light.rasi")' "the name does not reach the variants"
                want '.namedTheme == "doki"' "the name does not reach the rofi config"

                want '.activation | index("ddlc-rofi-theme")' "nothing picks the first variant"
                want '.activationAfter | index("linkGeneration")' \
                  "the switch runs before the variants are in place"

                want '.offPackages == []' "the package is installed while disabled"
                want '.offFiles == []' "the theme is deployed while disabled"
                want '.offTheme == null' "the rofi config is written while disabled"
                touch $out
              '';

          # The one shell file list lives here and nowhere else: CI's shell job is a
          # fast named status for this check, not a second copy of the commands
          scripts-lint =
            pkgs.runCommand "scripts-lint"
              {
                nativeBuildInputs = [
                  pkgs.shellcheck
                  pkgs.shfmt
                  pkgs.zsh
                ];
              }
              ''
                files="${switch} ${installer} ${testsDir}/run.sh ${testsDir}/installer.sh ${testsDir}/distro.sh ${testsDir}/check-completions.sh ${completionsDir}/install.sh.bash"
                # shellcheck disable=SC2086
                shellcheck $files
                # shellcheck disable=SC2086
                shfmt -d -i 2 -ci $files
                # zsh is not shellcheck's language; a parse is what can be checked
                zsh -n ${completionsDir}/install.sh.zsh

                # install.sh and its completions must not drift apart
                mkdir -p repo/tests
                cp ${installer} repo/install.sh
                cp -r ${completionsDir} repo/completions
                cp ${testsDir}/check-completions.sh repo/tests/
                bash repo/tests/check-completions.sh
                touch $out
              '';

          # The fast installer suite, in the sandbox: the manifest contract, the sweep,
          # staging, the refusal path, and the switch against its own install
          installer-suite =
            pkgs.runCommand "installer-suite"
              {
                # tests/installer.sh builds a deliberately install(1)-less PATH of these
                nativeBuildInputs = [ pkgs.coreutils ];
              }
              ''
                mkdir -p repo/tests
                cp ${installer} repo/install.sh
                cp ${switch} repo/ddlc-rofi-theme.sh
                cp ${versionFile} repo/VERSION
                cp -r ${dist} repo/dist
                cp -r ${completionsDir} repo/completions
                cp ${testsDir}/installer.sh ${testsDir}/check-completions.sh repo/tests/
                chmod -R +w repo
                chmod +x repo/install.sh repo/ddlc-rofi-theme.sh repo/tests/*.sh
                patchShebangs repo >/dev/null
                HOME=$PWD bash repo/tests/installer.sh "$PWD/repo"
                touch $out
              '';
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            rofi
            shellcheck
            shfmt
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
