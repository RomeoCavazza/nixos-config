{ config, pkgs, lib, inputs, ... }:
let
  mkOut = config.lib.file.mkOutOfStoreSymlink;

  terminal-rain-lightning = pkgs.python3Packages.buildPythonApplication rec {
    pname = "terminal-rain-lightning";
    version = "master";

    src = pkgs.fetchFromGitHub {
      owner = "rmaake1";
      repo = "terminal-rain-lightning";
      rev = "master";
      hash = "sha256-ghMqdEff2VLisCBG+GMZBxw7Ka7Y6KjLsDxwnm1njOQ=";
    };

    format = "pyproject";

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    doCheck = false;
  };
in
{
  home.username = "tco";
  home.homeDirectory = "/home/tco";
  home.stateVersion = "25.05";

  home.sessionPath = [
    "${config.home.homeDirectory}/.lmstudio/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    XDG_DATA_DIRS = "$HOME/.local/share:$XDG_DATA_DIRS";
    ELECTRON_OZONE_PLATFORM_HINT = "x11";
  };

  xdg.enable = true;
  xdg.configFile."hypr/theme/seaglass.conf".source = ../../config/hypr/theme/seaglass.conf;
  xdg.configFile."hypr/theme/hyprchroma.conf".source = ../../config/hypr/theme/hyprchroma.conf;
  xdg.configFile."hypr/theme/rules.conf".source = ../../config/hypr/theme/rules.conf;

  home.file.".config/hypr".source = ../../config/hypr;
  home.file.".config/waybar".source = ../../config/hypr/waybar;
  home.file.".config/rofi".source = ../../config/rofi;
  home.file.".config/foot".source = ../../config/foot;
  home.file.".config/swappy/config".source = ../../config/swappy/config;

  home.file.".local/bin/cursor".source = mkOut "/etc/nixos/config/bin/cursor";

  home.file.".local/bin/antigravity" = {
    force = true;
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec /etc/nixos/config/bin/antigravity "$@"
    '';
  };

  home.file.".local/bin/dw-apply" = {
    source = ../../config/bin/dw-apply;
    executable = true;
  };

  home.file.".local/bin/dw-toggle-global" = {
    source = ../../config/bin/dw-toggle-global;
    executable = true;
  };

  home.file.".local/bin/dw-toggle" = {
    source = ../../config/bin/dw-toggle;
    executable = true;
  };

  home.file.".local/bin/dw-daemon" = {
    source = ../../config/bin/dw-daemon;
    executable = true;
  };

  home.file.".local/bin/hypr-plugins-init" = {
    source = ../../config/bin/hypr-plugins-init;
    executable = true;
  };

  home.file.".local/lib/libhypr-darkwindow.so".source =
    "${pkgs.hyprlandPlugins.hypr-darkwindow}/lib/libhypr-darkwindow.so";

  home.packages = with pkgs; [
    bat
    eza
    fd
    fzf
    jq
    ripgrep
    yazi
    home-manager
    superfile
    grim
    slurp
    wf-recorder
    sway-contrib.grimshot
    libnotify
    dockfmt
    nixfmt
    shellcheck
    shfmt
    obs-studio
    zed-editor
    neovim
    git
    lua
    lua-language-server
    luaPackages.lgi
    lazygit
    aider-chat
    desktop-file-utils
    cargo
    openssl
    pkg-config
    rust-analyzer
    rustc
    rustfmt
    black
    isort
    (python3.withPackages (ps: with ps; [ pip pyglet ]))
    typescript-language-server
    vscode-langservers-extracted
    tailwindcss-language-server
    nodejs_22
    pnpm
    yarn
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.fr
    papirus-icon-theme
    swaynotificationcenter
    cava
    cool-retro-term
    nerd-fonts.symbols-only
    hyprcursor
    rose-pine-hyprcursor
    nerd-fonts.jetbrains-mono
    bibata-cursors
    conky
    adw-gtk3
    gnome-themes-extra
    pywal
    wpgtk
    qt6Packages.qtbase
    qt6Packages.qt6ct
    qt6Packages.qttools
    kdePackages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum
    hyprlandPlugins.hypr-darkwindow
    socat
    atop
    bottom
    btop
    glances
    htop
    nvitop
    appimage-run
    discord
    spotify
    kicad
    cbonsai
    cmatrix
    hollywood
    pipes
    sl
    terminal-rain-lightning
  ];

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
    };
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        ms-toolsai.jupyter
        ms-vscode.cpptools
        rust-lang.rust-analyzer
        esbenp.prettier-vscode
        jnoortheen.nix-ide
        mkhl.direnv
      ];
      userSettings = {
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
        "editor.fontLigatures" = true;
        "nix.enableLanguageServer" = true;
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
        "window.titleBarStyle" = "custom";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Romeo Cavazza";
        email = "romeo.cavazza@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
      export PATH="$HOME/.lmstudio/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
    '';
    shellAliases = {
      g = "git";
      ll = "eza -l --icons";
      ls = "eza --icons";
      devai = "nix develop /etc/nixos#ai";
      devemb = "nix develop /etc/nixos#embedded";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      hm = "home-manager switch --flake /etc/nixos#tco";
    };
  };

  home.activation.ensureWalFiles =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.cache/wal"
      mkdir -p "$HOME/.config/wal/templates"
      : > "$HOME/.cache/wal/colors-foot.ini"
      : > "$HOME/.cache/wal/colors-hyprland.conf"
      if [ ! -f "$HOME/.config/wal/templates/colors-foot.ini" ]; then
        cat > "$HOME/.config/wal/templates/colors-foot.ini" <<'EOF'
[colors]
background={background.strip}
foreground={foreground.strip}
regular0={color0.strip}
regular1={color1.strip}
regular2={color2.strip}
regular3={color3.strip}
regular4={color4.strip}
regular5={color5.strip}
regular6={color6.strip}
regular7={color7.strip}
bright0={color8.strip}
bright1={color9.strip}
bright2={color10.strip}
bright3={color11.strip}
bright4={color12.strip}
bright5={color13.strip}
bright6={color14.strip}
bright7={color15.strip}
EOF
      fi
      if [ ! -f "$HOME/.config/wal/templates/colors-hyprland.conf" ]; then
        cat > "$HOME/.config/wal/templates/colors-hyprland.conf" <<'EOF'

general {
  col.active_border = rgba({color6.strip}ff)
  col.inactive_border = rgba({color0.strip}aa)
}
EOF
      fi
    '';

  xdg.desktopEntries.cursor = {
    name = "Cursor";
    genericName = "AI Code Editor";
    comment = "Built for AI coding";
    exec = "cursor";
    terminal = false;
    categories = [ "Development" "TextEditor" "IDE" ];
    icon = "/home/tco/.local/share/icons/cursor-icon.png";
  };

  xdg.desktopEntries.antigravity = {
    name = "Antigravity";
    genericName = "IDE";
    comment = "Antigravity IDE";
    exec = "antigravity";
    terminal = false;
    categories = [ "Development" "IDE" ];
  };

  systemd.user.services.dw-daemon = {
    Unit = {
      Description = "Hypr DarkWindow auto-shade daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "%h/.local/bin/dw-daemon";
      Restart = "on-failure";
      RestartSec = 1;
      Environment = [
        "PATH=/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin:%h/.local/bin:%h/.npm-global/bin:%h/.lmstudio/bin"
        "XDG_CACHE_HOME=%h/.cache"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
