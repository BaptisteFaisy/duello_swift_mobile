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
        HStack(spacing: 10) {
            DetailBackButton(action: onBack)
            avatarView

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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

/// Bouton de retour en pastille, comme le `BackButton` d'Expo.
struct DetailBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour")
    }
}
