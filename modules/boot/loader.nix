_:

{
  # boot.loader.systemd-boot is force-disabled by modules/security/secure-boot.nix
  # (Lanzaboote replaces it and reads configurationLimit/timeout as its own
  # defaults). Its extraInstallCommands never runs; the real timeout is set in
  # boot.lanzaboote.settings.timeout.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.editor = false;
  boot.loader.systemd-boot.configurationLimit = 1;
  boot.loader.timeout = 0;
  boot.loader.efi.canTouchEfiVariables = true;
}
