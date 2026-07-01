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

  xdg.dataFile."icons/hicolor/256x256/apps/antigravity-icon.png".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/config/icons/hicolor/256x256/apps/antigravity-icon.png";
    sha256 = "sha256-XqsTQW5DXcLLTrh/0HYJhSugl8tFKBNFg3fjdeMlscE=";
  };
  xdg.dataFile."icons/hicolor/512x512/apps/antigravity-icon.png".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/config/icons/hicolor/512x512/apps/antigravity-icon.png";
    sha256 = "sha256-hYYyRVg9W0Fhl8yWMK4r2jEEMyXFkavPSi6xRy54xFc=";
  };
  xdg.dataFile."icons/hicolor/256x256/apps/cursor-icon.png".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/config/icons/hicolor/256x256/apps/cursor-icon.png";
    sha256 = "sha256-TAhb2UY6Q0V1Rr3HxZOCTbyQM9ix2SYP93nN0eeL1Ew=";
  };
  xdg.dataFile."icons/hicolor/512x512/apps/cursor-icon.png".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/config/icons/hicolor/512x512/apps/cursor-icon.png";
    sha256 = "sha256-FBnrdBPguVXbbfOU8IfwiKgPWM+qOXfNzeW0iXVj1DU=";
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };
}
