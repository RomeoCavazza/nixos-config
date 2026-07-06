{
  prometheus = 9090;
  node = 9100;
  nvidia = 9835;
  loki = 3100;
  lokiGrpc = 9095;
  grafana = 3001;
  grafanaProxy = 3000;
  promtail = 9080;
  # GitLab
  gitlab = 8929;        # Puma HTTP (interne)
  gitlabProxy = 8930;   # nginx reverse-proxy (accès local)
  gitlabPages = 8931;   # GitLab Pages (nginx)
  gitlabSSH = 2222;     # SSH Git (évite conflit avec sshd sur 22)
}
