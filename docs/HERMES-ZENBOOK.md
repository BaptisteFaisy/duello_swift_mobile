# Hermes sur ce dépôt — mode opératoire (runner : Zenbook)

**Quoi** : le gate Hermes du dépôt `duello` (contrôle des PR 24/7 : fraîcheur sur
`main`, résolution automatique des conflits, pas de fermeture de PR, pas de
régression) porté sur ce dépôt, exécuté par un unique runner self-hosted : le
Zenbook de Baptiste.

**Pourquoi le Zenbook** : les runners `duello` (VPS `azure-duello`, `pc-fixe`)
sont hors ligne depuis le 20/09/2026 — le gate d'origine ne tournait plus du
tout. Le Zenbook, lui, est en no-sleep permanent (`duello-mirror/nosleep-*`).

## Les 4 workflows

| Fichier | Rôle |
| --- | --- |
| `hermes.yml` (`hermes`) | Le gate. Vérifie la fraîcheur sur `main`, publie le check `Hermes`, pose les labels, merge automatiquement par rebase quand tout est vert. |
| `hermes-conflict-resolver.yml` | Le sous-agent. Dispatché par le gate quand la PR est en retard : rebase sur `main`, résout les conflits (heuristiques + IA Agnes), pousse en `--force-with-lease`. Jusqu'à `MAX_RESOLVER_ATTEMPTS`, puis label `hermes/intervention-humaine`. |
| `hermes-watchdog.yml` | Réveille le gate (dispatch API) quand la CI `batterie` se termine, et par cron `​*/5`. Groupe de concurrence propre : jamais annulé par `hermes-gate`. |
| `hermes-pr-no-close-guard.yml` | Rouvre toute PR fermée sans merge dont le contenu n'est pas dans `main`. |
| `ci.yml` (`batterie`) | La batterie native du dépôt (voir plus bas). Le check `Batterie` est la condition n°2 du merge. |

## Où est la machine, et comment la relancer

Tout vit sous `~/hermes` sur le Zenbook (utilisateur `baptiste`, **sans sudo**) :

```
~/hermes/
├── env                            # AGNES_API_KEY, JAVA_HOME, ANDROID_HOME, PATH
├── runner-swift/  runner-kotlin/  # un runner GitHub Actions par dépôt
├── bin/hermes-watchdog.sh         # timer locale : dispatch hermes.yml (gh)
├── systemd/hermes-runner@.service # unité --user, une instance par dépôt
│           hermes-watchdog.{service,timer}
└── logs/
```

Commandes (sur le Zenbook, `ssh zenbook`) :

```bash
systemctl --user status 'hermes-runner@*'      # état des runners
journalctl --user -u 'hermes-runner@*' -f      # logs live
systemctl --user restart hermes-runner@swift   # relancer un runner
systemctl --user list-timers hermes-watchdog.timer
```

## Clés d'API : environnement du runner, pas secrets GitHub

`AGNES_API_KEY` (IA Agnes : revue de PR + résolution de conflits) et
`HERMES_PUSH_TOKEN` éventuel se déposent dans `~/hermes/env`, lu par l'unité
systemd du runner. Conséquences voulues :

- rien à configurer dans GitHub, ni pour ce dépôt ni pour l'autre ;
- une seule clé pour les deux dépôts ;
- **sans clé, Hermes tourne quand même** : la partie déterministe (fraîcheur,
  rebase, labels, check, merge, gardien) est indépendante de l'IA. Sans clé, la
  revue IA est ignorée (`[agnes] pas de cle …`) et la résolution de conflits
  retombe sur les heuristiques, avec escalade `hermes/intervention-humaine` si
  ça ne suffit pas.

## Auto-merge : kill-switch

`HERMES_AUTO_MERGE=0` dans `~/hermes/env` → Hermes continue de tout vérifier,
rebase et signale, mais **ne merge plus rien**. Utile si une vague de merges
automatiques est jugée trop nerveuse. Pas besoin de toucher aux workflows.

## Ce que la batterie vérifie réellement (honnêteté)

- **duello_kotlin** : compilation réelle (`assembleDebug`), tests unitaires, lint
  Android. C'est un vrai filet — le portage Kotlin était jusqu'ici écrit sans
  compilateur.
- **duello_swift_mobile** : syntaxe (`swiftc -parse` sur les 150 fichiers),
  cohérence `Duello.xcodeproj/project.pbxproj` ↔ `Duello/` (le script maison
  `--check`), limites de complexité. **Pas** de `xcodebuild` : il n'y a pas de
  macOS ici. Un check Swift vert vaut « syntaxe + projet cohérent », pas
  « l'archive App Store passe ». Pour franchir ce mur : brancher un runner macOS
  (label `macos`) et ajouter son check à `battery_status` dans `hermes.yml`.

## Limites de complexité : ratchet, pas chantage

`scripts/hermes-lint-complexity.py` applique les règles de l'AGENTS.md Duello
(50 lignes/fonction, 10 fonctions/fichier, 500 lignes/fichier) **en ratchet** :
les violations déjà présentes sur `main` sont figées dans
`.github/hermes-baseline.txt` et ne bloquent rien ; seule une **nouvelle**
violation introduite par une PR la fait rougir. Sans ça, Hermes aurait refusé
toutes les PR indéfiniment pour des dettes qu'elles n'ont pas créées.

Réduire la dette = supprimer des lignes de la baseline dans le même commit que
le découpage. L'aggraver volontairement = régénérer la baseline
(`--update-baseline`) **et** le justifier dans la description de la PR.
