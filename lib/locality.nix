rec {
  user = "tco";
  homeDirectory = "/home/${user}";
  labApplicationsDir = "${homeDirectory}/Applications";
  devDir = "${homeDirectory}/dev";
  activeConfigRepo = "/etc/nixos";
  repoCheckout =
    let
      envRepo = builtins.getEnv "NIXOS_CONFIG_REPO";
    in
    if envRepo != "" then envRepo else activeConfigRepo;
  gitName = "RomeoCavazza";
  gitEmail = "romeo.cavazza@gmail.com";
  snapshotGitName = "Romeo Cavazza";
  snapshotGitEmail = "romeo.cavazza@users.noreply.github.com";
  snapshotRepoUrl = "git@github.com:RomeoCavazza/nixos-config.git";
  snapshotPublishDir = "/var/lib/grafana-snapshot-sync/nixos-config";
}
