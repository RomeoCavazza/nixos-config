_:

{
  boot.kernelModules = [
    "i2c-dev"
    "i2c-i801"
  ];

  boot.kernelParams = [
    "pcie_aspm=off"
  ];

  boot.blacklistedKernelModules = [
    "iTCO_wdt"
    "iTCO_vendor_support"
  ];
}
