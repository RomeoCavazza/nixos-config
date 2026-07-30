{
  config,
  lib,
  pkgs,
  locality,
  ...
}:

let
  ports = import ../observability/ports.nix;
  host = "gitlab.localhost";
  pagesHost = "pages.localhost";
  gitlabCfg = config.services.gitlab;
  sshHostKey = "${gitlabCfg.statePath}/ssh_host_ed25519_key";
in
{

  sops.secrets.gitlab_root_password = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gitlab_secret_key_base = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gitlab_db_key_base = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gitlab_otp_key_base = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gitlab_jws_private_key = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gmail_app_password = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gitlab_ar_primary_key = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gitlab_ar_deterministic_key = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  sops.secrets.gitlab_ar_salt = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab";
    group = "gitlab";
    mode = "0400";
  };

  services.gitlab = {
    enable = true;
    port = ports.gitlabProxy;
    https = false;
    inherit host;

    statePath = "/var/lib/gitlab";

    databaseCreateLocally = true;

    initialRootPasswordFile = config.sops.secrets.gitlab_root_password.path;

    secrets = {
      secretFile = config.sops.secrets.gitlab_secret_key_base.path;
      dbFile = config.sops.secrets.gitlab_db_key_base.path;
      otpFile = config.sops.secrets.gitlab_otp_key_base.path;
      jwsFile = config.sops.secrets.gitlab_jws_private_key.path;
      activeRecordPrimaryKeyFile = config.sops.secrets.gitlab_ar_primary_key.path;
      activeRecordDeterministicKeyFile = config.sops.secrets.gitlab_ar_deterministic_key.path;
      activeRecordSaltFile = config.sops.secrets.gitlab_ar_salt.path;
    };

    smtp = {
      enable = true;
      address = "smtp.gmail.com";
      port = 587;
      username = locality.gitEmail;
      passwordFile = config.sops.secrets.gmail_app_password.path;
      domain = host;
      authentication = "plain";
      enableStartTLSAuto = true;
      tls = false;
    };

    extraConfig = {
      gitlab = {
        email_from = locality.gitEmail;
        email_display_name = "GitLab (legion)";
        email_reply_to = "noreply@${host}";

        default_theme = 2;
        time_zone = "Europe/Paris";
        signup_enabled = false;
      };

      pages = {
        enabled = true;
        host = pagesHost;
        port = ports.gitlabPages;
        https = false;
        access_control = false;
      };

      puma = {
        workers = 4;
        min_threads = 1;
        max_threads = 4;
      };

      sidekiq = {
        concurrency = 8;
      };

      gitlab_shell = {
        ssh_port = ports.gitlabSSH;
      };
    };

    extraShellConfig = {
      audit_usernames = true;
      user = "git";
      sshd = {
        listen = "127.0.0.1:${toString ports.gitlabSSH}";
        web_listen = "localhost:9122";
        host_key_files = [ sshHostKey ];
      };
    };
  };

  users.users.nginx.extraGroups = [ "gitlab" ];

  networking.firewall.allowedTCPPorts = lib.mkAfter [ ports.gitlabSSH ];

  systemd.tmpfiles.rules = [
    "d /run/gitlab/shell 0750 ${gitlabCfg.user} ${gitlabCfg.group} -"
    "L+ /run/gitlab/shell/shell-config.yml - - - - /run/gitlab/shell-config.yml"
  ];

  systemd.services.gitlab-sshd = {
    after = [
      "network.target"
      "gitlab-config.service"
    ];
    wants = [ "gitlab-config.service" ];
    wantedBy = [ "gitlab.target" ];
    partOf = [ "gitlab.target" ];
    serviceConfig = {
      Type = "simple";
      User = gitlabCfg.user;
      Group = gitlabCfg.group;
      Restart = "on-failure";
      Slice = "system-gitlab.slice";
      ExecStartPre = pkgs.writeShellScript "gitlab-sshd-keygen" ''
        set -euo pipefail
        if [ ! -f "${sshHostKey}" ]; then
          ${pkgs.openssh}/bin/ssh-keygen -q -N "" -t ed25519 -f "${sshHostKey}"
        fi
      '';
      ExecStart = "${gitlabCfg.packages.gitlab-shell}/bin/gitlab-sshd -config-dir /run/gitlab/shell";
    };
  };
}
