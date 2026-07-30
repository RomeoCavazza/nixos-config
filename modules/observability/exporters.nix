{ locality, ... }:

let
  inherit (locality) user;
  ports = import ./ports.nix;
  textfileDir = "/var/lib/node_exporter/textfile_collector";
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 ${user} users -"
  ];

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = ports.node;
    enabledCollectors = [
      "hwmon"
      "thermal_zone"
      "pressure"
      "systemd"
    ];
    extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
  };

  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = ports.nvidia;
  };
}
