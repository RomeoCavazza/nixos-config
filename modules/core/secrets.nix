_:

{
  sops.defaultSopsFile = ../../secrets/backup.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.sshKeyPaths = [ ];
}
