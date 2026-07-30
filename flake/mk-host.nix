{
  self,
  nixpkgs,
  home-manager,
  inputs,
  system,
  locality,
  palette,
  typography,
}:
hostName:
let
  moduleProfiles = import ../profiles;
  selectedProfiles = import (../hosts + "/${hostName}/profiles.nix");
  selectedModules = import ./select-profiles.nix {
    inherit (nixpkgs) lib;
    inherit moduleProfiles selectedProfiles;
  };
in
nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit
      inputs
      locality
      palette
      typography
      hostName
      ;
    flakeSelf = self;
  };

  modules = [
    (../hosts + "/${hostName}/default.nix")
    inputs.disko.nixosModules.disko
    inputs.nix-snapd.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    inputs.stylix.nixosModules.stylix
    home-manager.nixosModules.home-manager

    (
      { config, pkgs, ... }:
      let
        customPkgs = import ../pkgs { inherit pkgs inputs; };
      in
      {
        nixpkgs.overlays = import ../overlays { inherit inputs system; };

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit
            inputs
            customPkgs
            locality
            palette
            typography
            ;
          inherit (config) theme;
          flakeSelf = self;
        };

        home-manager.users.${locality.user} = {
          imports = selectedModules.home;
        };
      }
    )
  ]
  ++ selectedModules.system;
}
