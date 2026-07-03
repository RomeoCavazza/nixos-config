{ hostName, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/disko/legion.nix
    ../../profiles/workstation.nix
  ];

  networking.hostName = hostName;

  hardware.nvidia-prime.enable = true;
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
  };

  system.stateVersion = "26.05";
}
