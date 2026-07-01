{
  config,
  lib,
  ...
}:

let
  cfg = config.local.buildSandbox.bindMount;
in
{
  options.local.buildSandbox.bindMount.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Bind /home/nix-build to /build for hosts without a dedicated /build filesystem.";
  };

  config = lib.mkIf cfg.enable {
    # --- Build Sandbox ---
    systemd.tmpfiles.rules = [
      "d /home/nix-build 2775 root nixbld - -"
    ];

    fileSystems."/build" = {
      device = "/home/nix-build";
      fsType = "none";
      options = [
        "bind"
        "x-systemd.requires-mounts-for=/home"
        "x-systemd.mkdir"
      ];
      neededForBoot = false;
    };
  };
}
