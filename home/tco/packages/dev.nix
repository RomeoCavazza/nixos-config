{
  pkgs,
  lib,
  customPkgs,
  ...
}:

{
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-dash
      gh-f
      gh-i
      gh-markdown-preview
      gh-s
    ];
  };

  home.packages = with pkgs; [
    customPkgs.cursor
    customPkgs.repl
    dockfmt
    nixfmt
    shellcheck
    shfmt
    zed-editor
    neovim
    lua
    lua-language-server
    luaPackages.lgi
    aider-chat
    cargo
    openssl
    pkg-config
    rust-analyzer
    rustc
    rustfmt
    black
    isort
    nmap
    pulseview
    (python3.withPackages (
      ps: with ps; [
        pip
        pyglet
        pdfplumber
      ]
    ))
    terraform
    kubeconform
    minikube
    (lib.hiPrio kubectl)
    (lib.lowPrio k3s)
    typescript-language-server
    vscode-langservers-extracted
    tailwindcss-language-server
    nodejs_22
    pnpm
    yarn
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.fr
  ];
}
