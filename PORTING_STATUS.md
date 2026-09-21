# PORTAGE — état final

Port **SwiftUI natif** (iOS 16) de l'application Expo / React Native Duello.

- Dépôt : `/home/baptiste/.zeroclaw/agents/a/workspace/duello_swift_work`
- Source : `/home/baptiste/.zeroclaw/agents/a/workspace/expo_ref`
- Branche : `agent/portage-swift-lot6`

## Chiffres

| Mesure | Valeur |
| --- | --- |
| Fichiers Swift | **550** |
| Lignes de Swift | **77 805** |
| Code Expo atteignable (hors tests, `.web.`, `.generated.`) | 320 |
| Non couverts | 19 |
| **Couverture du code applicable** | **100 %** (320/320) |
| Fichiers > 500 lignes | 0 |
| Collisions de type top-level | 0 |
| Sources `Sources` du `project.pbxproj` | 550 (toutes) |

Le pré-contrôle `scripts/verify-swift-linux.sh` est **vert** : syntaxe sur les
550 fichiers, contrôle de types sur les 287 fichiers portables, 1 « hors
couverture » structurel (`ChartXpSeries.swift`, qui cite `ExGXp` d'un lot non
portable).

## Lots livrés

| Lot | Contenu | Fichiers |
| --- | --- | --- |
| 1–5 | socle, écrans, sous-systèmes (sur le Zenbook) | 296 |
| **6** | AppleAuth, PushNotif, AcctSec, Chart, League, Report, PremCode, PhotoPick, Dict, Chal, OnbGift, Offl, Coll, RemPhoto | **163** |
| **7** | Stmt (énoncé/questions/LaTeX), KbSup, Rew, DevReg, OnbData, Ui2, Swipe, Consent, RemPhotoRx, TrainGrid, ThemePalette, DuelloApiError | **91** |
| **8** | corrections de fidélité issues de 5 audits indépendants | (modifs) |

## Hors périmètre assumé — les 19 fichiers non portés

Tous sont **spécifiques à une autre plateforme** ; les porter serait du code
mort dans une application iOS.

### 1. Web / PWA « installée » (16)

`ChallengeDesktopLayout`, `DesktopChapterStatusIcon`,
`DesktopLeaderboardLauncher`, `DesktopQrLoginButton`, `DownloadedChartWindow`,
`DownloadedPerformanceDetails`, `InstalledLeaderboardDrawer`,
`SettingsDesktopLayout`, `downloadedAuthFormStyles`,
`downloadedOnboardingStyles`, `useDesktopAccountNavigation`, `useOtaUpdate`,
`downloadedPerformanceStyles`, `downloadedDesktopApp`,
`downloadedPerformanceMetrics`, `downloadedSearchInputStyle`.

Raison : mise en page « bureau » (rail, tiroir, fenêtre) et mises à jour OTA
d'Expo Updates — sans objet sur un binaire natif iOS, où l'App Store assure la
mise à jour. Le port garde la navigation basse (`MainTabView`).

### 2. Web seul (2)

- `RemotePhotoWebPanel.tsx` — panneau **navigateur** de la photo à distance :
  il s'exécute sur l'ordinateur, jamais sur le téléphone. Le lot 6 a porté le
  côté téléphone (`RemPhotoPhonePanel`) et le lot 7 le récepteur
  (`RemPhotoRx*`).
- `webResponsiveLayout.ts` — la source le dit elle-même : `platform !== 'web'`
  renvoie toujours `'bottom'`. Sur iOS, la fonction est constante.

### 3. Android seul (1)

- `AndroidBackNavigation.tsx` — bouton retour matériel Android (`BackHandler`).
  Sur iOS, le retour est le geste de bord natif, déjà en place.

## Écarts de fidélité connus et assumés

- **Graphiques** : les 15 défauts de fidélité du lot 6 ont été corrigés au lot 8
  (poids 900 → `.black`, séparateur U+202F, easing cubique, thinning des points
  au-delà de 24, axe médian, largeurs d'axe, libellés d'accessibilité). Restent
  des approximations de rendu React Native sans équivalent SwiftUI exact
  (mesures de texte, ombres, `Reanimated`).
- **Gestes** : les seuils et vitesses React Native (gesture-handler) sont
  approximés par les gestes SwiftUI (`predictedEndTranslation`).
- **RevenueCat** : isolé derrière `PremCodePurchases` / `PremCodeSimulatedPurchases`
  (aucune dépendance SPM), documenté en tête de fichier.
- **Python** : la console native ne simule que les `print(…)` littéraux
  (pas d'interpréteur embarqué) — limite documentée dans le fichier.

## Vérifier

```sh
# Sur le Zenbook (seule machine avec la toolchain Swift) :
rsync -a --delete --exclude .git duello_swift_work/ zenbook:/tmp/duello-verify/
ssh zenbook 'export PATH="$HOME/.local/bin:$PATH"; cd /tmp/duello-verify && sh scripts/verify-swift-linux.sh'
```

## Reste à faire

- **Compiler sur macOS + Xcode** (seul juge définitif du contrôle de types) :
  ce PC et le Zenbook n'ont pas Xcode.
- **Pousser la branche** (`git push`) — action externe, clé SSH à régler.
