_:

{
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
}
