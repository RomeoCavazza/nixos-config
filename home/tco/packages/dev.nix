{
  pkgs,
  lib,
  customPkgs,
  ...
}:

{
  home.packages = with pkgs; [
    customPkgs.cursor
    dockfmt
    nixfmt
    shellcheck
    shfmt
    zed-editor
    neovim
    gh
    lua
    lua-language-server
    luaPackages.lgi
    lazygit
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
