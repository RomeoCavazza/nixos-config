_:

{
  # @root is wiped and recreated on every boot by the impermanence rollback
  # hook in modules/disko/legion.nix. Anything under /var/lib that needs to
  # survive a reboot must be bind-mounted from the untouched @persist
  # subvolume instead.
  fileSystems."/var/lib/sbctl" = {
    device = "/persist/var/lib/sbctl";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/sops-nix" = {
    device = "/persist/var/lib/sops-nix";
    fsType = "none";
    options = [ "bind" ];
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

  fileSystems."/var/lib/docker" = {
    device = "/persist/var/lib/docker";
    fsType = "none";
    options = [ "bind" ];
  };
}
