_:

{
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.i2c.enable = true;
  services.hardware.openrgb.enable = true;
}
