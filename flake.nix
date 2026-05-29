{
  description = "NixOS Workstation - Secure & Full Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Dedicated pin for xdg-desktop-portal workaround.
    # 24.11 is too old because it provides xdg-desktop-portal 1.18.4,
    # while GNOME 50 needs >= 1.19.1.
    nixpkgs-portal.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland/v0.54.2";

    hyprspace.url = "github:RomeoCavazza/Hyprspace";
    hyprspace.inputs.hyprland.follows = "hyprland";

    hyprchroma = {
      url = "github:RomeoCavazza/Hyprchroma/v3.4.0-v054";
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
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
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
              inputs.hyprland.overlays.default

              (final: prev: {
                promtail-bin = pkgs-stable.promtail;
                guix = pkgs-stable.guix;

                # Workaround for xdg-desktop-portal 1.20.4:
                # File chooser breaks with:
                # "Portal operation not allowed: Unable to open /proc/<pid>/root"
                #
                # nixos-24.11 is too old here: xdg-desktop-portal 1.18.4
                # breaks GNOME 50 builds. Use nixos-25.05 instead.
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
            };

            home-manager.users.tco = import ./home/tco/home.nix;
          })
        ];
      };
    };
}
