{
  config,
  locality,
  pkgs,
  ...
}:

{
  # Impermanence recreates /etc/shadow on every boot. Keep users declarative
  # so the password hash is reapplied from SOPS during each activation.
  users.mutableUsers = false;

  # Decrypt before users-groups activation reads hashedPasswordFile. Without
  # this, the activation can run first and leave the declarative account with
  # no usable password until another switch.
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
