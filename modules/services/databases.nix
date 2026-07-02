{ pkgs, lib, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    dataDir = "/var/lib/postgresql/17";

    extensions = with pkgs.postgresql_17.pkgs; [ postgis ];

    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
      password_encryption = "scram-sha-256";
    };

    authentication = pkgs.lib.mkOverride 10 ''
      # type  database  user      address       method
      local   all       postgres                peer
      local   all       all                     scram-sha-256
      host    all       all       127.0.0.1/32  scram-sha-256
      host    all       all       ::1/128       scram-sha-256
    '';
  };

  services.redis.servers.insider = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";

    settings = {
      appendonly = "yes";
      save = [
        "900 1"
        "300 10"
        "60 10000"
      ];
      maxmemory = "2gb";
      maxmemory-policy = "allkeys-lru";
      loglevel = "notice";
      protected-mode = "yes";
      tcp-keepalive = "60";
      notify-keyspace-events = "Ex";
    };
  };

  services.qdrant = {
    enable = true;
    settings = {
      service = {
        host = "127.0.0.1";
        http_port = 6333;
      };
      storage = {
        storage_path = "/var/lib/qdrant";
      };
    };
  };
}
