{ locality, pkgs, ... }:

{
  users.users.${locality.user} = {
    isNormalUser = true;
    password = "password";
    home = locality.homeDirectory;
    shell = pkgs.bash;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "docker"
      "libvirtd"
      "dialout"
      "i2c"
      "plugdev"
    ];
  };
}
