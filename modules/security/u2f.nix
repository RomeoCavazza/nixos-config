{ pkgs, ... }:

{
  security.pam.u2f = {
    control = "sufficient";
    settings = {
      authfile = "/var/lib/pam-u2f/u2f-mappings";
      cue = true;
    };
  };

  security.pam.services.sudo.u2f.enable = true;

  systemd.tmpfiles.rules = [
    "d /var/lib/pam-u2f 0750 root wheel - -"
    "f /var/lib/pam-u2f/u2f-mappings 0640 root wheel - -"
  ];

  environment.systemPackages = [ pkgs.pam_u2f ];
}
