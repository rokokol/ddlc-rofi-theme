# One rofi layout, two colour sets. Light and dark differ only in their hexes, so the
# structure lives once and each set is a list of ddlc-palette keys
#
# palette is ddlc-palette's flat attrset plus its rgba helper:
#   inputs.ddlc-palette.lib.palette // { inherit (inputs.ddlc-palette.lib) rgba; }
{
  palette,
  width ? "720px",
  font ? "sans-serif 12",
  promptFont ? font,
  monoFont ? "monospace 12",
  placeholder ? "Okay, everyone!",
}:

let
  # The same half-step offset grid the site's tile uses, as one SVG instead of 30 hand-placed circles
  polkaSvg =
    {
      ground,
      dot,
      w ? 720,
      h ? 520,
      step ? 140,
      row ? 90,
      r ? 19,
    }:
    let
      rows = builtins.genList (
        y:
        let
          cy = 38 + y * row;
          shift = if (builtins.bitAnd y 1) == 1 then step / 2 else 0;
          cols = builtins.genList (
            x: ''<circle cx="${toString (55 + shift + x * step)}" cy="${toString cy}" r="${toString r}" />''
          ) (w / step + 1);
        in
        builtins.concatStringsSep "\n" cols
      ) (h / row + 1);
    in
    ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${toString w} ${toString h}" preserveAspectRatio="xMidYMid slice">
        <rect width="${toString w}" height="${toString h}" fill="${ground}" />

        <g fill="${dot}">
      ${builtins.concatStringsSep "\n" rows}
        </g>
      </svg>
    '';

  # Shared by both sets, so they are not colour-set arguments: the pink border is the
  # theme's signature on either ground, and these alphas read the same on both
  edge = "pink";
  panelAlpha = "0.92";
  wellAlpha = "0.45";
  innerEdgeAlpha = "0.45";
  msgAlpha = "0.77";
  placeholderAlpha = "0.5";

  # Every colour below is a palette key, so a set reads as a list of names
  rasi =
    {
      polka,
      ground,
      panel,
      text,
      accent,
      edgeAlpha,
      rowEdge,
      rowEdgeAlpha,
      selBg,
      selBgAlpha,
      selEdge,
      selFg,
      alt,
      altAlpha,
      msg,
    }:
    let
      hex = n: palette.${n};
      rgba = n: palette.rgba.${n};
    in
    ''
      * {
        background-color: transparent;
        text-color: ${hex text};
        margin: 0px;
        padding: 0px;
        font: "${font}";
      }

      window {
        location: center;
        width: ${width};
        border: 2px;
        border-color: ${rgba edge edgeAlpha};
        border-radius: 28px;
        dynamic: true;
        padding: 18px;
        background-color: ${hex ground};
        background-image: url("${polka}", both);
      }

      inputbar {
        background-color: ${rgba panel panelAlpha};
        border: 1px;
        border-color: ${rgba edge innerEdgeAlpha};
        margin: 6px 6px 14px 6px;
        padding: 14px 16px;
        border-radius: 18px;
        children: [ prompt, entry ];
      }

      prompt {
        text-color: ${hex accent};
        margin: 0px 12px 0px 0px;
        font: "${promptFont}";
      }

      entry {
        placeholder: "${placeholder}";
        placeholder-color: ${rgba text placeholderAlpha};
        text-color: ${hex text};
      }

      listview {
        background-color: ${rgba panel wellAlpha};
        margin: 0px 6px 6px 6px;
        padding: 6px;
        border-radius: 20px;
        columns: 1;
        lines: 6;
        spacing: 8px;
        fixed-height: false;
      }

      element {
        orientation: horizontal;
        padding: 10px 14px;
        spacing: 10px;
        border-radius: 18px;
        border: 1px;
        border-color: ${rgba rowEdge rowEdgeAlpha};
        background-color: ${rgba panel panelAlpha};
      }

      element-icon {
        background-color: ${rgba accent "0.09"};
        padding: 6px;
        size: 28px;
        horizontal-align: 0.5;
        vertical-align: 0.5;
        border-radius: 12px;
      }

      element-text {
        horizontal-align: 0;
        vertical-align: 0.5;
        text-color: ${hex text};
        font: "${monoFont}";
      }

      element selected {
        background-color: ${rgba selBg selBgAlpha};
        border-color: ${hex selEdge};
        text-color: ${hex selFg};
      }

      element selected element-text {
        text-color: ${hex selFg};
      }

      element selected element-icon {
        background-color: ${rgba selFg "0.16"};
      }

      element alternate {
        background-color: ${rgba alt altAlpha};
      }

      message {
        margin: 8px 10px 0px 10px;
        padding: 10px 14px;
        background-color: ${rgba msg msgAlpha};
        border: 1px;
        border-color: ${rgba edge innerEdgeAlpha};
        border-radius: 16px;
      }

      textbox {
        text-color: ${hex accent};
        font: "${monoFont}";
      }
    '';
in
{
  polkaLight = polkaSvg {
    ground = palette.paper;
    dot = palette.dot;
  };

  polkaDark = polkaSvg {
    ground = palette.yuriShadow;
    dot = palette.yuri;
  };

  # The image is named, not pathed: rofi resolves a bare filename against
  # $XDG_CONFIG_HOME/rofi/themes and the data dirs, which is where both files ship
  light = rasi {
    polka = "ddlc-polka-light.svg";
    ground = "paper";
    panel = "paper";
    text = "ink";
    accent = "plum";
    edgeAlpha = "0.96";
    rowEdge = "blush";
    rowEdgeAlpha = "0.94";
    # Same wash as in dark, only lighter — and white text would drown in it,
    # so the selected row keeps the body text colour
    selBg = "pink";
    selBgAlpha = "0.45";
    selEdge = "plum";
    selFg = "ink";
    alt = "dot";
    altAlpha = "0.55";
    msg = "dot";
  };

  dark = rasi {
    polka = "ddlc-polka-dark.svg";
    ground = "yuriShadow";
    panel = "yuri";
    text = "dot";
    accent = "pink";
    edgeAlpha = "0.72";
    rowEdge = "plum";
    rowEdgeAlpha = "0.55";
    # The only opaque surface in the theme would read as a sticker on the dark ground,
    # and the pink edge would vanish into it. Translucent it sits in the same material
    selBg = "plum";
    selBgAlpha = "0.55";
    selEdge = "pink";
    selFg = "dot";
    alt = "yuri";
    altAlpha = "0.96";
    msg = "yuri";
  };
}
