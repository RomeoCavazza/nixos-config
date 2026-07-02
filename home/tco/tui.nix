{ pkgs, ... }:

{
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    shellWrapperName = "y";
    extraPackages = with pkgs; [
      ouch
    ];
    plugins = with pkgs.yaziPlugins; {
      inherit git ouch;
    };
    settings = {
      mgr = {
        show_hidden = true;
        title_format = "";
      };
      plugin = {
        prepend_previewers = [
          {
            mime = "application/*zip";
            run = "ouch";
          }
          {
            mime = "application/x-tar";
            run = "ouch";
          }
          {
            mime = "application/x-bzip2";
            run = "ouch";
          }
          {
            mime = "application/x-7z-compressed";
            run = "ouch";
          }
          {
            mime = "application/x-rar";
            run = "ouch";
          }
          {
            mime = "application/vnd.rar";
            run = "ouch";
          }
          {
            mime = "application/x-xz";
            run = "ouch";
          }
          {
            mime = "application/xz";
            run = "ouch";
          }
          {
            mime = "application/x-zstd";
            run = "ouch";
          }
          {
            mime = "application/zstd";
            run = "ouch";
          }
          {
            mime = "application/java-archive";
            run = "ouch";
          }
        ];
        prepend_fetchers = [
          {
            id = "git";
            name = "*";
            run = "git";
          }
          {
            id = "git";
            name = "*/";
            run = "git";
          }
        ];
      };
      opener.extract = [
        {
          run = ''ouch d -y "$@"'';
          desc = "Extract here with ouch";
          for = "unix";
        }
      ];
    };
    keymap.mgr.prepend_keymap = [
      {
        on = [ "C" ];
        run = "plugin ouch";
        desc = "Compress with ouch";
      }
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      dark = true;
      line-numbers = true;
      navigate = true;
      file-style = "#cdd6f4";
      file-decoration-style = "#6c7086";
      hunk-header-style = "file line-number syntax";
      hunk-header-file-style = "bold";
      hunk-header-line-number-style = "bold #a6adc8";
      line-numbers-left-style = "#6c7086";
      line-numbers-right-style = "#6c7086";
      line-numbers-minus-style = "bold #f38ba8";
      line-numbers-plus-style = "bold #a6e3a1";
      minus-style = "syntax #34293a";
      minus-emph-style = "bold syntax #53394c";
      plus-style = "syntax #2c3239";
      plus-emph-style = "bold syntax #404f4a";
    };
  };

  programs.lazygit = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      git = {
        pagers = [
          {
            colorArg = "always";
            pager = "delta --dark --paging=never";
          }
        ];
        parseEmoji = true;
      };
      gui = {
        nerdFontsVersion = "3";
        theme = {
          activeBorderColor = [ "cyan" ];
          selectedLineBgColor = [ "black" ];
        };
        branchColorPatterns = {
          "^(main|master|dev|develop|development|stage)$" = "magenta";
          "^(docs|documentation)/" = "blue";
          "^(feat|feature)/" = "yellow";
          "^(refc|refac|refactor|refactoring)/" = "green";
          "^(bug|bugfix|hotfix|fix)/" = "red";
          "^(test|testing)/" = "cyan";
          "^(chore)/" = "white";
        };
      };
    };
  };
}
