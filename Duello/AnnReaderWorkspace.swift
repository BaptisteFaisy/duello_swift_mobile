import SwiftUI

// MARK: - Atelier de réponse du lecteur d'annale
//
// Port de l'atelier d'`AnnaleViewer.tsx` (unité 18) : le séparateur déplaçable
// entre l'énoncé et la réponse (`useAnnaleSplit`, `PaneSplitter`,
// `AnnaleViewer.tsx:657-930`, monté à `:4141-4146`), puis l'atelier lui-même —
// champ de réponse, tableau blanc (`WhiteboardView`) et console Python
// (`PythonConsoleView`), montés respectivement à `AnnaleViewer.tsx:1570-1577`
// / `:4320-4325` et `:1628-1632` / `:4385-4389`.
//
// La dictée, la photo, le clavier mathématique et la composition de réponse
// (`AnswerComposition`) relèvent d'autres unités et ne sont pas montés ici.

/// Outil d'écriture affiché dans l'atelier.
enum AnnAnswerMode {
    case text
    case whiteboard
    case python
}

// MARK: - Séparateur énoncé / atelier

extension AnnReaderView {
    /// Zone de travail : énoncé (haut), séparateur déplaçable, atelier (bas).
    var splitArea: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let bounds = AnnaleSplit.annaleSplitBounds(contentHeight: height)
            let ratio = AnnaleSplit.effectiveAnnaleSplit(
                ratio: splitRatio,
                keyboardOpen: false,
                contentHeight: height
            )
            VStack(spacing: 0) {
                statementPane
                    .simultaneousGesture(documentSwipeGesture)
                    .frame(height: max(0, height * CGFloat(ratio) - AnnSplitterHandle.height / 2))
                AnnSplitterHandle(
                    ratio: splitRatio,
                    bounds: bounds,
                    contentHeight: height,
                    onRatio: { splitRatio = $0 },
                    onCommit: { AnnaleSplit.saveAnnaleSplit(itemId: entry.id, ratio: splitRatio) }
                )
                workspacePane
            }
        }
    }

    /// Atelier du bas : puces de question puis réponse (`AnnaleViewer.tsx:4171-4450`).
    var workspacePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                questionNavigation
                AnnAnswerWorkspace(
                    draft: $draft,
                    mode: $answerMode,
                    strokes: $whiteboardStrokes
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
    }

    /// Balayage horizontal sur l'énoncé : vers la gauche, il avance au corrigé
    /// (quand il est déverrouillé) ; vers la droite, il revient à l'énoncé
    /// (`documentSwipeGesture`, `AnnaleViewer.tsx:3521-3556`).
    var documentSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in swipeTracker.sample(value.translation.width) }
            .onEnded { value in
                let translationX = Double(value.translation.width)
                let translationY = Double(value.translation.height)
                guard AnnDocumentSwipe.intent(translationX: translationX, translationY: translationY) == .horizontal
                else { return }
                if let target = AnnDocumentSwipe.target(
                    current: mode,
                    translationX: translationX,
                    velocityX: swipeTracker.velocityX,
                    canShowSolution: canShowSolution
                ) {
                    mode = target
                }
            }
    }
}

// MARK: - Balayage du document

/// Suit la vitesse horizontale d'un glissement, sans provoquer de rendu
/// (contrairement à un `@State` mis à jour à chaque point).
final class AnnSwipeTracker {
    private var lastX: CGFloat = 0
    private var lastTime: Date = .distantPast
    private(set) var velocityX: Double = 0

    func sample(_ x: CGFloat) {
        let now = Date()
        let interval = now.timeIntervalSince(lastTime)
        if interval > 0, lastTime != .distantPast {
            velocityX = Double(x - lastX) / interval
        }
        lastX = x
        lastTime = now
    }
}

/// Direction d'un glissement, résolue à l'axe dominant
/// (`resolveHorizontalGestureIntent`, `utils/horizontalGesture.ts`).
enum AnnGestureIntent {
    case pending
    case horizontal
    case vertical
}

/// Seuils et cible du balayage de document, repris de `horizontalGesture.ts`
/// et `documentModeSwipe.ts`.
enum AnnDocumentSwipe {
    /// `HORIZONTAL_ACTIVATION_DISTANCE`.
    static let activationDistance = 9.0
    /// `VERTICAL_FAILURE_DISTANCE`.
    static let verticalFailureDistance = 4.0
    /// `HORIZONTAL_DOMINANCE_RATIO`.
    static let dominanceRatio = 1.5
    /// `SWIPE_COMMIT_DISTANCE`.
    static let commitDistance = 32.0
    /// `SWIPE_FLICK_MIN_DISTANCE`.
    static let flickMinDistance = 12.0
    /// `SWIPE_FLICK_VELOCITY`.
    static let flickVelocity = 380.0

