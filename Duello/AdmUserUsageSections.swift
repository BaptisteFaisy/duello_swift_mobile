//
//  AdmUserUsageSections.swift
//  Duello
//
//  Sections d'usage de la fiche d'un compte : temps par page, activité
//  quotidienne, actions et progression.
//
//  Fichier source Expo porté : src/admin/AdminUsersScreen.tsx (`UserDetail`,
//  `Metric`, `ActivityRow`, `areaLabels`). Les libellés sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Valeurs dérivées de l'usage d'un compte (`UserDetail` du source) :
/// trente derniers jours, moyenne par jour actif, répartition par page.
struct AdmUserUsageMetrics {
    let totalSeconds: Double
    let sessionCount: Int
    let totalAreaSeconds: Double
    let recentDays: [AdmUsageDay]
    let averageDaySeconds: Double

    private let pageSeconds: AdmPageCounters
    private let pageVisits: AdmPageCounters

    init(usage: AdmUsageAnalytics?) {
        let seconds = usage?.pageSeconds ?? AdmPageCounters()
        let visits = usage?.pageVisits ?? AdmPageCounters()
        let days = Array((usage?.daily ?? []).suffix(30).reversed())
        let active = days.filter { $0.activeSeconds > 0 }

        totalSeconds = usage?.totalActiveSeconds ?? 0
        sessionCount = usage?.sessionCount ?? 0
        pageSeconds = seconds
        pageVisits = visits
        totalAreaSeconds = seconds.total
        recentDays = days
        averageDaySeconds = active.isEmpty
            ? 0
            : active.reduce(0) { $0 + $1.activeSeconds } / Double(active.count)
    }

    func seconds(for page: AdmUsagePage) -> Double { pageSeconds.seconds(for: page) }

    func visits(for page: AdmUsagePage) -> Int { pageVisits.count(for: page) }
}

/// `UTILISATION DE L'APP`, `ACTIVITÉ JOUR PAR JOUR` et `ACTIONS ET PROGRESSION`.
struct AdmUserUsageSections: View {
    let user: AdmUserRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            usageSection
            dailySection
            activitySection
        }
    }

    private var metrics: AdmUserUsageMetrics { AdmUserUsageMetrics(usage: user.usage) }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdmSectionLabel(title: "UTILISATION DE L’APP")
            VStack(spacing: 17) {
                ForEach(AdmUsagePage.allCases) { page in
                    pageRow(page)
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
        }
    }

    /// Temps et visites d'une page, avec la part du temps total.
    private func pageRow(_ page: AdmUsagePage) -> some View {
        let seconds = metrics.seconds(for: page)
        let visits = metrics.visits(for: page)
        let fraction = metrics.totalAreaSeconds > 0 ? seconds / metrics.totalAreaSeconds : 0
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(page.label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("\(AdmFormat.durationSeconds(seconds)) · \(visits) visite\(AdmFormat.plural(visits))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            DuelloProgressTrack(fraction: fraction, tint: Theme.primary, height: 7)
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdmSectionLabel(title: "ACTIVITÉ JOUR PAR JOUR")
            VStack(spacing: 0) {
                if metrics.recentDays.isEmpty {
                    Text("Les données quotidiennes apparaîtront après la prochaine utilisation de l’app.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 22)
                } else {
                    ForEach(metrics.recentDays) { day in
                        dailyRow(day)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private func dailyRow(_ day: AdmUsageDay) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AdmFormat.dayLabel(day.date))
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("\(day.sessions) session\(AdmFormat.plural(day.sessions))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            dailyMetric(value: "\(day.actions.exerciseCompleted)", label: "exercices")
            dailyMetric(value: AdmFormat.durationSeconds(day.activeSeconds), label: "temps actif")
        }
        .frame(minHeight: 62)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    private func dailyMetric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(minWidth: 62, alignment: .trailing)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdmSectionLabel(title: "ACTIONS ET PROGRESSION")
            VStack(spacing: 0) {
                activityRow(icon: "figure.strengthtraining.traditional", label: "Exercices terminés", value: "\(user.usage?.actions.exerciseCompleted ?? 0)")
                activityRow(icon: "bolt", label: "Défis terminés", value: "\(user.usage?.actions.challengeCompleted ?? 0)")
                activityRow(icon: "book", label: "Mises à jour de cours", value: "\(user.usage?.actions.courseUpdated ?? 0)")
                activityRow(icon: "bubble.left.and.bubble.right", label: "Feedbacks envoyés", value: "\(user.usage?.actions.feedbackSent ?? 0)")
                activityRow(icon: "graduationcap", label: "Progression du programme", value: "\(Int((user.performance?.completion ?? 0).rounded())) %")
                activityRow(icon: "doc.text", label: "Notes renseignées", value: "\(user.performance?.gradeCount ?? 0)", last: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    /// `ActivityRow` : icône, libellé, valeur, séparateur sauf sur la dernière.
    private func activityRow(
        icon: String,
        label: String,
        value: String,
        last: Bool = false
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.ink)
        }
        .frame(minHeight: 58)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
            }
        }
    }
}
