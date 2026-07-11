{ config, pkgs, ... }:

let
  ports = import ../observability/ports.nix;
  gitlabUrl = "http://gitlab.localhost:${toString ports.gitlabProxy}";
in
{

  sops.secrets.gitlab_runner_token = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab-runner";
    group = "gitlab-runner";
    mode = "0400";
  };

  services.gitlab-runner = {
    enable = true;

    settings = {
      concurrent = 4;
      log_level = "info";
      check_interval = 0;
    };

    services = {
      shell-runner = {
        authenticationTokenConfigFile = config.sops.secrets.gitlab_runner_token.path;
        executor = "shell";
        cloneUrl = gitlabUrl;
        buildsDir = "/srv/gitlab-runner/builds";
      };

    };
  };

  systemd.services.gitlab-runner = {
    # The runner verifies its token during startup. GitLab can briefly return
    # 502 while Puma/Workhorse are still becoming ready after boot, so order
    # the units and retry instead of leaving the runner permanently failed.
    after = [ "gitlab.service" ];
    wants = [ "gitlab.service" ];
    serviceConfig = {
      ReadWritePaths = [ "/srv/gitlab-runner" ];
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
  systemd.tmpfiles.rules = [
    "d /srv/gitlab-runner 0750 gitlab-runner gitlab-runner -"
    "d /srv/gitlab-runner/builds 0750 gitlab-runner gitlab-runner -"
  ];

  users.groups.gitlab-runner = { };

  users.users.gitlab-runner = {
    isSystemUser = true;
    group = "gitlab-runner";
    extraGroups = [ "docker" ];
  };

  nix.settings.allowed-users = [ "@gitlab-runner" ];

  environment.systemPackages = with pkgs; [
    gitlab-runner
  ];
}
