import SwiftUI

// MARK: - Comptes bloqués

/// Un compte bloqué (données de démonstration locales).
private struct BlockedUser: Identifiable, Equatable {
    let id: String
    let displayName: String
    let prepName: String

    /// Initiale affichée dans la pastille, comme les avatars sans photo.
    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }
}

/// Écran « Comptes bloqués » : liste locale de démonstration, chaque appui sur
/// « Débloquer » retire le compte de la liste (`@State`). Reprend la
/// présentation de `BlockedUsersScreen.tsx`, sans appel réseau.
struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var blocked: [BlockedUser] = [
        BlockedUser(id: "member-camille", displayName: "Camille Renard", prepName: "Saint-Louis"),
        BlockedUser(id: "member-theo", displayName: "Théo Marchand", prepName: "Henri-IV"),
        BlockedUser(id: "member-ines", displayName: "Inès Bouvier", prepName: "Le Parc"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    explanationCard
                    if blocked.isEmpty {
                        emptyCard
                    } else {
                        memberList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Comptes bloqués")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var explanationCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "nosign")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Tu ne peux plus trouver ni suivre ces comptes, recevoir leurs notifications ou les inviter à un défi, et réciproquement. Ils sont aussi retirés de tes espaces sociaux.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 9) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Aucun compte bloqué.")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .duelloCard()
    }

    private var memberList: some View {
        VStack(spacing: 9) {
            ForEach(blocked) { user in
                memberRow(user)
            }
        }
    }

    private func memberRow(_ user: BlockedUser) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceMuted)
                    .frame(width: 42, height: 42)
                Text(user.initial)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("Bloqué · \(user.prepName)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            unblockButton(user)
        }
        .duelloCard()
    }

    private func unblockButton(_ user: BlockedUser) -> some View {
        Button {
            unblock(user)
        } label: {
            Text("Débloquer")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 11)
                .frame(minWidth: 86, minHeight: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Débloquer \(user.displayName)")
    }

    private func unblock(_ user: BlockedUser) {
        withAnimation(.easeInOut(duration: 0.2)) {
            blocked.removeAll { $0.id == user.id }
        }
    }
}
