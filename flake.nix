{
  description = "NixOS Workstation - Secure & Full Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland/v0.54.2";
    hyprspace.url = "path:./home/tco/pkgs/hyprspace-fork";
    hyprspace.inputs.hyprland.follows = "hyprland";
    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";
    hyprtasking.url = "github:raybbian/hyprtasking";
    hyprtasking.inputs.hyprland.follows = "hyprland";
    nix-snapd.url = "github:nix-community/nix-snapd";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs-stable = import nixpkgs-stable { inherit system; config.allowUnfree = true; };
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          inputs.nix-snapd.nixosModules.default
          inputs.sops-nix.nixosModules.sops
          ./modules/backup.nix
          home-manager.nixosModules.home-manager
          {
            # FORCE L'UPDATE DE NIX VERS LA VERSION PATCHÉE
            nix.package = nixpkgs.legacyPackages.${system}.nixVersions.latest;
            
            nixpkgs.overlays = [
              (import inputs.rust-overlay)
              inputs.hyprland.overlays.default
              (final: prev: {
                # On bypass le nom 'promtail' pour éviter le conflit d'option
                promtail-bin = pkgs-stable.promtail;
                guix = pkgs-stable.guix;
              })
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.tco = import ./home/tco/home.nix;
          }
        ];
      };
    };
}
