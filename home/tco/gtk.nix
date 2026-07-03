{ pkgs, theme, ... }:

let
  inherit (theme) palette;
in

{
  stylix.targets.gtk = {
    enable = true;
    extraCss = ''
      /* Nemo is GTK3/Cinnamon and can over-amplify generated theme tints. */
      .nemo-window .view,
      .nemo-window iconview,
      .nemo-window treeview,
      .nemo-window .places-treeview {
        background-color: ${palette.base};
        color: ${palette.text};
      }

      .nemo-window .places-treeview:selected,
      .nemo-window treeview:selected,
      .nemo-window .view:selected,
      .nemo-window iconview:selected {
        background-color: alpha(${palette.accent}, 0.16);
        color: ${palette.text};
      }

      .nemo-window .nemo-inactive-pane .view:not(:selected),
      .nemo-window .nemo-inactive-pane iconview {
        background-color: ${palette.mantle};
      }

      .nemo-window .floating-bar {
        background-color: ${palette.surface0};
        color: ${palette.text};
        border-color: ${palette.surface1};
      }
    '';
  };

  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.colorScheme = "dark";
  };
}
