//
//  SubjFlashcardEditorParts.swift
//  Duello
//
//  Lot « Subj » (9-F) — briques d'UI de l'éditeur de flashcard : aperçu
//  mathématique, bouton d'outil, repli du clavier maths.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 1819-1844)
//        `FlashcardEditorMathPreview` ;
//    - src/screens/SubjectsScreen.tsx (styles `flashcardToolButton*`,
//      lignes 11631-11657) : apparence du bouton d'outil.
//
//  Réutilisation stricte :
//    - `StmtLatex.editableMathPreview` pour la source composée du champ ;
//    - `LatexToUnicode.toUnicodeMath` pour le rendu de la formule ;
//    - `MathKbActionKey` (MathKbControls.swift) pour le chrome des touches de la
//      palette ;
//    - `Theme`, `.duelloCard()`.
//
//  Limites assumées :
//    - la source compose le document dans une WebView (`MathStatementText`) et
//      habille les blocs de code en console. Ici le rendu passe par
//      `LatexToUnicode.toUnicodeMath` : le texte reste exact, la mise en forme
//      console n'est pas reproduite ;
//    - la recomposition attend une pause dans la frappe (`COMPOSITION_DELAY`),
//      portée par `.task(id:)` ;
//    - la palette insère en fin de champ : SwiftUI n'expose ni caret ni
//      sélection pour un `TextField`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Aperçu mathématique

/// Aperçu de la formule saisie, recomposé après une pause
/// (`FlashcardEditorMathPreview`).
struct SubjFlashcardEditorMathPreview: View {
    let value: String

    @State private var settledValue: String

    init(value: String) {
        self.value = value
        _settledValue = State(initialValue: value)
    }

    var body: some View {
        Group {
            // Sans formule ni code, l'aperçu disparaît, comme la source
            // (`if (!preview) return null`).
            if let preview = Self.preview(for: settledValue) {
                card(preview)
            }
        }
        .task(id: value) { await settle() }
    }

    /// Carte grise de l'aperçu (`flashcardEditorMathPreview`).
    private func card(_ preview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aperçu mathématique")
                    .font(.system(size: 10, weight: .black))
                    .textCase(.uppercase)
                    .kerning(0.35)
                    .foregroundStyle(Theme.inkSoft)
                Text("Modifie la formule avec « Clavier maths »")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Text(LatexToUnicode.toUnicodeMath(preview))
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Silence de frappe avant recomposition — `.task(id:)` annule la
    /// recomposition précédente à chaque caractère.
    private func settle() async {
        let millis = SubjFlashcardEditorConfig.compositionDelayMilliseconds
        do {
            try await Task.sleep(nanoseconds: UInt64(millis) * 1_000_000)
        } catch {
            return // tâche annulée : une frappe plus récente a pris la main
        }
        settledValue = value
    }

    /// Source composée du champ, ou `nil` s'il n'y a rien à montrer
    /// (`editableMathPreview`).
    private static func preview(for raw: String) -> String? {
        StmtLatex.editableMathPreview(raw)
    }
}

// MARK: - Bouton d'outil

/// Bouton compact de la ligne d'outils (`flashcardToolButton` et ses états).
struct SubjFlashcardToolButton: View {
    let systemImage: String
    let label: String
    let accessibility: String
    var active: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(active ? Theme.surface : Theme.primary)
            .frame(minHeight: 31)
            .padding(.horizontal, 6)
            .background(active ? Theme.primary : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(active ? Theme.primary : Theme.border, lineWidth: 1)
            )
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(accessibility)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

// MARK: - Repli « Clavier maths »

/// Repli du clavier maths natif : une palette de symboles qui insère dans le
/// champ actif. Le clavier système reste la saisie principale ; cette palette
/// ne pose que ce que le clavier de l'iPhone ne donne pas directement.
struct SubjFlashcardSymbolPalette: View {
    let onInsert: (String) -> Void
    let onBackspace: () -> Void
    let onClose: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Clavier maths — insertion de symboles")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 0)
                MathKbActionKey(
                    accessibility: "Fermer le clavier maths",
                    systemImage: "keyboard.chevron.compact.down"
                ) { onClose() }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(SubjFlashcardEditorConfig.symbolPalette, id: \.self) { symbol in
                    Button { onInsert(symbol) } label: {
                        Text(symbol)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Insérer \(symbol)")
                }
            }
            HStack(spacing: 6) {
                MathKbActionKey(
                    accessibility: "Effacer le dernier caractère",
                    systemImage: "delete.left"
                ) { onBackspace() }
                Text("Le clavier système reste disponible pour le reste.")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(12)
        .duelloCard()
    }
}
