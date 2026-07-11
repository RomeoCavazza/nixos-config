_:

{
  # @root is wiped and recreated on every boot by the impermanence rollback
  # hook in modules/disko/legion.nix. Anything under /var/lib that needs to
  # survive a reboot must be bind-mounted from the untouched @persist
  # subvolume instead.
  #
  # /persist itself and the sops-nix key bind mount are marked
  # neededForBoot: sops-nix's setupSecrets activation script runs very early
  # (before regular fileSystems are mounted), and without this it races
  # against /persist and fails to find /var/lib/sops-nix/key.txt. This was
  # always latent but only surfaced once the rollback hook actually started
  # wiping @root for real (see modules/disko/legion.nix).
  fileSystems."/persist".neededForBoot = true;

  fileSystems."/var/lib/sbctl" = {
    device = "/persist/var/lib/sbctl";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/sops-nix" = {
    device = "/persist/var/lib/sops-nix";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  # UID/GID allocation table for users.mutableUsers = false (modules/core/users.nix).
  # Without this, tco's UID drifts on every boot (recreated from scratch each
  # time), leaving /home/tco owned by a stale UID and breaking login.
  fileSystems."/var/lib/nixos" = {
    device = "/persist/var/lib/nixos";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  fileSystems."/var/lib/gitlab" = {
    device = "/persist/var/lib/gitlab";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/postgresql" = {
    device = "/persist/var/lib/postgresql";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/grafana" = {
    device = "/persist/var/lib/grafana";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/loki" = {
    device = "/persist/var/lib/loki";
    fsType = "none";
    options = [ "bind" ];
  };

  # Avoid replaying up to 12 hours of journal entries after every root wipe.
  fileSystems."/var/lib/promtail" = {
    device = "/persist/var/lib/promtail";
    fsType = "none";
    options = [ "bind" ];
  };

  # NetworkManager keeps saved Wi-Fi credentials and connection metadata in
  # both locations. They must survive recreation of @root.
  fileSystems."/etc/NetworkManager/system-connections" = {
    device = "/persist/etc/NetworkManager/system-connections";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/NetworkManager" = {
    device = "/persist/var/lib/NetworkManager";
    fsType = "none";
    options = [ "bind" ];
  };

  # GDM reads user avatars and account metadata through AccountsService.
  fileSystems."/var/lib/AccountsService" = {
    device = "/persist/var/lib/AccountsService";
    fsType = "none";
    options = [ "bind" ];
  };

  # Preserve runner working state and builds instead of recreating /srv on
  # every boot. Authentication failures are diagnosed separately.
  fileSystems."/srv/gitlab-runner" = {
    device = "/persist/srv/gitlab-runner";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/docker" = {
    device = "/persist/var/lib/docker";
    fsType = "none";
    options = [ "bind" ];
  };

  # locality.activeConfigRepo ("/etc/nixos") is read by backup.nix's b2-critical
  # job and by the security audit tooling. It's not itself part of @persist —
  # the real checkout lives on @home, which already survives the root wipe —
  # but the symlink pointing at it does, so recreate it on every boot.
  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /home/tco/nixos-config"
  ];
}
