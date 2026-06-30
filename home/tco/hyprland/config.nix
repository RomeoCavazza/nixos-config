{ inputs, ... }:

{
  home.file.".config/hypr" = {
    source = inputs.hypr-config;
    force = true;
  };
}
