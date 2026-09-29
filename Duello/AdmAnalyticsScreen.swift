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
            VStack(alignment: .leading, spacing: 16) {
                header
                rangeRow
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .task(id: AdmLoadKey(reload: reloadKey, token: token)) { await load() }
    }

    /// `useMemo(() => buildAnalyticsSummary(users, range, analyticsToday()))`.
    private var summary: AdmAnalyticsSummary {
        AdmAnalyticsEngine.build(users: users, range: range, today: AdmAnalyticsEngine.today())
    }

    /// `title: { fontSize: 30 }` de la source (les autres écrans admin restent à 28).
    private var header: some View {
        AdmPageHeader(
            eyebrow: "PILOTAGE PRODUIT",
            title: "Analytics",
            subtitle: "Usage réel de l’application, actualisé à chaque session.",
            refreshLabel: "Actualiser les statistiques",
            onRefresh: { reloadKey += 1 },
            titleSize: 30
        )
    }

    /// `rangeRow` : piste `surfaceMuted` (`padding:4`, rayon 14) largeur du
    /// contenu, boutons `paddingHorizontal:13`, rayon 11, texte 12/800.
    private var rangeRow: some View {
        HStack(spacing: 7) {
            ForEach(AdmAnalyticsRange.allCases) { value in
                Button {
                    range = value
                } label: {
                    Text(value.title)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(range == value ? Theme.surface : Theme.inkSoft)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 13)
                        .background(range == value ? Theme.ink : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value.title)
                .accessibilityAddTraits(range == value ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(
                icon: "alert-circle-outline",
                message: "Calcul des indicateurs…",
                isLoading: true,
                padding: 32,
                background: Theme.surfaceMuted,
                showsBorder: false
            )
        } else if !errorMessage.isEmpty {
            AdmStateCard(
                icon: "alert-circle-outline",
                message: errorMessage,
                padding: 32,
                background: Theme.surfaceMuted,
                showsBorder: false
            )
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
                icon: "shield-checkmark-outline",
                text: "Mesures bornées à 120 jours : aucun brouillon, aucune réponse ni aucun contenu de copie n’est collecté.",
                iconSize: 20,
                textSize: 10,
                padding: 14,
                alignment: .center
            )
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdmSectionLabel(title: "AUJOURD’HUI")
            LazyVGrid(columns: metricColumns, spacing: 10) {
                AdmMetricTile(
                    icon: "people-outline",
                    label: "Utilisateurs actifs",
                    value: "\(summary.today.activeUsers)",
                    variant: .analytics
                )
                AdmMetricTile(
                    icon: "barbell-outline",
                    label: "Exercices terminés",
                    value: "\(summary.today.exercises)",
                    variant: .analytics
                )
                AdmMetricTile(
                    icon: "time-outline",
                    label: "Temps cumulé",
                    value: AdmFormat.durationMinutes(summary.today.activeSeconds),
                    variant: .analytics
                )
                AdmMetricTile(
                    icon: "enter-outline",
                    label: "Sessions ouvertes",
                    value: "\(summary.today.sessions)",
                    variant: .analytics
                )
            }
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdmSectionLabel(title: "SUR \(range.rawValue) JOURS")
            LazyVGrid(columns: metricColumns, spacing: 10) {
                AdmMetricTile(
                    icon: "pulse-outline",
                    label: "Utilisateurs actifs",
                    value: "\(summary.activeUsers)",
                    detail: "\(summary.trackedUsers)/\(summary.registeredUsers) comptes mesurés",
                    variant: .analytics
                )
                AdmMetricTile(
                    icon: "stopwatch-outline",
                    label: "Temps moyen / jour actif",
                    value: AdmFormat.durationMinutes(summary.averageDailySeconds),
                    detail: "\(summary.activeUserDays) journées utilisateur",
                    variant: .analytics
                )
                AdmMetricTile(
                    icon: "barbell-outline",
                    label: "Exercices terminés",
                    value: "\(summary.totalExercises)",
                    detail: "\(dailyExercises) par jour",
                    variant: .analytics
                )
                AdmMetricTile(
                    icon: "flash-outline",
                    label: "Défis terminés",
                    value: "\(summary.totalChallenges)",
                    detail: AdmFormat.durationMinutes(summary.totalSeconds),
                    variant: .analytics
                )
            }
        }
    }

    /// `(totalExercises / range).toFixed(1)` : exercices terminés par jour.
    private var dailyExercises: String {
        String(format: "%.1f", Double(summary.totalExercises) / Double(range.rawValue))
    }

    private var metricColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
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
