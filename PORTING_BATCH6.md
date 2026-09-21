# LOT 6 — brief de fan-out (à lire avec `PORTING_BRIEF.md`)

Lis d'abord `PORTING_BRIEF.md` (conventions, chemins, fichiers interdits, types
déjà déclarés). Ce document ne fait que répartir le travail : **un lot = un
sous-agent**, un **préfixe de types réservé** par sous-agent.

- Dépôt cible : `/home/baptiste/.zeroclaw/agents/a/workspace/duello_swift_work`
- Source Expo  : `/home/baptiste/.zeroclaw/agents/a/workspace/expo_ref`

Le lot 6 couvre les **surfaces Expo encore absentes** du port Swift (auth Apple,
notifications poussées, sécurité du compte, graphiques, promotions de ligue,
signalements, code premium, photo de profil, dictée, extras de défi, extras
d'onboarding, contenu hors ligne, extras colles/cours, photo à distance).

## Rappels critiques (identiques au lot 4)

- Tu **crées un ou plusieurs fichiers neufs** dans `Duello/`, **à plat**, nommés
  exactement comme indiqué. Tu ne modifies **aucun** fichier existant.
- **Tous** tes types portent ton préfixe. Les helpers `private` internes peuvent
  s'en passer.
- Cible **iOS 16** : pas de `@Observable`, `UnevenRoundedRectangle`,
  `ContentUnavailableView`, `.onChange` à deux paramètres, `NavigationStack`
  récursif dans un `TabView`. `import Charts` autorisé.
- Réutilise `Theme`, `.duelloCard()`, `DuelloUI.swift`, `DuelloAPI`,
  `SessionStore`. **Ne redéfinis jamais** un type déjà déclaré (voir la liste du
  brief ; en cas de doute, `grep` le dossier `Duello/`).
- Réseau : `DuelloAPI.request(...)`. Endpoint manquant ⇒ helper **local privé**
  dans ton fichier ; **n'édite pas** `DuelloAPI.swift`.
- Libellés UI **en français**, mot pour mot depuis la source Expo (apostrophes
  typographiques `’`, points de suspension `…`).
- Fichier **complet**, aucun `TODO`, aucune troncature, pas de `print`.
- **Aucun compilateur Swift ici** : sois conservateur, aucune API incertaine,
  aucune dépendance externe (pas de SPM, pas de RevenueCat / PythonKit /
  WebRTC / SpeechKit externe). Si une brique native manque, **simule-la
  proprement** et documente la limite en commentaire + dans l'UI si pertinent.
- **Complexité** : ≤ 500 lignes/fichier, ≤ 10 `func`/fichier, ≤ 50 lignes/func.
- En-tête de fichier : doc-comment citant les fichiers source Expo portés.

## Préfixes déjà employés (à ne PAS reprendre)

`Hec`, `Ctd`, `Prem`, `ExG`, `Ann`, `Plan`, `MathKb`, `Train`, `Wb`, `PyCon`,
`PhotoTx`, `Duel`, `Ranking`, `Messages`, `Notification`, `LatexToUnicode`,
`Program`, `Account`, `Progress`, `DuelloAPI`, `AnnCopyCorrection`, `AnnReader`,
`Ev`, `Adm`, `Aff`, `Affiliate`, `Course`, `Social`, `Google`, `Settings`,
`Schedule`, `Admin`, `Presence`, `Models`, `Theme`, `Session`, `Main`, `Root`,
`Welcome`, `Onboarding`, `Training`, `Challenges`, `Challenge`, `Events`,
`Annales`, `Premium`, `Whiteboard`, `Python`, `Duel`, `Leaderboard`,
`WeeklyXP`, `WeeklyXp`, `Installed`, `Legal`, `Load`, `Keychain`, `Server`.

## Préfixes réservés au lot 6

| Lot | Fichier(s) cible(s) | Préfixe | Sources Expo |
| --- | --- | --- | --- |
| A | `AppleAuth*.swift` | `AppleAuth` | `src/components/AppleAuthButton.tsx`, `AppleAuthButton.types.ts`, `SocialAuthFallbackButton.tsx`, `src/utils/appleAuth.ts`, `appleIdentity.ts`, `appleAccount.ts` |
| B | `PushNotif*.swift` | `PushNotif` | `src/utils/pushNotifications.ts`, `notificationPolicy.ts`, `pushNotificationTokenState.ts`, `pushNotificationSync.ts`, `pushNotificationRetryLoop.ts`, `pushNotificationOperationQueue.ts`, `pushNotificationReconciliation.ts`, `src/components/PushNotificationCoordinator.tsx`, `PushNotificationTapHandler.tsx`, `NotificationBadgeSync.tsx` |
| C | `AcctSec*.swift` | `AcctSec` | `src/screens/AccountEmailScreen.tsx`, `AccountPasswordScreen.tsx`, `src/components/PasswordResetForm.tsx`, `RecoveryCodeModal.tsx`, `src/utils/passwordReset*.ts`, `recoveryCodePolicy.ts`, `usernameAvailability.ts`, `biometricPolicy.ts`, `src/utils/loginAccountSelection.ts` |
| D | `Chart*.swift` | `Chart` | `src/components/XpChart.tsx`, `XpLevelCard.tsx`, `XpProgressBar.tsx`, `XpGainProgress.tsx`, `GradeChart.tsx`, `EloChart.tsx`, `MasteryPie.tsx`, `SubjectSuccessChart.tsx`, `SubjectTimeTrendChart.tsx`, `CorrectionGradeChart.tsx`, `GradeEvolutionBadge.tsx`, `ExerciseMetricHistory.tsx`, `PerformanceOverviewBar.tsx`, `src/utils/{xpSeries,gradeChart,smoothChartPath,subjectTimeSeries,accountMetricEvolution,xpLevelProgress,performanceChartWindow,timeChartNavigation}.ts` |
| E | `League*.swift` | `League` | `src/utils/eloLeaguePromotion.ts`, `leagueBadges.ts`, `src/components/EloLeaguePromotionCard.tsx`, `EloLeaguePromotionCelebration.tsx`, `LeagueBadgeOutline.tsx`, `BadgeFlipHint.tsx`, `src/hooks/useEloLeaguePromotionLifecycle.ts`, `useEloLeaguePromotionStyles.ts` |
| F | `Report*.swift` | `Report` | `src/components/UserReportModal.tsx`, `QuestionCorrectionReportModal.tsx`, `ExerciseReportButton.tsx`, `ProfileSafetyMenu.tsx`, `question-report/ReportSection.tsx`, `question-report/StatementPager.tsx`, `PublicProfilePublisher.tsx`, `src/utils/{publicProfileSnapshot,socialVisibility,knownSocialProfiles,socialProfileSanitize}.ts` |
| G | `PremCode*.swift` | `PremCode` | `src/components/PremiumCodeRedemptionCard.tsx`, `PremiumUnlockCelebration.tsx`, `SubscriptionPaymentSync.tsx`, `src/utils/{premiumCodeRedemption,premiumCodeRedemptionApi,premiumCodeRedemptionResponse,premiumCodeRedemptionState,premiumUnlockEvents,subscriptionSync,subscriptionEvents,remoteSubscription,purchaserIdentity}.ts` |
| H | `PhotoPick*.swift` | `PhotoPick` | `src/components/profile-photo/*`, `src/utils/{profilePhoto,profilePhotoUri}.ts` |
| I | `Dict*.swift` | `Dict` | `src/utils/{mathDictation,speechMath,dictationAccess,dictationLanguage,realTimeAsr}.ts`, `src/hooks/useDictationAppState.ts` |
| J | `Chal*.swift` | `Chal` | `src/components/ChallengeHomeOverview.tsx`, `IncomingChallengeModal.tsx`, `ChallengeInvitationCoordinator.tsx`, `src/hooks/useChallengeQueue.ts`, `src/utils/{challengeSeries,challengeTimer,challengeExerciseProgress}.ts` |
| K | `OnbGift*.swift` | `OnbGift` | `src/components/OnboardingPremiumGift*.tsx/ts`, `OnboardingLegalNotice.tsx`, `OnboardingMathProgressChart.tsx`, `OnboardingStepTransition.tsx`, `src/utils/{onboardingStepTransition,progressiveReveal}.ts` |
| L | `Offl*.swift` | `Offl` | `src/content/{contentDownloadConfig,contentDownloadCoordinator,contentDownloadState,contentStore,contentCache,contentSync,contentBootstrap,contentInteractionGate,resumableExercisePrefetch}.ts`, `src/components/OfflineDownloadProgress.tsx`, `src/hooks/{useContentDownload,useOfflineContentCache,useContentRevision}.ts` |
| M | `Coll*.swift` | `Coll` | `src/components/ColleCompletionPanel.tsx`, `CourseChapterSidebar.tsx`, `ExercisePageEmptyState.tsx`, `ProgressiveList.tsx`, `src/utils/{colleCompletion,colleBanks,colleExercises,courseDocumentData,courseFlashcards,courseKnowledgeIndex,trainingStartupSummary,trainingItemTitle,trainingTime,trainingSubmissionSummary}.ts` |
| N | `RemPhoto*.swift` | `RemPhoto` | `src/components/remote-photo-connection/*`, `src/utils/remotePhoto*.ts` |

## Points d'entrée attendus (contrat d'intégration)

Chaque lot expose **au moins** une vue d'entrée `public struct <Prefix>…View: View`
et un modèle décodable si la source en a un. Contrats précis :

- **A** : `struct AppleAuthView: View` (bouton « Continuer avec Apple » + état) et
  `enum AppleAuthService` avec `static func signIn() async throws -> AppleAuthCredential`.
  **Limite assumée** : `AuthenticationServices` n'est pas vérifiable ici — isole
  l'appel dans un `#if canImport(AuthenticationServices)` et documente.
- **B** : `enum PushNotifPolicy` (fonctions pures testables), `struct PushNotifSettingsView: View`,
  `final class PushNotifCoordinator` (enregistrement du jeton + envoi au serveur).
- **C** : `struct AcctSecEmailView: View`, `struct AcctSecPasswordView: View`,
  `struct AcctSecRecoveryCodeView: View`, `struct AcctSecPasswordResetForm: View`.
- **D** : vues `Chart…` (une par composant) + helpers de série.
- **E** : `struct LeaguePromotionCard: View`, `struct LeaguePromotionCelebration: View`,
  `enum LeagueBadges`.
- **F** : `struct ReportUserSheet: View`, `struct ReportQuestionSheet: View`,
  `struct ReportSafetyMenu: View`, `struct ReportStatementPager: View`.
- **G** : `struct PremCodeRedemptionCard: View`, `struct PremCodeUnlockCelebration: View`,
  `enum PremCodeAPI`.
- **H** : `struct PhotoPickSheet: View`, `enum PhotoPickService`.
- **I** : `struct DictControlView: View`, `enum DictPolicy`, `protocol DictEngine`.
- **J** : `struct ChalHomeOverview: View`, `struct ChalIncomingSheet: View`,
  `enum ChalSeries`, `enum ChalTimer`.
- **K** : `struct OnbGiftStepView: View`, `struct OnbGiftTimeline: View`,
  `struct OnbGiftLegalNotice: View`.
- **L** : `struct OfflDownloadProgressView: View`, `final class OfflContentStore`,
  `enum OfflDownloadConfig`.
- **M** : `struct CollCompletionPanel: View`, `struct CollChapterSidebar: View`,
  `struct CollProgressiveList: View`, `struct CollEmptyState: View`.
- **N** : `struct RemPhotoConnectionView: View`, `enum RemPhotoProtocol`, `enum RemPhotoAPI`.

## Réponse attendue de chaque sous-agent

1. Chemins des fichiers créés ; 2. résumé du porté ; 3. hors-périmètre et
pourquoi ; 4. liste des **types publics** déclarés (préfixés) ; 5. toute API
incertaine signalée. Sois bref (≤ 25 lignes).
