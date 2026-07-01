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
      sysctlBaseline = {
        expected = expectedSysctls;
        status = "runtime-check";
      };
      secureBoot = {
        expected = "Secure Boot state is visible before any Lanzaboote migration";
        status = "runtime-check";
        rationale = "Observation only. Lanzaboote must be handled in a dedicated boot run.";
      };
      tpm2 = {
        expected = "TPM device presence is visible before any TPM2 secret-binding work";
        status = "runtime-check";
        rationale = "Observation only. TPM2 enrollment must be handled in a dedicated secrets run.";
      };
      rootDiskEncryption = {
        expected = "Root filesystem encryption state is visible before any Disko migration";
        status = "runtime-check";
        rationale = "Observation only. Disk layout changes must be tested in a VM before touching the workstation.";
      };
      pamU2f = {
        expected = "PAM U2F state is visible before any sudo/login hardening";
        status = "runtime-check";
        rationale = "Observation only. U2F must keep a documented recovery path.";
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
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.iproute2
      pkgs.procps
      pkgs.util-linux
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
        if [[ -s /etc/u2f-mappings ]] || grep -Rqs 'pam_u2f' /etc/pam.d; then
          ok "PAM U2F appears configured"
        else
          warn "PAM U2F is not configured"
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
      check_root_disk_encryption
      check_pam_u2f

      if [[ "$failures" -gt 0 ]]; then
        printf 'local-security-check: %s failure(s)\n' "$failures" >&2
        exit 1
      fi
      ok "local security baseline passed"
    '';
  };

  environment.systemPackages = [ config.system.build.localSecurityCheck ];
}
