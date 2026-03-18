{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ==========================================================================
    # EMBEDDED SYSTEMS / IOT
    # ==========================================================================
    arduino-ide
    arduino-cli
    esptool  # ESP8266/ESP32 Flasher
    minicom  # Serial Monitor
  ];
}
