_:

{
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # I2C bus + OpenRGB (DDC/CI brightness and RGB peripheral control).
  # The matching i2c-dev/i2c-i801 kernel modules live in the boot module.
  hardware.i2c.enable = true;
  services.hardware.openrgb.enable = true;
}
