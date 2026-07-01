{
  config,
  lib,
  pkgs,
  ...
}:

let
  lanzabooteSrc = builtins.fetchTarball {
    url = "https://github.com/nix-community/lanzaboote/archive/refs/tags/v1.1.0.tar.gz";
    sha256 = "0rgjccwwzfanbf5chx91grmi8v9cgxgsm963ldkdnkh445as7a46";
  };
  lanzaboote = import lanzabooteSrc { inherit pkgs; };
  lzbtNixOSMenuTitle = lanzaboote.packages.lzbt.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      grep -q 'generation.describe()' shared/src/os_release.rs
      sed -i '40,44c\            generation.spec.bootspec.bootspec.label.clone()' shared/src/os_release.rs
      substituteInPlace systemd/tests/integration/os_release.rs \
        --replace-fail 'PRETTY_NAME=LanzaOS (Generation 1, 1970-01-01)' 'PRETTY_NAME=LanzaOS'
    '';
  });
in

{
  imports = [ lanzaboote.nixosModules.lanzaboote ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    package = lzbtNixOSMenuTitle;
    pkiBundle = "/var/lib/sbctl";
    settings = {
      timeout = "menu-force";
      auto-entries = false;
      auto-firmware = true;
    };
  };

  system.build.secureBootDryRun = pkgs.writeShellApplication {
    name = "secure-boot-dry-run";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.sbctl
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      warnings=0
      workdir="$(mktemp -d -t secure-boot-dry-run.XXXXXX)"
      trap 'rm -rf "$workdir"' EXIT
      bootctl_output="$workdir/bootctl"
      sbctl_output="$workdir/sbctl"

      ok() { printf '[ok] %s\n' "$*"; }
      warn() { printf '[warn] %s\n' "$*"; warnings=$((warnings + 1)); }

      if [[ "$EUID" -ne 0 ]]; then
        warn "run with sudo for complete ESP and EFI variable visibility"
      fi

      if [[ -d /sys/firmware/efi ]]; then
        ok "booted through UEFI"
      else
        warn "system was not booted through UEFI"
      fi

      if bootctl status --no-pager >"$bootctl_output" 2>&1; then
        ok "bootctl status is readable"
      else
        warn "bootctl status returned a warning or permission issue"
      fi

      if grep -q 'Secure Boot: disabled' "$bootctl_output" 2>/dev/null; then
        warn "Secure Boot is disabled"
      elif grep -q 'Secure Boot: enabled' "$bootctl_output" 2>/dev/null; then
        ok "Secure Boot is enabled"
      else
        warn "Secure Boot state was not found in bootctl output"
      fi

      if sbctl status >"$sbctl_output" 2>&1; then
        ok "sbctl status is readable"
      else
        warn "sbctl status returned a warning or permission issue"
      fi

      if grep -qi 'Secure Boot.*Disabled' "$sbctl_output" 2>/dev/null; then
        warn "sbctl reports Secure Boot disabled"
      fi
      if grep -qi 'Setup Mode.*Enabled' "$sbctl_output" 2>/dev/null; then
        warn "firmware appears to be in setup mode"
      fi

      boot_source="$(findmnt -no SOURCE /boot 2>/dev/null || true)"
      boot_fstype="$(findmnt -no FSTYPE /boot 2>/dev/null || true)"
      if [[ -n "$boot_source" ]]; then
        ok "/boot mounted from $boot_source ($boot_fstype)"
      else
        warn "/boot mount was not detected"
      fi

      if [[ ${if config.boot.lanzaboote.enable or false then "1" else "0"} -eq 1 ]]; then
        ok "NixOS uses Lanzaboote"
      elif [[ ${if config.boot.loader.systemd-boot.enable or false then "1" else "0"} -eq 1 ]]; then
        ok "NixOS uses systemd-boot"
      else
        warn "Neither Lanzaboote nor systemd-boot is enabled"
      fi

      if [[ -d /var/lib/sbctl ]]; then
        ok "sbctl key bundle directory exists at /var/lib/sbctl"
      else
        warn "sbctl key bundle directory is missing; run: sudo sbctl create-keys"
      fi

      warn "no firmware keys enrolled by this command"

      if [[ "$warnings" -gt 0 ]]; then
        printf 'secure-boot-dry-run: %s warning(s), no mutation performed\n' "$warnings" >&2
      else
        ok "secure boot dry run passed without warnings"
      fi
    '';
  };

  environment.systemPackages = [
    pkgs.sbctl
    config.system.build.secureBootDryRun
  ];
}
