{
  config,
  locality,
  pkgs,
  ...
}:

{
  # Required for hashedPasswordFile to actually be applied on every
  # activation. With the default mutableUsers=true, NixOS's user-groups
  # activation script only ever writes the declarative password once, at
  # account creation, and treats /etc/shadow as manually-managed state
  # afterward — update-users-groups.pl only copies hashedPassword into
  # /etc/shadow `if defined $u->{hashedPassword} && !$spec->{mutableUsers}`.
  # Under impermanence /etc/shadow is wiped every boot, so without this the
  # account looks "freshly created" each time but the password never
  # actually gets (re)applied from the sops secret.
  users.mutableUsers = false;

  sops.secrets.tco_password_hash = { };

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
