{
  config,
  inputs,
  lib,
  locality,
  pkgs,
  ...
}:

let
  pruneOldGenerations = pkgs.writeShellApplication {
    name = "prune-old-generations";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.nix
    ];
    text = ''
      min_generations=5
      max_age_seconds=$((7 * 86400))
      now=$(date +%s)

      prune_profile() {
        local profile="$1"
        [[ -e "$profile" || -L "$profile" ]] || return 0

        mapfile -t gen_ids < <(nix-env -p "$profile" --list-generations 2>/dev/null | awk '{print $1}' | tac)
        local -a to_delete=()
        for gen in "''${gen_ids[@]:$min_generations}"; do
          local link="''${profile}-''${gen}-link"
          [[ -e "$link" || -L "$link" ]] || continue
          (( now - $(stat -c %Y "$link" 2>/dev/null || echo "$now") > max_age_seconds )) && to_delete+=("$gen")
        done

        (( ''${#to_delete[@]} > 0 )) && nix-env -p "$profile" --delete-generations "''${to_delete[@]}" 2>/dev/null || true
      }

      prune_profile "/nix/var/nix/profiles/system"
      for hm_profile in /nix/var/nix/profiles/per-user/*/home-manager; do
        prune_profile "$hm_profile"
      done
    '';
  };
in
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
    options = "";
  };

  systemd.services.nix-gc = {
    serviceConfig.ExecStartPre = lib.getExe pruneOldGenerations;
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
