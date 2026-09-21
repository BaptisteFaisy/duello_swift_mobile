import SwiftUI

// MARK: - Modes de document

/// Document affiché par le lecteur (`DocumentMode` du lecteur Expo).
enum AnnDocumentMode: String, CaseIterable, Identifiable {
    case statement
    case markingScheme
    case comments
    case solution

    var id: String { rawValue }

    /// Libellé d'onglet, mot pour mot du lecteur Expo.
    var label: String {
        switch self {
        case .statement: return "Énoncé"
        case .markingScheme: return "Barème"
        case .comments: return "Commentaires"
        case .solution: return "Corrigé"
        }
    }
}

// MARK: - Boutons locaux

/// Bouton principal plein, aligné sur le bouton d'action des écrans Expo.
struct AnnSolidButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
    }
}

/// Bouton secondaire à bord fin, aligné sur les actions d'outil des écrans Expo.
struct AnnOutlineButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
