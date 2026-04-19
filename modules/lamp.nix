{ config, pkgs, lib, ... }:

let
  # PHP assembled with useful extensions, including openssl.
  phpWithExt = pkgs.php.buildEnv {
    extensions = ({ all, enabled }: with all; [
      curl gd intl mbstring mysqli opcache pdo_mysql session zlib xdebug openssl
    ]);
    extraConfig = ''
      display_errors = On
      error_reporting = E_ALL
      ; Reasonable secure defaults
      expose_php = Off
      allow_url_fopen = On
      allow_url_include = Off
    '';
  };

  # MariaDB init script. Change credentials before deployment.
  mysqlInit = pkgs.writeText "mysql-init.sql" ''
    CREATE USER IF NOT EXISTS 'dev_user'@'localhost' IDENTIFIED BY 'CHANGE_THIS_PASSWORD';
    CREATE DATABASE IF NOT EXISTS testdb;
    GRANT ALL PRIVILEGES ON testdb.* TO 'dev_user'@'localhost';
    FLUSH PRIVILEGES;
  '';
in
{
  #### Apache + PHP (mod_php, prefork)
  services.httpd = {
    enable = true;
    adminAddr = "admin@localhost";  # Change the admin email.

    # mod_php => prefork
    mpm = "prefork";
    enablePHP = true;
    phpPackage = phpWithExt;

    # Standard NixOS user/group for httpd.
    user = "wwwrun";
    group = "wwwrun";

    extraModules = [ "rewrite" "headers" "deflate" "expires" ];

    extraConfig = ''
      ServerTokens Prod
      ServerSignature Off
      FileETag MTime Size
      EnableSendfile Off

      # Default VHost.
      <Directory "/var/www">
        AllowOverride All
        Require all granted
        Options Indexes FollowSymLinks
      </Directory>
      DirectoryIndex index.php index.html
    '';

    virtualHosts = {
      "localhost" = {
        documentRoot = "/var/www";
      };
      "dev.localhost" = {
        documentRoot = "/var/www/dev/public";
        extraConfig = ''
          DirectoryIndex index.php index.html
          <Directory "/var/www/dev/public">
            AllowOverride All
            Require all granted
          </Directory>
        '';
      };
    };
  };

  #### MariaDB (MySQL)
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    dataDir = "/var/lib/mysql";

    ensureDatabases = [ "testdb" ];
    ensureUsers = [{
      name = "dev_user";  # Default user; change before deployment.
      ensurePermissions = { "testdb.*" = "ALL PRIVILEGES"; };
    }];
    initialScript = mysqlInit;

    # Listen on localhost only.
    settings.mysqld.bind-address = "127.0.0.1";
  };

  #### Useful LAMP packages (optional)
  environment.systemPackages = with pkgs; [
    phpWithExt
    phpPackages.composer
  ];

  # NOTE :
  # - /var/www creation and other tmpfiles rules should be managed
  #   centrally in the system configuration to avoid module collisions.
  # - Adminer can be added later through tmpfiles as a copy/symlink
  #   to /var/www/adminer.php.
}
