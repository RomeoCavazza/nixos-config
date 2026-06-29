{ config, lib, pkgs, ... }:

{
  # ============================================================================
  # NVIDIA DRIVERS & OPENGL
  # ============================================================================
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Modesetting is required for Wayland compositors (Hyprland/GNOME)
    modesetting.enable = true;

    # Use the open source kernel module (default true for recent GPUs)
    # Set to false if you encounter stability issues/regressions.
    open = lib.mkDefault true;

    # Enable Nvidia Settings menu
    nvidiaSettings = true;

    # Experimental persistence daemon (helps with boot times/wake)
    nvidiaPersistenced = true;

    # Power Management (Important for laptops)
    powerManagement = {
      enable = true;
      finegrained = true; # Offloads GPU when not in use
    };

    # Package Selection (Stable channel by default)
    package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.stable;

    # ==========================================================================
    # PRIME OFFLOAD (Hybrid Graphics)
    # ==========================================================================
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # Provides `nvidia-offload` command
      };

      # Bus IDs (Verify with `lspci` if hardware changes)
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
    };
  };
}
