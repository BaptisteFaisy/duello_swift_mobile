//
//  AcctSubBlockedUsersView.swift
//  Duello
//
//  Lot 15-A — compléments « utilisateurs bloqués ».
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/BlockedUsersScreen.tsx
//
//  Le lot « Account » fournit déjà une vue locale de démonstration
//  (`BlockedUsersView`, 139 l.) : liste en `@State`, retrait immédiat, sans
//  réseau. Cette vue-ci porte **ce qui manque** à cette démo, en réutilisant
//  le client réseau existant `ReportSafetyAPI` (`/user-safety`) et le modèle
//  `ReportBlockedProfile` — aucune de ces briques n'est redéfinie ici.
//
//  Compléments portés :
//    - chargement (« Chargement… ») et erreur de chargement + « Réessayer » ;
//    - erreur en ligne discrète quand une liste est déjà affichée ;
//    - confirmation `Alert` avant déblocage (texte source exact) ;
//    - état occupé du bouton (spinner, boutons désactivés pendant l'appel) ;
//    - chapeau « SÉCURITÉ » + titre ;
//    - pastille de présence (`SocPresenceStore`, AvatarPresence) et photo ;
//    - accessibilité : annonce de l'erreur (équivalent live region).
//
//  Limite : SwiftUI n'expose pas de « live region » ; l'erreur est annoncée
//  via `UIAccessibility.post(notification: .announcement, ...)`, équivalent
//  du `accessibilityLiveRegion="polite"` de React Native. L'état « busy »
//  d'un bouton (absent de SwiftUI avant iOS 17) est simulé par la désactivation
//  + le spinner, comme le fait la source.
//
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AcctSubBlockedUsersView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var presence = SocPresenceStore.shared

    @State private var profiles: [ReportBlockedProfile] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var attempt = 0
    @State private var unblockingId: String? = nil
    @State private var pendingUnblock: ReportBlockedProfile? = nil

    private static let loadErrorMessage = "Impossible de charger les comptes bloqués."
    private static let unblockErrorMessage = "Impossible de débloquer ce compte."
    private static let unblockConfirmationMessage = "Ce compte et le tien pourront à nouveau se trouver dans l’annuaire et interagir sur Duello."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                explanationCard
                stateContent
                if !errorMessage.isEmpty && !profiles.isEmpty {
                    inlineError
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Theme.background)
        .task(id: attempt) { await load() }
        .alert(
            "Débloquer \(pendingUnblock?.displayName ?? "") ?",
            isPresented: confirmBinding,
            presenting: pendingUnblock
        ) { member in
            Button("Annuler", role: .cancel) {}
            Button("Débloquer") { performUnblock(member) }
        } message: { _ in
            Text(Self.unblockConfirmationMessage)
        }
    }

    /// `pendingUnblock != nil` pilote la boîte de confirmation.
    private var confirmBinding: Binding<Bool> {
        Binding(
            get: { pendingUnblock != nil },
            set: { if !$0 { pendingUnblock = nil } }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SÉCURITÉ")
                .font(.system(size: 10, weight: .black))
                .tracking(1.1)
                .foregroundStyle(Theme.inkSoft)
            Text("Comptes bloqués")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private var stateContent: some View {
        if isLoading {
            loadingCard
        } else if !errorMessage.isEmpty && profiles.isEmpty {
            errorCard
        } else if profiles.isEmpty {
            emptyCard
        } else {
            memberList
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 9) {
            ProgressView().tint(Theme.ink)
            Text("Chargement…")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    private var errorCard: some View {
        VStack(spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Theme.like)
            Text(errorMessage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                attempt += 1
            } label: {
                Text("Réessayer")
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
            }
            .buttonStyle(DuelloPrimaryButton())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    private var emptyCard: some View {
        DuelloEmptyState(icon: "checkmark.circle", title: "Aucun compte bloqué.")
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    private var memberList: some View {
        VStack(spacing: 9) {
            ForEach(profiles) { member in
                memberRow(member)
            }
        }
    }

    private var inlineError: some View {
        Text(errorMessage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.like)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(errorMessage)
    }

    private func memberRow(_ member: ReportBlockedProfile) -> some View {
        HStack(spacing: 11) {
            avatar(member)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.displayName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("Bloqué")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            unblockButton(member)
        }
        .duelloCard()
    }

    /// Avatar : initiale, photo facultative (`AsyncImage`) et point de présence.
    private func avatar(_ member: ReportBlockedProfile) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(Theme.surfaceMuted)
                Text(String(member.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                if let uri = member.photoUri, let url = URL(string: uri) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())

            if presence.isOnline(member.id) {
                Circle()
                    .fill(Theme.progress)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }

    private func unblockButton(_ member: ReportBlockedProfile) -> some View {
        Button {
            pendingUnblock = member
        } label: {
            Group {
                if unblockingId == member.id {
                    ProgressView().tint(Theme.ink)
                } else {
                    Text("Débloquer")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
            }
            .frame(minWidth: 86, minHeight: 36)
            .padding(.horizontal, 11)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(unblockingId != nil)
        .accessibilityLabel("Débloquer \(member.displayName)")
    }

    private func load() async {
        isLoading = true
        errorMessage = ""
        do {
            let state = try await ReportSafetyAPI.fetchState(token: session.token)
            profiles = state.blockedProfiles
        } catch {
            setError(error, fallback: Self.loadErrorMessage)
        }
        isLoading = false
    }

    private func performUnblock(_ member: ReportBlockedProfile) {
        pendingUnblock = nil
        unblockingId = member.id
        errorMessage = ""
        Task {
            do {
                let state = try await ReportSafetyAPI.unblock(targetId: member.id, token: session.token)
                profiles = state.blockedProfiles
            } catch {
                setError(error, fallback: Self.unblockErrorMessage)
            }
            unblockingId = nil
        }
    }

    /// Message d'erreur lisible + annonce pour les technologies d'assistance.
    private func setError(_ error: Error, fallback: String) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let resolved = message.isEmpty ? fallback : message
        errorMessage = resolved
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: resolved)
        #endif
    }
}
