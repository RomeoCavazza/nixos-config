{ pkgs, ... }:

let
  lateShutdownMountUnits = [
    "nix.mount"
    "nix-store.mount"
    "run-keys.mount"
    "run-secrets.d.mount"
    "run-wrappers.mount"
  ];
  lateShutdownMount = ''
    [Unit]
    DefaultDependencies=no
  '';
  shutdownMountDropins = pkgs.runCommand "shutdown-mount-dropins" { } (
    builtins.concatStringsSep "\n" (
      map (unit: ''
        install -D -m 0444 ${pkgs.writeText "late-shutdown-mount.conf" lateShutdownMount} \
          "$out/lib/systemd/system/${unit}.d/late-shutdown-mount.conf"
      '') lateShutdownMountUnits
    )
  );
in

{
  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
  systemd.packages = [ shutdownMountDropins ];
}
