{ pkgs, lib, ... }:

let
  lateShutdownMountUnits = [
    "nix.mount"
    "nix-store.mount"
    "run-keys.mount"
    "run-secrets.d.mount"
    "run-wrappers.mount"
  ];
  silencedMountUnits = [
    "nix.mount"
    "nix-store.mount"
  ];
  dropinFor =
    unit:
    ''
      [Unit]
      DefaultDependencies=no
    ''
    + lib.optionalString (builtins.elem unit silencedMountUnits) ''

      [Mount]
      LogLevelMax=crit
    '';
  shutdownMountDropins = pkgs.runCommand "shutdown-mount-dropins" { } (
    builtins.concatStringsSep "\n" (
      map (unit: ''
        install -D -m 0444 ${pkgs.writeText "late-shutdown-mount.conf" (dropinFor unit)} \
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
