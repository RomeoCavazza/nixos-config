{ config, inputs, ... }:

{
  home.file.".config/rofi".source = "${inputs.hypr-config}/rofi";
  home.file.".config/foot".source = "${inputs.hypr-config}/foot";
  home.file.".config/swappy/config".source = "${inputs.hypr-config}/swappy/config";
  home.file.".config/conky".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/conky";
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/nvim";
  home.file.".config/doom".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/doom";

  xdg.configFile."eDEX-UI/settings.json".source = "${inputs.hypr-config}/edex/settings.json";

  xdg.configFile."wal/templates/colors-foot.ini".source = "${inputs.hypr-config}/wal/templates/colors-foot.ini";
  xdg.configFile."wal/templates/colors-hyprland.conf".source =
    "${inputs.hypr-config}/wal/templates/colors-hyprland.conf";
}
