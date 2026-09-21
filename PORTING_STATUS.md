# PORTAGE — état final

Port **SwiftUI natif** (iOS 16) de l'application Expo / React Native Duello.

- Dépôt : `/home/baptiste/.zeroclaw/agents/a/workspace/duello_swift_work`
- Source : `/home/baptiste/.zeroclaw/agents/a/workspace/expo_ref`
- Branche : `agent/portage-swift-lot6`

## Chiffres

| Mesure | Valeur |
| --- | --- |
| Fichiers Swift | **647** |
| Lignes de Swift | **94 079** |
| Code Expo `src/` (hors tests, `.web.`, `.generated.`) | 179 208 lignes |
| Fichiers > 500 lignes | 0 |
| Collisions de type top-level | 0 |
| Sources `Sources` du `project.pbxproj` | 647 (toutes) |

Le pré-contrôle `scripts/verify-swift-linux.sh` est **vert** : syntaxe sur les
647 fichiers, contrôle de types sur les 303 fichiers portables, 1 « hors
couverture » structurel (`AcctIntData.swift`, qui cite `ChartXpSummary` d'un lot
non portable).

## Fidélité, mesurée

⚠️ **Le chiffre annoncé au lot 7 était faux.** La « couverture 100 % » mesurait
qu'un **nom de fichier source** apparaisse quelque part dans les sources Swift —
pas que son contenu soit porté. La mesure utile est le **rapport de lignes** :
lignes Swift qui citent l'écran ÷ lignes du `.tsx` (les `StyleSheet` n'ont pas
d'équivalent SwiftUI, donc un rapport de ~0,7 est un portage complet).

| Écran Expo | TSX | Swift | ratio |
| --- | --- | --- | --- |
| `SubjectsScreen` | 12 492 | 7 948 | 0,64 |
| `AccountScreen` | 5 494 | 4 133 | 0,75 |
| `ChallengesScreen` | 4 140 | 3 537 | 0,85 |
| `OnboardingScreen` | 2 051 | 2 629 | 1,28 |
| `LoginScreen` | 819 | 2 112 | 2,58 |
| `MessagesScreen` | 1 023 | 874 (famille `Messages*`) | 0,85 |
| `RankingsScreen` | 1 057 | 966 (famille `Ranking*`) | 0,91 |
| **Total (23 écrans)** | **31 610** | **26 969** | **0,85** |

Limite du ratio : il ne compte que les fichiers Swift qui **citent** le nom du
`.tsx`. Une famille portée sous un autre nom (ex. `MessagesBubble.swift` pour
`MessageBubble`) compte 0. Les deux lignes corrigées à la main ci-dessus le
montrent ; le total est donc un **minorant**.

## Lots livrés

| Lot | Contenu | Fichiers |
| --- | --- | --- |
| 1–5 | socle, écrans, sous-systèmes | 296 |
| 6 | AppleAuth, PushNotif, AcctSec, Chart, League, Report, PremCode, PhotoPick, Dict, Chal, OnbGift, Offl, Coll, RemPhoto | 163 |
| 7 | Stmt, KbSup, Rew, DevReg, OnbData, Ui2, Swipe, Consent, RemPhotoRx, TrainGrid, ThemePalette, DuelloApiError | 91 |
| 8 | corrections de fidélité issues de 5 audits indépendants | (modifs) |
| **9** | **composants de `SubjectsScreen`** : modes, guide, domaine, filtres, flashcards (sélection, éditeur, session), lignes/étiquettes/progression, HEC, replis différés | **35** |
| **10–11** | **composants de `AccountScreen` et `ChallengesScreen`** : blason retournable, évolution, réglages, annuaire, vitrine ; modales, session, chrono, manches, bilan | **61** |
| **12–15** | Onboarding (constantes, champs, machine à états), Messages, Login, bloqués/parcours | **~20** |
| **16–20** | **intégration** : les 5 écrans assemblent enfin les composants | 5 modifiés + 12 neufs |

## Ce qui est désormais branché

- **Entraînement** : onglets de mode, guide du parcours, légende du cours,
  en-têtes de domaine, lignes de chapitre (statut, progression, résumé accordé),
  filtres de difficulté réellement filtrants, feuille « Cartes » (éditeur).
- **Compte** : vitrine assemblée — blason retournable avec **la pastille de
  présence de la PR #426** (`FlipBadgePresence` + `SocOnlineDot`), carte de
  ligue, statistiques, séries XP/Elo, succès par matière ; réglages
  « informations » ; annuaire de recherche.
- **Défis** : accueil à deux sections (Défis/Événements), file d'attente,
  invitations, déroulé **en manches** (`ChalRunRounds`), bilan comparatif
  (`ChalRunResultView`), victoire par abandon, révélation différée.
