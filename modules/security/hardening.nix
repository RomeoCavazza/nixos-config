{ lib, ... }:

{
  security.apparmor.enable = true;
  security.protectKernelImage = true;
  systemd.coredump.enable = false;
  # Discard kernel core dumps too; disabling the collector alone leaves core.PID files.
  boot.kernel.sysctl."kernel.core_pattern" = lib.mkForce "|/run/current-system/sw/bin/false";
}
