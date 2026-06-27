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

    hyprspace.url = "github:RomeoCavazza/hyprspace/fix/hyprland-055";
    hyprspace.inputs.hyprland.follows = "hyprland";

    hyprchroma = {
      url = "github:RomeoCavazza/hyprchroma";
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
    nixpkgs-stable,
    nixpkgs-portal,
    nixpkgs-legacy,
    home-manager,
    ...
  }@inputs:
    let
      system = "x86_64-linux";

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs-portal = import nixpkgs-portal {
        inherit system;
        config.allowUnfree = true;
      };

      # Création du channel legacy
      pkgs-legacy = import nixpkgs-legacy {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
          flakeSelf = self;
        };

        modules = [
          ./configuration.nix
          inputs.nix-snapd.nixosModules.default
          inputs.sops-nix.nixosModules.sops
          ./modules/backup.nix
          home-manager.nixosModules.home-manager

          ({ pkgs, lib, ... }: {
            nix.package = pkgs.nixVersions.latest;

            nixpkgs.config.allowUnfreePredicate = pkg:
              builtins.elem (lib.getName pkg) [
                "unrar"
              ];

            nixpkgs.overlays = [
              (import inputs.rust-overlay)

              (final: prev: {
                hyprland = inputs.hyprland.packages.${system}.hyprland;
                hyprland-unwrapped = inputs.hyprland.packages.${system}.hyprland-unwrapped;
                xdg-desktop-portal-hyprland = inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;

                promtail-bin = pkgs-legacy.promtail;
                
                guix = pkgs-stable.guix;
                xdg-desktop-portal = pkgs-portal.xdg-desktop-portal;
                xdg-desktop-portal-gtk = pkgs-portal.xdg-desktop-portal-gtk;
                xdg-desktop-portal-gnome = pkgs-portal.xdg-desktop-portal-gnome;
              })
            ];

            environment.systemPackages = with pkgs; [
              unrar
              usbutils
              pciutils
            ];

            users.users.tco.extraGroups = [
              "dialout"
              "plugdev"
            ];

            services.udev.packages = [ ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              flakeSelf = self;
            };

            home-manager.users.tco = import ./home/tco/home.nix;
          })
        ];
      };
    };
}
