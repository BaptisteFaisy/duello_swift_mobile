//
//  SubjFlashcardAnswerField.swift
//  Duello
//
//  Lot « Subj » (9-F) — champ de réponse d'une flashcard : saisie, aperçu
//  composé et outils (dicter, photo, clavier maths).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 2131-2334)
//        `FlashcardAnswerField` ;
//    - src/components/AnswerComposition.tsx
//        `AnswerComposition` (+ `COMPOSITION_DELAY` = 400 ms).
//
//  Réutilisation stricte (aucune brique redéfinie) :
//    - `StmtLatex.composeAnswerForDisplay` (`composeAnswerForDisplay`) pour la
//      source composée de l'aperçu ;
//    - `LatexToUnicode.toUnicodeMath` pour le rendu de la formule ;
//    - `WbCodec.isWhiteboardAnswer` (`isWhiteboardAnswer`) : un brouillon de
//      tableau blanc n'a rien à composer ;
//    - `DictControlModel` (DictControlView.swift) pour toute la dictée ;
//    - `ConsentPremiumGate` (`usePremiumToolGate`) pour la garde Premium ;
//    - `PhotoTranscriptionView`, `SubjFlashcardToolButton`,
//      `SubjFlashcardEditorConfig` (briques du même lot).
//
//  Limites assumées :
//    - `answerSelection` / `pendingSelection` de la source ne sont pas portés :
//      SwiftUI n'expose ni caret ni sélection pour un `TextField`. La dictée
//      ajoute donc la transcription en fin de champ (`DictPolicy.appendTranscript`)
//      et la photo y insère son bloc, là où la source insérait au caret ;
//    - le clavier maths natif (`MathKeyboard`) est hors de ce lot : le bouton
//      « Clavier maths » ne fait que signaler l'état au parent
//      (`onToggleMathKeyboard`), qui pose le repli de son côté ;
//    - l'aperçu passe par `LatexToUnicode.toUnicodeMath` : le texte reste exact,
//      la mise en forme « console » des blocs de code n'est pas reproduite.
//
//  Substitutions SF Symbols : mic-outline → mic, stop → stop.fill,
//  camera-outline → camera, calculator-outline → function.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Aperçu composé

/// Aperçu composé de la réponse en cours d'écriture (`AnswerComposition`).
///
/// Un champ de saisie n'affiche pas de math composée : il montre les caractères
/// qu'il contient. Ce bandeau rend ce que la réponse veut dire — le LaTeX n'y
/// est qu'un passage (`composeAnswerForDisplay` le fabrique, `LatexToUnicode` le
/// rend) et personne ne le voit. Le champ, lui, garde le texte exact qui partira
/// à la correction : l'aperçu ne remplace pas la réponse, il la relit.
struct SubjAnswerComposition: View {
    let answer: String
    var submitted: Bool = false

    @State private var settled: String

    init(answer: String, submitted: Bool = false) {
        self.answer = answer
        self.submitted = submitted
        _settled = State(initialValue: answer)
    }

    var body: some View {
        Group {
            if let displayed = displayedAnswer {
                panel(displayed)
            }
        }
        .task(id: answer) { await settle() }
    }

    /// Ce qui s'affiche : la réponse composée, ou — une fois soumise seulement —
    /// le texte brut (`composed || (submitted ? settled : '')`).
    private var displayedAnswer: String? {
        if !WbCodec.isWhiteboardAnswer(settled),
           let composed = StmtLatex.composeAnswerForDisplay(settled),
           !composed.isEmpty {
            return composed
        }
        return submitted && !settled.isEmpty ? settled : nil
    }

    /// Bandeau gris, hauteur bornée tant que la réponse n'est pas soumise.
    private func panel(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !submitted {
                Text("Aperçu")
                    .font(.system(size: 9, weight: .heavy))
                    .textCase(.uppercase)
                    .kerning(0.4)
                    .foregroundStyle(Theme.inkSoft)
            }
            ScrollView(.vertical, showsIndicators: true) {
                Text(LatexToUnicode.toUnicodeMath(text))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: submitted ? nil : 148)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(alignment: .top) {
            if !submitted {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
        }
    }

    /// La composition attend une pause dans la frappe : recomposer à chaque
    /// caractère ferait clignoter le bandeau. `.task(id:)` annule la pause
    /// précédente à chaque frappe.
    private func settle() async {
        let millis = SubjFlashcardEditorConfig.compositionDelayMilliseconds
        do {
            try await Task.sleep(nanoseconds: UInt64(millis) * 1_000_000)
        } catch {
            return // tâche annulée : une frappe plus récente a pris la main
        }
        settled = answer
    }
}

// MARK: - Champ de réponse

/// Champ de réponse d'une flashcard, avec ses outils (`FlashcardAnswerField`).
struct SubjFlashcardAnswerField: View {
    let answer: String
    let card: CollFlashcard
    let chapterName: String
    let subject: String
    let disabled: Bool
    let mathKeyboardOpen: Bool
    let onChangeAnswer: (String) -> Void
    let onToggleMathKeyboard: () -> Void
    /// Signale qu'une dictée est en cours ou se finalise
    /// (`onTranscriptionStateChange`).
    var onTranscriptionStateChange: ((Bool) -> Void)? = nil

