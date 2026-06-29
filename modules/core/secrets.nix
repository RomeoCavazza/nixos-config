{ ... }:

{
  # The source file is committed encrypted with SOPS.
  sops.defaultSopsFile = ../../secrets/backup.yaml;
  # Decrypt with a dedicated machine Age identity kept outside the repo.
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.sshKeyPaths = [ ];
}
