{ pkgs, ... }:

let
  lazyUnmountUnits = [
    "nix.mount"
    "nix-store.mount"
    "run-keys.mount"
    "run-secrets.d.mount"
    "run-wrappers.mount"
  ];
  lazyUnmount = ''
    [Mount]
    LazyUnmount=yes
  '';
  lazyUnmountDropins = pkgs.runCommand "lazy-unmount-dropins" { } (
    builtins.concatStringsSep "\n" (
      map (unit: ''
        install -D -m 0444 ${pkgs.writeText "lazy-unmount.conf" lazyUnmount} \
          "$out/lib/systemd/system/${unit}.d/lazy-unmount.conf"
      '') lazyUnmountUnits
    )
  );
in

{
  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
  systemd.packages = [ lazyUnmountDropins ];
}
