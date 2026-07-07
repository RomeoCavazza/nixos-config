{ pkgs, typography, ... }:

{
  home.packages = [ pkgs.nerd-fonts.symbols-only ];

  fonts.fontconfig.enable = true;

  xdg.configFile."fontconfig/conf.d/99-tco-symbols.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <match target="pattern">
        <edit name="family" mode="append" binding="weak">
          <string>${typography.symbols}</string>
        </edit>
      </match>
    </fontconfig>
  '';
}
