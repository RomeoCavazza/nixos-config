{ config, pkgs, ... }:

let
  ventoyConfig = "/home/tco/dev/ventoy-config/ventoy/ventoy/ventoy.json";
in
{
  system.build.recoveryReadinessCheck = pkgs.writeShellApplication {
    name = "recovery-readiness-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.jq
      pkgs.nix
      pkgs.systemd
      pkgs.util-linux
      config.system.build.nixos-rebuild
    ];
    text = ''
      warnings=0
      failures=0

      ok() { printf '[ok] %s\n' "$*"; }
      warn() { printf '[warn] %s\n' "$*"; warnings=$((warnings + 1)); }
      fail() { printf '[fail] %s\n' "$*"; failures=$((failures + 1)); }

      show_mount() {
        local target="$1" line
        line="$(findmnt -no SOURCE,FSTYPE,OPTIONS "$target" 2>/dev/null || true)"
        if [[ -n "$line" ]]; then
          ok "$target -> $line"
        else
          warn "$target is not a separate visible mount"
        fi
      }

      check_command() {
        local command="$1"
        if command -v "$command" >/dev/null 2>&1; then
          ok "$command available"
        else
          fail "$command missing"
        fi
      }

      check_ventoy() {
        local ventoy_dev vtoyefi_dev ventoy_parent vtoyefi_parent ventoy_fs vtoyefi_fs ventoy_rm mountpoint
        ventoy_dev="$(findfs LABEL=Ventoy 2>/dev/null || true)"
        vtoyefi_dev="$(findfs LABEL=VTOYEFI 2>/dev/null || true)"

        if [[ -z "$ventoy_dev" ]]; then
          warn "Ventoy data partition LABEL=Ventoy not detected"
          return
        fi
        if [[ -z "$vtoyefi_dev" ]]; then
          warn "Ventoy EFI partition LABEL=VTOYEFI not detected"
          return
        fi

        ventoy_parent="/dev/$(lsblk -no PKNAME "$ventoy_dev" 2>/dev/null | head -n1)"
        vtoyefi_parent="/dev/$(lsblk -no PKNAME "$vtoyefi_dev" 2>/dev/null | head -n1)"
        ventoy_fs="$(lsblk -no FSTYPE "$ventoy_dev" 2>/dev/null | head -n1)"
        vtoyefi_fs="$(lsblk -no FSTYPE "$vtoyefi_dev" 2>/dev/null | head -n1)"
        ventoy_rm="$(lsblk -ndo RM "$ventoy_parent" 2>/dev/null | head -n1)"

        ok "Ventoy partition detected: $ventoy_dev ($ventoy_fs)"
        ok "Ventoy EFI partition detected: $vtoyefi_dev ($vtoyefi_fs)"

        if [[ "$ventoy_parent" == "$vtoyefi_parent" ]]; then
          ok "Ventoy partitions share parent disk $ventoy_parent"
        else
          warn "Ventoy partitions are on different parent disks: $ventoy_parent / $vtoyefi_parent"
        fi

        if [[ "$ventoy_rm" == "1" ]]; then
          ok "$ventoy_parent is removable"
        else
          warn "$ventoy_parent is not reported as removable"
        fi

        mountpoint="$(lsblk -no MOUNTPOINT "$ventoy_dev" 2>/dev/null | head -n1 || true)"
        if [[ -n "$mountpoint" ]]; then
          ok "Ventoy data partition is mounted at $mountpoint"
          if [[ -f "$mountpoint/iso/nixos-graphical-26.05pre956934.cf59864ef8aa-x86_64-linux.iso" ]]; then
            ok "NixOS ISO exists on Ventoy"
          else
            warn "NixOS ISO from ventoy-config was not found on mounted Ventoy"
          fi
        else
          warn "Ventoy data partition is not mounted; ISO presence cannot be verified from the running system"
        fi
      }

      check_ventoy_config() {
        local config_path=${ventoyConfig}
        if [[ -f "$config_path" ]]; then
          ok "Ventoy config found at $config_path"
        else
          warn "Ventoy config missing at $config_path"
          return
        fi

        if jq empty "$config_path" >/dev/null; then
          ok "Ventoy JSON is valid"
        else
          fail "Ventoy JSON is invalid"
          return
        fi

        if jq -e '.menu_alias[] | select(.alias == "NixOS")' "$config_path" >/dev/null; then
          ok "Ventoy menu contains a NixOS entry"
        else
          warn "Ventoy menu has no NixOS alias"
        fi
        if jq -e '.menu_alias[] | select(.alias == "SystemRescue")' "$config_path" >/dev/null; then
          ok "Ventoy menu contains a SystemRescue entry"
        else
          warn "Ventoy menu has no SystemRescue alias"
        fi
        if jq -e '.menu_alias[] | select(.alias == "GParted")' "$config_path" >/dev/null; then
          ok "Ventoy menu contains a GParted entry"
        else
          warn "Ventoy menu has no GParted alias"
        fi
      }

      printf '== Recovery Readiness ==\n'
      check_command git
      check_command nix
      check_command nixos-rebuild
      check_command bootctl
      check_command findmnt
      check_command lsblk

      printf '\n== Current System Layout ==\n'
      show_mount /
      show_mount /boot
      show_mount /home
      show_mount /build
      show_mount /nix/store
      show_mount /gnu/store
      if swapon --show=NAME,TYPE,SIZE --noheadings | grep -q .; then
        swapon --show=NAME,TYPE,SIZE --noheadings | awk '{ print "[ok] swap -> "$0 }'
      else
        warn "no active swap detected"
      fi

      if [[ ${if config.boot.loader.systemd-boot.enable or false then "1" else "0"} -eq 1 ]]; then
        ok "systemd-boot is enabled in NixOS"
      else
        warn "systemd-boot is not enabled in NixOS"
      fi

      printf '\n== Ventoy USB ==\n'
      check_ventoy

      printf '\n== Ventoy Config ==\n'
      check_ventoy_config

      printf '\n== Manual Boot Drill Still Required ==\n'
      warn "manual step: boot the Ventoy NixOS or SystemRescue entry once before enabling Lanzaboote"
      warn "manual step: confirm you can see /dev/nvme0n1p1, p5, p6 and p7 from the live environment"
      warn "manual step: confirm you can mount /boot and root from the live environment"

      if [[ "$failures" -gt 0 ]]; then
        printf 'recovery-readiness-check: %s failure(s), %s warning(s)\n' "$failures" "$warnings" >&2
        exit 1
      fi
      printf 'recovery-readiness-check: %s warning(s), no mutation performed\n' "$warnings" >&2
    '';
  };

  environment.systemPackages = [ config.system.build.recoveryReadinessCheck ];
}
