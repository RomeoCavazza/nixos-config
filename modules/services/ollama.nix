{ config, lib, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  systemd.services.ollama.serviceConfig = {
    Environment = [
      "OLLAMA_NUM_CTX=32768"
      "OLLAMA_KEEP_ALIVE=24h"
      "OLLAMA_KV_CACHE_TYPE=q8_0"
    ];
  };
}
