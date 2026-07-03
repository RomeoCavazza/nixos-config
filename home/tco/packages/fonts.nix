{ pkgs, ... }:

let
  # Single source of truth for desktop typography.
  # UI stays on DejaVu Sans (the deliberate look); terminals use JetBrainsMono.
  # "Symbols Nerd Font" is kept as a glyph fallback so nerd icons keep rendering.
  # Consumers (waybar, rofi, conky, hyprlock, foot) reference the generic
  # families "sans-serif" / "monospace" and inherit these choices.
  typo = {
    ui = "DejaVu Sans";
    mono = "JetBrainsMono Nerd Font";
    serif = "DejaVu Serif";
    symbols = "Symbols Nerd Font";
  };
in
{
  home.packages = with pkgs; [
    dejavu_fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  fonts.fontconfig.enable = true;

  xdg.configFile."fontconfig/conf.d/99-tco-fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <alias>
        <family>sans-serif</family>
        <prefer>
          <family>${typo.ui}</family>
          <family>${typo.symbols}</family>
        </prefer>
      </alias>
      <alias>
        <family>monospace</family>
        <prefer>
          <family>${typo.mono}</family>
          <family>${typo.symbols}</family>
        </prefer>
      </alias>
      <alias>
        <family>serif</family>
        <prefer>
          <family>${typo.serif}</family>
        </prefer>
      </alias>
    </fontconfig>
  '';
}
