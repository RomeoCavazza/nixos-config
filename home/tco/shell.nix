{ locality, ... }:

{
  home.file.".config/fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      format = "[░▒▓](#94e2d5)[  ](bg:#94e2d5 fg:#090c0c)[](fg:#94e2d5 bg:#1d2230)$directory[](fg:#1d2230 bg:none)$character";
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

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "RomeoCavazza";
        email = "romeo.cavazza@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      safe.directory = locality.repoCheckout;
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
      rebuild = "command rebuild";
      scope = "bash ${locality.labApplicationsDir}/launch-hantek.sh";
      tinysa = "bash ${locality.labApplicationsDir}/launch-tinysa.sh";
    };
  };
}
