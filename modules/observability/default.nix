{ pkgs, ... }:

{
  imports = [
    ./prometheus.nix
    ./exporters.nix
    ./collectors.nix
    ./loki.nix
    ./promtail.nix
    ./grafana.nix
    ./snapshot-sync.nix
  ];

  environment.systemPackages = with pkgs; [
    prometheus
    loki
    promtail-bin
    imagemagick
  ];
}
