{ pkgs }:

pkgs.python3Packages.buildPythonApplication {
  pname = "terminal-rain-lightning";
  version = "master";

  src = pkgs.fetchFromGitHub {
    owner = "rmaake1";
    repo = "terminal-rain-lightning";
    rev = "master";
    hash = "sha256-GJvGnvo78l4RK2Y9ACbqOXHLQkNtIwIktbm/FK1vOcc=";
  };

  format = "pyproject";

  nativeBuildInputs = with pkgs.python3Packages; [
    setuptools
    wheel
  ];

  doCheck = false;
}
