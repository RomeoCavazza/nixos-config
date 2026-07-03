_:

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
                type = "lvm_pv";
                vg = "legion";
              };
            };
          };
        };
      };
    };

    lvm_vg.legion = {
      type = "lvm_vg";
      lvs = {
        root = {
          size = "80G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "defaults" ];
          };
        };

        home = {
          size = "220G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/home";
            mountOptions = [
              "nodev"
              "nosuid"
            ];
          };
        };

        build = {
          size = "80G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/build";
            mountOptions = [ "nodev" ];
          };
        };

        swap = {
          size = "32G";
          content = {
            type = "swap";
          };
        };

        nix = {
          size = "100%FREE";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/nix";
            mountOptions = [ "nodev" ];
          };
        };
      };
    };
  };
}
