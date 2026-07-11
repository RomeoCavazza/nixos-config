{
  config,
  locality,
  pkgs,
  ...
}:

{
  users.mutableUsers = false;

  sops.secrets.tco_password_hash.neededForUsers = true;

  users.users.${locality.user} = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets.tco_password_hash.path;
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
