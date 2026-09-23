import SwiftUI

// MARK: - Widgets du tableau blanc
//
// Petits composants autonomes extraits de `WhiteboardView.swift` (limite de
// 500 lignes par fichier, AGENTS.md Duello). Aucun changement de rendu ni
// d’API : mêmes types, mêmes membres, même style.

/// Bouton d’action carré (annuler, rétablir, agrandir, effacer).
struct WbIconButton: View {
    let icon: String
    let label: String
    var enabled: Bool = true
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(prominent ? Theme.surface : Theme.ink)
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

/// Pastille de couleur de la palette.
struct WbColorDot: View {
    let entry: WbColor
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(entry.color).frame(width: 20, height: 20)
                Circle().stroke(Theme.border, lineWidth: 1).frame(width: 20, height: 20)
                if selected {
                    Circle().stroke(Theme.ink, lineWidth: 2).frame(width: 26, height: 26)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
    }
}
