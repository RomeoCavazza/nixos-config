{ pkgs, lib, ... }:

let
  app = pkgs.writeText "streamlit_app.py" ''
    import streamlit as st
    st.set_page_config(page_title="NixOS Streamlit")
    st.title("Hello Streamlit (uv runtime)")
    st.write("Installed at runtime into /var/lib/streamlit/venv.")
  '';
in
{
  systemd.services.streamlit = {
    description = "Streamlit app (installed at runtime with uv)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      StateDirectory = "streamlit";
      StateDirectoryMode = "0755";
      WorkingDirectory = "/var/lib/streamlit";
      Environment = [
        "HOME=/var/lib/streamlit"
        "PIP_DISABLE_PIP_VERSION_CHECK=1"
        "PYTHONUNBUFFERED=1"
      ];

      ExecStartPre = [
        "${pkgs.uv}/bin/uv venv --seed --python ${pkgs.python311}/bin/python venv"
        "/var/lib/streamlit/venv/bin/python -m pip install --no-cache-dir --upgrade pip 'streamlit==1.45.*'"
      ];

      # Launch through python -m streamlit to avoid shebang/exec issues.
      ExecStart = ''
        /var/lib/streamlit/venv/bin/python -m streamlit run ${app} \
          --server.port=8501 --server.address=127.0.0.1 --server.headless=true
      '';

      Restart = "on-failure";
      RestartSec = "2s";

      DynamicUser = true;
      ReadWritePaths = [ "/var/lib/streamlit" ];

      # Reasonable sandboxing; strict mode can block venv executions.
      ProtectSystem = "full";
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
