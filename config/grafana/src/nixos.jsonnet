local g = import 'lib/dashboard.libsonnet';

// Minimal NixOS Dashboard Shell
// Status: Reset / Clean Slate

g.dashboard('NixOS (Minimal)', 'nixos-minimal', '5s', 'Minimal NixOS Dashboard') {
  panels: [
    g.rowPanel(1, 'System Vitals', 0),
  ],
}