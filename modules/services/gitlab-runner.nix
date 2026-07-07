{ config, pkgs, ... }:

let
  ports = import ../observability/ports.nix;
  gitlabUrl = "http://gitlab.localhost:${toString ports.gitlabProxy}";
in
{
  # ─── Secrets ────────────────────────────────────────────────────────────────
  # Le fichier doit contenir les variables d'env au format :
  #   CI_SERVER_URL=http://gitlab.localhost:8930
  #   CI_SERVER_TOKEN=glrt-xxxxxxxxxxxx
  # À renseigner dans SOPS après le premier boot de GitLab
  # (Admin > CI/CD > Runners > New instance runner > copy token)

  sops.secrets.gitlab_runner_token = {
    sopsFile = ../../secrets/gitlab.yaml;
    owner = "gitlab-runner";
    group = "gitlab-runner";
    mode = "0400";
  };

  # ─── Service gitlab-runner ───────────────────────────────────────────────────

  services.gitlab-runner = {
    enable = true;

    settings = {
      concurrent = 4; # jusqu'à 4 jobs simultanés (Ultra 9 275HX)
      log_level = "info";
      check_interval = 0;
    };

    services = {
      # Runner shell — pour les jobs simples sur la machine host
      shell-runner = {
        # Mode "authentication token" (GitLab ≥ 16.x — plus de registration tokens)
        # Le fichier contient :
        #   CI_SERVER_URL=http://gitlab.localhost:8930
        #   CI_SERVER_TOKEN=glrt-xxxxxxxxxxxx
        authenticationTokenConfigFile = config.sops.secrets.gitlab_runner_token.path;
        executor = "shell";
        cloneUrl = gitlabUrl;
      };

      # Runner Docker — pour les images CI reproductibles
      docker-runner = {
        authenticationTokenConfigFile = config.sops.secrets.gitlab_runner_token.path;
        executor = "docker";
        cloneUrl = gitlabUrl;

        dockerImage = "nixos/nix:latest";

        dockerVolumes = [
          "/nix/store:/nix/store:ro" # partage du store Nix → builds rapides
          "/var/run/docker.sock:/var/run/docker.sock"
        ];

        dockerPrivileged = false;
      };
    };
  };

  # Groupe gitlab-runner (requis explicitement sur NixOS)
  users.groups.gitlab-runner = { };

  # Accès Docker pour les jobs Docker
  users.users.gitlab-runner = {
    isSystemUser = true;
    group = "gitlab-runner";
    extraGroups = [ "docker" ];
  };

  # Autoriser gitlab-runner à utiliser le démon Nix pour les jobs CI/CD
  nix.settings.allowed-users = [ "@gitlab-runner" ];

  # ─── Packages utiles pour les runners ───────────────────────────────────────
  environment.systemPackages = with pkgs; [
    gitlab-runner
  ];
}
