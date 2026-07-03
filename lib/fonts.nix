# Typography design tokens (companion to lib/palette.nix for colours).
# Consumed by home/tco/packages/fonts.nix, which installs these fonts and
# writes fontconfig aliases so the generic families resolve to them.
{
  ui = "DejaVu Sans";
  mono = "JetBrainsMono Nerd Font";
  serif = "DejaVu Serif";
  symbols = "Symbols Nerd Font";
}
