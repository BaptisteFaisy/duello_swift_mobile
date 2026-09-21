//
//  AdmReportsScreen.swift
//  Duello
//
//  Signalements : comptes signalés par d'autres comptes, et contenus
//  (énoncés, corrigés) signalés par les élèves.
//
//  Fichier source Expo porté : src/admin/AdminExerciseReportsScreen.tsx
//  (`AdminExerciseReportsScreen`, `Promise.all`, onglets `Utilisateurs` /
//  `Contenus`, recherche). Les libellés sont repris mot pour mot.
//
//  Les deux listes sont chargées en parallèle, comme le `Promise.all` d'origine.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `reportKind` : les deux natures de signalement.
private enum AdmReportKind {
    case users, content
}

/// Charge utile d'une des deux requêtes lancées ensemble.
private enum AdmReportsPayload {
    case users([AdmUserReportRecord])
    case contents([AdmExerciseReportRecord])
}

/// `AdminExerciseReportsScreen` : signalements de comptes et de contenus.
struct AdmReportsScreen: View {
    let token: String

    @State private var userReports: [AdmUserReportRecord] = []
    @State private var contentReports: [AdmExerciseReportRecord] = []
    @State private var kind: AdmReportKind = .users
    @State private var query = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var reloadKey = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                kindTabs
                AdmSearchBar(placeholder: searchPlaceholder, text: $query)
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
            title: "Signalements",
            subtitle: "\(userReports.count) compte\(AdmFormat.plural(userReports.count)) · \(contentReports.count) contenu\(AdmFormat.plural(contentReports.count))",
            refreshLabel: "Actualiser les signalements",
            onRefresh: { reloadKey += 1 }
        )
    }

    private var kindTabs: some View {
        HStack(spacing: 8) {
            kindTab(.users, icon: "person.2", title: "Utilisateurs (\(userReports.count))")
            kindTab(.content, icon: "doc.text", title: "Contenus (\(contentReports.count))")
        }
    }

    /// Onglet de nature de signalement ; changer d'onglet efface la recherche.
    private func kindTab(_ target: AdmReportKind, icon: String, title: String) -> some View {
        let selected = kind == target
        return Button {
            kind = target
            query = ""
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(selected ? Theme.primary : Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var searchPlaceholder: String {
        kind == .users ? "Compte, motif, précision…" : "Élève, exercice, matière…"
    }

    /// `visibleUserReports` : compte, motif et précisions confidentielles.
    private var visibleUserReports: [AdmUserReportRecord] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return userReports }
        return userReports.filter { report in
            let haystack = [
                report.reporterDisplayName,
                report.reporterId,
                report.reportedDisplayName,
                report.reportedId,
                report.reason.label,
                report.details,
            ]
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(normalized)
        }
    }

    /// `visibleContentReports` : élève, exercice, matière et précision.
    private var visibleContentReports: [AdmExerciseReportRecord] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return contentReports }
        return contentReports.filter { report in
            let haystack = [
                report.displayName,
                report.exerciseTitle,
                report.exerciseId,
                report.subject,
                report.message,
                report.target.label,
                report.source.label,
            ]
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(normalized)
        }
    }

    /// L'onglet actif n'a rien à afficher (liste vide ou recherche sans résultat).
    private var hasNoVisibleReports: Bool {
        kind == .users ? visibleUserReports.isEmpty : visibleContentReports.isEmpty
    }

    private var emptyMessage: String {
        if !query.isEmpty { return "Aucun signalement ne correspond à la recherche." }
        return kind == .users
            ? "Aucun utilisateur signalé pour le moment."
            : "Aucun contenu signalé pour le moment."
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(icon: "hourglass", message: "Chargement des signalements…", isLoading: true)
        } else if !errorMessage.isEmpty {
            AdmStateCard(icon: "exclamationmark.circle", message: errorMessage, tint: Theme.like)
        } else if hasNoVisibleReports {
            AdmStateCard(icon: kind == .users ? "person.2" : "ladybug", message: emptyMessage)
        } else if kind == .users {
            VStack(spacing: 10) {
                ForEach(visibleUserReports) { report in
                    AdmUserReportCard(report: report)
                }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(visibleContentReports) { report in
                    AdmContentReportCard(report: report)
                }
            }
        }
    }

    /// `Promise.all([listAdminUserReports, listAdminExerciseReports])`.
    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = ""
        do {
            let payloads = try await withThrowingTaskGroup(of: AdmReportsPayload.self) { group in
                group.addTask {
                    .users(try await AdmAPI.listUserReports(token: token))
                }
                group.addTask {
                    .contents(try await AdmAPI.listExerciseReports(token: token))
                }
                var collected: [AdmReportsPayload] = []
                for try await payload in group {
                    collected.append(payload)
                }
                return collected
            }
            for payload in payloads {
                switch payload {
                case let .users(records):
                    userReports = records
                case let .contents(records):
                    contentReports = records
                }
            }
        } catch {
            userReports = []
            contentReports = []
            errorMessage = AdmErrorText.message(error, fallback: "Impossible de charger les signalements.")
        }
        isLoading = false
    }
}
