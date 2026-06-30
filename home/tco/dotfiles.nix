{ config, inputs, ... }:

let
  repoCheckout = "/etc/nixos";
  liveConfig = name: config.lib.file.mkOutOfStoreSymlink "${repoCheckout}/config/${name}";
in
{
  home.file.".config/rofi".source = "${inputs.hypr-config}/rofi";
  home.file.".config/foot".source = "${inputs.hypr-config}/foot";
  home.file.".config/swappy/config".source = "${inputs.hypr-config}/swappy/config";
  home.file.".config/conky".source = liveConfig "conky";
  home.file.".config/nvim".source = liveConfig "nvim";
  home.file.".config/doom".source = liveConfig "doom";

  xdg.configFile."eDEX-UI/settings.json".source = "${inputs.hypr-config}/edex/settings.json";

  xdg.configFile."wal/templates/colors-foot.ini".source =
    "${inputs.hypr-config}/wal/templates/colors-foot.ini";
  xdg.configFile."wal/templates/colors-hyprland.conf".source =
    "${inputs.hypr-config}/wal/templates/colors-hyprland.conf";
}
