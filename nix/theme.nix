# One rofi layout, two colour sets. Light and dark differ only in their hexes, so the
# structure lives once and each set is a list of ddlc-palette keys
#
# palette is ddlc-palette's flat attrset plus its rgba helper:
#   inputs.ddlc-palette.lib.palette // { inherit (inputs.ddlc-palette.lib) rgba; }
# roles is the roles of ddlc-themes as hexes per variant, with the paper's grid:
#   builtins.fromJSON (builtins.readFile inputs.ddlc-themes.lib.roles)
{
  palette,
  roles,
  width ? "720px",
  font ? "Nunito Medium 12",
  # The face of the prompt and the search line. rofi draws the placeholder in the entry's
  # own layout, so the entry's font covers it too. Pango puts a weight on every family in a
  # list, so "Doki, Nunito Black" would draw Doki in synthetic bold. An axis value reaches
  # only a font that has the axis: Doki has none and stays as drawn, the variable Nunito
  # becomes Black
  headingFont ? "Doki,Nunito 13 @wght=900",
  promptFont ? headingFont,
  rowFont ? font,
  monoFont ? "monospace 12",
  placeholder ? "Okay, everyone!",
  # What the message's title bar says after its prompt, such as user@host
  title ? "",
}:

let
  inherit (roles) polka;

  # Both the placeholder and the title land inside markup
  escapeXml =
    builtins.replaceStrings
      [ "&" "<" ">" "\"" "'" ]
      [ "&amp;" "&lt;" "&gt;" "&quot;" "&apos;" ];

  # rofi draws an image with the scale "width" at the widget's width times the display
  # scale, so an image as wide as its widget in logical pixels comes out at its own size
  # on any screen. The unscaled "none" would be drawn in device pixels and shrink on a
  # scaled one. So the images are as wide as the window and the message, which a width
  # in px gives; any other unit is drawn as if the window were 720px wide
  windowWidth =
    let
      m = builtins.match "([0-9]+)px" width;
    in
    if m == null then 720 else builtins.fromJSON (builtins.head m);
  windowBorder = 2;
  windowPadding = 18;

  # One row of tiles of the paper across the window. rofi repeats a background image, so
  # the row repeats down the window
  polkaSvg =
    variant:
    let
      inherit (roles.${variant}) ground dots;
      w = toString windowWidth;
      tile = toString polka.tile;
      quarter = toString (polka.tile / 4);
      threeQuarters = toString (polka.tile * 3 / 4);
      dot = toString polka.dot;
    in
    ''
      <svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${tile}">
        <defs>
          <pattern id="paper" width="${tile}" height="${tile}" patternUnits="userSpaceOnUse">
            <circle cx="${quarter}" cy="${quarter}" r="${dot}" fill="${dots}" />
            <circle cx="${threeQuarters}" cy="${threeQuarters}" r="${dot}" fill="${dots}" />
          </pattern>
        </defs>
        <rect width="${w}" height="${tile}" fill="${ground}" />
        <rect width="${w}" height="${tile}" fill="url(#paper)" />
      </svg>
    '';

  # The message is a small kitty window, as a code block is in the Obsidian theme: square,
  # dark on both sides, with a title bar that carries a prompt. A rofi message holds its
  # text and nothing else, so the bar and the prompt are painted into its background
  # image. The sizes are the Obsidian ones, in the em of monoFont, read as pt at 96 dpi
  monoSize =
    let
      m = builtins.match ".* ([0-9]+)" monoFont;
    in
    if m == null then 12 else builtins.fromJSON (builtins.head m);
  monoFamily =
    let
      m = builtins.match "(.*[^ ]) +[0-9]+" monoFont;
    in
    if m == null then monoFont else builtins.head m;
  em = monoSize * 4 / 3;
  bar = em * 12 / 5;
  barGap = em * 3 / 4;
  inset = 16;
  # rofi starts a repeated image at the outer edge of the margin and paints it inside the
  # border, so the image has to know the margin to put the bar on the window's top edge
  msgMargin = {
    top = 0;
    right = 6;
    bottom = 12;
    left = 6;
  };
  # As wide as the message with its margin, and taller than any message, so the image
  # never visibly repeats
  windowCanvas = {
    w = windowWidth - 2 * (windowBorder + windowPadding);
    h = 300;
  };

  windowSvg =
    variant:
    let
      r = roles.${variant};
      w = toString windowCanvas.w;
      h = toString windowCanvas.h;
      barTop = toString msgMargin.top;
      # The prompt stands where the text's first column starts: past the margin, the
      # border and the inset, and in the middle of the bar
      promptX = toString (msgMargin.left + 1 + inset);
      promptY = toString (msgMargin.top + bar / 2);
      size = toString em;
      # Two columns after the prompt, as the language stands in the Obsidian bar
      titleText = if title == "" then "" else " ${escapeXml title}";
    in
    ''
      <svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">
        <rect width="${w}" height="${h}" fill="${r.window-ground}" />
        <rect y="${barTop}" width="${w}" height="${toString bar}" fill="${r.window-bar}" />
        <text x="${promptX}" y="${promptY}" dominant-baseline="central" xml:space="preserve"
          font-family="${monoFamily}, monospace" font-size="${size}"><tspan fill="${r.window-prompt}">&gt;</tspan><tspan fill="${r.window-title}">${titleText}</tspan></text>
      </svg>
    '';

  px = n: "${toString n}px";

  # Shared by both sets, so they are not colour-set arguments: the pink border is the
  # theme's signature on either ground, and these alphas read the same on both
  edge = "pink";
  panelAlpha = "0.92";
  wellAlpha = "0.45";
  innerEdgeAlpha = "0.45";
  placeholderAlpha = "0.5";

  # Every colour below is a palette key, so a set reads as a list of names. The ground is
  # the paper's, so the window reads the same before its image is drawn
  rasi =
    {
      variant,
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
    }:
    let
      hex = n: palette.${n};
      rgba = n: palette.rgba.${n};
      role = roles.${variant};
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
        border: ${px windowBorder};
        border-color: ${rgba edge edgeAlpha};
        border-radius: 28px;
        dynamic: true;
        padding: ${px windowPadding};
        background-color: ${role.ground};
        background-image: url("ddlc-polka-${variant}.svg", width);
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
        font: "${headingFont}";
        placeholder: "${escapeXml placeholder}";
        placeholder-markup: true;
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
        font: "${rowFont}";
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
        margin: ${px msgMargin.top} ${px msgMargin.right} ${px msgMargin.bottom} ${px msgMargin.left};
        padding: ${px (bar + barGap)} ${px inset} ${px inset} ${px inset};
        background-color: ${role.window-ground};
        background-image: url("ddlc-window-${variant}.svg", width);
        border: 1px;
        border-color: ${role.window-border};
        border-radius: 0px;
      }

      textbox {
        text-color: ${role.window-text};
        font: "${monoFont}";
      }
    '';
in
{
  polkaLight = polkaSvg "light";
  polkaDark = polkaSvg "dark";
  windowLight = windowSvg "light";
  windowDark = windowSvg "dark";

  # The images are named, not pathed: rofi resolves a bare filename against
  # $XDG_CONFIG_HOME/rofi/themes and the data dirs, which is where they ship
  light = rasi {
    variant = "light";
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
  };

  dark = rasi {
    variant = "dark";
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
  };
}
