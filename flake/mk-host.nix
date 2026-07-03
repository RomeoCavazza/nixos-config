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
    ../hosts/${hostName}/default.nix
    inputs.disko.nixosModules.disko
    inputs.nix-snapd.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    home-manager.nixosModules.home-manager

    (
      { pkgs, ... }:
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
          flakeSelf = self;
        };

        home-manager.users.${locality.user} = import (../home + "/${locality.user}");
      }
    )
  ];
}
