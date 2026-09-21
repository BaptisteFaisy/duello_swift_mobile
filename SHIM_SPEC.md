# SPÉCIFICATION — shims Linux pour le type-check complet

## But

`scripts/verify-swift-linux.sh` ne contrôle les **types** que des fichiers
« portables » (ceux qui n'importent que Foundation / UIKit / Security / Combine /
GoogleSignIn) : **303 sur 647**. Les **344 autres** — dont **326 qui importent
SwiftUI** — ne sont contrôlés qu'en **syntaxe** (`-parse`). Le cœur de l'app
n'a donc jamais passé un contrôle de types.

Objectif : écrire de faux modules (`scripts/linux-shims/`) couvrant SwiftUI et
les frameworks Apple utilisés, pour que `swiftc -typecheck` puisse voir
**l'ensemble du projet** et attraper les vraies erreurs : symbole inexistant,
membre mal nommé, mauvais libellé d'argument, type `private` utilisé depuis un
autre fichier, déclaration en double.

## Règles

- Les shims vivent dans `scripts/linux-shims/` et **ne sont jamais livrés** :
  hors de `Duello/`, donc hors de la cible Xcode.
- **Ne modifier AUCUN fichier de `Duello/`.** Un shim se corrige, pas le code.
- Cible iOS 16 / Swift 5. Rien qui exige une version supérieure.
- Un shim peut être **permissif** (c'est voulu) mais jamais **faux** : s'il
  déclare une signature qui n'existe pas dans le vrai framework, il masque une
  vraie erreur. Dans le doute, choisir la signature réelle.

## Approche recommandée

SwiftUI se prête au shim parce que sa structure est régulière :

```swift
public protocol View {}

extension View {
    public func font(_ font: Font?) -> some View { _ShimView() }
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { _ShimView() }
    // …
}
```

- `View` **sans exigence** : toute vue conforme trivialement, et `some View`
  fonctionne partout. On perd le contrôle « ce type est-il bien une vue ? », on
  garde tout le reste.
- Un `@resultBuilder ViewBuilder` avec `buildBlock`/`buildEither`/`buildIf`
  renvoyant un type unique.
- Les modificateurs sont des `extension View` renvoyant `some View` (ou un
  `_ShimView` concret) : le chaînage marche.
- **Ce qui est réellement testé** : les types et fonctions **du projet**.
  Leurs signatures sont déclarées dans `Duello/` et confrontées à leurs
  appels — c'est exactement là que 26 agents parallèles ont pu diverger.

## Surface à couvrir — mesurée sur le projet

### Types SwiftUI (occurrences)

```
View 1791 · Text 1083 · VStack 628 · RoundedRectangle 564 · HStack 491
Color 399 · Image 378 · Button 338 · Spacer 197 · ForEach 185 · ViewBuilder 135
Rectangle 112 · ZStack 110 · ScrollView 98 · Binding 95 · Circle 78
Capsule 74 · ProgressView 69 · EnvironmentObject 50 · Group 48 · ObservableObject 38
Environment 38 · ObservedObject 37 · StateObject 37 · TextField 34
GeometryReader 26 · NavigationStack 22 · ToolbarItem 23 · State 413
Published 161 · MainActor 99 · FocusState 8 · LazyVGrid · GridItem · TabView
Menu · Link · Label · Divider · List · Section · Form · Toggle · Slider
Picker · DatePicker · SecureField · TextEditor · NavigationLink · Sheet
LinearGradient · RadialGradient · AngularGradient · Gradient · Shadow
Shape · Path · Ellipse · InsettableShape · StrokeStyle · AnyView
ViewModifier · PreferenceKey · EnvironmentKey · Alignment · Animation
Transition · Namespace · ScrollViewReader · ScrollViewProxy · AsyncImage
AsyncImagePhase · ColorScheme · EdgeInsets · Edge · Axis · UnitPoint
ContentMode · TextAlignment · FontWeight · FontDesign · ShapeStyle
TupleView · EmptyView · ConditionalContent · ModifiedContent
```

### Modificateurs (occurrences ≥ 3)

```
font 1416 · foregroundStyle 1345 · padding 1142 · frame 957 · clipShape 399
buttonStyle 275 · overlay 262 · stroke 229 · opacity 156 · fixedSize 109
lineLimit 109 · multilineTextAlignment 98 · onChange 68 · contentShape 63
accessibilityElement 57 · tint 55 · offset 47 · textCase 47 · task 38
onAppear 35 · scaleEffect 31 · accessibilityHidden · accessibilityLabel
accessibilityValue · accessibilityHint · accessibilityAddTraits
background · foregroundColor · cornerRadius · resizable · scaledToFit
scaledToFill · ignoresSafeArea · navigationTitle · navigationBarTitleDisplayMode
toolbar · sheet · fullScreenCover · transition · animation · gesture
onTapGesture · simultaneousGesture · rotationEffect · rotation3DEffect
shadow · blur · border · truncationMode · allowsHitTesting · disabled
environmentObject · onReceive · onPreferenceChange · onDisappear · onSubmit
keyboardType · textContentType · textInputAutocapitalization · autocorrectionDisabled
submitLabel · labelsHidden · pickerStyle · progressViewStyle · tabViewStyle
scrollContentBackground · scrollDismissesKeyboard · focused · tag · tabItem
monospacedDigit · minimumScaleFactor · kerning · tracking · textSelection
controlSize · listRowSeparator · listRowBackground · listRowInsets
listStyle · contentMargins · containerRelativeFrame · layoutPriority
aspectRatio · drawingGroup · compositingGroup · zIndex · id
```

### Property wrappers

`@State` · `@Binding` · `@StateObject` · `@ObservedObject` ·
`@EnvironmentObject` · `@Environment` · `@Published` · `@FocusState` ·
`@ViewBuilder` · `@MainActor` · `@Namespace` · `@AppStorage` · `@SceneStorage`

### Attributs de déclaration

`@available` · `@escaping` · `@autoclosure` · `@discardableResult` ·
`@inlinable` · `@frozen` · `@objc` · `@propertyWrapper` · `@resultBuilder`

## Autres frameworks à shimer

| Module | Usage |
| --- | --- |
| `Charts` | 2 fichiers — `Chart`, `BarMark`, `LineMark`, `PointMark`, `AxisMarks`, `chartYAxis` |
| `PhotosUI` | 4 — `PhotosPickerItem`, `PHPickerViewController` |
| `AVFoundation` | 4 — `AVAudioSession`, `AVAudioRecorder`, `AVCaptureSession` |
| `LocalAuthentication` | 2 — `LAContext`, `LAPolicy`, `canEvaluatePolicy` |
| `UserNotifications` | 6 — `UNUserNotificationCenter`, `UNMutableNotificationContent` |
| `UniformTypeIdentifiers` | 2 — `UTType` |
| `MessageUI` | 2 — `MFMailComposeViewController`, `MFMessageComposeViewController` |
| `AuthenticationServices` | 1 — `ASAuthorizationController`, `ASAuthorizationAppleIDCredential` |
| `WebKit` | 1 — `WKWebView`, `WKScriptMessageHandler` |
| `PDFKit` | 1 — `PDFView`, `PDFDocument` |
| `Speech` | 1 — `SFSpeechRecognizer` |
| `Photos` | 1 — `PHPhotoLibrary` |
| `CryptoKit` | 1 — `SHA256` |
| `CoreGraphics` | 11 — sous Linux, `Foundation` fournit déjà `CGFloat`/`CGPoint`/`CGRect` : un shim qui réexporte suffit |

## Mise à jour du périmètre

`scripts/swift_linux_scope.py` filtre sur `PORTABLE_IMPORTS`. Une fois un shim
en place, **ajouter son module à cette liste** pour qu'il entre dans le lot
typé. Le tri (`triage`) écarte déjà les « cannot find type 'X' » quand `X` est
déclaré dans un fichier hors lot : ce garde-fou reste utile pendant la
transition.

## Boucle de travail

```sh
rsync -a --delete --exclude .git duello_swift_work/ zenbook:/tmp/<ton-dir>/
ssh zenbook 'export PATH="$HOME/.local/bin:$PATH"; cd /tmp/<ton-dir> && sh scripts/verify-swift-linux.sh 2>&1 | tail -40'
```

⚠️ **Un seul répertoire de travail par agent** : deux runs simultanés dans le
même dossier se marchent dessus.

## Critère de réussite

1. Le script **ne régresse pas** : la syntaxe des 647 fichiers reste propre et
   le lot portable actuel reste vert.
2. Le nombre de fichiers **réellement type-checkés augmente** (viser les 647).
3. Les erreurs qui **restent** sont dans `Duello/` — ce sont des **vraies
   erreurs** du portage. Les lister : c'est le résultat utile.