- **Inscription** : le parcours complet (`OnbFlowView`) est hébergé, toutes les
  étapes de la source (`origin`, `target`, `identity`, `auth-method`,
  `credentials`, `premium-gift`).
- **Connexion** : le login **noir** de la source (`LoginScrScreen`).

## Ce qui reste réduit, et pourquoi

Tout ce qui suit est **documenté dans les en-têtes de fichiers**, jamais inventé.

### Entraînement
- `SubjFlashcardReviewSession` n'est **pas branché** : l'écran n'a ni file de
  cartes ni verdict.
- Mode **Annales** : état vide (aucune banque d'annales chargée).
- Mode **Cours** : statut de chapitre seulement (pas de lecteur PDF — PDFKit
  interdit, et la source ne dessine elle-même que des pages factices).
- « Notions » / « Classique » : sélecteurs d'interface seuls, la banque servie
  n'ayant ni badges ni prérequis.

### Compte
- **XP totale = 0** (aucun store d'XP local) → niveau 1 ; complétion du
  programme = 0 %.
- **Séries XP/Elo = `[]`** (pas d'historique horodaté) et **succès par matière =
  `[]`** (le regroupement item → matière n'est pas relié) : ces sections
  s'affichent en état vide.
- Premium, présence, biométrie, suppression de compte, proposition de défi :
  pas de source locale → repli neutre.

### Défis
- `ChalSeries` = **1 exercice** (pas de tirage multi-exercices).
- Volet d'invitation d'un ami absent → les boutons retombent sur la file
  aléatoire.
- `opponentAbandoned` déduit d'un `verdict.summary.contains("abandonné")` :
  **heuristique fragile** si le libellé du juge change.

### Inscription
- L'étape « filière actuelle » ne propose **que ECG** : c'est **fidèle à la
  source** (lignes 1087-1108, restriction de développement assumée), mais c'est
  plus restrictif que l'ancienne vue Swift. Les autres filières sont derrière
  `OnbFlowCoordinator.visibleCurrentTracks` — un filtre à retirer pour les
  rouvrir.
- Identité/mot de passe collectés mais **non envoyés** (pas de `signUp`).
- Le pré-vol réseau au montage bloque l'avance hors ligne.

### Connexion
- `accounts` reste vide : l'activation admin et la récupération par code de
  secours sont **inatteignables** (registre local `utils/auth.ts` non porté).
- **Apple se branche sur le chemin Google** : `SessionStore` n'expose pas
  d'entrée Apple. Contournement documenté.

### Messagerie
Trois divergences signalées, non corrigées (elles vivent dans des fichiers
existants hors du périmètre des lots) : onglets « Direct/Forum » vs «
Messages/Forums » dans la source ; initiale figée `"P"` au lieu de
`profile.displayName` ; contrat `unreadCount` remplacé par un compteur local.

## Hors périmètre assumé — les fichiers non portés

Spécifiques à une autre plateforme ; les porter serait du code mort sur iOS.

- **Web / PWA « installée » (16)** : `ChallengeDesktopLayout`,
  `DesktopChapterStatusIcon`, `DesktopLeaderboardLauncher`,
  `DesktopQrLoginButton`, `DownloadedChartWindow`,
  `DownloadedPerformanceDetails`, `InstalledLeaderboardDrawer`,
  `SettingsDesktopLayout`, `downloaded*`, `useDesktopAccountNavigation`,
  `useOtaUpdate`. Mise en page « bureau » et mises à jour Expo Updates : sur un
  binaire natif iOS, l'App Store s'en charge.
- **Web seul (2)** : `RemotePhotoWebPanel` (s'exécute dans le navigateur de
  l'ordinateur) ; `webResponsiveLayout` (renvoie `'bottom'` dès que la
  plateforme n'est pas web).
- **Android seul (1)** : `AndroidBackNavigation` (bouton retour matériel).

## Vérifier

```sh
rsync -a --delete --exclude .git duello_swift_work/ zenbook:/tmp/duello-verify/
ssh zenbook 'export PATH="$HOME/.local/bin:$PATH"; cd /tmp/duello-verify && sh scripts/verify-swift-linux.sh'
```

## Reste à faire

- **Compiler sur macOS + Xcode.** C'est le seul juge : le pré-contrôle Linux
  vérifie la syntaxe des 647 fichiers et le typage des 303 fichiers
  `Foundation`, mais **ne type-check pas les vues SwiftUI**. Plusieurs lots
  signalent des points à confirmer (isolation `@MainActor`, `@ViewBuilder` en
  propriété stockée, `TabView(.page)`).
- **Pousser la branche** (action externe — la clé SSH GitHub de ce PC est
  refusée ; celle du Zenbook fonctionne).
