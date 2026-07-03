{
  self,
  inputs,
  pkgs,
  mkApp,
}:
let
  scripts = rec {
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

    reuse = pkgs.writeShellApplication {
      name = "nixos-config-reuse";
      runtimeInputs = [ pkgs.reuse ];
      text = ''
        reuse lint
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
        ${reuse}/bin/nixos-config-reuse
        ${grafana-check}/bin/nixos-config-grafana-check
        nix flake archive "$flake_ref"
        nix flake check --no-build "$flake_ref"
      '';
    };
  };
in
{
  inherit scripts;

  formatter = pkgs.nixfmt;

  devShell = pkgs.mkShell {
    packages = with pkgs; [
      deadnix
      jq
      jsonnet
      nil
      nixfmt
      reuse
      statix
    ];
  };

  apps = {
    fmt = mkApp scripts.fmt "Format tracked Nix files with nixfmt.";
    fmt-check = mkApp scripts.fmt-check "Check tracked Nix formatting.";
    deadnix = mkApp scripts.deadnix "Fail on unused Nix declarations.";
    grafana-check = mkApp scripts.grafana-check "Verify generated Grafana dashboards match Jsonnet sources.";
    repo-audit = mkApp scripts.repo-audit "Show flake-input drift against upstream.";
    reuse = mkApp scripts.reuse "Verify REUSE licensing metadata.";
    statix = mkApp scripts.statix "Run configured statix lint checks.";
    quality = mkApp scripts.quality "Run the local quality gate.";
  };

  checks = {
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

    reuse =
      pkgs.runCommand "nixos-config-reuse-check"
        {
          nativeBuildInputs = [ pkgs.reuse ];
          src = self;
        }
        ''
          cp -R "$src" source
          chmod -R u+w source
          cd source
          reuse lint
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
}
