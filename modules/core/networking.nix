{ ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];
  services.avahi.openFirewall = false;

  # Démo Bernstein (seminar-dop) : résolution locale vers un nœud du cluster DOKS.
  # /!\ IP éphémère — à retirer/mettre à jour si le cluster est recréé.
  networking.extraHosts = ''
    157.230.26.170 poll.dop.io result.dop.io
  '';
}
