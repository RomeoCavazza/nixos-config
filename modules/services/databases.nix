{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # POSTGRESQL 17 (Local Dev)
  # ============================================================================
  services.postgresql = {
    enable  = true;
    package = pkgs.postgresql_17;
    dataDir = "/var/lib/postgresql/17";

    # Extensions
    extensions = with pkgs.postgresql_17.pkgs; [ postgis ];

    # Network Security: Bind strictly to localhost IPv4
    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
    };

    # Authentication Configuration
    authentication = pkgs.lib.mkOverride 10 ''
      # type  database  user      address       method
      local   all       postgres                peer
      local   all       all                     md5
      host    all       all       127.0.0.1/32  md5
      host    all       all       ::1/128       md5
    '';
  };

  # ============================================================================
  # REDIS (Cache Service)
  # ============================================================================
  services.redis.servers.insider = {
    enable = true;
    port   = 6379;
    bind   = "127.0.0.1";

    settings = {
      appendonly = "yes";
      save = [ "900 1" "300 10" "60 10000" ];
      maxmemory = "2gb";
      maxmemory-policy = "allkeys-lru";
      loglevel = "notice";
      protected-mode = "yes";
      tcp-keepalive = "60";
      notify-keyspace-events = "Ex";
    };
  };

  # ============================================================================
  # Qdrant (RAG Nvim)
  # ============================================================================
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
