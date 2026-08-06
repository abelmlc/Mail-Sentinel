# Mail Sentinel

Mail Sentinel est une application macOS locale qui consulte les nouveaux messages via Apple Mail, les classe avec `qwen3:8b` dans Ollama et affiche une notification lorsqu'un message mérite probablement d'être lu ou traité.

L'application propose aussi une analyse historique configurable des anciens messages et un journal local des décisions prises par le modèle.

## Principes de confidentialité

- Aucun mot de passe de messagerie n'est demandé ou stocké.
- Le contenu est envoyé uniquement à Ollama sur `127.0.0.1`.
- Le corps des messages n'est pas enregistré sur disque.
- L'historique local conserve pendant 30 jours l'expéditeur, l'objet, le score, la justification et les retours utile/inutile.
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

Dans **Réglages et historique**, l'onglet **Historique** affiche chaque décision de Qwen. L'onglet **Réglages** permet de lancer un rattrapage sur 7 à 365 jours. Pour limiter l'utilisation du GPU, 250 messages au maximum sont classés par lancement.

Les autorisations peuvent être vérifiées dans **Réglages Système → Confidentialité et sécurité → Automatisation** et **Notifications**.

## Développement

```bash
./scripts/test.sh
swift run MailSentinel
```

Le lancement avec `swift run` est utile pour le développement, mais la version `.app` est recommandée afin que macOS associe correctement les autorisations à Mail Sentinel.
