{ pkgs, ... }:

{
  services.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
    startWithUserSession = "graphical";
    client.enable = true;
  };

  home.packages = with pkgs; [
    emacs-pgtk
    clang
    cmake
    gnumake
    libtool
    sqlite
    nil
    bash-language-server
    pandoc
    (texlive.combine {
      inherit (texlive)
        scheme-medium
        wrapfig
        ulem
        capt-of
        hyperref
        ;
    })
  ];
}
