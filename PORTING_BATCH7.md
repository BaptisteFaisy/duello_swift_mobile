# LOT 7 — brief de fan-out (à lire avec `PORTING_BRIEF.md`)

Lis d'abord `PORTING_BRIEF.md` (conventions, chemins, fichiers interdits, types
déjà déclarés). Ce document ne fait que répartir le travail : **un lot = un
sous-agent**, un **préfixe de types réservé** par sous-agent.

- Dépôt cible : `/home/baptiste/.zeroclaw/agents/a/workspace/duello_swift_work`
- Source Expo  : `/home/baptiste/.zeroclaw/agents/a/workspace/expo_ref`

Le lot 7 ferme les **derniers modules atteignables depuis les écrans** encore
absents du port Swift (calcul de l'énoncé, énoncés/questions, clavier
mathématique avancé, récompenses, données locales d'onboarding, UI générique,
gestes d'onglets, consentement/garde premium, photo à distance côté récepteur).

## Rappels critiques (identiques aux lots 4 et 6)

- Tu **crées un ou plusieurs fichiers neufs** dans `Duello/`, **à plat**, nommés
  exactement comme indiqué. Tu ne modifies **aucun** fichier existant.
- **Tous** tes types portent ton préfixe. Les helpers `private` internes peuvent
  s'en passer.
- Cible **iOS 16** : pas de `@Observable`, `UnevenRoundedRectangle`,
  `ContentUnavailableView`, `.onChange` à deux paramètres, `NavigationStack`
  récursif dans un `TabView`. `import Charts` autorisé.
- Réutilise `Theme`, `.duelloCard()`, `DuelloUI.swift`, `DuelloAPI`,
  `SessionStore`. **Ne redéfinis jamais** un type déjà déclaré (en cas de doute,
  `grep` le dossier `Duello/`).
- Réseau : `DuelloAPI.request(...)`. Endpoint manquant ⇒ helper **local privé** ;
  **n'édite pas** `DuelloAPI.swift`.
- Libellés UI **en français**, mot pour mot depuis la source Expo (apostrophes
  typographiques `’` U+2019, points de suspension `…` U+2026, insécables).
- Fichier **complet**, aucun `TODO`, aucune troncature, pas de `print`.
- **Aucun compilateur Swift ici** : sois conservateur, aucune API incertaine,
  aucune dépendance externe (pas de SPM, pas de RevenueCat / PythonKit /
  WebRTC). Simule proprement et documente la limite en commentaire.
- **Complexité** : ≤ 500 lignes/fichier, ≤ 10 `func`/fichier, ≤ 50 lignes/func.
- En-tête de fichier : doc-comment citant les fichiers source Expo portés.

## Préfixes déjà employés (à ne PAS reprendre)

`Hec`, `Ctd`, `Prem`, `ExG`, `Ann`, `Plan`, `MathKb`, `Train`, `Wb`, `PyCon`,
`PhotoTx`, `Duel`, `Ranking`, `Messages`, `Notification`, `LatexToUnicode`,
`Program`, `Account`, `Progress`, `DuelloAPI`, `AnnCopyCorrection`, `AnnReader`,
`Ev`, `Adm`, `Aff`, `Affiliate`, `Course`, `Social`, `Google`, `Settings`,
`Schedule`, `Admin`, `Presence`, `Models`, `Theme`, `Session`, `Main`, `Root`,
`Welcome`, `Onboarding`, `Training`, `Challenges`, `Challenge`, `Events`,
`Annales`, `Premium`, `Whiteboard`, `Python`, `Leaderboard`, `WeeklyXP`,
`Installed`, `Legal`, `Load`, `Keychain`, `Server`, `AppleAuth`, `PushNotif`,
`AcctSec`, `Chart`, `League`, `Report`, `PremCode`, `PhotoPick`, `Dict`, `Chal`,
`OnbGift`, `Offl`, `Coll`, `RemPhoto`, `Soc`, `ExG`, `Ann`.

## Préfixes réservés au lot 7

| Lot | Fichier(s) cible(s) | Préfixe | Sources Expo |
| --- | --- | --- | --- |
| A | `Stmt*.swift` | `Stmt` | `src/utils/statementLayout.ts` (1 664 l.), `statementQuestions.ts` (659 l.), `mathAnswerLatex.ts` (761 l.), `questionReferenceSolution.ts`, `markingSchemeDisplay.ts`, `exerciseAnswerInput.ts` |
| B | `KbSup*.swift` | `KbSup` | `src/utils/mathKeySuggestions.ts`, `mathOcrSettings.ts` |
| C | `Rew*.swift` | `Rew` | `src/utils/exerciseCompletionReward.ts`, `activityMutationQueue.ts`, `storageScope.ts`, `followPublicationQueue.ts`, `eventConstants.ts` |
| D | `DevReg*.swift` | `DevReg` | `src/utils/deviceRegistration.ts` |
| E | `OnbData*.swift` | `OnbData` | `src/utils/onboardingSteps.ts`, `src/data/prepas.ts`, `src/data/targetSchools.ts`, `src/data/classicQuestions.ts`, `src/hooks/useOnboardingProviderAuth.ts` |
| F | `Ui2*.swift` | `Ui2` | `src/components/AddGradeModal.tsx`, `DuelloLoadingMark.tsx`, `ElasticScrollView.tsx`, `OrderedTabPager.tsx`, `SettingsCategoryRow.tsx`, `SwipeBackScreen.tsx`, `TrainingStartupSurface.tsx`, `PrepaSearchModal.tsx` (513 l.), `trainingGridStyles.ts` |
| G | `Swipe*.swift` | `Swipe` | `src/utils/bottomTabSwipe.ts`, `orderedTabSwipe.ts`, `settingsTabSwipe.ts`, `leaderboardSectionSwipe.ts`, `src/components/BottomTabSwipeGestureContext.ts`, `src/hooks/useLeaderboardCurrentRowVisibility.ts` |
| H | `Consent*.swift` | `Consent` | `src/components/AiConsentCard.tsx`, `src/hooks/useAiDataSharingConsent.ts`, `usePremiumToolGate.ts`, `useCourseLegendVisibility.ts`, `useScrollChromeVisibility.ts`, `useQuestionCorrectionSeconds.ts`, `usePushNotificationSettingsActions.ts`, `src/components/correction-summary/confirmStopCorrection.ts` |
| I | `RemPhotoRx*.swift` | `RemPhotoRx` | `src/components/remote-photo-connection/remotePhotoConnectionUtils.ts`, `useRemotePhotoReceiver.ts`, `remotePhotoConnectionStyles.ts` |

## Points d'entrée attendus (contrat d'intégration)

Chaque lot expose **au moins** un type d'entrée préfixé :

- **A** : `enum StmtLayout` (segmentation d'un énoncé en blocs/questions),
  `enum StmtQuestions` (extraction des questions, lettres, ancrage),
  `enum StmtLatex` (conversion réponse → LaTeX), `enum StmtReferenceSolution`,
  `enum StmtMarkingScheme`, `enum StmtAnswerInput`.
- **B** : `enum KbSupSuggestions` (clés suggérées selon le contexte),
  `enum KbSupOcrSettings`.
- **C** : `enum RewCompletion` (bonus de fin d'exercice, seuil 16/20),
  `final class RewMutationQueue`, `enum RewStorageScope`,
  `final class RewFollowQueue`, `enum RewEventConstants`.
- **D** : `enum DevReg` (identifiant d'installation stable, `GET`/`POST /devices`).
- **E** : `enum OnbDataSteps`, `enum OnbDataPrepas`, `enum OnbDataTargetSchools`,
  `enum OnbDataClassicQuestions`, `enum OnbDataProviderAuth`.
- **F** : `struct Ui2AddGradeSheet: View`, `struct Ui2LoadingMark: View`,
  `struct Ui2ElasticScrollView<Content: View>: View`,
  `struct Ui2OrderedTabPager<Content: View>: View`,
  `struct Ui2SettingsRow: View`, `struct Ui2SwipeBackContainer<Content: View>: View`,
  `struct Ui2TrainingStartupSurface: View`, `struct Ui2PrepaSearchSheet: View`.
- **G** : `enum SwipeBottomTabs`, `enum SwipeOrderedTabs`, `enum SwipeSettingsTabs`,
  `enum SwipeLeaderboardSections`, `enum SwipeRowVisibility`.
- **H** : `struct ConsentAiCard: View`, `enum ConsentAiSharing`,
  `enum ConsentPremiumGate`, `enum ConsentChromeVisibility`,
  `enum ConsentCorrectionSeconds`, `enum ConsentPushActions`,
  `enum ConsentStopCorrection`.
- **I** : `enum RemPhotoRxUtils`, `final class RemPhotoRxReceiver`,
  `enum RemPhotoRxStyles`.

## Réponse attendue de chaque sous-agent

1. Chemins des fichiers créés ; 2. résumé du porté ; 3. hors-périmètre et
pourquoi ; 4. liste des **types publics** déclarés (préfixés) ; 5. toute API
incertaine signalée. Sois bref (≤ 25 lignes).
