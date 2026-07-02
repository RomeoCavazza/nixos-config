{
  description = "NixOS Workstation - Secure & Full Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-legacy.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland/v0.55.4";

    hypr-config = {
      url = "github:RomeoCavazza/hyprland-config";
      flake = false;
    };

    conky-config = {
      url = "github:RomeoCavazza/conky-config";
      flake = false;
    };

    doom-config = {
      url = "github:RomeoCavazza/emacs-config";
      flake = false;
    };

    grafana-config = {
      url = "github:RomeoCavazza/grafana-config";
      flake = false;
    };

    nvim-config = {
      url = "github:RomeoCavazza/nvim-config";
      flake = false;
    };

    hyprspace.url = "github:RomeoCavazza/hyprspace/main";
    hyprspace.inputs.hyprland.follows = "hyprland";

    hyprchroma = {
      url = "github:RomeoCavazza/hyprchroma/main";
      flake = false;
    };

    hypr-canvas = {
      url = "github:RomeoCavazza/hypr-canvas/main";
      flake = false;
    };

    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    hyprtasking.url = "github:raybbian/hyprtasking";
    hyprtasking.inputs.hyprland.follows = "hyprland";

    nix-snapd.url = "github:nix-community/nix-snapd";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      locality = rec {
        user = "tco";
        homeDirectory = "/home/${user}";
        labApplicationsDir = "${homeDirectory}/Applications";
        activeConfigRepo = "${homeDirectory}/dev/nixos-config";
        # Runtime path to the deployed checkout for scripts that inspect this repo.
        # Prefer the canonical user checkout over any stale system clone.
        repoCheckout =
          let
            envRepo = builtins.getEnv "NIXOS_CONFIG_REPO";
          in
          if envRepo != "" then
            envRepo
          else if builtins.pathExists "${activeConfigRepo}/.git" then
            activeConfigRepo
          else
            "/etc/nixos";
        gitName = "RomeoCavazza";
        gitEmail = "romeo.cavazza@gmail.com";
        snapshotGitName = "Romeo Cavazza";
        snapshotGitEmail = "romeo.cavazza@users.noreply.github.com";
        snapshotRepoUrl = "git@github.com:RomeoCavazza/nixos-config.git";
        snapshotPublishDir = "/var/lib/grafana-snapshot-sync/nixos-config";
      };
      palette = import ./lib/palette.nix;
      mkApp = package: description: {
        type = "app";
        program = "${package}/bin/${package.meta.mainProgram}";
        meta = { inherit description; };
      };
      qualityScripts = rec {
        fmt = pkgs.writeShellApplication {
          name = "nixos-config-fmt";
          runtimeInputs = [
            pkgs.git
            pkgs.nixfmt
          ];
          text = ''
            git ls-files '*.nix' | xargs nixfmt
          '';
        };

        fmt-check = pkgs.writeShellApplication {
          name = "nixos-config-fmt-check";
          runtimeInputs = [
            pkgs.git
            pkgs.nixfmt
          ];
          text = ''
            git ls-files '*.nix' | xargs nixfmt --check
          '';
        };

        deadnix = pkgs.writeShellApplication {
          name = "nixos-config-deadnix";
          runtimeInputs = [
            pkgs.git
            pkgs.deadnix
          ];
          text = ''
            mapfile -t nix_files < <(git ls-files '*.nix')
            deadnix --fail "''${nix_files[@]}"
          '';
        };

        statix = pkgs.writeShellApplication {
          name = "nixos-config-statix";
          runtimeInputs = [ pkgs.statix ];
          text = ''
            statix check .
          '';
        };

        grafana-check = pkgs.writeShellApplication {
          name = "nixos-config-grafana-check";
          runtimeInputs = [
            pkgs.diffutils
            pkgs.jq
            pkgs.jsonnet
          ];
          text = ''
            grafana_dir="''${GRAFANA_DIR:-${inputs.grafana-config}}"
            tmp_dir="$(mktemp -d)"
            trap 'rm -rf "$tmp_dir"' EXIT

            declare -A mapping=(
              ["nix-dashboard"]="nixos-metrics"
              ["nix-efficiency-dashboard"]="nix-efficiency"
              ["incident-correlation-dashboard"]="incident-correlation"
              ["nixos-compiled"]="nixos-compiled"
            )

            for source in "''${!mapping[@]}"; do
              target="''${mapping[$source]}"
              jsonnet "$grafana_dir/src/$source.jsonnet" | jq . > "$tmp_dir/$target.json"
              diff -u "$grafana_dir/$target.json" "$tmp_dir/$target.json"
            done
          '';
        };

        repo-audit = pkgs.writeShellApplication {
          name = "nixos-config-repo-audit";
          runtimeInputs = [
            pkgs.git
            pkgs.jq
          ];
          text = ''
            repo_dir="''${REPO_DIR:-$PWD}"
            cd "$repo_dir"

            short_rev() {
              local rev="''${1:--}"
              if [[ "$rev" == "-" || -z "$rev" ]]; then
                printf '%s\n' "-"
              else
                printf '%.7s\n' "$rev"
              fi
            }

            status_for() {
              local pinned="$1"
              local upstream="$2"
              if [[ -z "$upstream" || "$upstream" == "-" ]]; then
                printf '%s\n' "unknown"
              elif [[ "$pinned" == "$upstream" ]]; then
                printf '%s\n' "ok"
              else
                printf '%s\n' "drift"
              fi
            }

            remote_head() {
              local url="$1"
              local ref="''${2:-main}"
              git ls-remote "$url" "refs/heads/$ref" 2>/dev/null | awk 'NR == 1 { print $1 }'
            }

            printf 'RomeoCavazza flake inputs\n'
            printf '%-18s %-24s %-10s %-10s %-8s\n' "input" "repo" "locked" "upstream" "status"
            jq -r '
              .nodes
              | to_entries[]
              | select(.value.locked.type? == "github")
              | select(.value.locked.owner? == "RomeoCavazza")
              | select(.value.locked.rev?)
              | [
                  .key,
                  .value.locked.repo,
                  .value.locked.rev,
                  (.value.original.ref? // .value.locked.ref? // "main")
                ]
              | @tsv
            ' flake.lock | while IFS=$'\t' read -r input repo locked ref; do
              upstream="$(remote_head "https://github.com/RomeoCavazza/$repo.git" "$ref")"
              printf '%-18s %-24s %-10s %-10s %-8s\n' \
                "$input" "$repo" "$(short_rev "$locked")" "$(short_rev "$upstream")" "$(status_for "$locked" "$upstream")"
            done
          '';
        };

        quality = pkgs.writeShellApplication {
          name = "nixos-config-quality";
          runtimeInputs = [ pkgs.nix ];
          text = ''
            flake_ref="''${FLAKE_REF:-git+file://$PWD}"

            ${fmt-check}/bin/nixos-config-fmt-check
            ${deadnix}/bin/nixos-config-deadnix
            ${statix}/bin/nixos-config-statix
            ${grafana-check}/bin/nixos-config-grafana-check
            nix flake archive "$flake_ref"
            nix flake check --no-build "$flake_ref"
          '';
        };
      };

      mkHost =
        hostName:
        nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit
              inputs
              locality
              palette
              hostName
              ;
            flakeSelf = self;
          };

          modules = [
            ./hosts/${hostName}/default.nix
            inputs.nix-snapd.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager

            (
              { pkgs, ... }:
              let
                customPkgs = import ./pkgs { inherit pkgs inputs; };
              in
              {
                nixpkgs.overlays = import ./overlays { inherit inputs system; };

                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit
                    inputs
                    customPkgs
                    locality
                    palette
                    ;
                  flakeSelf = self;
                };

                home-manager.users.${locality.user} = import (./home + "/${locality.user}");
              }
            )
          ];
        };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          deadnix
          jq
          jsonnet
          nil
          nixfmt
          statix
        ];
      };

      apps.${system} = {
        fmt = mkApp qualityScripts.fmt "Format tracked Nix files with nixfmt.";
        fmt-check = mkApp qualityScripts.fmt-check "Check tracked Nix formatting.";
        deadnix = mkApp qualityScripts.deadnix "Fail on unused Nix declarations.";
        grafana-check = mkApp qualityScripts.grafana-check "Verify generated Grafana dashboards match Jsonnet sources.";
        repo-audit = mkApp qualityScripts.repo-audit "Show flake-input drift against upstream.";
        statix = mkApp qualityScripts.statix "Run configured statix lint checks.";
        quality = mkApp qualityScripts.quality "Run the local quality gate.";
      };

      checks.${system} = {
        fmt =
          pkgs.runCommand "nixos-config-fmt-check"
            {
              nativeBuildInputs = [ pkgs.nixfmt ];
              src = self;
            }
            ''
              cp -R "$src" source
              chmod -R u+w source
              cd source
              find . -name '*.nix' -print0 | xargs -0 nixfmt --check
              touch "$out"
            '';

        deadnix =
          pkgs.runCommand "nixos-config-deadnix-check"
            {
              nativeBuildInputs = [ pkgs.deadnix ];
              src = self;
            }
            ''
              find "$src" -name '*.nix' -print0 | xargs -0 deadnix --fail
              touch "$out"
            '';

        statix =
          pkgs.runCommand "nixos-config-statix-check"
            {
              nativeBuildInputs = [ pkgs.statix ];
              src = self;
            }
            ''
              cp -R "$src" source
              chmod -R u+w source
              cd source
              statix check .
              touch "$out"
            '';

        grafana =
          pkgs.runCommand "nixos-config-grafana-check"
            {
              nativeBuildInputs = [
                pkgs.diffutils
                pkgs.jq
                pkgs.jsonnet
              ];
              grafanaSrc = inputs.grafana-config;
            }
            ''
              set -euo pipefail
              cp -R "$grafanaSrc" grafana
              chmod -R u+w grafana
              mkdir -p generated

              declare -A mapping=(
                ["nix-dashboard"]="nixos-metrics"
                ["nix-efficiency-dashboard"]="nix-efficiency"
                ["incident-correlation-dashboard"]="incident-correlation"
                ["nixos-compiled"]="nixos-compiled"
              )

              for source in "''${!mapping[@]}"; do
                target="''${mapping[$source]}"
                jsonnet "grafana/src/$source.jsonnet" | jq . > "generated/$target.json"
                diff -u "grafana/$target.json" "generated/$target.json"
              done

              touch "$out"
            '';
      };

      nixosConfigurations = nixpkgs.lib.genAttrs [ "legion" ] mkHost;
    };
}
