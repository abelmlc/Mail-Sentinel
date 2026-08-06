# Mail Sentinel

Mail Sentinel est une application macOS locale qui consulte les nouveaux messages via Apple Mail, les classe avec `qwen3:8b` dans Ollama et affiche une notification lorsqu'un message mérite probablement d'être lu ou traité.

## Principes de confidentialité

- Aucun mot de passe de messagerie n'est demandé ou stocké.
- Le contenu est envoyé uniquement à Ollama sur `127.0.0.1`.
- Le corps des messages n'est pas enregistré sur disque.
- L'historique local contient seulement les identifiants traités et les retours utile/inutile avec l'expéditeur et l'objet.
- L'application ne répond pas, ne déplace pas et ne supprime pas les messages.

## Construire

```bash
chmod +x scripts/build_app.sh
./scripts/build_app.sh
```

L'application est créée dans `dist/Mail Sentinel.app`.

## Premier lancement

1. Vérifier qu'Ollama fonctionne et que `qwen3:8b` est installé.
2. Ouvrir `dist/Mail Sentinel.app`.
3. Autoriser les notifications.
4. Cliquer sur l'icône d'enveloppe dans la barre des menus, puis sur **Analyser maintenant**.
5. Autoriser Mail Sentinel à contrôler Apple Mail lorsque macOS le demande.

Les autorisations peuvent être vérifiées dans **Réglages Système → Confidentialité et sécurité → Automatisation** et **Notifications**.

## Développement

```bash
./scripts/test.sh
swift run MailSentinel
```

Le lancement avec `swift run` est utile pour le développement, mais la version `.app` est recommandée afin que macOS associe correctement les autorisations à Mail Sentinel.
