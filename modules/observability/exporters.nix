{ ... }:

let
  textfileDir = "/var/lib/node_exporter/textfile_collector";
in
{
  # tco owns the dir so the rebuild wrapper can write nix-rebuild.prom without sudo.
  # nix-metrics runs as root and can write there regardless.
  # node_exporter reads 644 files — no group membership needed.
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 tco users -"
  ];

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "hwmon" "thermal_zone" "pressure" "systemd" ];
    extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
  };

  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9835;
  };
}