    /// `resolveHorizontalGestureIntent` : l'axe vertical garde la main sur un
    /// défilement, l'axe horizontal n'est réservé que sur une intention nette.
    static func intent(translationX: Double, translationY: Double) -> AnnGestureIntent {
        let distanceX = abs(translationX)
        let distanceY = abs(translationY)
        if distanceY >= verticalFailureDistance, distanceY >= distanceX { return .vertical }
        if distanceX >= activationDistance, distanceX > distanceY * dominanceRatio { return .horizontal }
        return .pending
    }

    /// `resolveDocumentSwipeTarget` : un geste trop court garde l'onglet courant,
    /// la gauche va au corrigé déverrouillé, la droite revient à l'énoncé.
    static func target(
        current: AnnDocumentMode,
        translationX: Double,
        velocityX: Double,
        canShowSolution: Bool
    ) -> AnnDocumentMode? {
        let distance = abs(translationX)
        let deliberate = distance > commitDistance
            || (distance > flickMinDistance && abs(velocityX) > flickVelocity)
        guard deliberate else { return nil }
        let direction = distance > 2 ? translationX : velocityX
        if direction >= 0 { return .statement }
        return canShowSolution ? .solution : nil
    }
}

/// Poignée du séparateur : 24 pt de haut, trait `border` de 2 pt centré
/// (`paneSplitterRoot` / `paneSplitter` / `paneSplitterLine`, `AnnaleViewer.tsx:900-935`).
struct AnnSplitterHandle: View {
    /// Hauteur de la zone de préhension (`paneSplitterRoot.height`, `:900`).
    static let height: CGFloat = 24

    let ratio: Double
    let bounds: (min: Double, max: Double)
    let contentHeight: CGFloat
    let onRatio: (Double) -> Void
    let onCommit: () -> Void

    /// Position de la ligne au début du geste (`dragOrigin`, `:698`).
    @State private var dragOrigin: Double?

    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 2)
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(Theme.background)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let origin = dragOrigin ?? ratio
                        if dragOrigin == nil { dragOrigin = origin }
                        guard contentHeight > 0 else { return }
                        let next = origin + Double(value.translation.height) / Double(contentHeight)
                        onRatio(min(bounds.max, max(bounds.min, next)))
                    }
                    .onEnded { _ in
                        dragOrigin = nil
                        onCommit()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hauteur de l’énoncé ou du corrigé")
            .accessibilityHint("Maintiens puis déplace la ligne pour agrandir l’énoncé ou le champ de réponse")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: nudge(AnnaleSplit.SPLIT_STEP)
                case .decrement: nudge(-AnnaleSplit.SPLIT_STEP)
                @unknown default: break
                }
            }
    }

    /// `nudgeRatio` : un cran au clavier/lecteur d'écran, puis enregistrement.
    private func nudge(_ delta: Double) {
        onRatio(min(bounds.max, max(bounds.min, ratio + delta)))
        onCommit()
    }
}

// MARK: - Atelier

/// Atelier de réponse : champ de réponse, tableau blanc ou console Python,
/// avec la barre d'outils de la source (`answerCard` + `answerToolsDock`,
/// `AnnaleViewer.tsx:4270-4450`).
struct AnnAnswerWorkspace: View {
    @Binding var draft: String
    @Binding var mode: AnnAnswerMode
    @Binding var strokes: [WbStroke]

    @State private var whiteboardExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            answerCard
            tools
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var answerCard: some View {
        switch mode {
        case .whiteboard:
            WhiteboardView(
                strokes: $strokes,
                expanded: whiteboardExpanded,
                onToggleExpanded: { whiteboardExpanded.toggle() }
            )
        case .python:
            VStack(alignment: .leading, spacing: 0) {
                answerField(placeholder: "Écris ici ton programme Python…")
                PythonConsoleView(code: draft)
            }
        case .text:
            answerField(placeholder: "Rédige ici ta réponse, tes calculs et tes justifications…")
        }
    }

    /// Champ de réponse multiligne (`TextInput` de `AnnaleViewer.tsx:4360-4405`).
    private func answerField(placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if draft.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
            }
            TextEditor(text: $draft)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(minHeight: 150, alignment: .topLeading)
        .accessibilityLabel("Ma résolution de l’annale")
    }

    /// Barre d'outils : tableau blanc, bloc Python, effacer
    /// (`MoreAnswerTools`, `AnnaleViewer.tsx:968-1018`).
    private var tools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                toolButton("Tableau blanc", icon: "brush-outline", active: mode == .whiteboard) {
                    mode = mode == .whiteboard ? .text : .whiteboard
                }
                toolButton("Bloc Python", icon: "logo-python", active: mode == .python) {
                    mode = mode == .python ? .text : .python
                }
                toolButton("Effacer la réponse", icon: "trash-outline", active: false) {
                    draft = ""
                    strokes = []
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    private func toolButton(
        _ title: String,
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                IonIcon(name: icon, size: 15, color: Theme.primary)
                Text(title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(active ? Theme.primaryLight : Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}
