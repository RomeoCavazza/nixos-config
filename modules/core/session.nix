{ pkgs, ... }:

let
  lazyUnmount = ''
    [Mount]
    LazyUnmount=yes
  '';
  nixLazyUnmountDropins = pkgs.runCommand "nix-lazy-unmount-dropins" { } ''
    install -D -m 0444 ${pkgs.writeText "lazy-unmount.conf" lazyUnmount} \
      "$out/lib/systemd/system/nix.mount.d/lazy-unmount.conf"
    install -D -m 0444 ${pkgs.writeText "lazy-unmount.conf" lazyUnmount} \
      "$out/lib/systemd/system/nix-store.mount.d/lazy-unmount.conf"
  '';
in

{
  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
  systemd.packages = [ nixLazyUnmountDropins ];
}
