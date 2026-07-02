_:

{
  security.auditd.enable = true;

  security.audit = {
    enable = true;
    rules = [
      "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules"
      "-a always,exit -F arch=b64 -S kexec_load -k kexec"
      "-a always,exit -F arch=b64 -S mount,umount2 -k mounts"
      "-a always,exit -F arch=b64 -S settimeofday,clock_settime,adjtimex -k time"
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/sudoers -p wa -k sudoers"
      "-w /etc/sudoers.d -p wa -k sudoers"
    ];
  };
}
