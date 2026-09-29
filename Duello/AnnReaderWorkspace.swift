import SwiftUI

// MARK: - Atelier de réponse du lecteur d'annale
//
// Port de l'atelier d'`AnnaleViewer.tsx` (unité 18) : séparateur, champ de
// réponse, tableau blanc, console Python et outils (dicter, photo, clavier
// maths, menu « Effacer » à deux entrées) ; soumission du lecteur hors fichier.

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
                    strokes: $whiteboardStrokes,
                    // `questionDisplayLabel` de la question ouverte.
                    questionLabel: activeQuestionId
                        .flatMap { id in entry.questions.first { $0.id == id } }?
                        .displayLabel ?? entry.questions.first?.displayLabel ?? "",
                    subject: subject,
                    prompt: entry.title,
                    // `clearAllAnswers` : le lecteur ne tient qu'un brouillon, les
                    // verdicts reçus sont en lecture seule (voir en-tête).
                    onClearAll: {
                        draft = ""
                        whiteboardStrokes = []
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
    }

    /// Balayage horizontal sur l'énoncé : gauche → corrigé déverrouillé,
    /// droite → énoncé (`documentSwipeGesture`, `AnnaleViewer.tsx:3521-3556`).
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

    /// `checkPythonBeforeCorrection` (`AnnaleViewer.tsx:3445`) : exécute le
    /// programme Python de la question ouverte avant d'engager sa correction ;
    /// rend la question qui bloque, `nil` si tout tourne. La soumission du
    /// lecteur n'est pas portée (écart U18#2) : l'hôte appelle cette garde.
    func firstBlockingPythonQuestion() async -> String? {
        await PyConConsoleModel().firstBlockingQuestion([(id: activeQuestionId ?? "", source: draft)])
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

/// Direction d'un glissement, résolue à l'axe dominant (`horizontalGesture.ts`).
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

/// Poignée du séparateur : 24 pt de haut, trait `border` 2 pt (`paneSplitter`, `:900-935`).
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

/// Atelier de réponse (`answerCard` + `answerToolsDock`, `:4270-4712`) : dicter,
/// photo, clavier maths, tableau blanc, bloc Python, menu de suppression.
/// Écarts assumés (18#2/18#6) : soumission/correction non portées (hors fichier) ;
/// « Supprimer toutes les réponses » n'efface que le brouillon ; dictée et photo
/// insèrent en fin de champ (pas de sélection exposée par SwiftUI).
struct AnnAnswerWorkspace: View {
    @Binding var draft: String
    @Binding var mode: AnnAnswerMode
    @Binding var strokes: [WbStroke]
    /// Libellé de la question ouverte, pour « Supprimer réponse X ».
    var questionLabel: String = ""
    /// Matière du sujet, transmise à la transcription photo.
    var subject: String = ""
    /// Intitulé du sujet, transmis à la transcription photo.
    var prompt: String = ""
    /// `clearAllAnswers` : efface la réponse ouverte (et ses tracés).
    var onClearAll: () -> Void = {}

    @EnvironmentObject private var session: SessionStore
    @StateObject private var dictation = DictControlModel()
    @State private var whiteboardExpanded = false
    @State private var photoModalOpen = false
    @State private var mathKeyboardOpen = false
    @FocusState private var focused: Bool

    /// Invite de permission de la dictée (`permissionMessage` de la source).
    private static let dictationPermissionMessage =
        "Autorise le micro et la reconnaissance vocale pour dicter ta réponse."

    private var accountId: String {
        ConsentPremiumGate.accountId(email: session.profile.email)
    }

    /// Vrai dès que la question ouverte porte quelque chose (`currentAnswer`).
    private var hasCurrentAnswer: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !strokes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            answerCard
            if mathKeyboardOpen { mathKeyboard }
            tools
            statusLines
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .onChange(of: questionLabel) { _ in dictation.annuler() }
        .sheet(isPresented: $photoModalOpen) {
            PhotoTranscriptionView(
                subject: subject,
                exercisePrompt: prompt.isEmpty ? nil : prompt,
                onClose: { photoModalOpen = false },
                // `insertBlockAtSelection` : la transcription s'ajoute en bloc.
                onInsert: { transcription in
                    let rendu = LatexToUnicode.toUnicodeMath(transcription)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !rendu.isEmpty else { return }
                    let propre = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft = propre.isEmpty ? rendu : "\(propre)\n\n\(rendu)"
                }
            )
        }
        // Consentement au partage IA de la dictée premium
        // (`requestAiDataSharingConsent`, `useDictation.ts:913-915`).
        .modifier(DictAiConsentAlert(model: dictation))
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
                .focused($focused)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(minHeight: 150, alignment: .topLeading)
        .accessibilityLabel("Ma résolution de l’annale")
    }

    /// Clavier maths (`MathKeyboard`) sous le champ (`SubjFlashcardReviewSession`).
    private var mathKeyboard: some View {
        MathKeyboardView(
            mode: .math,
            onInsertWithBack: { text, back in
                draft = SubjFlashcardMathEditing.insert(text, back: back, into: draft)
            },
            onBackspace: { draft = SubjFlashcardMathEditing.deleteLast(draft) },
            onClose: { mathKeyboardOpen = false }
        )
    }

    /// Barre d'outils (`answerToolsDock` + `MoreAnswerTools`) : dicter, photo,
    /// clavier maths, tableau blanc, bloc Python, menu de suppression.
    private var tools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                toolButton(dictationLabel, icon: dictationIcon, active: dictation.isListening) {
                    toggleDictation()
                }
                toolButton("Photo", icon: "camera-outline", active: false) {
                    openPhotoTranscription()
                }
                toolButton("Clavier maths", icon: "calculator-outline", active: mathKeyboardOpen) {
                    mathKeyboardOpen.toggle()
                }
                toolButton("Tableau blanc", icon: "brush-outline", active: mode == .whiteboard) {
                    mode = mode == .whiteboard ? .text : .whiteboard
                }
                toolButton("Bloc Python", icon: "logo-python", active: mode == .python) {
                    mode = mode == .python ? .text : .python
                }
                deleteMenu
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Menu de suppression à deux entrées (`deleteMenu`,
    /// `AnnaleViewer.tsx:4675-4712`) : la réponse ouverte, ou toutes.
    private var deleteMenu: some View {
        Menu {
            Button(deleteCurrentLabel) {
                draft = ""
                strokes = []
            }
            .disabled(!hasCurrentAnswer)
            Button("Supprimer toutes les réponses") { onClearAll() }
                .disabled(!hasCurrentAnswer)
        } label: {
            toolLabel("Effacer", icon: "trash-outline", active: false)
        }
        .accessibilityLabel("Supprimer des réponses")
    }

    /// `deleteCurrentLabel` : « Supprimer réponse X », ou « Supprimer réponse ».
    private var deleteCurrentLabel: String {
        questionLabel.isEmpty ? "Supprimer réponse" : "Supprimer réponse \(questionLabel)"
    }

    /// Lignes d'état de la dictée (`dictationStatus` / `dictationNotice`).
    @ViewBuilder
    private var statusLines: some View {
        if !dictation.error.isEmpty {
            Text(dictation.error)
                .font(.system(size: 12))
                .foregroundStyle(Theme.like)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        if !dictation.notice.isEmpty {
            Text(dictation.notice)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    private var dictationIcon: String {
        if dictation.isFormatting { return "sparkles" }
        return dictation.isListening ? "stop" : "mic-outline"
    }

    private var dictationLabel: String {
        if dictation.isFormatting { return "Transcription…" }
        return dictation.isListening ? "Arrêter" : "Transcrire"
    }

    // MARK: Outils

    /// Dicte la réponse. Hors écoute, la garde Premium s'applique d'abord
    /// (`requirePremiumTool('voice-transcription', dictation.createToggleRequest())`,
    /// `AnnaleViewer.tsx:2872-2875`).
    private func toggleDictation() {
        Task { @MainActor in
            if dictation.isListening {
                await dictation.toggle(
                    currentText: draft,
                    math: true,
                    permissionMessage: Self.dictationPermissionMessage,
                    apply: { draft = $0 }
                )
                return
            }
            let request = dictation.createToggleRequest(
                currentText: draft, math: true,
                permissionMessage: Self.dictationPermissionMessage,
                apply: { draft = $0 })
            _ = await ConsentPremiumGate.gate(tool: .voiceTranscription, accountId: accountId) { request() }
        }
    }

    /// Ouvre la transcription photo, dictée coupée et clavier maths replié
    /// (`openPhotoTranscription`).
    private func openPhotoTranscription() {
        Task { @MainActor in
            _ = await ConsentPremiumGate.gate(tool: .photoTranscription, accountId: accountId) {
                dictation.annuler()
                focused = false
                if mathKeyboardOpen { mathKeyboardOpen = false }
                photoModalOpen = true
            }
        }
    }

    private func toolButton(
        _ title: String,
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { toolLabel(title, icon: icon, active: active) }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    /// Étiquette d'outil (`toolButton`) : icône + libellé encre, fond
    /// `primaryLight` quand l'outil est actif.
    private func toolLabel(_ title: String, icon: String, active: Bool) -> some View {
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
}
