{ pkgs, ... }:

{
  # --- Docker ---
  virtualisation.docker = {
    enable = true;

    autoPrune = {
      enable = true;
      flags = [
        "--all"
        "--volumes"
      ];
    };
  };

  # --- Libvirt / KVM ---
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # --- Binary Format Emulation ---
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # --- Tools ---
  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    qemu
    quickemu
  ];
}
