{
  config,
  inputs,
  lib,
  locality,
  pkgs,
  ...
}:

{
  nix.package = pkgs.nixVersions.latest;

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

  nix.settings = {
    allowed-users = [
      "@wheel"
      locality.user
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

  system.activationScripts.reportChanges = ''
    PATH=$PATH:${
      lib.makeBinPath [
        pkgs.nvd
        config.nix.package
      ]
    }
    nvd diff $(ls -dv /nix/var/nix/profiles/system-*-link 2>/dev/null | tail -2) 2>/dev/null || true
  '';
}
