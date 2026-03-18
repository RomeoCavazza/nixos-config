{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ==========================================================================
    # DATA & OBSERVABILITY
    # ==========================================================================
    dbeaver-bin # Universal Database Tool
    grafana
    influxdb2
  ];
}
