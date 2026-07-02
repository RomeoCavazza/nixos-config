_:

{
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="04b5", ATTRS{idProduct}=="6cde", MODE="0666", TAG+="uaccess"

    KERNEL=="ttyACM*", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", MODE="0666", TAG+="uaccess"
  '';
}
