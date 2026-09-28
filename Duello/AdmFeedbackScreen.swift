//
//  AdmFeedbackScreen.swift
//  Duello
//
//  Messages envoyés par les utilisateurs, vus par l'administration.
//
//  Fichier source Expo porté : src/admin/AdminFeedbackScreen.tsx
//  (`AdminFeedbackScreen`, recherche multi-champs, carte de message). Les
//  libellés et les mesures sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `AdminFeedbackScreen` : boîte des feedbacks.
struct AdmFeedbackScreen: View {
    let token: String

    @State private var feedback: [AdmFeedbackRecord] = []
    @State private var query = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var reloadKey = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                AdmSearchBar(placeholder: "Rechercher dans les messages…", text: $query)
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
            title: "Feedback",
            subtitle: "\(feedback.count) message\(AdmFormat.plural(feedback.count)) reçu\(AdmFormat.plural(feedback.count))",
            refreshLabel: "Actualiser les feedbacks",
            onRefresh: { reloadKey += 1 }
        )
    }

    /// `visibleFeedback` : nom, objet, message et adresses.
    private var visibleFeedback: [AdmFeedbackRecord] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return feedback }
        return feedback.filter { item in
            let haystack = [
                item.displayName,
                item.subject,
                item.message,
                item.accountEmail ?? "",
                item.contactEmail ?? "",
            ]
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(normalized)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(
                icon: "chatbubble-ellipses-outline",
                message: "Chargement des messages…",
                isLoading: true
            )
        } else if !errorMessage.isEmpty {
            AdmStateCard(icon: "alert-circle-outline", message: errorMessage)
        } else if visibleFeedback.isEmpty {
            AdmStateCard(
                icon: "chatbubble-ellipses-outline",
                message: query.isEmpty
                    ? "Aucun feedback reçu pour le moment."
                    : "Aucun message ne correspond à la recherche.",
                iconSize: 25
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(visibleFeedback) { item in
                    card(item)
                }
            }
        }
    }

    /// `feedbackCard` : `padding: 17`, `...cardShadow`, marges internes du source
    /// (objet `marginTop: 15`, message `7`, pastille d'adresse `13`).
    private func card(_ item: AdmFeedbackRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(AdmUserText.initial(for: item.displayName))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(AdmFormat.recordDate(item.createdAt))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Text(item.subject)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 15)
            Text(item.message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
            if let address = item.contactAddress {
                contactChip(address)
                    .padding(.top, 13)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }

    /// `contact` : pastille grise de l'adresse, alignée à gauche.
    private func contactChip(_ address: String) -> some View {
        HStack(spacing: 6) {
            IonIcon(name: "mail-outline", size: 15, color: Theme.inkSoft)
            Text(address)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .textSelection(.enabled)
                .lineLimit(1)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = ""
        do {
            feedback = try await AdmAPI.listFeedback(token: token)
        } catch {
            feedback = []
            errorMessage = AdmErrorText.message(error, fallback: "Impossible de charger les feedbacks.")
        }
        isLoading = false
    }
}
