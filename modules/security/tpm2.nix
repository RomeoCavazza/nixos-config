{
  config,
  pkgs,
  ...
}:

{
  boot.initrd.systemd.tpm2.enable = true;
  systemd.tpm2.enable = true;

  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  system.build.tpm2UnlockCheck = pkgs.writeShellApplication {
    name = "tpm2-unlock-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.cryptsetup
      pkgs.gnugrep
      pkgs.gnused
      pkgs.systemd
      pkgs.tpm2-tools
    ];
    text = ''
      warnings=0
      failures=0
      luks_device="/dev/disk/by-partlabel/legion-crypt"

      ok() { printf '[ok] %s\n' "$*"; }
      warn() { printf '[warn] %s\n' "$*"; warnings=$((warnings + 1)); }
      fail() { printf '[fail] %s\n' "$*"; failures=$((failures + 1)); }

      if [[ -c /dev/tpmrm0 ]]; then
        ok "TPM resource manager is available at /dev/tpmrm0"
      elif [[ -c /dev/tpm0 ]]; then
        warn "TPM is available at /dev/tpm0, but /dev/tpmrm0 is missing"
      else
        fail "no TPM device found"
      fi

      if systemctl --version | grep -q '+TPM2'; then
        ok "systemd was built with TPM2 support"
      else
        fail "systemd does not report TPM2 support"
      fi

      if systemd-cryptenroll --help | grep -q -- '--tpm2-device'; then
        ok "systemd-cryptenroll supports TPM2 enrollment"
      else
        fail "systemd-cryptenroll does not expose TPM2 enrollment"
      fi

      if [[ -e "$luks_device" ]]; then
        ok "LUKS device exists at $luks_device"
      else
        fail "LUKS device is missing at $luks_device"
      fi

      if tpm2_pcrread sha256:7 >/dev/null 2>&1; then
        ok "TPM PCR 7 is readable"
      else
        warn "TPM PCR 7 is not readable as this user; retry with sudo after rebuild if needed"
      fi

      if [[ "$EUID" -ne 0 ]]; then
        warn "run with sudo to inspect LUKS TPM2 tokens"
      elif [[ -e "$luks_device" ]]; then
        luks_dump="$(cryptsetup luksDump "$luks_device" 2>/dev/null || true)"
        if [[ -z "$luks_dump" ]]; then
          fail "cryptsetup could not read LUKS metadata from $luks_device"
        elif grep -qi 'systemd-tpm2' <<< "$luks_dump"; then
          ok "LUKS has a systemd-tpm2 token enrolled"
        else
          warn "no systemd-tpm2 token enrolled yet"
          warn "enroll manually with: sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 $luks_device"
        fi
      fi

      if [[ "$failures" -gt 0 ]]; then
        printf 'tpm2-unlock-check: %s failure(s), %s warning(s)\n' "$failures" "$warnings" >&2
        exit 1
      fi
      if [[ "$warnings" -gt 0 ]]; then
        printf 'tpm2-unlock-check: %s warning(s), no mutation performed\n' "$warnings" >&2
      else
        ok "TPM2 unlock readiness passed without warnings"
      fi
    '';
  };

  environment.systemPackages = [
    pkgs.tpm2-tools
    config.system.build.tpm2UnlockCheck
  ];
}
