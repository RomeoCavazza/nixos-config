{ pkgs, ... }:

{
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

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    qemu
    quickemu
  ];
}