    /// Invite de permission de la dictée (`permissionMessage` de la source).
    private static let dictationPermissionMessage =
        "Autorise le micro et la reconnaissance vocale pour dicter ta réponse."

    @EnvironmentObject private var session: SessionStore
    @StateObject private var dictation = DictControlModel()
    @State private var photoModalOpen = false
    @FocusState private var focused: Bool

    private var accountId: String { ConsentPremiumGate.accountId(email: session.profile.email) }

    private var transcriptionPending: Bool {
        dictation.isListening || dictation.isFormatting
    }

    private var answerBinding: Binding<String> {
        Binding(get: { answer }, set: { onChangeAnswer($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ta réponse")
                    .font(.system(size: 11, weight: .black))
                    .textCase(.uppercase)
                    .kerning(0.35)
                    .foregroundStyle(Theme.inkSoft)
                TextField("Rédige ta réponse avant de la soumettre…", text: answerBinding, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(6...16)
                    .disabled(disabled)
                    .focused($focused)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .frame(minHeight: 132, alignment: .topLeading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Ma réponse à la flashcard")
                SubjAnswerComposition(answer: answer)
            }
            toolRow
            if !dictation.error.isEmpty {
                Text(dictation.error)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.like)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dictation.notice.isEmpty {
                Text(dictation.notice)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: disabled) { value in
            if value { dictation.annuler() }
        }
        .onChange(of: transcriptionPending) { onTranscriptionStateChange?($0) }
        .sheet(isPresented: $photoModalOpen) {
            PhotoTranscriptionView(
                subject: subject,
                exercisePrompt: "\(chapterName) — \(card.question)",
                onClose: { photoModalOpen = false },
                onInsert: insertTranscription
            )
        }
    }

    // MARK: Vues internes

    /// Ligne d'outils : dicter, photo, clavier maths.
    private var toolRow: some View {
        HStack(spacing: 3) {
            SubjFlashcardToolButton(
                systemImage: dictationIcon,
                label: dictationLabel,
                accessibility: dictation.isListening
                    ? "Arrêter la transcription de la réponse"
                    : "Transcrire la réponse à la voix",
                active: dictation.isListening,
                disabled: disabled || dictation.isFormatting,
                action: toggleDictation
            )
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                SubjFlashcardToolButton(
                    systemImage: "camera",
                    label: "Photo",
                    accessibility: "Transcrire une photo dans la réponse",
                    disabled: disabled || dictation.isFormatting,
                    action: openPhotoTranscription
                )
                SubjFlashcardToolButton(
                    systemImage: "function",
                    label: "Clavier maths",
                    accessibility: "Clavier maths pour la réponse",
                    active: mathKeyboardOpen,
                    disabled: disabled,
                    action: onToggleMathKeyboard
                )
            }
        }
    }

    private var dictationIcon: String {
        if dictation.isFormatting { return "sparkles" }
        return dictation.isListening ? "stop.fill" : "mic"
    }

    private var dictationLabel: String {
        if dictation.isFormatting { return "Transcription…" }
        return dictation.isListening ? "Arrêter" : "Transcrire"
    }

    // MARK: Outils

    /// Dicte la réponse. Hors écoute, la garde Premium s'applique d'abord
    /// (`requirePremiumTool('voice-transcription', …)`).
    private func toggleDictation() {
        Task { @MainActor in
            if dictation.isListening {
                await dictation.toggle(
                    currentText: answer,
                    math: true,
                    permissionMessage: Self.dictationPermissionMessage,
                    apply: { onChangeAnswer($0) }
                )
                return
            }
            _ = await ConsentPremiumGate.gate(tool: .voiceTranscription, accountId: accountId) {
                await dictation.toggle(
                    currentText: answer,
                    math: true,
                    permissionMessage: Self.dictationPermissionMessage,
                    apply: { onChangeAnswer($0) }
                )
            }
        }
    }

    /// Ouvre la transcription photo, dictée coupée et clavier maths replié
    /// (`openPhotoTranscription`).
    private func openPhotoTranscription() {
        Task { @MainActor in
            _ = await ConsentPremiumGate.gate(tool: .photoTranscription, accountId: accountId) {
                dictation.annuler()
                focused = false
                if mathKeyboardOpen { onToggleMathKeyboard() }
                photoModalOpen = true
            }
        }
    }

    /// Insère une transcription photo en bloc, comme `insertBlockAtSelection`.
    private func insertTranscription(_ transcription: String) {
        let rendu = LatexToUnicode.toUnicodeMath(transcription)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rendu.isEmpty else { return }
        let propre = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        onChangeAnswer(propre.isEmpty ? rendu : "\(propre)\n\n\(rendu)")
    }
}
