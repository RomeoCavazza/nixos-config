{ config, ... }:

let
  cacheHome = config.xdg.cacheHome;
  configHome = config.xdg.configHome;
  dataHome = config.xdg.dataHome;
  runtimeDir = "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}";
  stateHome = config.xdg.stateHome;
in
{
  home.sessionVariables = {
    ANDROID_USER_HOME = "${dataHome}/android";
    BUNDLE_USER_CACHE = "${cacheHome}/bundle";
    BUNDLE_USER_CONFIG = "${configHome}/bundle";
    BUNDLE_USER_PLUGIN = "${dataHome}/bundle";
    CARGO_HOME = "${dataHome}/cargo";
    CLAUDE_CONFIG_DIR = "${configHome}/claude";
    CUDA_CACHE_PATH = "${cacheHome}/nv";
    DOCKER_CONFIG = "${configHome}/docker";
    DOTNET_CLI_HOME = "${dataHome}/dotnet";
    GOPATH = "${dataHome}/go";
    GRADLE_USER_HOME = "${dataHome}/gradle";
    HISTFILE = "${stateHome}/bash/history";
    MINIKUBE_HOME = "${dataHome}/minikube";
    NODE_REPL_HISTORY = "${stateHome}/node_repl_history";
    NPM_CONFIG_CACHE = "${cacheHome}/npm";
    NPM_CONFIG_INIT_MODULE = "${configHome}/npm/config/npm-init.js";
    NPM_CONFIG_TMP = "${runtimeDir}/npm";
    PLATFORMIO_CORE_DIR = "${dataHome}/platformio";
    PYTHON_HISTORY = "${stateHome}/python/history";
    RUSTUP_HOME = "${dataHome}/rustup";
    USQL_HISTORY = "${stateHome}/usql_history";
  };
}
