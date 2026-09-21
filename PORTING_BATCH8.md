# LOT 8 — corrections de fidélité (audits indépendants du lot 6)

Ce lot ne crée **aucun** fichier : il **corrige** des fichiers du lot 6 et du
lot 4. Chaque défaut ci-dessous a été **revérifié contre la source Expo** avant
d'être inscrit ici (le rapport d'audit seul ne fait pas foi).

Règles : iOS 16 ; libellés FR **mot pour mot** ; aucune dépendance externe ;
≤ 500 lignes/fichier, ≤ 10 `func`/fichier, ≤ 50 lignes/func ; **ne touche à
aucun fichier hors de ta liste** ; relis la source Expo citée avant de modifier.

## Agent C1 — fidélité `Chart` (11 fichiers)

| # | Fichier:ligne | Défaut (vérifié) | Correction |
| --- | --- | --- | --- |
| 1 | `ChartDateFormat.swift` (`historyDate`) | `formatter("d MMMM yyyy 'à' HH:mm")` ⇒ jour non paddé ; source `ExerciseMetricHistory.tsx:15-21` = `day:'2-digit'` ⇒ « 05 septembre 2026 à 14:05 » | `"dd MMMM yyyy 'à' HH:mm"` |
| 2 | `ExGGradingFoundation.swift` (`ExGFormat.xp`) | `formatter.groupingSeparator = "\u{00A0}"` ; source `utils/xp.ts:183` sépare avec **U+202F** | `"\u{202F}"` (vérifier les autres usages d'`ExGFormat.xp`) |
| 3 | `ChartXpGainProgress.swift` | interpolation **linéaire** en 60 pas ; source `XpGainProgress.tsx:8,21-23` = 1 800 ms, `Easing.inOut(Easing.cubic)`, délai 350 ms | courbe cubique in-out |
| 4 | `ChartLinePlot.swift` | « thinning » absent ; source `XpChart.tsx:25,64` et `EloChart.tsx:22,79` = `MAX_VISIBLE_DOTS = 24`, `showsEveryDot = points.length <= 24` | masquer les points intermédiaires au-delà de 24 |
| 5 | `ChartLinePlot.swift` (`dotSize`) | défaut 6 ; source `SubjectSuccessChart.tsx:26` = `DOT_SIZE = 8` | 8 pour `ChartSubjectSuccessChart` |
| 6 | `ChartXpChart.swift` | marge gauche infobulle 40 ; source `XpChart.tsx:176` = `marginLeft: 46` | 46 |
| 7 | `ChartCorrectionGradeChart.swift` | repère d'axe médian perdu ; source `CorrectionGradeChart.tsx:125-127` = `20` / `10` / `0` | ajouter le libellé médian |
| 8 | `ChartSubjectTimeTrendChart.swift` | axe `32×180` ; source `SubjectTimeTrendChart.tsx:37,377` = `width: 38`, `height: PLOT_HEIGHT + 13` = 138+13 = **151** | 38 / 151 |
| 9 | `ChartSubjectTimeTrendChart.swift` | barre « courante » et libellé x gras perdus (source : dernière colonne en `colors.ink`, libellé gras) | re-teinter la dernière barre |
| 10 | `ChartGradeChart.swift` | `accessibilityLabel` absent ; source `GradeChart.tsx:89` | « Évolution de N note(s) sur 20, répartie en M courbe(s) par type » (singulier/pluriel) |
| 11 | `ChartExerciseMetricHistory.swift` (`metric`) | pas d'`accessibilityLabel` ; source `ExerciseMetricHistory.tsx:24` = `accessibilityLabel={\`${label} : ${value}\`}` | ajouter le libellé |
| 12 | `ChartExerciseMetricHistory.swift` | « Essai N » non majusculé ; source en `textTransform: 'uppercase'` | `.textCase(.uppercase)` |
| 13 | `ChartXpLevelCard.swift` | icône de compteur 13 ; source `size={14}` | 14 |
| 14 | `ChartLinePlot`, `ChartExerciseMetricHistory`, `ChartXpLevelCard` | `fontWeight: '900'` rendu `.heavy` (**= 800** en SwiftUI) ; la source demande 900 | `.black` |
| 15 | `ChartCorrectionGradeChart`, `ChartSubjectSuccessChart` | infobulle jointe par « — » alors que la source empile **2 lignes** ; `ChartSubjectSuccessChart:51` affiche toujours le 2ᵉ sujet | séparer ; rétablir le garde `entries.length > 1` |

## Agent C2 — `Report`, `AcctSec`, `PhotoPick`, `Offl`, `Dict` (7 fichiers)

| # | Fichier | Défaut | Correction |
| --- | --- | --- | --- |
| 1 | `ReportAPI.swift` | corps `PUT /profiles` : `xpAwards` omis (la source l'envoie toujours, défaut `[]`) et `photoUri` non filtré | ajouter `xpAwards: []`, passer par `publicProfilePhotoUri` |
| 2 | `AcctSecPasswordResetForm.swift` | la source exige session **+ `account` + concordance d'e-mail** (`requirePasswordResetAuthentication`, `passwordResetIdentityMatches`) ; le port ne contrôle que `session` | valider aussi `account.email` |
| 3 | `AcctSecRecoveryCodePolicy.swift` | `normalize` garde les lettres/chiffres **non ASCII** ; la source ne garde que `[a-z0-9]` | filtrer `[a-z0-9]` |
| 4 | `AcctSecUsernameAvailability.swift` | `CharacterSet.decimalDigits` (≈`\p{Nd}`) au lieu de `\p{N}` ; `letters` au lieu de `\p{L}` | aligner sur `\p{N}` / `\p{L}` |
| 5 | `PhotoPickService.swift:45` | libellé « Complète ton nom et ton e-mail pour publier ta photo. » ≠ source « Complète ton nom pour apparaître dans l'annuaire. » | reprendre la source |
| 6 | `OfflDownloadProgressView.swift:37` | icône SF ≠ source `cloud-download-outline` | glyph SF équivalent |
| 7 | `DictMathFormat.swift` | messages d'erreur : le nom du fournisseur est remplacé par un placeholder entre crochets là où la source le nomme | **vérifier contre la source** puis rétablir le nom exact |

## Agent C3 — `Chal`, `RemPhoto`, `OnbGift` (7 fichiers)

| # | Fichier | Défaut | Correction |
| --- | --- | --- | --- |
| 1 | `ChalInvitationCoordinator.swift:89-92` | `busy` court-circuite **avant** l'appel réseau ⇒ le serveur ne reçoit jamais `busy=true` ; la source (`useChallengeQueue.ts`) appelle `fetchIncoming(busy:)` **puis** vide | appeler puis vider |
| 2 | `ChalAPI.swift:224-225` | `chapterKeys`/`chapterNames` filtrés des chaînes vides ; source `strings()` les conserve | retirer le filtre |
| 3 | `ChalAPI.swift:228-229` | `createdAt`/`expiresAt` restent `nil` ; source les replie sur `Date.now()` | replier sur l'instant courant |
| 4 | `RemPhotoProtocol.swift:59-60` | clé `photoId` **absente** acceptée ; source la rejette (`!== null && typeof !== 'string'`) | rejeter la clé absente |
| 5 | `RemPhotoProtocol.swift:117` | clé `connectedAt` **absente** acceptée ; même règle source | rejeter la clé absente |
| 6 | `OnbGiftHand.swift:57-58` | la main est centrée par le `ZStack` (centre y = 105) alors que `OnboardingPremiumGiftHand.tsx:92-93` la pose `top: 210/2 − 52` (centre y = 79) | corriger l'offset (26 pt) |
| 7 | `OnbGiftMathProgressChart.swift:34-36` | `padding(16)` + fond noir ajoutés, absents de `OnboardingMathProgressChart.tsx:226` (`story: {width:'100%', gap:18}`) ⇒ double marge | retirer l'ajout |

## Réponse attendue

Pour chaque fichier touché : `fichier:ligne`, ce qui a changé, et la source Expo
qui le justifie. Sois bref (≤ 25 lignes). Signale tout défaut que tu **n'as pas**
pu corriger et pourquoi.
