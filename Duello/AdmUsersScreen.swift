//
//  AdmUsersScreen.swift
//  Duello
//
//  Liste des comptes du registre admin : recherche, actualisation, détail.
//
//  Fichier source Expo porté : src/admin/AdminUsersScreen.tsx (`AdminUsersScreen`,
//  `StateCard`, recherche `searchableUser`, ligne de compte). Les libellés sont
//  repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `AdminUsersScreen` : registre des comptes utilisateurs.
struct AdmUsersScreen: View {
    let token: String

    @State private var users: [AdmUserRecord] = []
    @State private var selected: AdmUserRecord?
    @State private var query = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var reloadKey = 0
    /// `visibleUsers` mémoïsé : recalculé uniquement quand `users` ou `query`
    /// change, au lieu de l'être à chaque évaluation de `body`.
    @State private var visibleUsers: [AdmUserRecord] = []

    var body: some View {
        Group {
            if let selected {
                AdmUserDetailView(user: selected) {
                    self.selected = nil
                }
            } else {
                list
            }
        }
        .task(id: AdmLoadKey(reload: reloadKey, token: token)) { await load() }
        .onChange(of: users) { _ in refreshVisibleUsers() }
        .onChange(of: query) { _ in refreshVisibleUsers() }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AdmPageHeader(
                    eyebrow: "ADMINISTRATION",
                    title: "Users",
                    subtitle: "\(users.count) compte\(AdmFormat.plural(users.count)) inscrit\(AdmFormat.plural(users.count))",
                    refreshLabel: "Actualiser les utilisateurs",
                    onRefresh: { reloadKey += 1 }
                )
                AdmSearchBar(placeholder: "Nom, prépa, filière…", text: $query)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(icon: "hourglass", message: "Chargement des comptes…", isLoading: true)
        } else if !errorMessage.isEmpty {
            AdmStateCard(icon: "exclamationmark.circle", message: errorMessage)
        } else if visibleUsers.isEmpty {
            AdmStateCard(
                icon: "person.2",
                message: query.isEmpty
                    ? "Aucun utilisateur inscrit."
                    : "Aucun utilisateur ne correspond."
            )
        } else {
            LazyVStack(spacing: 10) {
                ForEach(visibleUsers) { user in
                    row(user)
                }
            }
        }
    }

    /// `visibleUsers` : filtre insensible à la casse sur les champs du compte.
    private func refreshVisibleUsers() {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            visibleUsers = users
            return
        }
        visibleUsers = users.filter { AdmUserText.searchable($0).contains(normalized) }
    }

    private func row(_ user: AdmUserRecord) -> some View {
        Button {
            selected = user
        } label: {
            HStack(spacing: 12) {
                Text(AdmUserText.initial(for: user.displayName))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46)
                    .background(Theme.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName.isEmpty ? "Utilisateur sans nom" : user.displayName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(AdmUserText.path(for: user))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                    Text(metaText(user))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(14)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(user.displayName.isEmpty ? "Utilisateur sans nom" : user.displayName)
    }

    /// « 2 h 05 · dernière activité 12 sept. 2026 à 14:30 ».
    private func metaText(_ user: AdmUserRecord) -> String {
        let duration = AdmFormat.durationSeconds(user.usage?.totalActiveSeconds)
        let activity = AdmFormat.lastActivityDate(AdmUserText.lastActivity(for: user))
        return "\(duration) · dernière activité \(activity)"
    }

    /// `useEffect([reloadKey, token])` : rechargement du registre admin.
    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = ""
        do {
            users = try await AdmAPI.listUsers(token: token)
        } catch {
            users = []
            errorMessage = AdmErrorText.message(error, fallback: "Impossible de charger les utilisateurs.")
        }
        isLoading = false
    }
}
