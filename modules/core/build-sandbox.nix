_:

{
  # /build is the Nix sandbox build directory (sandbox-build-dir in core/nix.nix).
  # Bind it onto an on-disk path so large builds use /home space instead of tmpfs/RAM.
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
