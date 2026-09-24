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
                Image(systemName: name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

/// Bouton de retour du `BackButton` d'Expo : chevron noir seul, **sans fond,
/// cadre ni forme** — `styles.button` d'Expo (borderWidth 0, borderRadius 0,
/// backgroundColor transparent) écrase le style passé par l'écran. Zone tactile
/// 40 × 40 (`minWidth`/`minHeight` du composant), chevron décalé de −4 pt comme
/// `transform: translateX(-4)`.
struct DetailBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .offset(x: -4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour")
    }
}
