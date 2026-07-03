{
  boot.system = [ ./boot.nix ];
  core.system = [ ./core.nix ];
  desktop-hyprland.system = [ ./desktop-hyprland.nix ];
  hardware.system = [ ./hardware.nix ];
  launcher.system = [ ./launcher.nix ];
  observability.system = [ ./observability.nix ];
  services.system = [ ./services.nix ];

  tco-home.home = [ ../home/tco ];
}
