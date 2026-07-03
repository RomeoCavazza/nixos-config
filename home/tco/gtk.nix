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
  # GTK is intentionally NOT themed by Stylix: its Catppuccin Mocha accent
  # (mauve) leaked into every GTK app. adw-gtk3-dark gives neutral gray
  # surfaces with a blue accent — the gray/blue look, consistent with foot.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
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
    gtk3.extraCss = ''
      /* Nemo (GTK3/Cinnamon) polished to a neutral blue-gray surface. */
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
}
