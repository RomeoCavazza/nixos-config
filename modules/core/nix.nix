{ pkgs, ... }:

{
  nix.package = pkgs.nixVersions.latest;

  nix.settings = {
    allowed-users = [
      "@wheel"
      "tco"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    warn-dirty = false;
    download-buffer-size = 268435456;
    sandbox = true;
    sandbox-build-dir = "/build";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
