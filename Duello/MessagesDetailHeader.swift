import SwiftUI

// MARK: - En-tête de vue détail

/// Bandeau de tête commun aux deux vues détail : retour, avatar, libellés.
struct DetailHeader: View {
    enum Avatar {
        case initial(String, background: Color)
        case symbol(String, background: Color)
    }

    let title: String
    let subtitle: String
    let avatar: Avatar
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            DuelloBackButton(
                iconSize: 20,
                accessibilityLabel: "Retour",
                action: onBack
            )
            avatarView
                .padding(.leading, 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
            .padding(.leading, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 63)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            switch avatar {
            case .initial(let letter, let background):
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
                    .frame(width: 39, height: 39)
                Text(letter)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
            case .symbol(let name, let background):
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
                    .frame(width: 39, height: 39)
                Image(systemName: name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

// Le bouton retour local (`DetailBackButton`) a été retiré en vague 3 : il
// ré-implémentait ce que le composant partagé `DuelloBackButton`
// (`DuelloBackButton.swift`, port de `BackButton.tsx`) porte désormais — boîte
// 40 × 40, chevron `ink` décalé de −4 (`translateX`), sans fond/bord/rayon.
// `DetailHeader` l'appelle directement (`iconSize: 20`, libellé « Retour »,
// comme `MessagesScreen.tsx:428` / `:488`).
