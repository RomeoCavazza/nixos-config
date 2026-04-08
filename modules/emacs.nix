{ config, pkgs, ... }:

{
  # ============================================================================
  # EMACS DAEMON
  # ============================================================================
  # Starts Emacs server on login for instant client startup
  services.emacs.enable = true;
  services.emacs.package = pkgs.emacs-pgtk; # Pure GTK build (Wayland native)

  # ============================================================================
  # TOOLCHAIN & DEPENDENCIES
  # ============================================================================
  environment.systemPackages = with pkgs; [
    # Core Editor
    emacs-pgtk

    # Performance / Compilation Tools (Required for vterm, treesitter)
    ripgrep
    fd
    clang
    cmake
    gnumake
    libtool
    sqlite

    # LSP & Language Servers (Minimal set, others via devShells)
    nil # Nix LSP
    bash-language-server

    # Publishing & Org-Mode Tools
    pandoc
    graphviz

    # LaTeX (Medium scheme to balance size/features)
    (texlive.combine {
      inherit (texlive)
        scheme-medium
        wrapfig
        ulem
        capt-of
        hyperref;
    })
  ];
}
