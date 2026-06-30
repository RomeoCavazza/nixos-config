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

  # Observability CLI tools (kept grouped here rather than split per service).
  environment.systemPackages = with pkgs; [
    prometheus
    loki
    promtail-bin
    imagemagick
  ];
}
