{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ==========================================================================
    # CAD / EDA
    # ==========================================================================
    obsidian # Note taking / Second Brain
    kicad    # PCB & Schematic Design
    freecad  # Parametric 3D CAD
    plantuml # Flowcharts & Diagrams
    graphviz # Dot engine for PlantUML
    jdk      # Java runtime for PlantUML
    # openscad
    # blender
  ];
}
