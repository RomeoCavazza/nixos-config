{ pkgs }:

pkgs.fetchurl {
  url = "https://github.com/GitSquared/edex-ui/releases/download/v2.2.8/eDEX-UI-Linux-x86_64.AppImage";
  sha256 = "c8f28cd721ca032ca0c1960b756ca3e64dc441a643c32eafbb79c673b402d681";
}
