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
| `LatexToUnicode`, `Programs`, `DuelloExerciseCatalog`, `Models`, `DuelloAPI` | socle | `utils/latex.ts`, `data/tracks.ts`… |

### À porter

| Lot | Fichier cible | Sources Expo | État |
| --- | --- | --- | --- |
| Catalogue d'entraînement | `TrainingCatalogView.swift` | `SubjectsScreen.tsx`, `data/tracks.ts` | ⏳ |
| Espace de travail d'exercice | `ExerciseWorkspaceView.swift` | `ChallengeExerciseWorkspace.tsx`, `SuccessSummary.tsx` | ⏳ |
| Clavier mathématique | `MathKeyboardView.swift` | `MathKeyboard.tsx` | ⏳ |
| Cours & TD | `CourseTdView.swift` | `CourseTdPanel.tsx`, `HtmlDocumentView.tsx` | ⏳ |
| Annales | `AnnalesView.swift` | `AnnaleViewer.tsx`, `AnnaleCopyCorrectionModal.tsx` | ⏳ |
| Premium / paywall | `PremiumView.swift` | `EnhancedPlanScreen.tsx`, `PaywallContent.tsx` | ⏳ |
| Outils d'étude | `StudyToolsView.swift` | `PythonConsole.tsx`, `Whiteboard.native.tsx`, `PhotoTranscriptionModal.tsx` | ⏳ |
| Parcours HEC | `HecJourneyView.swift` | `HecJourney.tsx`, `HecJourneyScene.tsx` | ⏳ |
| Événements | `EventsView.swift` | `EventsList.tsx`, `event/` | ⏳ |
| Social (invitations, présence, profil public) | `SocialViews.swift` | `ChallengeInviteModal.tsx`, `PresenceProvider.tsx` | ⏳ |
| Réglages annexes & planification | `SettingsExtraViews.swift` | `FeedbackScreen.tsx`, `ScheduleEditor.tsx` | ⏳ |
| Affiliation | `AffiliateView.swift` | `features/affiliate/` | ⏳ |
| Administration | `AdminView.swift` | `admin/` | ⏳ |
