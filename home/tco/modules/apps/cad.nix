{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ==========================================================================
    # CAD / EDA
    # ==========================================================================
    obsidian # Note taking / Second Brain
    kicad    # PCB & Schematic Design
    freecad  # Parametric 3D CAD
    # openscad
    # blender
  ];
}
