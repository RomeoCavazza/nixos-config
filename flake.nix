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
        repoCheckout =
          let
            envRepo = builtins.getEnv "NIXOS_CONFIG_REPO";
            devRepo = "${homeDirectory}/dev/nixos-config";
          in
          if envRepo != "" then
            envRepo
          else if builtins.pathExists devRepo then
            devRepo
          else if builtins.pathExists "/etc/nixos/flake.nix" then
            "/etc/nixos"
          else
            devRepo;
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

        quality = pkgs.writeShellApplication {
          name = "nixos-config-quality";
          runtimeInputs = [ pkgs.nix ];
          text = ''
            ${fmt-check}/bin/nixos-config-fmt-check
            ${deadnix}/bin/nixos-config-deadnix
            ${statix}/bin/nixos-config-statix
            nix flake check --no-build
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

                home-manager.users.${locality.user} = import ./home/tco;
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
          nil
          nixfmt
          statix
        ];
      };

      apps.${system} = {
        fmt = mkApp qualityScripts.fmt "Format tracked Nix files with nixfmt.";
        fmt-check = mkApp qualityScripts.fmt-check "Check tracked Nix formatting.";
        deadnix = mkApp qualityScripts.deadnix "Fail on unused Nix declarations.";
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
      };

      nixosConfigurations.legion = mkHost "legion";
    };
}
