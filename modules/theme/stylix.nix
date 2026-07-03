{
  config,
  pkgs,
  ...
}:

{
  stylix = {
    enable = true;
    autoEnable = false;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    image = config.theme.wallpaper;
    polarity = "dark";

    fonts = {
      serif = {
        package = pkgs.dejavu_fonts;
        name = config.theme.typography.serif;
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = config.theme.typography.ui;
      };
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = config.theme.typography.mono;
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    targets.font-packages.enable = true;
    targets.fontconfig.enable = true;
  };
}
