//
//  SubjFlashcardEditor.swift
//  Duello
//
//  Lot « Subj » (9-F) — éditeur de flashcard : les deux faces (recto / verso),
//  l'aperçu mathématique de chaque face et les outils de saisie.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 1817-2129)
//        `FlashcardEditorSide`, `FlashcardEditorFields`.
//
//  Réutilisation stricte (aucune brique redéfinie) :
//    - `LatexToUnicode.toUnicodeMath` : rendu d'une formule ;
//    - `StmtLatex.editableMathPreview` (`editableMathPreview`) : source composée
//      du champ modifiable ;
//    - `DictControlModel` (DictControlView.swift) : toute la dictée ;
//    - `ConsentPremiumGate` (`usePremiumToolGate`) : garde Premium ;
//    - `PhotoTranscriptionView` : transcription photo ;
//    - `Theme`, et les briques d'UI de `SubjFlashcardEditorParts.swift`.
//
//  Limites assumées (aucune API iOS 17, aucun compilateur ici) :
//    - le clavier maths natif (`MathKeyboard`) est **hors de ce lot**. Le bouton
//      « Clavier maths » ouvre un repli — la palette de symboles
//      `SubjFlashcardSymbolPalette` — qui insère dans le champ actif ; le clavier
//      système reste la saisie principale ;
//    - SwiftUI n'expose ni caret ni sélection pour un `TextField` : l'insertion
//      se fait donc **en fin de champ**, là où la source insérait au caret
//      (`caret`, `TextSelection`, `insertStructuredTextAtSelection`). La
//      suppression du repli retire un caractère, alors que la source retirait le
//      groupe entier (`deleteBeforeSelection`) ;
//    - `chapterId` est conservé pour la surface de `FlashcardEditorFields` : il
//      n'alimente que les suggestions du clavier maths, hors périmètre.
//
//  Substitutions SF Symbols : mic-outline → mic, stop → stop.fill,
//  camera-outline → camera, calculator-outline → function.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Configuration

/// Constantes de l'éditeur : un seuil nommé plutôt qu'un littéral dispersé.
enum SubjFlashcardEditorConfig {
    /// Silence après lequel la frappe est considérée comme posée
    /// (`COMPOSITION_DELAY` de la source), en millisecondes.
    static let compositionDelayMilliseconds = 400

    /// Invite de permission de la dictée (`permissionMessage` de la source).
    static let dictationPermissionMessage =
        "Autorise le micro et la reconnaissance vocale pour dicter ta flashcard."

    /// Symboles du repli « Clavier maths » : les touches que le clavier système
    /// de l'iPhone ne donne pas directement (`SUGGESTIBLE_KEY_LABELS` de
    /// `KbSupVocabulary`, restreint aux symboles insérables tels quels).
    static let symbolPalette: [String] = [
        "−", "×", "÷", "±", "·", "≠", "≈", "≤", "≥", "√", "π",
        "²", "³", "⁻¹", "ₙ", "ₙ₊₁", "ₖ", "→", "↦", "∞",
        "∫", "∑", "∏", "∂", "∇", "∈", "∉", "⊂", "∪", "∩",
        "∖", "∅", "ℝ", "ℤ", "ℕ",
    ]
}

// MARK: - Faces

/// Face éditée d'une flashcard (`FlashcardEditorSide`).
enum SubjFlashcardEditorSide: String, CaseIterable, Identifiable {
    case front
    case back

    var id: String { rawValue }

    /// Libellé du champ (`Recto` / `Verso`).
    var label: String {
        switch self {
        case .front: return "Recto"
        case .back: return "Verso"
        }
    }

    /// Invite du champ vide (`placeholder` de la source).
    var placeholder: String {
        switch self {
        case .front: return "Question ou notion"
        case .back: return "Réponse"
        }
    }

    /// Libellé d'accessibilité (`« Recto de la flashcard »`).
    var accessibilityLabel: String { "\(label) de la flashcard" }

    /// Nom employé dans la ligne d'outils (« recto » / « verso »).
    var toolTarget: String {
        switch self {
        case .front: return "recto"
        case .back: return "verso"
        }
    }
}

// MARK: - Éditeur

/// Éditeur des deux faces d'une flashcard (`FlashcardEditorFields`).
struct SubjFlashcardEditor: View {
    let front: String
    let back: String
    /// Réservé à la surface de `FlashcardEditorFields` : n'alimente que les
    /// suggestions du clavier maths, hors périmètre de ce lot.
    let chapterId: String
    let chapterName: String
    let subject: String
    let onChangeFront: (String) -> Void
    let onChangeBack: (String) -> Void
    /// Signale l'ouverture du repli « Clavier maths », comme
    /// `onMathKeyboardVisibilityChange`.
    var onMathKeyboardVisibilityChange: ((Bool) -> Void)? = nil

    @EnvironmentObject private var session: SessionStore
    @StateObject private var dictation = DictControlModel()
    @State private var activeSide: SubjFlashcardEditorSide = .front
    @State private var mathPaletteOpen = false
    @State private var photoModalOpen = false
    @FocusState private var focusedSide: SubjFlashcardEditorSide?

    private var activeText: String { text(for: activeSide) }

    private var accountId: String { ConsentPremiumGate.accountId(email: session.profile.email) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sides
            Text("Outils pour le \(activeSide.toolTarget)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
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
            if mathPaletteOpen {
                SubjFlashcardSymbolPalette(
                    onInsert: { symbol in mutateActiveText { $0 + symbol } },
                    onBackspace: { mutateActiveText { String($0.dropLast()) } },
                    onClose: { mathPaletteOpen = false }
                )
            }
        }
        .onChange(of: focusedSide) { newValue in
            if let newValue { activateSide(newValue) }
        }
        .onChange(of: mathPaletteOpen) { onMathKeyboardVisibilityChange?($0) }
        .onDisappear { onMathKeyboardVisibilityChange?(false) }
        .sheet(isPresented: $photoModalOpen) {
            PhotoTranscriptionView(
                subject: subject,
                exercisePrompt: photoExercisePrompt,
                onClose: { photoModalOpen = false },
                onInsert: insertTranscription
            )
        }
    }

