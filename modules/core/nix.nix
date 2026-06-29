{ ... }:

{
  # nix.package is still set in the flake's inline module; it moves here in Run 2B.
  nix.settings = {
    allowed-users = [ "@wheel" "tco" ];
    experimental-features = [ "nix-command" "flakes" ];
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
