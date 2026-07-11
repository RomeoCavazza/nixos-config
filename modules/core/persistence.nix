_:

{
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

  fileSystems."/var/lib/promtail" = {
    device = "/persist/var/lib/promtail";
    fsType = "none";
    options = [ "bind" ];
  };

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

  fileSystems."/var/lib/AccountsService" = {
    device = "/persist/var/lib/AccountsService";
    fsType = "none";
    options = [ "bind" ];
  };

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

  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /home/tco/nixos-config"
  ];
}
