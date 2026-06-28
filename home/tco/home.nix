{
  config,
  pkgs,
  lib,
  inputs,
  flakeSelf,
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
            mkdir -p $out source/waybar source/scss

            cp -R ${inputs.hypr-config}/waybar/. $out/
            chmod -R u+w $out
            rm -f $out/style.css

            cp ${inputs.hypr-config}/waybar/style.scss source/waybar/style.scss
            cp -R ${inputs.hypr-config}/scss/. source/scss/

        sass \
          --no-source-map \
          --no-charset \
          --style=expanded \
          source/waybar/style.scss \
          $out/style.css
      '';
  hyprConfig = pkgs.runCommand "hypr-config-canvas"
    { }
    ''
      cp -R ${inputs.hypr-config}/. $out/
      chmod -R u+w $out

      substituteInPlace $out/hyprland.conf \
        --replace-fail 'bind = $mod, F, togglefloating' 'bind = $mod, F, canvas:float' \
        --replace-fail 'bind = $mod, left,  movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up,    movefocus, u
bind = $mod, down,  movefocus, d' '# Canvas navigation
bind = $mod, left,  canvas:nav, left
bind = $mod, right, canvas:nav, right
bind = $mod, up,    canvas:nav, up
bind = $mod, down,  canvas:nav, down' \
        --replace-fail 'bind = $mod SHIFT, left,  swapwindow, l
bind = $mod SHIFT, right, swapwindow, r
bind = $mod SHIFT, up,    swapwindow, u
bind = $mod SHIFT, down,  swapwindow, d' '# Canvas swap
bind = $mod SHIFT, left,  canvas:swap, left
bind = $mod SHIFT, right, canvas:swap, right
bind = $mod SHIFT, up,    canvas:swap, up
bind = $mod SHIFT, down,  canvas:swap, down' \
        --replace-fail '# Layout toggle (Simple, decoupled)
bind = $mod, Z, exec, $HOME/.local/bin/hypr-layout-toggle
bind = $mod, B, exec, $HOME/.local/bin/waybar-toggle
bind = $mod, M, exec, $HOME/.local/bin/cursor-toggle
# Hypr-canvas binds
bind = $mod, R, canvas:reset,
bind = $mod ALT SHIFT, left,  canvas:pan, left
bind = $mod ALT SHIFT, right, canvas:pan, right
bind = $mod ALT SHIFT, up,    canvas:pan, up
bind = $mod ALT SHIFT, down,  canvas:pan, down
bind = $mod, minus,           canvas:zoom, out
bind = $mod, equal,           canvas:zoom, in' '# Canvas mode
bind = $mod, Z, canvas:toggle
bind = $mod, X, canvas:center
bind = $mod, R, canvas:home
bind = $mod, B, exec, $HOME/.local/bin/waybar-toggle
bind = $mod, M, exec, $HOME/.local/bin/cursor-toggle

# Manual viewport nudge
bind = $mod ALT SHIFT, left,  canvas:pan, left
bind = $mod ALT SHIFT, right, canvas:pan, right
bind = $mod ALT SHIFT, up,    canvas:pan, up
bind = $mod ALT SHIFT, down,  canvas:pan, down

# Zoom
bind = $mod, minus, canvas:zoom, out
bind = $mod, equal, canvas:zoom, in

# Canvas extras
bind = $mod, W, canvas:overview
bind = $mod, P, canvas:pin'
    '';

  # Hyprchroma v3.4.1-v055 — unified adaptive tint release
  hyprchroma-src = pkgs.lib.cleanSource inputs.hyprchroma;
  hypr-darkwindow = pkgs.stdenv.mkDerivation {
    pname = "hypr-darkwindow";
    version = "3.4.1-v055";
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
    meta.description = "Hyprchroma v3.4.1-v055 — unified adaptive tint release";
  };
  hypr-canvas-src = pkgs.fetchFromGitHub {
    owner = "RomeoCavazza";
    repo = "hypr-canvas";
    rev = "v0.4.11";
    hash = "sha256-StYgRzo27WzE4vej+Kho/e69jfT/8EWEN1iz+j2xxoQ=";
  };
  hypr-canvas = pkgs.stdenv.mkDerivation {
    pname = "hypr-canvas";
    version = "0.4.11";

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
    source = hyprConfig;
    force = true;
  };
  home.file.".config/waybar".source = waybarConfig;
  home.file.".config/rofi".source = "${inputs.hypr-config}/rofi";
  home.file.".config/foot".source = "${inputs.hypr-config}/foot";
  home.file.".config/swappy/config".source = "${inputs.hypr-config}/swappy/config";
  home.file.".config/conky".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/conky";
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/nvim";
  home.file.".config/doom".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/doom";
  xdg.configFile."eDEX-UI/settings.json".source = "${inputs.hypr-config}/edex/settings.json";

  home.file.".local/bin/cursor" = {
    source = ../../config/bin/cursor;
    executable = true;
  };

  home.file.".local/bin/cursor-toggle" = {
    source = ../../config/bin/cursor-toggle;
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
    source = "${inputs.hypr-config}/bin/hypr-plugins-init";
    executable = true;
  };

  home.file.".local/bin/hypr-gap-state.sh" = {
    source = "${inputs.hypr-config}/bin/hypr-gap-state.sh";
    executable = true;
  };

  home.file.".local/bin/hypr-overview-toggle" = {
    source = "${inputs.hypr-config}/bin/hypr-overview-toggle";
    executable = true;
  };

  home.file.".local/bin/hypr-layout-toggle" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec hyprctl dispatch canvas:toggle
    '';
  };

  home.file.".local/bin/hypr-close-all" = {
    source = "${inputs.hypr-config}/bin/hypr-close-all";
    executable = true;
  };

  home.file.".local/bin/edex-conky-toggle" = {
    source = "${inputs.hypr-config}/bin/edex-conky-toggle";
    executable = true;
  };

  home.file.".local/bin/edex-toggle" = {
    source = "${inputs.hypr-config}/bin/edex-toggle";
    executable = true;
  };

  home.file.".local/bin/edex-ui-toggle" = {
    source = "${inputs.hypr-config}/bin/edex-toggle";
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
    source = "${inputs.hypr-config}/bin/waybar-toggle";
    executable = true;
  };

  home.file.".local/bin/rebuild" = {
    source = ../../config/bin/rebuild;
    executable = true;
  };

  home.file.".local/bin/scss-compile" = {
    source = "${inputs.hypr-config}/bin/scss-compile";
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

  xdg.configFile."wal/templates/colors-foot.ini".source = "${inputs.hypr-config}/wal/templates/colors-foot.ini";
  xdg.configFile."wal/templates/colors-hyprland.conf".source =
    "${inputs.hypr-config}/wal/templates/colors-hyprland.conf";
}
