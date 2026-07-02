{ pkgs, ... }:

let
  nixMountUsers = [
    "dbus-broker.service"
    "dbus.socket"
    "display-manager.service"
    "loki.service"
    "prometheus.service"
    "prometheus-node-exporter.service"
    "prometheus-nvidia-gpu-exporter.service"
    "promtail.service"
    "user@1000.service"
  ];
  nixMountOrdering = ''
    [Unit]
    Before=${builtins.concatStringsSep " " nixMountUsers}
  '';
  nixMountOrderingDropins = pkgs.runCommand "nix-mount-ordering-dropins" { } ''
    mkdir -p \
      "$out/lib/systemd/system/nix-store.mount.d" \
      "$out/lib/systemd/system/nix.mount.d"
    cp ${pkgs.writeText "nix-mount-ordering.conf" nixMountOrdering} \
      "$out/lib/systemd/system/nix-store.mount.d/ordering.conf"
    cp ${pkgs.writeText "nix-mount-ordering.conf" nixMountOrdering} \
      "$out/lib/systemd/system/nix.mount.d/ordering.conf"
  '';
in

{
  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
  systemd.packages = [ nixMountOrderingDropins ];
}
