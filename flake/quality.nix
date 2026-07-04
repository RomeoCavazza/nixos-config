{
  self,
  inputs,
  pkgs,
  mkApp,
  palette,
}:
let
  colors = import ../lib/colors.nix { inherit (pkgs) lib; };
  grafanaMochaBlock = colors.grafanaMocha palette;
  expectedMochaFile = pkgs.writeText "grafana-mocha-expected.libsonnet" grafanaMochaBlock;
  extractMochaAwk = ''awk '/^local mocha = \{$/{flag=1} flag{print} /^\};$/{if(flag){exit}}' '';
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

    grafana-check = pkgs.writeShellApplication {
      name = "nixos-config-grafana-check";
      runtimeInputs = [
        pkgs.diffutils
        pkgs.gawk
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

        ${extractMochaAwk} "$grafana_dir/src/lib/palette.libsonnet" > "$tmp_dir/mocha-actual.libsonnet"
        diff -u ${expectedMochaFile} "$tmp_dir/mocha-actual.libsonnet"
      '';
    };

    sync-grafana-palette = pkgs.writeShellApplication {
      name = "nixos-config-sync-grafana-palette";
      runtimeInputs = [ pkgs.gawk ];
      text = ''
        repo_dir="''${REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
        if [[ -n "''${GRAFANA_DIR:-}" ]]; then
          grafana_dir="$GRAFANA_DIR"
        elif [[ -d "''${repo_dir}/src" ]]; then
          grafana_dir="$repo_dir"
        else
          echo "ERROR: Grafana Jsonnet sources not found." >&2
          echo "Run from grafana-config, or set GRAFANA_DIR=/path/to/grafana-config." >&2
          exit 1
        fi

        target="''${grafana_dir}/src/lib/palette.libsonnet"
        awk -v block_file=${expectedMochaFile} '
          BEGIN { while ((getline line < block_file) > 0) block = block line "\n"; close(block_file) }
          /^local mocha = \{$/ { printf "%s", block; in_mocha = 1; next }
          in_mocha && /^\};$/ { in_mocha = 0; next }
          in_mocha { next }
          { print }
        ' "$target" > "$target.tmp"
        mv "$target.tmp" "$target"
        echo "Synced mocha palette into $target"
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
        # --no-build only evaluates: on a NixOS module that readFile's a
        # git-fetched input (Hyprland's VERSION, via hyprspace), that requires
        # the source to already be realized in the local store. It happens to
        # be cached here from earlier work, but a fresh checkout/CI runner has
        # nothing to fall back on and errors out on that readFile. Run a real
        # check instead so this is reproducible everywhere.
        nix flake check "$flake_ref"
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
      statix
    ];
  };

  apps = {
    fmt = mkApp scripts.fmt "Format tracked Nix files with nixfmt.";
    fmt-check = mkApp scripts.fmt-check "Check tracked Nix formatting.";
    deadnix = mkApp scripts.deadnix "Fail on unused Nix declarations.";
    grafana-check = mkApp scripts.grafana-check "Verify generated Grafana dashboards match Jsonnet sources.";
    sync-grafana-palette = mkApp scripts.sync-grafana-palette "Sync grafana-config's mocha reference palette from lib/palette.nix.";
    repo-audit = mkApp scripts.repo-audit "Show flake-input drift against upstream.";
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

    grafana =
      pkgs.runCommand "nixos-config-grafana-check"
        {
          nativeBuildInputs = [
            pkgs.diffutils
            pkgs.gawk
            pkgs.jq
            pkgs.jsonnet
          ];
          grafanaSrc = inputs.grafana-config;
          expectedMocha = expectedMochaFile;
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

          ${extractMochaAwk} "grafana/src/lib/palette.libsonnet" > "generated/mocha-actual.libsonnet"
          diff -u "$expectedMocha" "generated/mocha-actual.libsonnet"

          touch "$out"
        '';
  };
}
