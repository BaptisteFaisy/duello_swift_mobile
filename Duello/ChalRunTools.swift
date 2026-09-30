//
//  ChalRunTools.swift
//  Duello
//
//  Lot S05 (vague 6) — outils de saisie d'une manche de défi : dicter, photo,
//  clavier maths, bloc Python, et la console Python sous le champ
//  (`inputTools` + `dictationStatus`, `ChallengesScreen.tsx:2161-2285`).
//
//  Fichier source Expo porté (libellés, seuils et icônes repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx
//        · `requestDictationToggle` (:1122-1130), `openPhotoTranscription`
//          (:1237-1247), `toggleMathKeyboard` (:1222-1235),
//          `insertPythonBlock` (:1266-1270) ;
//        · `inputTools` (:2161-2264) et `dictationStatus` (:2267-2285) ;
//        · `mathKeyboardAvailable` (:1962), `answerInputMode` (:1963),
//          `pythonSource` (:1965), `mathKeySuggestions` (:1070-1073) ;
//        · styles `inputTools`/`toolButton`/`toolText` (:3624-3659).
//    - src/utils/pythonAnswer.ts — `pythonSourceFromAnswer`,
//      `insertPythonBlockAtSelection`.
//    - src/utils/exerciseAnswerInput.ts — `exerciseAnswerInputMode`.
//
//  Réutilisation stricte (aucune brique redéfinie) :
//    - `DictControlModel` + `DictAiConsentAlert` (dictée) ;
//    - `ConsentPremiumGate` (`usePremiumToolGate`) pour la garde Premium ;
//    - `PhotoTranscriptionView` (photo) ;
//    - `MathKeyboardView` (clavier maths/Python) et `KbSupSuggestions` ;
//    - `PythonConsoleView` (console) et `PythonAnswer` (bloc + source) ;
//    - `SubjFlashcardMathEditing` (insertion/recul du clavier maths).
//
//  Icônes Ionicons du RN rendues par `IonIcon` (taille 15) : mic-outline / stop /
//  sparkles, camera-outline, calculator-outline / code-slash-outline,
//  logo-python ; `radio` 13 et `sparkles` 13 pour l'état de la dictée.
//
//  Écarts assumés (iOS 16) : le curseur d'un `TextField` n'est pas exposé, donc
//  la dictée, la photo et le bloc Python s'ajoutent en **fin** de champ, là où
//  la source insérait au curseur (mêmes limites que `SubjFlashcardAnswerField`) ;
//  le clavier maths se pose **sous** le champ (la source le place en tête
//  d'écran), faute de pouvoir le détacher du champ — même choix que
//  `AnnReaderWorkspace`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Bouton d'outil de la manche (`toolButton` + ses états) : pastille bordée,
/// fond `surfaceMuted`, texte et icône `primary`, actif sur fond `primary`.
struct ChalRunToolButton: View {
    let ionIcon: String
    let label: String
    let accessibility: String
    var active: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                IonIcon(name: ionIcon, size: 15, color: active ? Theme.surface : Theme.primary)
                Text(label)
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundStyle(active ? Theme.surface : Theme.primary)
            .frame(minHeight: 36)
            .padding(.horizontal, 12)
            .background(active ? Theme.primary : Theme.surfaceMuted)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? Theme.primary : Theme.border, lineWidth: 1))
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(accessibility)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

/// Outils de saisie d'une manche (`inputTools` + `dictationStatus`) : dicter,
/// photo, clavier maths, bloc Python, et la console Python sous le champ.
struct ChalRunAnswerTools: View {
    @EnvironmentObject private var session: SessionStore

    /// Matière du défi (`session.subject`) : commande l'accès au clavier maths.
    let subject: String
    /// Chapitre porteur (`session.sourceItem.chapterId`) : commande le mode de
    /// saisie (`exerciseAnswerInputMode`) et les suggestions du clavier.
    let chapterId: String?
    /// Énoncé de l'exercice (`duelExercisePrompt`) : contexte de la photo et des
    /// suggestions du clavier.
    let exercisePrompt: String
    @Binding var answer: String
    var disabled: Bool = false

    @StateObject private var dictation = DictControlModel()
    @State private var photoModalOpen = false
    @State private var mathKeyboardOpen = false
    @FocusState private var focused: Bool

    /// Invite de permission de la dictée (`permissionMessage` de la source).
    private static let dictationPermissionMessage =
        "Autorise le micro et la reconnaissance vocale pour dicter ta réponse."

