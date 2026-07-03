{ pkgs, ... }:

let
  nemoPalette = {
    bg = "#1f2430";
    bgAlt = "#252b38";
    bgInactive = "#191d27";
    border = "#3b4252";
    selection = "rgba(90, 139, 214, 0.24)";
    text = "#d8dee9";
    muted = "#aeb6c5";
  };
in

{
  stylix.targets.gtk = {
    enable = true;
    extraCss = ''
      /* Nemo is GTK3/Cinnamon and can over-amplify generated theme tints.
         Keep it on a neutral blue-gray surface while the rest of GTK follows Stylix. */
      .nemo-window,
      .nemo-window.background,
      .nemo-window notebook,
      .nemo-window paned,
      .nemo-window stack,
      .nemo-window scrolledwindow,
      .nemo-window viewport,
      .nemo-window .view,
      .nemo-window iconview,
      .nemo-window treeview,
      .nemo-window .places-treeview {
        background-color: ${nemoPalette.bg};
        color: ${nemoPalette.text};
      }

      .nemo-window headerbar,
      .nemo-window toolbar,
      .nemo-window actionbar,
      .nemo-window statusbar {
        background-color: ${nemoPalette.bgAlt};
        color: ${nemoPalette.text};
        border-color: ${nemoPalette.border};
      }

      .nemo-window separator {
        background-color: ${nemoPalette.border};
      }

      .nemo-window .places-treeview:selected,
      .nemo-window row:selected,
      .nemo-window treeview:selected,
      .nemo-window .view:selected,
      .nemo-window iconview:selected {
        background-color: ${nemoPalette.selection};
        color: ${nemoPalette.text};
      }

      .nemo-window .nemo-inactive-pane .view:not(:selected),
      .nemo-window .nemo-inactive-pane iconview {
        background-color: ${nemoPalette.bgInactive};
      }

      .nemo-window .floating-bar {
        background-color: ${nemoPalette.bgAlt};
        color: ${nemoPalette.text};
        border-color: ${nemoPalette.border};
      }

      .nemo-window label:disabled,
      .nemo-window .dim-label {
        color: ${nemoPalette.muted};
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
