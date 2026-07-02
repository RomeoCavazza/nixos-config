{ pkgs, ... }:

let
  nixUnmountUnits = [
    "nix.mount"
    "nix-store.mount"
  ];
  lateRuntimeMountUnits = [
    "run-keys.mount"
    "run-secrets.d.mount"
    "run-wrappers.mount"
  ];
  lazyUnmount = ''
    [Mount]
    LazyUnmount=yes
  '';
  lateRuntimeMount = ''
    [Unit]
    DefaultDependencies=no
  '';
  shutdownMountDropins = pkgs.runCommand "shutdown-mount-dropins" { } (
    builtins.concatStringsSep "\n" (
      (map (unit: ''
        install -D -m 0444 ${pkgs.writeText "lazy-unmount.conf" lazyUnmount} \
          "$out/lib/systemd/system/${unit}.d/lazy-unmount.conf"
      '') nixUnmountUnits)
      ++ (map (unit: ''
        install -D -m 0444 ${pkgs.writeText "runtime-mount.conf" lateRuntimeMount} \
          "$out/lib/systemd/system/${unit}.d/runtime-mount.conf"
      '') lateRuntimeMountUnits)
    )
  );
in

{
  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
  systemd.packages = [ shutdownMountDropins ];
}
