_:

{
  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
}
