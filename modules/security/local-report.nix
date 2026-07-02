{
  config,
  lib,
  pkgs,
  ...
}:

let
  ports = import ../observability/ports.nix;
  rollbackLimit = config.boot.loader.systemd-boot.configurationLimit or 0;
  expectedSysctls = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.perf_event_paranoid" = 2;
    "kernel.randomize_va_space" = 2;
    "kernel.sysrq" = 0;
    "kernel.yama.ptrace_scope" = 1;
    "dev.tty.ldisc_autoload" = 0;
    "fs.suid_dumpable" = 0;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
  };
  sysctlChecks = lib.mapAttrsToList (name: expected: ''
    check_sysctl ${lib.escapeShellArg name} ${lib.escapeShellArg (toString expected)}
  '') expectedSysctls;
  loopbackPorts = {
    inherit (ports)
      grafana
      loki
      prometheus
      promtail
      ;
    node-exporter = ports.node;
    nvidia-exporter = ports.nvidia;
    grafana-proxy = ports.grafanaProxy;
  };
  loopbackChecks = lib.mapAttrsToList (name: port: ''
    check_loopback_port ${lib.escapeShellArg name} ${toString port}
  '') loopbackPorts;
  pamU2fAuthFile = config.security.pam.u2f.settings.authfile or null;
  sudoPamU2fEnabled = config.security.pam.services.sudo.u2f.enable or false;
  localSecurityReport = {
    schema = "nixos-config.local-security.v1";
    host = config.networking.hostName;
    generatedBy = "nixos-config";
    controls = {
      bootRollback = {
        expected = "systemd-boot keeps the intentionally configured generation count";
        actual = rollbackLimit;
        status = if rollbackLimit == 1 then "accepted" else "ok";
        rationale = "This workstation intentionally keeps one systemd-boot entry; rollback strategy is handled outside the boot menu.";
      };
      firewall = {
        expected = "NixOS firewall enabled";
        actual = config.networking.firewall.enable;
        status = if config.networking.firewall.enable then "ok" else "fail";
      };
      githubKnownHosts = {
        expected = "GitHub SSH host keys are pinned in /etc/ssh/github_known_hosts";
        status = "configured";
      };
      sops = {
        expected = "SOPS default file is declared and secrets are decrypted outside the repo";
        defaultSopsFile = toString config.sops.defaultSopsFile;
        ageKeyFile = config.sops.age.keyFile;
        status = "configured";
      };
      observabilityLoopback = {
        expected = "Observability services bind only to loopback";
        ports = loopbackPorts;
        status = "runtime-check";
      };
      recoveryReadiness = {
        expected = "Recovery tooling and Ventoy readiness are checked before any Lanzaboote activation";
        actual = {
          command = "recovery-readiness-check";
          ventoyConfig = "/home/tco/dev/ventoy-config/ventoy/ventoy/ventoy.json";
        };
        status = "runtime-check";
        rationale = "This check is non-mutating. It verifies recovery tools, current mounts, Ventoy/VTOYEFI presence and the Ventoy config, but the real boot drill remains manual.";
      };
      sysctlBaseline = {
        expected = expectedSysctls;
        status = "runtime-check";
      };
      secureBoot = {
        expected = "Lanzaboote is configured for signed boot artifacts before firmware enforcement is enabled";
        actual = {
          lanzaboote = config.boot.lanzaboote.enable or false;
          systemdBoot = config.boot.loader.systemd-boot.enable or false;
          canTouchEfiVariables = config.boot.loader.efi.canTouchEfiVariables or false;
          dryRunCommand = "secure-boot-dry-run";
          sbctl = pkgs.sbctl.version;
          pkiBundle = config.boot.lanzaboote.pkiBundle or null;
          signing = if config.boot.lanzaboote.enable or false then "configured" else "not-configured";
        };
        status =
          if config.boot.lanzaboote.enable or false then "lanzaboote-configured" else "dry-run-ready";
        rationale = "Lanzaboote signs boot artifacts with the sbctl key bundle. Firmware key enrollment remains a separate manual step.";
      };
      tpm2 = {
        expected = "TPM device presence and TPM2 unlock readiness stay visible before and after enrollment";
        actual = {
          systemdInitrdSupport = config.boot.initrd.systemd.tpm2.enable or false;
          systemdRuntimeSupport = config.systemd.tpm2.enable or false;
          runtimeTools = config.security.tpm2.enable or false;
          unlockCheck = "tpm2-unlock-check";
          luksDevice = "/dev/disk/by-partlabel/legion-crypt";
          recommendedEnrollment = "sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/legion-crypt";
        };
        status = "runtime-check";
        rationale = "The NixOS side only prepares TPM2 support and check tooling. LUKS token enrollment remains a manual, auditable step and keeps the passphrase fallback.";
      };
      rootDiskEncryption = {
        expected = "Root filesystem encryption state stays visible after the LUKS/LVM migration";
        status = "runtime-check";
        rationale = "Observation only. Future disk layout changes must be handled as dedicated migration runs.";
      };
      pamU2f = {
        expected = "PAM U2F is enabled for sudo only, with password fallback";
        actual = {
          sudo = sudoPamU2fEnabled;
          control = config.security.pam.u2f.control;
          authFile = pamU2fAuthFile;
        };
        status = if sudoPamU2fEnabled then "configured" else "runtime-check";
        rationale = "U2F is intentionally scoped to sudo first. With control=sufficient, a missing or failed key falls back to the regular password path.";
      };
    };
    acceptedRisks = [
      {
        id = "bootloader-single-generation";
        status = "accepted";
        rationale = "The boot menu is intentionally kept at one generation for a clean local workflow. Rollback must use build outputs, git, external media or a planned boot recovery run.";
      }
      {
        id = "antigravity-electron-sandbox";
        status = "accepted";
        rationale = "The local Antigravity wrapper currently needs Electron sandbox relaxations on this NixOS setup. Keep this exception visible and revisit if the packaging changes.";
      }
      {
        id = "restic-sensitive-scope";
        status = "accepted";
        rationale = "Backups intentionally include SSH, GPG and broad user config for machine recovery. Restic encryption and SOPS protect credentials, but restore and key-rotation drills remain important.";
      }
      {
        id = "hyprland-home-manager-force";
        status = "accepted";
        rationale = "Hyprland runtime config is owned by Nix/Home Manager. Local experiments should happen in git, not directly under ~/.config/hypr.";
      }
    ];
  };
