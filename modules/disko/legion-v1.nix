{
  acknowledgeFreshDiskWipe ? false,
  disk ? throw "modules/disko/legion-v1.nix requires an explicit disk, for example: { disk = \"/dev/vda\"; }",
  luksPasswordFile ? "/tmp/disko-legion.key",
  sizes ? {
    root = "80G";
    nix = "220G";
    home = "220G";
    build = "80G";
    swap = "32G";
  },
}:

if !acknowledgeFreshDiskWipe then
  throw ''
    modules/disko/legion-v1.nix is a fresh-disk VM layout.
    It rewrites the whole target disk as GPT with only ESP + cryptroot.
    Do not use it for the real Legion dual-boot NVMe where Windows must stay intact.
    Pass acknowledgeFreshDiskWipe = true only for disposable VM/test disks.
  ''
else
  {
    disko.devices = {
      disk.legion = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              label = "legion-esp";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            cryptroot = {
              label = "legion-crypt";
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                passwordFile = luksPasswordFile;
                settings = {
                  allowDiscards = true;
                };
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
            size = sizes.root;
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [
                "-L"
                "nixos-root"
              ];
              mountpoint = "/";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };

          nix = {
            size = sizes.nix;
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [
                "-L"
                "nixos-nix"
              ];
              mountpoint = "/nix";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };

          home = {
            size = sizes.home;
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [
                "-L"
                "nixos-home"
              ];
              mountpoint = "/home";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };

          build = {
            size = sizes.build;
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [
                "-L"
                "nixos-build"
              ];
              mountpoint = "/build";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };

          swap = {
            size = sizes.swap;
            content = {
              type = "swap";
              discardPolicy = "both";
              extraArgs = [
                "-L"
                "nixos-swap"
              ];
            };
          };

        };
      };
    };
  }
