import SwiftUI

// MARK: - Widgets du tableau blanc
//
// Petits composants autonomes extraits de `WhiteboardView.swift` (limite de
// 500 lignes par fichier, AGENTS.md Duello). Aucun changement de rendu ni
// d’API : mêmes types, mêmes membres, même style.

/// Bouton d’action carré (annuler, rétablir, agrandir) : icône Ionicons 18
/// (`WhiteboardHistoryControls.tsx:185-230`).
struct WbIconButton: View {
    let icon: String
    let label: String
    var enabled: Bool = true
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IonIcon(name: icon, size: 18, color: prominent ? Theme.surface : Theme.primary)
                .frame(width: 32, height: 32)
                .background(prominent ? Theme.primary : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}