in
{
  boot.kernel.sysctl = {
    "kernel.randomize_va_space" = 2;
    "fs.suid_dumpable" = 0;
  };

  system.build.localSecurityReportDocument = pkgs.writers.writeJSON "local-security-report.json" localSecurityReport;

  system.build.localSecurityCheck = pkgs.writeShellApplication {
    name = "local-security-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.cryptsetup
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.iproute2
      pkgs.procps
      pkgs.util-linux
      config.system.build.recoveryReadinessCheck
    ];
    text = ''
      failures=0

      ok() { printf '[ok] %s\n' "$*"; }
      warn() { printf '[warn] %s\n' "$*"; }
      fail() { printf '[fail] %s\n' "$*"; failures=$((failures + 1)); }

      check_sysctl() {
        local key="$1" expected="$2" actual
        if ! actual="$(sysctl -n "$key" 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')"; then
          fail "sysctl $key is unreadable"
          return
        fi
        if [[ "$actual" == "$expected" ]]; then
          ok "sysctl $key=$expected"
        else
          fail "sysctl $key expected '$expected', got '$actual'"
        fi
      }

      check_loopback_port() {
        local name="$1" port="$2" listeners bad=0
        listeners="$(ss -ltnH | awk '{ print $4 }' | grep -E "(^|:|\])''${port}$" || true)"
        if [[ -z "$listeners" ]]; then
          warn "$name:$port is not listening"
          return
        fi
        while IFS= read -r addr; do
          [[ -n "$addr" ]] || continue
          case "$addr" in
            127.0.0.1:*|\[::1\]:*)
              ;;
            *)
              fail "$name:$port listens on non-loopback address $addr"
              bad=1
              ;;
          esac
        done <<< "$listeners"
        if [[ "$bad" -eq 0 ]]; then
          ok "$name:$port loopback-only"
        fi
      }

      check_secure_boot() {
        local file state
        if [[ ! -d /sys/firmware/efi ]]; then
          warn "Secure Boot not checkable: system was not booted through UEFI"
          return
        fi
        file="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' -print -quit 2>/dev/null || true)"
        if [[ -z "$file" ]]; then
          warn "Secure Boot efivar is missing"
          return
        fi
        state="$(od -An -t u1 -j 4 -N 1 "$file" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ "$state" == "1" ]]; then
          ok "Secure Boot is enabled"
        else
          warn "Secure Boot is disabled"
        fi
      }

      check_tpm2() {
        if [[ -c /dev/tpmrm0 || -c /dev/tpm0 ]]; then
          ok "TPM device is present"
        else
          warn "TPM device is not detected"
        fi
      }

      check_tpm2_unlock() {
        local luks_device="/dev/disk/by-partlabel/legion-crypt" luks_dump
        if [[ ${if config.boot.initrd.systemd.tpm2.enable or false then "1" else "0"} -eq 1 ]]; then
          ok "TPM2 unlock support is configured in initrd"
        else
          warn "TPM2 unlock support is not configured in initrd"
        fi
        if command -v tpm2-unlock-check >/dev/null 2>&1; then
          ok "tpm2-unlock-check is installed"
        else
          warn "tpm2-unlock-check is not installed"
        fi
        if [[ ! -e "$luks_device" ]]; then
          warn "TPM2 LUKS token not inspectable: $luks_device is missing"
          return
        fi
        if [[ "$EUID" -ne 0 ]]; then
          ok "TPM2 LUKS token inspection requires sudo; run sudo tpm2-unlock-check"
          return
        fi
        luks_dump="$(cryptsetup luksDump "$luks_device" 2>/dev/null || true)"
        if [[ -z "$luks_dump" ]]; then
          warn "TPM2 LUKS token not inspectable: cryptsetup could not read $luks_device"
        elif grep -qi 'systemd-tpm2' <<< "$luks_dump"; then
          ok "LUKS has a systemd-tpm2 token enrolled"
        else
          warn "LUKS has no systemd-tpm2 token enrolled"
        fi
      }

      check_root_disk_encryption() {
        local source type parent parent_type
        source="$(findmnt -no SOURCE / 2>/dev/null || true)"
        if [[ -z "$source" ]]; then
          warn "root filesystem source is not detectable"
          return
        fi
        if [[ "$source" == /dev/mapper/* ]]; then
          ok "root filesystem is backed by a mapped device ($source)"
          return
        fi
        type="$(lsblk -no TYPE "$source" 2>/dev/null | head -n1 || true)"
        parent="$(lsblk -no PKNAME "$source" 2>/dev/null | head -n1 || true)"
        parent_type=""
        if [[ -n "$parent" ]]; then
          parent_type="$(lsblk -no TYPE "/dev/$parent" 2>/dev/null | head -n1 || true)"
        fi
        if [[ "$type" == "crypt" || "$parent_type" == "crypt" ]]; then
          ok "root filesystem appears to be dm-crypt backed ($source)"
        else
          warn "root filesystem does not appear to be dm-crypt backed ($source)"
        fi
      }

      check_pam_u2f() {
        local auth_file=${lib.escapeShellArg (toString pamU2fAuthFile)}
        if grep -qs 'pam_u2f' /etc/pam.d/sudo; then
          ok "PAM U2F is wired for sudo"
        else
          warn "PAM U2F is not wired for sudo"
          return
        fi
        if [[ -s "$auth_file" ]]; then
          ok "PAM U2F mapping file has at least one entry ($auth_file)"
        else
          warn "PAM U2F mapping file is empty or missing ($auth_file); sudo will fall back to password"
        fi
      }

      check_recovery_readiness() {
        if command -v recovery-readiness-check >/dev/null 2>&1; then
          ok "recovery-readiness-check is installed"
        else
          warn "recovery-readiness-check is not installed"
        fi
        if findfs LABEL=Ventoy >/dev/null 2>&1 && findfs LABEL=VTOYEFI >/dev/null 2>&1; then
          ok "Ventoy and VTOYEFI partitions are detected"
        else
          warn "Ventoy recovery USB is not detected"
        fi
      }

      check_iommu() {
        if [[ -d /sys/class/iommu ]] && [[ -n "$(ls -A /sys/class/iommu 2>/dev/null)" ]]; then
          ok "IOMMU is enabled"
        else
          warn "IOMMU is not enabled"
        fi
      }

      check_apparmor() {
        if [[ -d /sys/kernel/security/apparmor ]]; then
          ok "AppArmor LSM is active"
        else
          warn "AppArmor LSM is not active"
        fi
      }

      if [[ ${toString rollbackLimit} -eq 1 ]]; then
        warn "systemd-boot keeps 1 generation by explicit policy"
      elif [[ ${toString rollbackLimit} -gt 1 ]]; then
        ok "systemd-boot keeps ${toString rollbackLimit} generations"
      else
        fail "systemd-boot configurationLimit is ${toString rollbackLimit}; expected a positive value"
      fi

      if [[ -s /etc/ssh/github_known_hosts ]] && grep -q '^github.com ssh-ed25519 ' /etc/ssh/github_known_hosts; then
        ok "GitHub SSH host keys are pinned"
      else
        fail "GitHub SSH host keys are missing from /etc/ssh/github_known_hosts"
      fi

      ${lib.concatStringsSep "\n" sysctlChecks}

      ${lib.concatStringsSep "\n" loopbackChecks}

      check_secure_boot
      check_tpm2
      check_tpm2_unlock
      check_root_disk_encryption
      check_pam_u2f
      check_recovery_readiness
      check_iommu
      check_apparmor

      if [[ "$failures" -gt 0 ]]; then
        printf 'local-security-check: %s failure(s)\n' "$failures" >&2
        exit 1
      fi
      ok "local security baseline passed"
    '';
  };

  environment.systemPackages = [ config.system.build.localSecurityCheck ];
}
