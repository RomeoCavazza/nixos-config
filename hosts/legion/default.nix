{
  imports = [
    ./hardware-configuration.nix
    ./local-hosts.nix
    ../../profiles/workstation.nix
  ];

  networking.hostName = "nixos";

  # Legion-specific PRIME bus IDs. Verify with `lspci` if the motherboard/GPU
  # topology changes.
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
  };

  system.stateVersion = "26.05";
}
