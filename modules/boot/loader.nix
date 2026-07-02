{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.editor = false;
  boot.loader.systemd-boot.configurationLimit = 1;
  boot.loader.timeout = null;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.systemd-boot.extraInstallCommands = ''
    conf=/boot/loader/loader.conf
    ${pkgs.gnused}/bin/sed -i '/^timeout /d; /^auto-entries /d' "$conf"
    echo "timeout menu-force" >> "$conf"
    echo "auto-entries no" >> "$conf"
  '';
}
