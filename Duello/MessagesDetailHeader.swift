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
            DetailBackButton(action: onBack)
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
                IonIcon(name: name, size: 19, color: Theme.ink)
            }
        }
    }
}

/// Bouton de retour : chevron nu, comme le `BackButton` d'Expo. Le composant
/// RN applique `styles.button` **après** le `style` reçu (`BackButton.tsx:53`),
/// si bien que `backButton` (`MessagesScreen.tsx:838-847` : bordure 1 px, rayon
/// 14, fond `surface`) est écrasé par `borderWidth: 0`, `borderRadius: 0`,
/// `backgroundColor: 'transparent'` (`BackButton.tsx:86-96`). Le bouton rendu
/// est donc un chevron nu dans une boîte 40×40 transparente, glyphe décalé de
/// −4 pt (`BackButton.tsx:87,93`).
struct DetailBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IonIcon(name: "chevron-back", size: 20, color: Theme.ink)
                .offset(x: -4)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour")
    }
}
