{ pkgs, typography, ... }:

# Typography tokens live in lib/fonts.nix (companion to lib/palette.nix).
# UI consumers (waybar, rofi, conky, hyprlock) use the generic "sans-serif"
# family, aliased below to DejaVu Sans (+ Symbols Nerd Font fallback so nerd
# icons keep rendering). foot sets typography.mono (JetBrainsMono) explicitly
# in its own config; the generic "monospace" is left to the system default,
# so it is intentionally not aliased here.
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
          <family>${typography.ui}</family>
          <family>${typography.symbols}</family>
        </prefer>
      </alias>
      <alias>
        <family>serif</family>
        <prefer>
          <family>${typography.serif}</family>
        </prefer>
      </alias>
    </fontconfig>
  '';
}
