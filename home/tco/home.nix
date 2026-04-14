{ config, pkgs, lib, inputs, ... }:
let
  hyprland-pkg = inputs.hyprland.packages.${pkgs.system}.hyprland;
  hyprspacePkg = inputs.hyprspace.packages.${pkgs.system}.Hyprspace;

  # Hyprchroma v3.3 — grouped adaptive chromakey tint
  # Point to the fork source
  hyprchroma-src = pkgs.writeText "hyprchroma-main.cpp" (builtins.readFile ./pkgs/Hyprchroma-fork/src/main.cpp);
  hypr-darkwindow = pkgs.stdenv.mkDerivation {
    pname   = "hypr-darkwindow";
    version = "3.3.1-v054";
    srcs        = [];
    dontUnpack  = true;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;
    buildPhase = ''
      g++ -shared -fPIC -std=c++2b -O2 \
        $(pkg-config --cflags hyprland pixman-1 libdrm) \
        -DWLR_USE_UNSTABLE \
        ${hyprchroma-src} \
        -o libhypr-darkwindow.so
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp libhypr-darkwindow.so $out/lib/
    '';
    meta.description = "Hyprchroma v3.3 — grouped adaptive chromakey tint";
  };
  hypr-canvas = pkgs.stdenv.mkDerivation {
    pname = "hypr-canvas";
    version = "0.2.0-patched";

    srcs = [];
    dontUnpack = true;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;

    buildPhase =
      let srcDir = lib.cleanSource ./pkgs/hypr-canvas-fork;
      in ''
        g++ -shared -fPIC -std=c++2b -O2 \
          $(pkg-config --cflags hyprland pixman-1 libdrm) \
          ${srcDir}/src/main.cpp ${srcDir}/src/canvas.cpp \
          -o hypr-canvas.so
      '';

    installPhase = ''
      mkdir -p $out/lib
      cp hypr-canvas.so $out/lib/
    '';

    meta.description = "Infinite canvas plugin for Hyprland";
  };

  terminal-rain-lightning = pkgs.python3Packages.buildPythonApplication {
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

  home.file.".config/fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;

  xdg.enable = true;
  xdg.desktopEntries = {
    cursor = {
      name = "Cursor";
      genericName = "AI Code Editor";
      comment = "Built for AI coding";
      exec = "cursor %U";
      icon = "cursor-icon";
      terminal = false;
      startupNotify = true;
      categories = [
        "Development"
        "TextEditor"
        "IDE"
      ];
    };

    antigravity = {
      name = "Antigravity";
      genericName = "IDE";
      comment = "Antigravity IDE";
      exec = "antigravity %U";
      icon = "antigravity-icon";
      terminal = false;
      startupNotify = true;
      categories = [
        "Development"
        "IDE"
      ];
    };
  };

  xdg.dataFile."icons/hicolor/256x256/apps/antigravity-icon.png".source = ../../config/icons/hicolor/256x256/apps/antigravity-icon.png;
  xdg.dataFile."icons/hicolor/512x512/apps/antigravity-icon.png".source = ../../config/icons/hicolor/512x512/apps/antigravity-icon.png;
  xdg.dataFile."icons/hicolor/256x256/apps/cursor-icon.png".source = ../../config/icons/hicolor/256x256/apps/cursor-icon.png;
  xdg.dataFile."icons/hicolor/512x512/apps/cursor-icon.png".source = ../../config/icons/hicolor/512x512/apps/cursor-icon.png;

  xdg.configFile."hypr/theme/seaglass.conf".source = ../../config/hypr/theme/seaglass.conf;
  xdg.configFile."hypr/theme/hyprchroma.conf".source = ../../config/hypr/theme/hyprchroma.conf;
  xdg.configFile."hypr/theme/rules.conf".source = ../../config/hypr/theme/rules.conf;
  home.file.".config/hypr".source = ../../config/hypr;
  home.file.".config/waybar".source = ../../config/hypr/waybar;
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

  home.file.".local/bin/antigravity" = {
    source = ../../config/bin/antigravity;
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

  home.file.".local/lib/libhypr-darkwindow.so" = {
    source = "${hypr-darkwindow}/lib/libhypr-darkwindow.so";
    executable = true;
  };

  home.file.".local/lib/hypr-canvas.so" = {
    source = "${hypr-canvas}/lib/hypr-canvas.so";
    executable = true;
  };

  home.file.".local/lib/hyprspace.so" = {
    source = "${hyprspacePkg}/lib/libHyprspace.so";
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
  xdg.configFile."wal/templates/colors-hyprland.conf".source = ../../config/wal/templates/colors-hyprland.conf;
}
