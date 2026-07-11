{ pkgs, ... }:

{
  disko.devices = {
    disk.legion = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-WD_PC_SN8000S_SDEPNRK-1T00-1101_25100D4A7S01";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 10;
            label = "EFI system partition";
            type = "EF00";
            size = "260M";
            content = {
              type = "filesystem";
              format = "vfat";
            };
          };

          msr = {
            priority = 20;
            label = "Microsoft reserved partition";
            type = "0C01";
            size = "16M";
          };

          windows = {
            priority = 30;
            label = "Basic data partition";
            type = "0700";
            size = "451G";
          };

          winre = {
            priority = 40;
            label = "Windows recovery environment";
            type = "2700";
            size = "2G";
          };

          cryptroot = {
            priority = 50;
            label = "legion-crypt";
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nodev"
                    ];
                  };

                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nodev"
                      "nosuid"
                    ];
                  };

                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  "@swap" = {
                    mountpoint = "/swap";
                    swap.swapfile.size = "32G";
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  boot.initrd.systemd.storePaths = [
    "${pkgs.util-linux}/bin/mount"
    "${pkgs.util-linux}/bin/umount"
  ];

  boot.initrd.systemd.services.rollback-root = {
    description = "Rollback btrfs @root subvolume (impermanence)";
    wantedBy = [ "initrd-root-device.target" ];
    after = [ "systemd-cryptsetup@cryptroot.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    script = ''
      mkdir -p /mnt-btrfs
      mount -o subvol=/ /dev/mapper/cryptroot /mnt-btrfs
      if [ -e /mnt-btrfs/@root ]; then
        mkdir -p /mnt-btrfs/old_roots
        timestamp=$(date --date="@$(stat -c %Y /mnt-btrfs/@root)" "+%Y-%m-%d_%H:%M:%S")
        mv /mnt-btrfs/@root "/mnt-btrfs/old_roots/$timestamp"
      fi
      delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
          delete_subvolume_recursively "/mnt-btrfs/$i"
        done
        btrfs subvolume delete "$1"
      }
      for i in $(find /mnt-btrfs/old_roots/ -maxdepth 1 -mtime +14); do
        delete_subvolume_recursively "$i"
      done
      btrfs subvolume create /mnt-btrfs/@root
      umount /mnt-btrfs
    '';
  };
}
