{ config, pkgs, lib, inputs, ... }:
let
  mkOut = config.lib.file.mkOutOfStoreSymlink;

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

  hyprland-logo-cursor = pkgs.stdenv.mkDerivation {
    pname = "hyprland-logo-cursor";
    version = "master";
    src = pkgs.fetchFromGitHub {
      owner = "hyprcow";
      repo = "hyprland_theme";
      rev = "main";
      sha256 = "0ff8n019n7gapj3yy0rk5f8jg4l3vqjwb72wyikiwsqgcvzi38v6";
    };
    installPhase = ''
      mkdir -p $out/share/icons/Hyprland-Logo
      cp -r * $out/share/icons/Hyprland-Logo/
    '';
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

  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",

        "logo": {
            "source": "\u001b[38;2;42;81;158m    \u259c\u2588\u2588\u259b    \u259c\u2588\u2588\u2588\u2599 \u259c\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u259b\n     \u259c\u259b     \u259f\u2588\u2588\u2588\u2588\u2599 \u259c\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u259b \n           \u259f\u2588\u2588\u2588\u2588\u2588\u2588\u2599         \u259c\u2588\u2588\u2588\u2599     \n          \u259f\u2588\u2588\u2588\u259b\u259c\u2588\u2588\u2588\u2599         \u259c\u2588\u2588\u2588\u2599    \n         \u259f\u2588\u2588\u2588\u259b  \u259c\u2588\u2588\u2588\u2599         \u259c\u2588\u2588\u2588\u2599   \n         \u259d\u2580\u2580\u2580    \u2580\u2580\u2580\u2598         \u2580\u2580\u2580\u2598   \u001b[0m",
            "type": "auto",
            "padding": {
                "right": 2
            }
        },

        "display": {
            "separator": " ",
            "key": { "type": "none" },
            "color": {
                "keys": "38;2;172;230;243",
                "title": "38;2;172;230;243"
            },
            "bar": {
                "char": {
                    "elapsed": "\u2588",
                    "total": "-"
                },
                "width": 10
            }
        },

        "modules": [
            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u256d\u2500\u2500\u2500 System Core \u256e\u001b[0m"
            },
            {
                "type": "kernel",
                "format": "\u001b[38;2;172;230;243m\u2502  \uf17c Kernel      \u2502\u001b[0m   {2}"
            },
            {
                "type": "os",
                "format": "\u001b[38;2;172;230;243m\u2502  󰣇 Distro      \u2502\u001b[0m   {3} {10}"
            },
            {
                "type": "cpu",
                "format": "\u001b[38;2;172;230;243m\u2502  󰓅 CPU Freq    \u2502\u001b[0m   {7} GHz"
            },
            {
                "type": "display",
                "format": "\u001b[38;2;172;230;243m\u2502  󰹑 Display     \u2502\u001b[0m   {1}x{2} @ {3}Hz"
            },
            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u2570\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u256f\u001b[0m"
            },

            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u256d\u2500\u2500\u2500 Software \u2500\u2500\u2500\u256e\u001b[0m"
            },
            {
                "type": "shell",
                "format": "\u001b[38;2;172;230;243m\u2502  󱆃 Shell       \u2502\u001b[0m   {1} {4}"
            },
            {
                "type": "terminal",
                "format": "\u001b[38;2;172;230;243m\u2502  󰆍 Terminal    \u2502\u001b[0m   {1} {6}"
            },
            {
                "type": "packages",
                "format": "\u001b[38;2;172;230;243m\u2502  󰏖 Packages    \u2502\u001b[0m   {1}"
            },
            {
                "type": "wm",
                "format": "\u001b[38;2;172;230;243m\u2502  󰨇 WM          \u2502\u001b[0m   {1}"
            },
            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u2570\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u256f\u001b[0m"
            },

            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u256d\u2500\u2500\u2500 Hardware \u2500\u2500\u2500\u256e\u001b[0m"
            },
            {
                "type": "cpu",
                "format": "\u001b[38;2;172;230;243m\u2502  󰍛 CPU         \u2502\u001b[0m   {1}"
            },
            {
                "type": "gpu",
                "hideType": "integrated",
                "format": "\u001b[38;2;172;230;243m\u2502  󰢮 GPU         \u2502\u001b[0m   {2}"
            },
            {
                "type": "command",
                "shell": "sh",
                "text": "free -m | awk '/Mem:/ {u=$3; t=$2; p=int(u/t*100); b=int(p/10); split(\"0;95;255 0;95;255 17;108;253 34;122;252 51;135;250 68;149;249 85;163;247 102;176;246 137;203;244 172;230;243\", colors, \" \"); printf \"[ \"; for(i=1;i<=b;i++) printf \"\\033[38;2;\" colors[i] \"m█\\033[0m\"; for(i=b+1;i<=10;i++) printf \"-\"; printf \" ] %0.2f / %0.2f GiB\", u/1024, t/1024}'",
                "format": "\u001b[38;2;172;230;243m\u2502  \uf2db RAM         \u2502\u001b[0m   {1}"
            },
            {
                "type": "command",
                "shell": "sh",
                "text": "df -h / | tail -1 | awk '{p=int($5); b=int(p/10); split(\"0;95;255 0;95;255 17;108;253 34;122;252 51;135;250 68;149;249 85;163;247 102;176;246 137;203;244 172;230;243\", colors, \" \"); printf \"[ \"; for(i=1;i<=b;i++) printf \"\\033[38;2;\" colors[i] \"m█\\033[0m\"; for(i=b+1;i<=10;i++) printf \"-\"; printf \" ] %s / %s\", $3, $2}'",
                "format": "\u001b[38;2;172;230;243m\u2502  \uf0a0 SSD         \u2502\u001b[0m   {1}"
            },
            {
                "type": "command",
                "shell": "sh",
                "text": "cat /sys/class/power_supply/BAT0/capacity | awk '{p=int($1); b=int(p/10); split(\"0;95;255 0;95;255 17;108;253 34;122;252 51;135;250 68;149;249 85;163;247 102;176;246 137;203;244 172;230;243\", colors, \" \"); printf \"[ \"; for(i=1;i<=b;i++) printf \"\\033[38;2;\" colors[i] \"m█\\033[0m\"; for(i=b+1;i<=10;i++) printf \"-\"; printf \" ] %d%%\", p}'",
                "format": "\u001b[38;2;172;230;243m\u2502  \uf240 Battery     \u2502\u001b[0m   {1}"
            },
            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u2570\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u256f\u001b[0m"
            },

            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u256d\u2500\u2500\u2500 Colors \u2500\u2500\u2500\u2500\u2500\u256e\u001b[0m"
            },
            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u2502  󱓉 Colors      \u2502\u001b[0m   \u001b[38;2;42;81;158m\u25cf \u001b[38;2;88;94;160m\u25cf \u001b[38;2;58;107;206m\u25cf \u001b[38;2;166;109;136m\u25cf \u001b[38;2;42;159;232m\u25cf \u001b[38;2;94;155;225m\u25cf \u001b[38;2;172;230;243m\u25cf \u001b[38;2;120;161;170m\u25cf\u001b[0m"
            },
            {
                "type": "custom",
                "format": "\u001b[38;2;172;230;243m\u2570\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u256f\u001b[0m"
            }
        ]
    }
  '';

  xdg.enable = true;
  xdg.configFile."hypr/theme/seaglass.conf".source = ../../config/hypr/theme/seaglass.conf;
  xdg.configFile."hypr/theme/hyprchroma.conf".source = ../../config/hypr/theme/hyprchroma.conf;

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

  home.file.".local/bin/hypr-plugins-init" = {
    source = ../../config/bin/hypr-plugins-init;
    executable = true;
  };

  home.file.".local/bin/hypr-layout-toggle" = {
    source = ../../config/bin/hypr-layout-toggle;
    executable = true;
  };

  home.file.".local/bin/hypr-float-active" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      TARGET_W=939
      TARGET_H=1136

      ACTIVE_JSON="$(hyprctl activewindow -j)"
      ADDR="$(printf '%s\n' "$ACTIVE_JSON" | jq -r '.address')"
      FLOATING="$(printf '%s\n' "$ACTIVE_JSON" | jq -r '.floating')"

      if [[ -z "$ADDR" || "$ADDR" == "0x" ]]; then
        exit 0
      fi

      if [[ "$FLOATING" == "true" ]]; then
        hyprctl dispatch settiled "address:$ADDR" >/dev/null
      else
        hyprctl --batch \
          "dispatch setfloating address:$ADDR; \
           dispatch resizewindowpixel exact $TARGET_W $TARGET_H,address:$ADDR"
      fi
    '';
  };

  home.file.".local/bin/hypr-close-all" = {
    source = ../../config/bin/hypr-close-all;
    executable = true;
  };

  home.file.".local/bin/waybar-toggle" = {
    source = ../../config/bin/waybar-toggle;
    executable = true;
  };

  home.file.".local/bin/hypr-measure-active" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      hyprctl activewindow -j | jq -r '
        if .address == "0x" or .address == "" then
          "No active window"
        else
          [
            "title      : \(.title)",
            "class      : \(.class)",
            "floating   : \(.floating)",
            "workspace  : \(.workspace.name) (#\(.workspace.id))",
            "at         : x=\(.at[0]) y=\(.at[1])",
            "size       : w=\(.size[0]) h=\(.size[1])",
            "box        : \(.size[0])x\(.size[1])+\(.at[0])+\(.at[1])"
          ] | join("\n")
        end
      '
    '';
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

  # home.file.".local/lib/hyprexpo.so".source =
  #   "${inputs.hyprland-plugins.packages.${pkgs.system}.hyprexpo}/lib/libhyprexpo.so";

  # home.file.".local/lib/hyprtasking.so".source =
  #   "${inputs.hyprtasking.packages.${pkgs.system}.default}/lib/libhyprtasking.so";

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
    appimage-run
    discord
    spotify
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
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
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

}
