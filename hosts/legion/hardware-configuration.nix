{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usbhid"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-partlabel/legion-crypt";
    allowDiscards = true;
  };

  fileSystems."/" = {
    device = "/dev/legion/root";
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = "/dev/legion/home";
    fsType = "ext4";
    options = [
      "nodev"
      "nosuid"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/legion/nix";
    fsType = "ext4";
    options = [
      "nodev"
    ];
  };

  fileSystems."/build" = {
    device = "/dev/legion/build";
    fsType = "ext4";
    options = [
      "nodev"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partuuid/6486f8bd-126f-4045-bdf4-ba81ded35f90";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/legion/swap"; }
  ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
