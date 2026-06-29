{ ... }:

{
  services.udev.extraRules = ''
    # Hantek 6074BC USB Raw
    SUBSYSTEM=="usb", ATTRS{idVendor}=="04b5", ATTRS{idProduct}=="6cde", MODE="0666", TAG+="uaccess"

    # TinySA Ultra TTY/ACM
    KERNEL=="ttyACM*", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", MODE="0666", TAG+="uaccess"
  '';
}
