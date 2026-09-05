# Inbox local

Sources récupérées depuis l’application installée le 5 septembre 2026, puis intégrées au dépôt. Les caches Python ont été exclus. Aucun accès aux comptes ni donnée de production n’a été copié ; data/demo-emails.json contient les exemples livrés avec le code.

Le module modules/services/inbox.nix construit Python et le lanceur avec les paquets du flake.lock Nix. requirements.txt documente les versions Python amont mais ne pilote pas cette construction Nix.
modules/services/inbox-local.nix active le service et référence les secrets SOPS chiffrés. La base de production reste /var/lib/inbox/inbox.sqlite3, utilisateur tco. Écoute locale sur 127.0.0.1:8000.

Modifier source/ pour développer localement. Reconstruire avec nix build .#nixosConfigurations.legion.config.system.build.toplevel.
