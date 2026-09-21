//
//  AdmAnalyticsScreen.swift
//  Duello
//
//  Écran « Analytics » : pilotage produit de l'usage réel de l'application.
//
//  Fichier source Expo porté : src/admin/AdminAnalyticsScreen.tsx (en-tête,
//  sélecteur de période, indicateurs du jour et de la période, cartes de
//  panneaux). Les libellés sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `AdminAnalyticsScreen` : indicateurs d'usage agrégés.
struct AdmAnalyticsScreen: View {
    let token: String

    @State private var users: [AdmUserRecord] = []
    @State private var range: AdmAnalyticsRange = .thirty
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var reloadKey = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                rangeRow
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .task(id: AdmLoadKey(reload: reloadKey, token: token)) { await load() }
    }

    /// `useMemo(() => buildAnalyticsSummary(users, range, analyticsToday()))`.
    private var summary: AdmAnalyticsSummary {
        AdmAnalyticsEngine.build(users: users, range: range, today: AdmAnalyticsEngine.today())
    }

    private var header: some View {
        AdmPageHeader(
            eyebrow: "PILOTAGE PRODUIT",
            title: "Analytics",
            subtitle: "Usage réel de l’application, actualisé à chaque session.",
            refreshLabel: "Actualiser les statistiques",
            onRefresh: { reloadKey += 1 }
        )
    }

    private var rangeRow: some View {
        HStack(spacing: 8) {
            ForEach(AdmAnalyticsRange.allCases) { value in
                Button {
                    range = value
                } label: {
                    Text(value.title)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(range == value ? Theme.surface : Theme.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(range == value ? Theme.primary : Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value.title)
                .accessibilityAddTraits(range == value ? [.isSelected] : [])
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(icon: "hourglass", message: "Calcul des indicateurs…", isLoading: true)
        } else if !errorMessage.isEmpty {
            AdmStateCard(icon: "exclamationmark.circle", message: errorMessage)
        } else {
            todaySection
            rangeSection
            AdmDailyActivityPanel(
                days: summary.days,
                totalSeconds: summary.totalSeconds,
                range: range
            )
            AdmPageTimePanel(pageSeconds: summary.pageSeconds, pageVisits: summary.pageVisits)
            AdmTopUsersPanel(users: summary.topUsers)
            AdmNoticeCard(
                icon: "checkmark.shield",
                text: "Mesures bornées à 120 jours : aucun brouillon, aucune réponse ni aucun contenu de copie n’est collecté."
            )
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdmSectionLabel(title: "AUJOURD’HUI")
            LazyVGrid(columns: metricColumns, spacing: 9) {
                AdmMetricTile(
                    icon: "person.2",
                    label: "Utilisateurs actifs",
                    value: "\(summary.today.activeUsers)"
                )
                AdmMetricTile(
                    icon: "figure.strengthtraining.traditional",
                    label: "Exercices terminés",
                    value: "\(summary.today.exercises)"
                )
                AdmMetricTile(
                    icon: "clock",
                    label: "Temps cumulé",
                    value: AdmFormat.durationMinutes(summary.today.activeSeconds)
                )
                AdmMetricTile(
                    icon: "arrow.right.square",
                    label: "Sessions ouvertes",
                    value: "\(summary.today.sessions)"
                )
            }
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdmSectionLabel(title: "SUR \(range.rawValue) JOURS")
            LazyVGrid(columns: metricColumns, spacing: 9) {
                AdmMetricTile(
                    icon: "waveform.path.ecg",
                    label: "Utilisateurs actifs",
                    value: "\(summary.activeUsers)",
                    detail: "\(summary.trackedUsers)/\(summary.registeredUsers) comptes mesurés"
                )
                AdmMetricTile(
                    icon: "stopwatch",
                    label: "Temps moyen / jour actif",
                    value: AdmFormat.durationMinutes(summary.averageDailySeconds),
                    detail: "\(summary.activeUserDays) journées utilisateur"
                )
                AdmMetricTile(
                    icon: "figure.strengthtraining.traditional",
                    label: "Exercices terminés",
                    value: "\(summary.totalExercises)",
                    detail: "\(dailyExercises) par jour"
                )
                AdmMetricTile(
                    icon: "bolt",
                    label: "Défis terminés",
                    value: "\(summary.totalChallenges)",
                    detail: AdmFormat.durationMinutes(summary.totalSeconds)
                )
            }
        }
    }

    /// `(totalExercises / range).toFixed(1)` : exercices terminés par jour.
    private var dailyExercises: String {
        String(format: "%.1f", Double(summary.totalExercises) / Double(range.rawValue))
    }

    private var metricColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
    }

    /// `useEffect([reloadKey, token])` : le registre admin porte les mesures.
    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = ""
        do {
            users = try await AdmAPI.listUsers(token: token)
        } catch {
            errorMessage = AdmErrorText.message(error, fallback: "Statistiques indisponibles.")
        }
        isLoading = false
    }
}
