{ config, locality, ... }:

{
  systemd.tmpfiles.rules = [
    "d ${config.users.users.${locality.user}.home}/.cache/wal 0755 ${locality.user} users -"
    "d /nix/var/nix/profiles/per-user/${locality.user} 0755 ${locality.user} users -"
    "d /nix/var/nix/gcroots/per-user/${locality.user} 0755 ${locality.user} users -"
  ];
}
