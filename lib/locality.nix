rec {
  user = "tco";
  homeDirectory = "/home/${user}";
  labApplicationsDir = "${homeDirectory}/Applications";
  devDir = "${homeDirectory}/dev";
  activeConfigRepo = "${devDir}/nixos-config";
  repoCheckout =
    let
      envRepo = builtins.getEnv "NIXOS_CONFIG_REPO";
    in
    if envRepo != "" then
      envRepo
    else if builtins.pathExists "${activeConfigRepo}/.git" then
      activeConfigRepo
    else
      "/etc/nixos";
  gitName = "RomeoCavazza";
  gitEmail = "romeo.cavazza@gmail.com";
  snapshotGitName = "Romeo Cavazza";
  snapshotGitEmail = "romeo.cavazza@users.noreply.github.com";
  snapshotRepoUrl = "git@github.com:RomeoCavazza/nixos-config.git";
  snapshotPublishDir = "/var/lib/grafana-snapshot-sync/nixos-config";
}
