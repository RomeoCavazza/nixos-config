{ config, pkgs, lib, ... }:

let
  # PHP assemblé avec extensions utiles (inclut openssl)
  phpWithExt = pkgs.php.buildEnv {
    extensions = ({ all, enabled }: with all; [
      curl gd intl mbstring mysqli opcache pdo_mysql session zlib xdebug openssl
    ]);
    extraConfig = ''
      display_errors = On
      error_reporting = E_ALL
      ; Sécurité raisonnable par défaut
      expose_php = Off
      allow_url_fopen = On
      allow_url_include = Off
    '';
  };

  # Script d'init MariaDB - ⚠️ MODIFIER LES IDENTIFIANTS AVANT DÉPLOIEMENT
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
    adminAddr = "admin@localhost";  # ⚠️ CHANGER L'EMAIL ADMIN

    # mod_php => prefork
    mpm = "prefork";
    enablePHP = true;
    phpPackage = phpWithExt;

    # Utilisateur/groupe NixOS standards pour httpd
    user = "wwwrun";
    group = "wwwrun";

    extraModules = [ "rewrite" "headers" "deflate" "expires" ];

    extraConfig = ''
      ServerTokens Prod
      ServerSignature Off
      FileETag MTime Size
      EnableSendfile Off

      # VHost par défaut
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
      name = "dev_user";  # ⚠️ UTILISATEUR PAR DÉFAUT - CHANGER
      ensurePermissions = { "testdb.*" = "ALL PRIVILEGES"; };
    }];
    initialScript = mysqlInit;

    # Écoute uniquement en local
    settings.mysqld.bind-address = "127.0.0.1";
  };

  #### Paquets utiles côté LAMP (facultatif)
  environment.systemPackages = with pkgs; [
    phpWithExt
    phpPackages.composer
  ];

  # NOTE :
  # - La création de /var/www et autres règles de tmpfiles
  #   doit être gérée centralement dans la configuration système
  #   pour éviter les collisions entre modules.
  # - Si tu veux Adminer automatiquement, on pourra l’ajouter
  #   via tmpfiles (copie/symlink) vers /var/www/adminer.php.
}
