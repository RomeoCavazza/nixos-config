{
  description = "NixOS Workstation Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    hyprchroma.url = "github:alexhulbert/hyprchroma";    
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, rust-overlay, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ (import rust-overlay) ];
      };
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              (import rust-overlay)
              (final: prev: {
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

      devShells.${system} = {
        ai = pkgs.mkShell {
          name = "ai-lab";
          buildInputs = with pkgs; [
            python311 git
            stdenv.cc.cc.lib zlib glib
            linuxPackages.nvidia_x11
            python311Packages.pip
          ];
          shellHook = ''
            export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.linuxPackages.nvidia_x11}/lib:$LD_LIBRARY_PATH
          '';
        };

        embedded = pkgs.mkShell {
          name = "embedded-lab";
          buildInputs = with pkgs; [
            (rust-bin.stable.latest.default.override { extensions = [ "rust-src" "rust-analyzer" ]; })
            cargo-watch
            gcc clang cmake gnumake gdb
            arduino-ide arduino-cli esptool openocd minicom
            mosquitto
          ];
        };
      };
    };
}
