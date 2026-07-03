{ pkgs, typography, ... }:

# Typography tokens live in lib/fonts.nix (companion to lib/palette.nix) and are
# consumed by modules/theme (which feeds Stylix). Stylix owns the base fonts:
# it installs DejaVu (sans/serif), JetBrainsMono and Noto emoji via its
# font-packages target, and writes the fontconfig defaults via its fontconfig
# target. This module only adds the one thing Stylix does not know about — the
# Nerd "Symbols" font — and appends it as a universal glyph fallback so nerd
# icons keep rendering everywhere.
{
  home.packages = [ pkgs.nerd-fonts.symbols-only ];

  fonts.fontconfig.enable = true;

  xdg.configFile."fontconfig/conf.d/99-tco-symbols.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <match target="pattern">
        <edit name="family" mode="append" binding="weak">
          <string>${typography.symbols}</string>
        </edit>
      </match>
    </fontconfig>
  '';
}
