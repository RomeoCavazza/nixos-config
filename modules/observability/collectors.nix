{ pkgs, ... }:

let
  repoRoot = ../../.;

  nixMetricsScript = pkgs.writeShellApplication {
    name = "nix-metrics";
    runtimeInputs = [
      pkgs.nix
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.python3
    ];
    text = builtins.readFile (repoRoot + "/config/bin/nix-metrics");
  };

  hyprMetricsScript = pkgs.writeShellApplication {
    name = "hypr-metrics";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile (repoRoot + "/config/bin/hypr-metrics");
  };
in
{
  systemd.services.nix-metrics = {
    description = "Collect Nix store metrics for Prometheus";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nixMetricsScript}/bin/nix-metrics";
    };
  };

  systemd.timers.nix-metrics = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
      Unit = "nix-metrics.service";
    };
  };

  systemd.services.hypr-metrics = {
    description = "Collect Hyprland workspace and window metrics";
    serviceConfig = {
      Type = "oneshot";
      User = "tco";
      ExecStart = "${hyprMetricsScript}/bin/hypr-metrics";
    };
  };

  systemd.timers.hypr-metrics = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "30s";
      Unit = "hypr-metrics.service";
    };
  };
}
