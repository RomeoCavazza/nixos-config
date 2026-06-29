{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/workstation.nix
  ];

  system.stateVersion = "26.05";
}
