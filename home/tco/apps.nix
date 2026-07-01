{ config, pkgs, ... }:

let
  localBin = "${config.home.homeDirectory}/.local/bin";
in
{
  xdg.desktopEntries = {
    cursor = {
      name = "Cursor";
      genericName = "AI Code Editor";
      comment = "Built for AI coding";
      exec = "${localBin}/cursor %U";
      icon = "cursor-icon";
      terminal = false;
      startupNotify = true;
      categories = [
        "Development"
        "TextEditor"
        "IDE"
      ];
    };

    devin = {
      name = "Devin";
      genericName = "AI Code Editor";
      comment = "Devin AI Desktop";
      exec = "${localBin}/devin %U";
      icon = "text-editor";
      terminal = false;
      startupNotify = true;
      categories = [
        "Development"
        "TextEditor"
        "IDE"
      ];
    };

    antigravity = {
      name = "Antigravity 2.0";
      genericName = "AI Assistant";
      comment = "Antigravity v2";
      exec = "${localBin}/antigravity %U";
      icon = "antigravity-icon";
      terminal = false;
      startupNotify = true;
      categories = [
        "Development"
      ];
    };

    antigravity-ide = {
      name = "Antigravity IDE";
      genericName = "IDE";
      comment = "Antigravity IDE Application";
      exec = "${localBin}/antigravity-ide %U";
      icon = "antigravity-icon";
      terminal = false;
      startupNotify = true;
      categories = [
        "Development"
        "IDE"
      ];
    };
  };

  xdg.dataFile."icons/hicolor/256x256/apps/antigravity-icon.png".source =
    https://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/config/icons/hicolor/256x256/apps/antigravity-icon.png;
  xdg.dataFile."icons/hicolor/512x512/apps/antigravity-icon.png".source =
    https://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/config/icons/hicolor/512x512/apps/antigravity-icon.png;
  xdg.dataFile."icons/hicolor/256x256/apps/cursor-icon.png".source =
    https://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/config/icons/hicolor/256x256/apps/cursor-icon.png;
  xdg.dataFile."icons/hicolor/512x512/apps/cursor-icon.png".source =
    https://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/config/icons/hicolor/512x512/apps/cursor-icon.png;

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };
}
