{
  description = "NixOS Workstation - Secure & Full Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-legacy.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland/v0.55.4";

    hypr-config = {
      url = "github:RomeoCavazza/hyprland-config";
      flake = false;
    };

    conky-config = {
      url = "github:RomeoCavazza/conky-config";
      flake = false;
    };

    doom-config = {
      url = "github:RomeoCavazza/emacs-config";
      flake = false;
    };

    grafana-config = {
      url = "github:RomeoCavazza/grafana-config";
      flake = false;
    };

    hermes-agent.url = "github:NousResearch/hermes-agent";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";

    nvim-config = {
      url = "github:RomeoCavazza/nvim-config";
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

    stylix.url = "github:nix-community/stylix/release-26.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
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
      locality = import ./lib/locality.nix;
      palette = import ./lib/palette.nix;
      typography = import ./lib/fonts.nix;
      mkApp = import ./flake/mk-app.nix;
      quality = import ./flake/quality.nix {
        inherit
          self
          inputs
          pkgs
          mkApp
          palette
          ;
      };
      mkHost = import ./flake/mk-host.nix {
        inherit
          self
          nixpkgs
          home-manager
          inputs
          system
          locality
          palette
          typography
          ;
      };
    in
    {
      formatter.${system} = quality.formatter;

      devShells.${system}.default = quality.devShell;

      apps.${system} = quality.apps;

      checks.${system} = quality.checks;

      nixosConfigurations = nixpkgs.lib.genAttrs [ "legion" ] mkHost;
    };
}
