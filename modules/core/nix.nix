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

  # Pin the flake registry and legacy nixPath to this flake's locked nixpkgs, so
  # `nix run nixpkgs#x`, `nix shell nixpkgs#x` and nix-shell resolve to the exact
  # same nixpkgs as the system — reproducible, no channel drift.
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

  # After every `nixos-rebuild switch`, print the package diff (previous -> new
  # generation) via nvd — a quick "what changed" report. Idea from gvolpe/nix-config.
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
