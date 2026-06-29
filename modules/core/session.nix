{ ... }:

{
  # Kill leftover user processes on logout and cap the unit stop timeout so
  # reboots/shutdowns don't hang on a stuck service.
  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
}
