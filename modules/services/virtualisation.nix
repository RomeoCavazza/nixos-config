{ config, pkgs, ... }:

{
  # ============================================================================
  # DOCKER (Container Engine)
  # ============================================================================
  virtualisation.docker = {
    enable = true;
    
    # Automatic Garbage Collection
    autoPrune = {
      enable = true;
      flags = [ "--all" "--volumes" ];
    };
  };

  # ============================================================================
  # LIBVIRT / KVM (Virtual Machines)
  # ============================================================================
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true; # GUI for KVM

  # ============================================================================
  # BINARY FORMAT EMULATION (ARM Support)
  # ============================================================================
  # Allows running Aarch64 binaries/containers natively on x86_64 kernel
  # Crucial for Raspberry Pi / Jetson SD card building
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # ============================================================================
  # VIRTUALIZATION TOOLS
  # ============================================================================
  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    qemu
    quickemu # Simplifies VM creation (Windows/MacOS/Linux)
  ];
}
