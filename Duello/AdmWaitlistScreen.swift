//
//  AdmWaitlistScreen.swift
//  Duello
//
//  Inscriptions à la liste d'attente du site, vues par l'administration.
//
//  Fichier source Expo porté : src/admin/AdminWaitlistScreen.tsx
//  (`AdminWaitlistScreen`, recherche téléphone/e-mail/prépa, carte de contact).
//  Les libellés et les mesures sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `AdminWaitlistScreen` : liste des contacts inscrits sur le site.
struct AdmWaitlistScreen: View {
    let token: String

    @State private var entries: [AdmWaitlistEntry] = []
    @State private var query = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var reloadKey = 0
    /// `visibleEntries` mémoïsé : recalculé uniquement quand `entries` ou
    /// `query` change, au lieu de l'être à chaque évaluation de `body`.
    @State private var visibleEntries: [AdmWaitlistEntry] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                AdmNoticeCard(
                    icon: "shield-checkmark-outline",
                    text: "Ces adresses e-mail sont visibles uniquement dans ton espace administrateur.",
                    tint: Theme.primary,
                    iconSize: 19,
                    textSize: 12,
                    padding: 13,
                    background: Theme.primaryLight,
                    alignment: .center
                )
                AdmSearchBar(placeholder: "E-mail ou prépa…", text: $query, showsClearButton: false)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .task(id: AdmLoadKey(reload: reloadKey, token: token)) { await load() }
        .onChange(of: entries) { _ in refreshVisibleEntries() }
        .onChange(of: query) { _ in refreshVisibleEntries() }
    }

    private var header: some View {
        AdmPageHeader(
            eyebrow: "ADMINISTRATION",
            title: "Waitlist",
            subtitle: "\(entries.count) contact\(AdmFormat.plural(entries.count)) inscrit\(AdmFormat.plural(entries.count)) sur le site",
            refreshLabel: "Actualiser la liste d’attente",
            onRefresh: { reloadKey += 1 }
        )
    }

    /// `visibleEntries` : téléphone, e-mail et prépa.
    private func refreshVisibleEntries() {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            visibleEntries = entries
            return
        }
        visibleEntries = entries.filter { entry in
            let haystack = [entry.phone ?? "", entry.email ?? "", entry.school]
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(normalized)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(
                icon: "people-outline",
                message: "Chargement des inscriptions…",
                isLoading: true,
                showsIconWhenLoading: true
            )
        } else if !errorMessage.isEmpty {
            AdmStateCard(icon: "people-outline", message: errorMessage)
        } else if visibleEntries.isEmpty {
            AdmStateCard(
                icon: "people-outline",
                message: query.isEmpty
                    ? "Aucune inscription pour le moment."
                    : "Aucune inscription ne correspond."
            )
        } else {
            LazyVStack(spacing: 10) {
                ForEach(visibleEntries) { entry in
                    row(entry)
                }
            }
        }
    }

    /// `entryCard` : `minHeight: 76`, `...cardShadow`.
    private func row(_ entry: AdmWaitlistEntry) -> some View {
        HStack(spacing: 12) {
            IonIcon(
                name: entry.phone?.isEmpty == false ? "call-outline" : "mail-outline",
                size: 18,
                color: Theme.ink
            )
            .frame(width: 40, height: 40)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.contact)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .lineLimit(1)
                Text(entry.school)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                Text(metaText(entry))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }

    /// « Rang 12 · inscrit · 3 filleuls » (les parrainages sont facultatifs).
    private func metaText(_ entry: AdmWaitlistEntry) -> String {
        var text = "Rang \(entry.position) · inscrit"
        if entry.referrals > 0 {
            text += " · \(entry.referrals) filleul\(AdmFormat.plural(entry.referrals))"
        }
        return text
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = ""
        do {
            entries = try await AdmAPI.listWaitlist(token: token)
        } catch {
            entries = []
            errorMessage = AdmErrorText.message(error, fallback: "Impossible de charger la liste d’attente.")
        }
        isLoading = false
    }
}
