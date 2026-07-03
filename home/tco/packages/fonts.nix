{ pkgs, typography, ... }:

# Typography tokens live in lib/fonts.nix (companion to lib/palette.nix).
# UI stays on DejaVu Sans; foot uses JetBrainsMono explicitly. Consumers
# (waybar, rofi, conky, hyprlock) use the generic families "sans-serif" /
# "monospace"; the aliases below resolve those to the tokens, with
# "Symbols Nerd Font" kept as a glyph fallback so nerd icons keep rendering.
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
        <family>monospace</family>
        <prefer>
          <family>${typography.mono}</family>
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
