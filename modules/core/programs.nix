_:

{
  programs.zoxide.enable = true;

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