    private var accountId: String { ConsentPremiumGate.accountId(email: session.profile.email) }
    /// `mathKeyboardAvailable` : le clavier maths n'existe qu'en mathématiques.
    private var mathKeyboardAvailable: Bool { subject == "Mathématiques" }
    /// `answerInputMode` : `python` pour un chapitre `python-*`, `math` sinon.
    private var isPythonAnswer: Bool { StmtAnswerInput.mode(chapterId: chapterId) == .python }
    /// `pythonSource` : programme porté par la réponse, s'il y en a un.
    private var pythonSource: String? {
        PythonAnswer.sourceFromAnswer(answer, wholeAnswerIsPython: isPythonAnswer)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if mathKeyboardAvailable && mathKeyboardOpen { mathKeyboard }
            if let pythonSource { PythonConsoleView(code: pythonSource, disabled: disabled) }
            toolRow
            statusLines
        }
        .sheet(isPresented: $photoModalOpen) { photoSheet }
        .modifier(DictAiConsentAlert(model: dictation))
        .onChange(of: disabled) { value in
            if value { dictation.annuler() }
        }
    }

    // MARK: Vues internes

    /// Ligne d'outils (`inputTools`) : enroulement ligne à ligne, filet en tête.
    private var toolRow: some View {
        MathKbFlowLayout(spacing: 8, lineSpacing: 8) {
            dictationButton
            ChalRunToolButton(
                ionIcon: "camera-outline",
                label: "Photo",
                accessibility: "Transcrire une photo de ma copie",
                disabled: disabled || dictation.isFormatting,
                action: openPhotoTranscription
            )
            if mathKeyboardAvailable {
                ChalRunToolButton(
                    ionIcon: isPythonAnswer ? "code-slash-outline" : "calculator-outline",
                    label: isPythonAnswer ? "Clavier Python" : "Clavier maths",
                    accessibility: isPythonAnswer ? "Clavier Python" : "Clavier maths",
                    active: mathKeyboardOpen,
                    disabled: disabled || dictation.isFormatting,
                    action: { mathKeyboardOpen.toggle() }
                )
            }
            ChalRunToolButton(
                ionIcon: "logo-python",
                label: "Bloc Python",
                accessibility: "Insérer un bloc de code Python",
                disabled: disabled || dictation.isFormatting,
                action: insertPythonBlock
            )
        }
        .padding(10)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Bouton de dictée (`dictation.isFormatting`/`isListening`).
    private var dictationButton: some View {
        ChalRunToolButton(
            ionIcon: dictationIcon,
            label: dictationLabel,
            accessibility: dictation.isListening
                ? "Arrêter la transcription"
                : "Transcrire ma réponse",
            active: dictation.isListening,
            disabled: disabled || dictation.isFormatting,
            action: toggleDictation
        )
    }

    /// Lignes d'état (`dictationStatus` / `dictationNotice` / `dictationError`).
    @ViewBuilder
    private var statusLines: some View {
        if dictation.isListening || dictation.isFormatting {
            HStack(alignment: .top, spacing: 6) {
                IonIcon(
                    name: dictation.isFormatting ? "sparkles" : "radio",
                    size: 13,
                    color: Theme.accent
                )
                Text(statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 9)
        }
        if !dictation.notice.isEmpty {
            Text(dictation.notice)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(4)
                .padding(.top, 9)
        }
        if !dictation.error.isEmpty {
            Text(dictation.error)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.like)
                .lineSpacing(4)
                .padding(.top, 9)
        }
    }

    /// Clavier maths, posé sous le champ (`MathKeyboard`).
    private var mathKeyboard: some View {
        MathKeyboardView(
            mode: isPythonAnswer ? .text : .math,
            onInsertWithBack: { text, back in
                answer = SubjFlashcardMathEditing.insert(text, back: back, into: answer)
            },
            onBackspace: { answer = SubjFlashcardMathEditing.deleteLast(answer) },
            onClose: { mathKeyboardOpen = false },
            suggestions: mathSuggestions
        )
    }

    /// Feuille de transcription photo (`PhotoTranscriptionModal`).
    private var photoSheet: some View {
        PhotoTranscriptionView(
            subject: subject,
            exercisePrompt: exercisePrompt.isEmpty ? nil : exercisePrompt,
            onClose: { photoModalOpen = false },
            onInsert: insertTranscription
        )
    }

    /// Touches proposées pour l'exercice ouvert (`suggestMathKeys`).
    private var mathSuggestions: [MathKbKey] {
        KbSupSuggestions.suggest(
            KbSupInput(statement: exercisePrompt, chapterId: chapterId)
        )
    }

    private var dictationIcon: String {
        if dictation.isFormatting { return "sparkles" }
        return dictation.isListening ? "stop" : "mic-outline"
    }

    private var dictationLabel: String {
        if dictation.isFormatting { return "Transcription…" }
        return dictation.isListening ? "Arrêter" : "Transcrire"
    }

    /// Libellé d'état de la dictée (`dictationStatusText`), étape et moteur exacts.
    private var statusText: String {
        if dictation.isFormatting {
            return dictation.stage == .alibaba
                ? "Étape 1/2 — Alibaba réécoute toute ta phrase pour utiliser le maximum de contexte."
                : "Étape 2/2 — [OI] distingue les nombres et les expressions mathématiques sans modifier la transcription Alibaba."
        }
        if dictation.engine == .device {
            return "Le téléphone transcrit ta réponse en direct. Relis-la avant de rendre."
        }
        if dictation.engine != nil {
            return "Écoute en cours : toute ta réponse apparaîtra après le bouton Arrêter."
        }
        return "Connexion au service vocal…"
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
                    apply: { answer = $0 }
                )
                return
            }
            let request = dictation.createToggleRequest(
                currentText: answer,
                math: true,
                permissionMessage: Self.dictationPermissionMessage,
                apply: { answer = $0 }
            )
            _ = await ConsentPremiumGate.gate(tool: .voiceTranscription, accountId: accountId) {
                request()
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
                mathKeyboardOpen = false
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
        answer = propre.isEmpty ? rendu : "\(propre)\n\n\(rendu)"
    }

    /// Referme la sélection en bloc Python au curseur
    /// (`insertPythonBlockAtSelection`) : le curseur est réputé en fin de champ.
    private func insertPythonBlock() {
        let end = (answer as NSString).length
        let edit = PythonAnswer.insertBlockAtSelection(
            answer,
            StmtTextSelection(start: end, end: end)
        )
        answer = edit.value
    }
}
