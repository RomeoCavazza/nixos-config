{
  description = "NixOS Workstation - Secure & Full Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-portal.url = "github:NixOS/nixpkgs/nixos-26.05";
    
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

    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    hyprtasking.url = "github:raybbian/hyprtasking";
    hyprtasking.inputs.hyprland.follows = "hyprland";

    nix-snapd.url = "github:nix-community/nix-snapd";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  }@inputs:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.legion = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
          flakeSelf = self;
        };

        modules = [
          ./hosts/legion/default.nix
          inputs.nix-snapd.nixosModules.default
          inputs.sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager

          ({ pkgs, lib, ... }:
          let
            customPkgs = import ./pkgs { inherit pkgs inputs; };
          in
          {
            nixpkgs.config.allowUnfreePredicate = pkg:
              builtins.elem (lib.getName pkg) [
                "unrar"
              ];

            nixpkgs.overlays = import ./overlays { inherit inputs system; };

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs customPkgs;
              flakeSelf = self;
            };

            home-manager.users.tco = import ./home/tco/home.nix;
          })
        ];
      };

      # Compat alias for the nixos -> legion rename (rebuild wrapper, muscle memory).
      # Remove in a dedicated run once nothing references #nixos.
      nixosConfigurations.nixos = self.nixosConfigurations.legion;
    };
}
