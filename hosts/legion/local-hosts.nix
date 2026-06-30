{
  # Bernstein demo (seminar-dop): local resolution to a DOKS cluster node.
  # Ephemeral IP; update or remove when the cluster is recreated.
  networking.extraHosts = ''
    157.230.26.170 poll.dop.io result.dop.io
  '';
}
