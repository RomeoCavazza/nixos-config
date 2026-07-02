{ config, lib, ... }:

{
  options.hardware.nvidia-prime.enable = lib.mkEnableOption "NVIDIA PRIME hybrid graphics offload";

  config = lib.mkIf config.hardware.nvidia-prime.enable {
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];

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

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };
  };
}