    // MARK: Vues internes

    /// Les deux faces, chacune avec son aperçu mathématique.
    private var sides: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SubjFlashcardEditorSide.allCases) { side in
                sideField(side)
            }
        }
    }

    /// Une face : libellé, champ multiligne, aperçu de la formule.
    private func sideField(_ side: SubjFlashcardEditorSide) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(side.label)
                .font(.system(size: 11, weight: .black))
                .textCase(.uppercase)
                .kerning(0.35)
                .foregroundStyle(Theme.inkSoft)
            TextField(side.placeholder, text: binding(for: side), axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .lineLimit(4...12)
                .focused($focusedSide, equals: side)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(minHeight: 104, alignment: .topLeading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .stroke(activeSide == side ? Theme.ink : Theme.border, lineWidth: 1)
                )
                .accessibilityLabel(side.accessibilityLabel)
            SubjFlashcardEditorMathPreview(value: text(for: side))
        }
    }

    /// Invite donnée à la transcription photo : le recto s'il porte déjà la
    /// question, sinon le nom du chapitre (`exercisePrompt` de la source).
    private var photoExercisePrompt: String {
        activeSide == .back && !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? front
            : chapterName
    }

    /// Ligne d'outils de la face active : dicter, photo, clavier maths.
    private var toolRow: some View {
        HStack(spacing: 3) {
            SubjFlashcardToolButton(
                systemImage: dictationIcon,
                label: dictationLabel,
                accessibility: dictation.isListening
                    ? "Arrêter la transcription de la flashcard"
                    : "Transcrire la flashcard à la voix",
                active: dictation.isListening,
                disabled: dictation.isFormatting,
                action: toggleDictation
            )
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                SubjFlashcardToolButton(
                    systemImage: "camera",
                    label: "Photo",
                    accessibility: "Transcrire une photo dans le \(activeSide.toolTarget)",
                    disabled: dictation.isFormatting,
                    action: openPhotoTranscription
                )
                SubjFlashcardToolButton(
                    systemImage: "function",
                    label: "Clavier maths",
                    accessibility: "Clavier maths pour le \(activeSide.toolTarget)",
                    active: mathPaletteOpen,
                    action: toggleMathPalette
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

    // MARK: Face active

    /// Texte d'une face, tel que le parent le détient.
    private func text(for side: SubjFlashcardEditorSide) -> String {
        side == .front ? front : back
    }

    /// Liaison d'écriture d'une face, branchée sur le parent.
    private func binding(for side: SubjFlashcardEditorSide) -> Binding<String> {
        side == .front
            ? Binding(get: { front }, set: { onChangeFront($0) })
            : Binding(get: { back }, set: { onChangeBack($0) })
    }

    /// Change la face active ; la dictée en cours est abandonnée, comme la
    /// source (`dictation.cancel()`).
    private func activateSide(_ side: SubjFlashcardEditorSide) {
        guard side != activeSide else { return }
        dictation.annuler()
        activeSide = side
    }

    /// Réécrit la face active via le parent.
    private func mutateActiveText(_ transform: (String) -> String) {
        let current = text(for: activeSide)
        let next = transform(current)
        guard next != current else { return }
        switch activeSide {
        case .front: onChangeFront(next)
        case .back: onChangeBack(next)
        }
    }

    // MARK: Outils

    /// Dicte la face active. Hors écoute, la garde Premium s'applique d'abord
    /// (`requirePremiumTool('voice-transcription', …)`).
    private func toggleDictation() {
        Task { @MainActor in
            if dictation.isListening {
                await dictation.toggle(
                    currentText: activeText,
                    math: true,
                    permissionMessage: SubjFlashcardEditorConfig.dictationPermissionMessage,
                    apply: { value in mutateActiveText { _ in value } }
                )
                return
            }
            _ = await ConsentPremiumGate.gate(tool: .voiceTranscription, accountId: accountId) {
                await dictation.toggle(
                    currentText: activeText,
                    math: true,
                    permissionMessage: SubjFlashcardEditorConfig.dictationPermissionMessage,
                    apply: { value in mutateActiveText { _ in value } }
                )
            }
        }
    }

    /// Ouvre la transcription photo, dictée coupée et clavier replié
    /// (`openPhotoTranscription`).
    private func openPhotoTranscription() {
        Task { @MainActor in
            _ = await ConsentPremiumGate.gate(tool: .photoTranscription, accountId: accountId) {
                dictation.annuler()
                focusedSide = nil
                mathPaletteOpen = false
                photoModalOpen = true
            }
        }
    }

    /// Ouvre ou referme le repli « Clavier maths » ; le clavier système est
    /// replié à l'ouverture.
    private func toggleMathPalette() {
        if !mathPaletteOpen { focusedSide = nil }
        mathPaletteOpen.toggle()
    }

    /// Insère une transcription photo en bloc, comme `insertBlockAtSelection`.
    private func insertTranscription(_ transcription: String) {
        let rendu = LatexToUnicode.toUnicodeMath(transcription)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rendu.isEmpty else { return }
        mutateActiveText { current in
            let propre = current.trimmingCharacters(in: .whitespacesAndNewlines)
            return propre.isEmpty ? rendu : "\(propre)\n\n\(rendu)"
        }
    }
}
