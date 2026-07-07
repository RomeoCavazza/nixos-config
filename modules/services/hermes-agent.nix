{ inputs, config, pkgs, lib, ... }:

{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  services.hermes-agent = {
    enable = true;
    user = "tco";
    group = "users";
    createUser = false;
    addToSystemPackages = true;
  };
}
