# Portage Expo → SwiftUI natif (iOS)

Application Duello : portage de l'app **Expo / React Native** vers une app
**SwiftUI** native. Ce document est la feuille de route ; il est mis à jour à
chaque lot livré.

- **Cible** : `Duello/` (Swift, à plat) + `Duello.xcodeproj` (iOS 16+).
- **Source** : app Expo de dev servie sur le VPS (`duello-development`), ~1528
  fichiers `.ts/.tsx` (320 Mo). Les banques d'exercices `src/data/*.generated.ts`
  (3–4 Mo chacune) **ne sont pas portées** : elles sont servies par l'API
  (`/content/manifest.json`) et déjà consommées par `DuelloAPI`.
- **Contrainte** : aucun compilateur Swift sur la machine de portage → le code
  est écrit et relu avec soin, mais **la compilation se fait sur le Mac**.
- **Enregistrement des sources** : `python3 scripts/sync_xcode_sources.py`
  inscrit automatiquement tout nouveau `Duello/*.swift` dans le pbxproj.

## Conventions

| Élément | Règle |
| --- | --- |
| Couleurs / mesures | `Theme` (`Theme.ink`, `Theme.border`, `Theme.radiusMedium`…) |
| Composants partagés | `DuelloUI.swift` (`DuelloSectionHeader`, `DuelloPill`, `DuelloStatTile`…) |
| Carte standard | modificateur `.duelloCard()` |
| Réseau | `DuelloAPI.request(...)` — helpers locaux si l'endpoint manque |
| Session | `SessionStore` (`@EnvironmentObject`) |
| Cible | iOS 16 (pas d'API 17+) |
| Langue | libellés et commentaires en français |

## État

### Livré

| Fichier | Contenu | Source Expo |
| --- | --- | --- |
| `DuelloApp`, `MainTabView`, `RootView` | racine, onglets | `App.tsx`, `BottomNavigation.tsx` |
| `WelcomeView`, `GoogleAuth` | accueil, connexion, inscription, Google | `WelcomeScreen.tsx`, `LoginScreen.tsx`, `GoogleAuthButton` |
| `OnboardingView` | première configuration | `OnboardingScreen.tsx` |
| `AccountView`, `AccountDetailViews` | compte + écrans annexes | `AccountScreen.tsx`, `BlockedUsersScreen.tsx`… |
| `TrainingView` | entraînement (base) | `SubjectsScreen.tsx` (partiel) |
| `ChallengesView`, `ChallengePlayerView`, `DuelJudge` | défis, matchmaking, notation | `ChallengesScreen.tsx`, `utils/duel.ts` |
| `MessagesView` | messages direct + forum | `MessagesScreen.tsx` |
| `ProgressView`, `ProgressStore` | progression locale | `EnhancedProgressScreen.tsx` |
| `RankingsView` | ligues Elo + XP hebdo | `LeaderboardScreen.tsx`, `RankingsScreen.tsx` |
| `NotificationsViews` | réglages + rappels locaux | `NotificationSettingsCard.tsx` |
| `DuelloUI` | kit UI partagé | — |
| `TrainingCatalogView` | catalogue d'une matière : chapitres groupés par domaine, dépliage vers les exercices servis, filtre/tri par difficulté | `SubjectsScreen.tsx`, `data/tracks.ts` |
| `MathKeyboardView` | clavier mathématique : 7 onglets maths + 73 raccourcis Python, mode indice, outils guidés (matrice, opérateur, intervalle) | `MathKeyboard.tsx`, `utils/mathKeyboardLayout.ts` |
| `ExerciseGradingViews` | espace de travail d'exercice : bonus XP, appréciations, bilan de révision, célébration, **bilan de correction** | `ChallengeExerciseWorkspace.tsx`, `SuccessSummary.tsx` |
| `PremiumView` | offres (gratuit / annuel / hebdo), remises, code promo, badge, paywall + feuille réutilisable | `PaywallContent.tsx`, `PremiumOffers.tsx`, `premium-offers/…` |
| `AnnalesView` | liste filtrable, lecteur (énoncé / barème / commentaires / corrigé), correction de copie + moniteur de fond | `AnnaleViewer.tsx`, `AnnaleCopyCorrectionModal.tsx` |
| `PlanView` | planning journalier : grille horaire, carrousel de jours, analyseur de tâches local, répartition, persistance | `EnhancedPlanScreen.tsx` |
| `LatexToUnicode`, `Programs`, `DuelloExerciseCatalog`, `Models`, `DuelloAPI` | socle | `utils/latex.ts`, `data/tracks.ts`… |

### À porter

| Lot | Fichier cible | Sources Expo | État |
| --- | --- | --- | --- |
| Catalogue d'entraînement | `TrainingCatalogView.swift` | `SubjectsScreen.tsx`, `data/tracks.ts` | ✅ |
| Espace de travail d'exercice | `ExerciseGradingViews.swift` | `ChallengeExerciseWorkspace.tsx`, `SuccessSummary.tsx` | ✅ |
| Clavier mathématique | `MathKeyboardView.swift` | `MathKeyboard.tsx` | ✅ |
| Cours & TD | `CourseTdView.swift` | `CourseTdPanel.tsx`, `HtmlDocumentView.tsx` | ✅ |
| Annales | `AnnalesView.swift` | `AnnaleViewer.tsx`, `AnnaleCopyCorrectionModal.tsx` | ✅ |
| Premium / paywall | `PremiumView.swift` | `PaywallContent.tsx`, `PremiumOffers.tsx` | ✅ |
| Planning journalier | `PlanView.swift` | `EnhancedPlanScreen.tsx` | ✅ |
| Outils d'étude | `PythonConsoleView.swift`, `WhiteboardView.swift`, `PhotoTranscriptionView.swift` | `PythonConsole.tsx`, `Whiteboard.native.tsx`, `PhotoTranscriptionModal.tsx` | ✅ |
| Parcours HEC | `HecJourneyView.swift` | `HecJourney.tsx`, `HecJourneyScene.tsx` | ✅ |
| Événements | `EventsView.swift` | `EventsList.tsx`, `event/` | ✅ |
| Social (invitations, présence, profil public) | `SocialInviteModal.swift`, `PresenceViews.swift` | `ChallengeInviteModal.tsx`, `PresenceProvider.tsx` | ✅ |
| Réglages annexes & planification | `SettingsExtraViews.swift`, `ScheduleEditorView.swift` | `FeedbackScreen.tsx`, `ScheduleEditor.tsx` | ✅ |
| Affiliation | `AffiliateView.swift` | `features/affiliate/` | ✅ |
| Administration | `AdminView.swift` | `admin/` | ✅ |

**Roadmap terminée** : tous les lots prévus sont portés. Reste l'intégration
native (montage des écrans dans `MainTabView`/`AccountView`, `Info.plist`,
`project.pbxproj`) et la **compilation sur le Mac**.

## Conformité aux règles de complexité Duello

Règles (héritées de l'`AGENTS.md` du VPS, cf. `AGENTS.md` du workspace) :
**max 500 lignes/fichier, 10 fonctions/fichier, 50 lignes/fonction**.

Les gros écrans ont été découpés en modules à responsabilité claire — découpage
**transparent** (aucun type, propriété, méthode ni signature renommé) :

| Fichier d'origine | Lignes | Modules |
| --- | --- | --- |
| `AnnalesView.swift` | 2 827 | 14 fichiers `Ann*` |
| `PlanView.swift` | 2 103 | 16 fichiers `Plan*` |
| `MathKeyboardView.swift` | 2 071 | 15 fichiers `MathKb*` |
| `ExerciseGradingViews.swift` | 1 975 | 10 fichiers `ExG*` |
| `TrainingCatalogView.swift` | 1 066 | 15 fichiers `Train*` |
| `PremiumView.swift` (paywall) | 1 018 | 12 fichiers `Prem*` |

**Conformité atteinte** : tous les fichiers `Duello/*.swift` sont désormais
**≤ 500 lignes**. Vague v1–v3 découpée (batch 2) :

| Fichier d'origine | Lignes | Modules |
| --- | --- | --- |
| `AccountDetailViews.swift` | 963 | 7 fichiers `Account*` |
| `RankingsView.swift` | 855 | 9 fichiers `Ranking*` |
| `MessagesView.swift` | 845 | 9 fichiers `Messages*` |
| `NotificationsViews.swift` | 724 | 4 fichiers `Notification*` |
| `LatexToUnicode.swift` | 712 | 7 fichiers `LatexToUnicode*` |
| `Programs.swift` | 668 | 8 fichiers `Program*` |
| `DuelJudge.swift` | 635 | 5 fichiers `Duel*` |
| `AnnCopyCorrectionSheet.swift` | 624 | 5 fichiers `AnnCopyCorrection*` |
| `AnnReaderView.swift` | 607 | 4 fichiers `AnnReader*` |
| `DuelloAPI.swift` | 571 | 8 fichiers `DuelloAPI*` (extensions) |
| `ProgressView.swift` | 558 | 7 fichiers `Progress*` |

**Total : 211 fichiers Swift**, tous ≤ 500 lignes, ≤ 10 fonctions, ≤ 50 lignes
par fonction (sauf dérogations documentées en en-tête : grandes fonctions
héritées non découpables sans réécriture, et données statiques volumineuses).

> ⚠️ **Concurrence** : plusieurs sessions `agent -a a` travaillant dans le
> **même** arbre git se sont écrasées mutuellement (le paywall `PremiumView` a
> été perdu avant `e4c9f2b`, puis reconstruit). **Une seule session à la fois
> sur ce dépôt**, ou des clones / worktrees séparés.

## Pré-contrôle Swift sans Xcode (Linux)

Une toolchain **Swift 6.1.2 pour Linux** est installée sur le poste de
développement (`~/.local/bin/swiftc`) : elle ne remplace pas Xcode, mais elle
attrape déjà une classe entière de défauts avant d'ouvrir le Mac.

```sh
scripts/verify-swift-linux.sh     # exit 0 = vert
```

1. **Syntaxe** — `swiftc -parse` sur **tous** les fichiers (SwiftUI inclus).
2. **Types** — `swiftc -typecheck` sur le **lot portable** : les fichiers qui
   n'importent que Foundation / UIKit / Security / Combine / GoogleSignIn.
   SwiftUI, Charts, PDFKit… n'existent pas sous Linux : les vues ne sont pas
   typées ici.
3. **Tri** — `scripts/swift_linux_scope.py` sépare les échecs réels des faux
   positifs structurels : un fichier portable qui cite un type déclaré dans un
   fichier non portable est rapporté « hors couverture », sans faire échouer le
   contrôle. Tout le reste est un vrai défaut.

`scripts/linux-shims/` fournit des modules factices (`Security`, `UIKit`,
`Combine`, `GoogleSignIn`) **jamais livrés** : ils sont hors de la cible Xcode,
et `scripts/sync_xcode_sources.py` ne scanne que `Duello/`.

**Ce que ce contrôle a déjà attrapé** : `NSUserCancelledErrorCode` (symbole
inventé au portage, absent des en-têtes de Foundation du SDK iOS 16.4 — il
aurait cassé le build sur le Mac) et six `@Published` sans `import Combine`.
Il ne voit **pas** les erreurs de vue (layout, modificateurs, SF Symbols) :
la compilation sur Mac reste le seul juge final.
