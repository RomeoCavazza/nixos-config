{
  acknowledgeRealNvmeMigration ? false,
  disk ? "/dev/disk/by-id/nvme-WD_PC_SN8000S_SDEPNRK-1T00-1101_25100D4A7S01",
  luksPasswordFile ? "/tmp/disko-legion.key",
  geometry ? {
    esp = {
      start = "2048s";
      end = "534527s";
    };
    msr = {
      start = "534528s";
      end = "567295s";
    };
    windows = {
      start = "567296s";
      end = "946300927s";
    };
    winre = {
      start = "1996312576s";
      end = "2000408575s";
    };
    cryptroot = {
      start = "946300928s";
      end = "1996312575s";
    };
  },
  sizes ? {
    root = "80G";
    nix = "220G";
    home = "220G";
    build = "80G";
    swap = "32G";
  },
}:

if !acknowledgeRealNvmeMigration then
  throw ''
    modules/disko/legion-preserve-windows.nix models the real Legion NVMe migration.
    It preserves partitions 1..4 and replaces the current Linux area with cryptroot.
    Do not import it until the migration preflight has confirmed the exact disk, sectors and backup state.
  ''
else
  {
    disko.devices = {
      disk.legion = {
        type = "disk";
        device = disk;
        destroy = false;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 10;
              label = "EFI system partition";
              uuid = "6486f8bd-126f-4045-bdf4-ba81ded35f90";
              type = "EF00";
              start = geometry.esp.start;
              end = geometry.esp.end;
              alignment = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };

            msr = {
              priority = 20;
              label = "Microsoft reserved partition";
              uuid = "5e27aa97-9a00-4d66-bb19-e0dde0039692";
              type = "e3c9e316-0b5c-4db8-817d-f92df00215ae";
              start = geometry.msr.start;
              end = geometry.msr.end;
              alignment = 1;
            };

            windows = {
              priority = 30;
              label = "Basic data partition";
              uuid = "0ba9753e-2b9a-4b49-928b-0e2f63b93ab7";
              type = "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7";
              start = geometry.windows.start;
              end = geometry.windows.end;
              alignment = 1;
            };

            winre = {
              priority = 40;
              label = "Basic data partition";
              uuid = "c41f63b4-3799-4248-8246-e18167b39b0f";
              type = "de94bba4-06d1-4d40-a16a-bfd50179d6ac";
              start = geometry.winre.start;
              end = geometry.winre.end;
              alignment = 1;
            };

            cryptroot = {
              priority = 50;
              label = "legion-crypt";
              type = "ca7d7ccb-63ed-4c53-861c-1742536059cc";
              start = geometry.cryptroot.start;
              end = geometry.cryptroot.end;
              alignment = 1;
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
