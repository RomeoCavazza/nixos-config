{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  hyprland-pkg = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  waybarConfig =
    pkgs.runCommand "waybar-config"
      {
        nativeBuildInputs = [ pkgs.dart-sass ];
      }
      ''
            mkdir -p $out source/config/hypr/waybar source/config/scss

            cp -R ${../../config/hypr/waybar}/. $out/
            chmod -R u+w $out
            rm -f $out/style.css

            cp ${../../config/hypr/waybar/style.scss} source/config/hypr/waybar/style.scss
            cp -R ${../../config/scss}/. source/config/scss/

        sass \
          --no-source-map \
          --no-charset \
          --style=expanded \
          source/config/hypr/waybar/style.scss \
          $out/style.css
      '';

  # Hyprchroma v3.4.0-v054 — unified adaptive tint release
  hyprchroma-src = pkgs.lib.cleanSource inputs.hyprchroma;
  hypr-darkwindow = pkgs.stdenv.mkDerivation {
    pname = "hypr-darkwindow";
    version = "3.4.0-v054";
    srcs = [ ];
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;
    buildPhase = ''
      g++ -shared -fPIC -std=c++2b -O2 \
        $(pkg-config --cflags hyprland pixman-1 libdrm) \
        -DWLR_USE_UNSTABLE \
        ${hyprchroma-src}/src/main.cpp \
        -o libhypr-darkwindow.so
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp libhypr-darkwindow.so $out/lib/
    '';
    meta.description = "Hyprchroma v3.4.0-v054 — unified adaptive tint release";
  };
  hypr-canvas-src = pkgs.fetchFromGitHub {
    owner = "RomeoCavazza";
    repo = "hypr-canvas";
    rev = "e245d426d4b34f321f6dfc58d155fcb551ae40fd";
    hash = "sha256-h2qz/AYxXZmctL2orVbQR2k5wD0fIEl/x073SYSG2j4=";
  };
  hypr-canvas = pkgs.stdenv.mkDerivation {
    pname = "hypr-canvas";
    version = "0.3.0";

    srcs = [ ];
    dontUnpack = true;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;

    buildPhase = ''
      g++ -shared -fPIC -std=c++2b -O2 \
        $(pkg-config --cflags hyprland pixman-1 libdrm) \
        ${hypr-canvas-src}/src/main.cpp ${hypr-canvas-src}/src/canvas.cpp \
        -o hypr-canvas.so
    '';

    installPhase = ''
      mkdir -p $out/lib
      cp hypr-canvas.so $out/lib/
    '';

    meta.description = "Infinite canvas plugin for Hyprland";
  };
  hyprspace = inputs.hyprspace.packages.${pkgs.stdenv.hostPlatform.system}.Hyprspace;

  terminal-rain-lightning = pkgs.python3Packages.buildPythonApplication {
    pname = "terminal-rain-lightning";
    version = "master";

    src = pkgs.fetchFromGitHub {
      owner = "rmaake1";
      repo = "terminal-rain-lightning";
      rev = "master";
      hash = "sha256-GJvGnvo78l4RK2Y9ACbqOXHLQkNtIwIktbm/FK1vOcc=";
    };

    format = "pyproject";

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    doCheck = false;
  };

  edexUiAppImage = pkgs.fetchurl {
    url = "https://github.com/GitSquared/edex-ui/releases/download/v2.2.8/eDEX-UI-Linux-x86_64.AppImage";
    sha256 = "c8f28cd721ca032ca0c1960b756ca3e64dc441a643c32eafbb79c673b402d681";
  };
in
{
  imports = [
    ./modules/apps/cad.nix
    ./modules/apps/embedded.nix
    ./modules/apps/data.nix
  ];

  home.username = "tco";
  home.homeDirectory = "/home/tco";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  home.sessionPath = [
    "${config.home.homeDirectory}/.lmstudio/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    PATH = "$HOME/.local/bin:$PATH";
    XDG_DATA_DIRS = "$HOME/.local/share:$XDG_DATA_DIRS";
    ELECTRON_OZONE_PLATFORM_HINT = "x11";
  };

  home.file.".config/fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;

  xdg.enable = true;
  xdg.mime.enable = true;
  xdg.desktopEntries = {
    cursor = {
      name = "Cursor";
      genericName = "AI Code Editor";
      comment = "Built for AI coding";
      exec = "/home/tco/.local/bin/cursor %U";
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
      exec = "/home/tco/.local/bin/devin %U";
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
      exec = "/home/tco/.local/bin/antigravity %U";
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
      exec = "/home/tco/.local/bin/antigravity-ide %U";
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
    ../../config/icons/hicolor/256x256/apps/antigravity-icon.png;
  xdg.dataFile."icons/hicolor/512x512/apps/antigravity-icon.png".source =
    ../../config/icons/hicolor/512x512/apps/antigravity-icon.png;
  xdg.dataFile."icons/hicolor/256x256/apps/cursor-icon.png".source =
    ../../config/icons/hicolor/256x256/apps/cursor-icon.png;
  xdg.dataFile."icons/hicolor/512x512/apps/cursor-icon.png".source =
    ../../config/icons/hicolor/512x512/apps/cursor-icon.png;

  home.file.".config/hypr" = {
    source = ../../config/hypr;
    recursive = true;
    force = true;
  };
  home.file.".config/waybar".source = waybarConfig;
  home.file.".config/rofi".source = ../../config/rofi;
  home.file.".config/foot".source = ../../config/foot;
  home.file.".config/swappy/config".source = ../../config/swappy/config;
  home.file.".config/conky".source = ../../config/conky;
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/nvim";
  xdg.configFile."eDEX-UI/settings.json".source = ../../config/edex/settings.json;

  home.file.".local/bin/cursor" = {
    source = ../../config/bin/cursor;
    executable = true;
  };

  home.file.".local/bin/devin" = {
    source = ../../config/bin/devin;
    executable = true;
  };

  home.file.".local/bin/antigravity" = {
    source = ../../config/bin/antigravity;
    executable = true;
  };

  home.file.".local/bin/antigravity-ide" = {
    source = ../../config/bin/antigravity-ide;
    executable = true;
  };

  home.file.".local/bin/hypr-plugins-init" = {
    source = ../../config/bin/hypr-plugins-init;
    executable = true;
  };



  home.file.".local/bin/hypr-layout-toggle" = {
    source = ../../config/bin/hypr-layout-toggle;
    executable = true;
  };

  home.file.".local/bin/hypr-close-all" = {
    source = ../../config/bin/hypr-close-all;
    executable = true;
  };

  home.file.".local/bin/edex-conky-toggle" = {
    source = ../../config/bin/edex-conky-toggle;
    executable = true;
  };

  home.file.".local/bin/edex-toggle" = {
    source = ../../config/bin/edex-toggle;
    executable = true;
  };

  home.file.".local/bin/edex-ui-toggle" = {
    source = ../../config/bin/edex-toggle;
    executable = true;
  };

  home.file.".local/bin/edex-ui-run" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      export SHELL="''${SHELL:-${pkgs.bashInteractive}/bin/bash}"
      export TERM="''${TERM:-xterm-256color}"
      export COLORTERM="''${COLORTERM:-truecolor}"
      export PATH="''${PATH:-${config.home.profileDirectory}/bin:/run/current-system/sw/bin}"
      export LD_LIBRARY_PATH="${pkgs.libxshmfence}/lib:''${LD_LIBRARY_PATH:-}"
      exec ${pkgs.appimage-run}/bin/appimage-run ${edexUiAppImage} \
        --no-sandbox --disable-gpu-sandbox \
        --ozone-platform=x11 --disable-features=UseOzonePlatform "$@"
    '';
  };

  home.file.".local/bin/waybar-toggle" = {
    source = ../../config/bin/waybar-toggle;
    executable = true;
  };

  home.file.".local/bin/rebuild" = {
    source = ../../config/bin/rebuild;
    executable = true;
  };

  home.file.".local/bin/scss-compile" = {
    source = ../../config/bin/scss-compile;
    executable = true;
  };

  # Hyprchroma / hypr-darkwindow is disabled for Hyprland 0.55.x: its render
  # hooks and custom pass element still target the 0.54-era internals.

  home.file.".local/lib/hypr-canvas.so" = {
    source = "${hypr-canvas}/lib/hypr-canvas.so";
    executable = true;
  };

  home.file.".local/lib/hyprspace.so" = {
    source = "${hyprspace}/lib/libHyprspace.so";
    executable = true;
  };

  home.file.".local/bin/legion-pulse" = {
    source = ../../config/bin/legion-pulse;
    executable = true;
  };

  home.file.".local/bin/legion-toggle" = {
    source = ../../config/bin/legion-toggle;
    executable = true;
  };

  home.packages = with pkgs; [
    chafa
    bat
    eza
    fd
    fzf
    jq
    d2
    ripgrep
    yazi
    home-manager
    superfile
    grim
    slurp
    wev
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
    gh
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
    nmap
    pulseview
    (python3.withPackages (
      ps: with ps; [
        pip
        pyglet
        pdfplumber
      ]
    ))
    terraform
    kubeconform
    minikube
    (lib.hiPrio kubectl)
    (lib.lowPrio k3s)
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
    socat
    atop
    bottom
    btop
    glances
    htop
    nvitop
    nvtopPackages.full
    hyprlock
    hypridle
    brightnessctl
    playerctl
    appimage-run
    discord
    spotify
    cbonsai
    cmatrix
    hollywood
    pipes
    sl
    terminal-rain-lightning
    dart-sass
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
      size = 24;
    };
    gtk4.theme = config.gtk.theme;
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      format = "[░▒▓](#94e2d5)[  ](bg:#94e2d5 fg:#090c0c)[](fg:#94e2d5 bg:#1d2230)$directory[](fg:#1d2230 bg:none)$character";
      directory = {
        style = "fg:#94e2d5 bg:#1d2230";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };
      character = {
        success_symbol = "[ ❯](bold #94e2d5)";
        error_symbol = "[ ❯](bold #ff0055)";
      };
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };


  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "RomeoCavazza";
        email = "romeo.cavazza@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      safe.directory = "/etc/nixos";
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

      # Smart Tab: ls + exec on empty line
      _tab_smart_ls_exec() {
        if [[ -z "$READLINE_LINE" ]]; then
          local selected
          selected=$(fzf --height 40% --reverse --preview '[[ -d {} ]] && eza --icons --tree --level=1 {} || (bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null || cat {})' 2>/dev/null)
          if [[ -n "$selected" ]]; then
            if [[ -d "$selected" ]]; then
              cd "$selected"
              READLINE_LINE=""
              READLINE_POINT=0
              printf "\r\n"
              ls --icons
            else
              if [[ -x "$selected" ]]; then
                READLINE_LINE="./$selected"
              else
                READLINE_LINE="xdg-open \"$selected\""
              fi
              printf "\r\n"
              eval "$READLINE_LINE"
              READLINE_LINE=""
              READLINE_POINT=0
            fi
          fi
          # Force prompt refresh
          printf "\r"
        else
          # Fallback to standard completion (Insert a literal tab and trigger)
          # Note: bind -x is limited, but this works for simple cases
          printf "\t"
        fi
      }
      bind -x '"\t": _tab_smart_ls_exec'
    '';
    shellAliases = {
      g = "git";
      ll = "eza -l --icons";
      ls = "eza --icons";
      devai = "nix develop /etc/nixos#ai";
      devemb = "nix develop /etc/nixos#embedded";
      rebuild = "command rebuild";
    };
  };

  xdg.configFile."wal/templates/colors-foot.ini".source = ../../config/wal/templates/colors-foot.ini;
  xdg.configFile."wal/templates/colors-hyprland.conf".source =
    ../../config/wal/templates/colors-hyprland.conf;
}
