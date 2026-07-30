{ pkgs, ... }:

{
  home.packages = with pkgs; [
    obsidian
    kicad
    freecad
    plantuml
    graphviz
    jdk
  ];
}
