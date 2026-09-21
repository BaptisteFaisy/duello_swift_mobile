# Contrôle de types Swift complet — mode d'emploi et résultat

## Le problème

`scripts/verify-swift-linux.sh` ne contrôlait les **types** que des fichiers
« portables » — ceux qui n'importent que Foundation / UIKit / Security /
Combine / GoogleSignIn : **303 sur 647**. Les **344 autres**, dont **326 qui
importent SwiftUI**, n'étaient contrôlés qu'en **syntaxe** (`-parse`). Le cœur
de l'app n'avait donc jamais passé un contrôle de types, et un portage fait par
26 agents parallèles n'était vérifié que sur la forme.

Le lot « portable » avait en outre ses propres angles morts : `Int.color` est
déclaré dans `DuelloUI.swift` (non portable), donc les 21 sites
`Theme.<x>Hex.color` remontaient comme fautifs alors qu'ils étaient valides.

## La solution : 19 modules factices

`scripts/linux-shims/` contient des faux modules qui laissent `swiftc` voir
l'ensemble du projet. Ils ne sont **jamais livrés** (hors de `Duello/`, donc
hors de la cible Xcode).

| Module | Fichiers | Note |
| --- | --- | --- |
| `SwiftUI` | 4 | ~150 Ko : `View`, builders, property wrappers, modificateurs, formes, `Layout`, `Canvas`, `TimelineView`… |
| `Charts` | 1 | `Chart`, `BarMark`, `LineMark`, `AxisMarks` |
| `PhotosUI`, `AVFoundation`, `LocalAuthentication`, `UserNotifications`, `UniformTypeIdentifiers`, `MessageUI`, `AuthenticationServices`, `WebKit`, `PDFKit`, `Speech`, `Photos`, `CryptoKit` | 1 chacun | surface réellement utilisée seulement |
| `CoreGraphics` | 1 | réexporte `Foundation` (qui fournit `CGFloat`/`CGPoint`/`CGRect` sous Linux) |

`Security.swift` et `UIKit.swift` complètent ceux qui existaient déjà.

### Choix de modélisation, et pourquoi ils comptent

Un shim **permissif** est sans danger ; un shim **faux** masque de vraies
erreurs. Trois décisions ont été prises pour rester fidèle :

- **`View` est `@MainActor @preconcurrency`**, et `body` l'est aussi. C'est la
  déclaration du SDK employé pour construire l'app. Conséquence modélisée : un
  type qui conforme devient isolé, donc son `init` peut appeler un
  initialiseur `@MainActor`. Les initialiseurs **du shim** sont `nonisolated` :
  ils apparaissent en valeur par défaut des signatures, expressions évaluées
  hors contexte isolé.
- **Les API iOS 17 ne sont pas déclarées** (`UnevenRoundedRectangle`,
  `ContentUnavailableView`, `@Observable`…) : la cible est iOS 16, et leur
  absence fait échouer leur usage — c'est ce qu'on veut.
- **`ViewBuilder` s'arrête à dix enfants**, comme le vrai. Au-delà, SwiftUI
  échoue ; le shim doit échouer pareil.

### Ce que le shim ne peut PAS vérifier

- le rendu, la mise en page, les couleurs ;
- les types à l'intérieur d'un chaînage de modificateurs (ils renvoient
  `some View`, volontairement) ;
- les API absentes du shim : un symbole manquant produit une erreur « cannot
  find in scope » qu'il faut d'abord attribuer au shim, pas au projet.

## Usage

```sh
rsync -a --delete --exclude .git duello_swift_work/ zenbook:/tmp/duello-verify/
ssh zenbook 'export PATH="$HOME/.local/bin:$PATH"; cd /tmp/duello-verify && sh scripts/verify-swift-linux.sh'
```

Le script fait tout : il construit les 19 shims dans l'ordre de dépendance,
parse les 649 fichiers, puis les type-check tous en lot.

⚠️ **`-enable-batch-mode` est indispensable.** Sans lui, `swiftc` s'arrête au
premier fichier fautif et masque toutes les erreurs suivantes. La différence
est spectaculaire : la passe séquentielle montrait **2** erreurs, la passe en
lot en montre **82**. Le script l'active.

La séparation « portable / non portable » a été **supprimée** : tout est shimé,
donc tout est typé. Elle ne servait plus qu'à produire des faux positifs.

## Résultat

19 modules construits, **649 fichiers type-checkés, 0 erreur**. Au passage,
**12 erreurs de compilation réelles** ont été trouvées dans `Duello/` — toutes
corrigées (commits `e95880a` et suivants) :

| # | Fichier | Erreur |
| --- | --- | --- |
| 1 | `StmtQuestionParse.swift` | `StmtQuestionSupport.` — type inexistant |
| 2 | `AccountForgotPasswordView.swift` | `isPlausibleEmail` jamais déclaré |
| 3 | `MessagesBubble.swift` | `UnevenRoundedRectangle` (iOS 17) |
| 4 | `AccountView.swift` | 23 enfants dans un `ViewBuilder` (limite 10) |
| 5 | `AcctSearchView.swift` | état `@MainActor` lu sans `await` |
| 6 | `ChalRunRounds.swift` | `private var` ⇒ initialiseur membre-à-membre `private` |
| 7 | `ChartEloChart.swift` | arguments dans le désordre |
| 8 | `AcctSecPasswordResetForm.swift` | `prime()` isolée appelée sans `await` |
| 9 | `LatexToUnicodeNormalization.swift` | `String([String])` n'existe pas |
| 10 | `LatexToUnicodeRendering.swift` | `String += Character` n'existe pas |
| 11 | `OnbFlowView.swift` | `EvEventAudience.programYear` — déclaré sur `EvEventAudienceFilter` |
| 12 | `StmtLayoutDocument.swift` | `match.range(at:)` sur un tuple qui n'expose que `range` |
| 13 | `PlanScreen.swift` ↔ `PlanView+*.swift` | ~40 accès `private` entre deux fichiers (les deux sens) |
| 14 | `Ui2AddGradeSheet.swift` | 14 enfants dans un `ViewBuilder` (limite 10) |

Les 21 sites `Theme.<x>Hex.color` corrigés au passage n'étaient **pas**
fautifs : c'étaient des faux positifs du lot portable. Les accesseurs
`Theme.gradingPerfect…` ajoutés restent une amélioration de cohérence.

Aucune de ces erreurs n'était visible dans le contrôle précédent : ni en
syntaxe, ni sur le lot portable.

## Pièges rencontrés

- **`swiftc` séquentiel masque tout.** Voir `-enable-batch-mode` ci-dessus.
- **Un shim peut crasher le compilateur** (`signal 11`) : c'est arrivé avec un
  `environment(_:_:)` attendant un `WritableKeyPath` alors que la propriété du
  shim était en lecture seule. Un crash de `swiftc` est un signal de shim
  incohérent, pas de bug du projet.
- **`CoreFoundation` sous Linux** : `CFString` n'accepte pas de littéral et
  `CFDictionary` n'est pas `[String: Any]`. Le shim `Security` ramène donc ces
  deux types à leurs équivalents Swift.
- **`URL.startAccessingSecurityScopedResource`** n'existe pas dans
  corelibs-foundation : l'extension vit dans le shim SwiftUI (les fichiers de
  Duello importent SwiftUI, donc ils la voient).
