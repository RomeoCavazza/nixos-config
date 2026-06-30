{ config, lib, ... }:

{
  options.hardware.nvidia-prime.enable = lib.mkEnableOption "NVIDIA PRIME hybrid graphics offload";

  config = lib.mkIf config.hardware.nvidia-prime.enable {
    # --- NVIDIA Drivers ---
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;

      open = lib.mkDefault true;

      nvidiaSettings = true;

      nvidiaPersistenced = true;

      powerManagement = {
        enable = true;
        finegrained = true;
      };

      package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.stable;

      # --- PRIME Offload ---
      # Hosts importing this module and enabling nvidia-prime must set GPU bus IDs, for example:
      #   hardware.nvidia.prime.intelBusId  = "PCI:0:2:0";
      #   hardware.nvidia.prime.nvidiaBusId = "PCI:2:0:0";
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };
  };
}
