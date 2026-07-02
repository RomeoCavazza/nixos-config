{
  config,
  lib,
  pkgs,
  ...
}:

let
  bootDevice = config.fileSystems."/boot".device;
  auditTools = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.lsof
    pkgs.procps
    pkgs.psmisc
    pkgs.util-linux
  ];
  auditPath = lib.makeBinPath auditTools;
  lateShutdownAudit = pkgs.writeShellScript "shutdown-audit-late" ''
    set +e

    export PATH=${auditPath}:$PATH

    boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"
    action="''${1:-unknown}"
    esp="/run/shutdown-audit-esp"

    mkdir -p "$esp"
    mount -t vfat -o rw,nosuid,nodev,noexec "${bootDevice}" "$esp" 2>/dev/null \
      || mount "${bootDevice}" "$esp" 2>/dev/null \
      || exit 0

    mkdir -p "$esp/shutdown-audit"
    log="$esp/shutdown-audit/$boot_id-late-$action.log"

    {
      echo "== shutdown-audit late =="
      date -u "+utc=%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true
      echo "action=$action"
      echo "boot_id=$boot_id"
      echo

      echo "== /proc/mounts =="
      cat /proc/mounts 2>/dev/null || true
      echo

      echo "== /proc/swaps =="
      cat /proc/swaps 2>/dev/null || true
      echo

      echo "== processes =="
      ps -eo pid,ppid,stat,comm,args --sort=pid 2>/dev/null || true
      echo

      for path in /run/keys /run/secrets.d /run/wrappers /run/user/1000 /nix /nix/store /build /home /boot; do
        echo "== holders: $path =="
        findmnt "$path" 2>/dev/null || true
        fuser -vm "$path" 2>&1 || true
        lsof +f -- "$path" 2>&1 || true
        echo
      done
    } > "$log" 2>&1

    sync "$log" 2>/dev/null || sync
    umount "$esp" 2>/dev/null || true
  '';
in
{
  systemd.shutdownRamfs.contents."/lib/systemd/system-shutdown/shutdown-audit-late".source =
    lateShutdownAudit;
  systemd.shutdownRamfs.storePaths = auditTools;
}
