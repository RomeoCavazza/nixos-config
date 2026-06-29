{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (python313.withPackages (
      ps: with ps; [
        pydantic
        anyio
        smbus2
        pyserial
      ]
    ))
  ];
}
