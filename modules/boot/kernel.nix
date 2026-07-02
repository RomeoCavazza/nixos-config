_:

{
  boot.kernelModules = [
    "i2c-dev"
    "i2c-i801"
  ];

  boot.kernelParams = [
    "pcie_aspm=off"
    "intel_iommu=on"
    "iommu=pt"
    "page_alloc.shuffle=1"
    "slab_nomerge=yes"
  ];

  boot.blacklistedKernelModules = [
    "iTCO_wdt"
    "iTCO_vendor_support"
  ];
}
