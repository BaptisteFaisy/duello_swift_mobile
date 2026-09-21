//
//  AdmWaitlistScreen.swift
//  Duello
//
//  Inscriptions à la liste d'attente du site, vues par l'administration.
//
//  Fichier source Expo porté : src/admin/AdminWaitlistScreen.tsx
//  (`AdminWaitlistScreen`, recherche téléphone/e-mail/prépa, carte de contact).
//  Les libellés sont repris mot pour mot.
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                AdmNoticeCard(
                    icon: "checkmark.shield",
                    text: "Ces adresses e-mail sont visibles uniquement dans ton espace administrateur.",
                    tint: Theme.primary
                )
                AdmSearchBar(placeholder: "E-mail ou prépa…", text: $query)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .task(id: AdmLoadKey(reload: reloadKey, token: token)) { await load() }
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
    private var visibleEntries: [AdmWaitlistEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return entries }
        return entries.filter { entry in
            let haystack = [entry.phone ?? "", entry.email ?? "", entry.school]
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(normalized)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(icon: "person.2", message: "Chargement des inscriptions…", isLoading: true)
        } else if !errorMessage.isEmpty {
            AdmStateCard(icon: "person.2", message: errorMessage)
        } else if visibleEntries.isEmpty {
            AdmStateCard(
                icon: "person.2",
                message: query.isEmpty
                    ? "Aucune inscription pour le moment."
                    : "Aucune inscription ne correspond."
            )
        } else {
            VStack(spacing: 10) {
                ForEach(visibleEntries) { entry in
                    row(entry)
                }
            }
        }
    }

    private func row(_ entry: AdmWaitlistEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.phoneOrNil == nil ? "envelope" : "phone")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.contact)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .lineLimit(1)
                Text(entry.school)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                Text(metaText(entry))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
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
