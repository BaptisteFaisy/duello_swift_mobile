//
//  AdmAnalyticsPanels.swift
//  Duello
//
//  Panneaux de l'écran Analytics : temps actif quotidien, temps par page,
//  utilisateurs les plus engagés.
//
//  Fichier source Expo porté : src/admin/AdminAnalyticsScreen.tsx (panneaux
//  `Temps actif quotidien`, `Temps passé par page`, `Utilisateurs les plus
//  engagés`). Les libellés sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `Temps actif quotidien` : barres des jours visibles, 14 au maximum.
struct AdmDailyActivityPanel: View {
    let days: [AdmAnalyticsDay]
    let totalSeconds: Double
    let range: AdmAnalyticsRange

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Temps actif quotidien")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("Cumul de tous les utilisateurs · 14 derniers jours maximum")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(AdmFormat.durationMinutes(totalSeconds))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            chart
            Text("Le nombre au-dessus de chaque barre indique les utilisateurs actifs.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
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

    /// `summary.days.slice(-Math.min(14, range))`.
    private var visibleDays: [AdmAnalyticsDay] {
        Array(days.suffix(min(14, range.rawValue)))
    }

    /// `Math.max(1, ...activeSeconds)` : évite la division par zéro.
    private var maxSeconds: Double {
        max(1, visibleDays.map { $0.activeSeconds }.max() ?? 1)
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(visibleDays) { day in
                column(day)
            }
        }
    }

    private func column(_ day: AdmAnalyticsDay) -> some View {
        VStack(spacing: 6) {
            // Le source écrit `day.activeUsers || ''` ; une espace garde ici la
            // hauteur de la colonne sans chiffre, la barre restant alignée.
            Text(day.activeUsers > 0 ? "\(day.activeUsers)" : " ")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceMuted)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.primary)
                    .frame(height: barHeight(day))
            }
            .frame(height: 120)
            Text(AdmFormat.shortDate(day.date))
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// Hauteur de la barre, avec un minimum visible de 6 points dès qu'il y a
    /// de l'activité (le source garantit 5 % de la hauteur de piste).
    private func barHeight(_ day: AdmAnalyticsDay) -> CGFloat {
        let fraction = maxSeconds > 0 ? day.activeSeconds / maxSeconds : 0
        let proportional = CGFloat(fraction) * 120
        return max(day.activeSeconds > 0 ? 6 : 0, proportional)
    }
}

/// `Temps passé par page` : part du temps au premier plan, par page.
struct AdmPageTimePanel: View {
    let pageSeconds: [AdmUsagePage: Double]
    let pageVisits: [AdmUsagePage: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Temps passé par page")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Durée au premier plan, hors application inactive.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 17) {
                ForEach(AdmUsagePage.allCases) { page in
                    row(page)
                }
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

    private var totalSeconds: Double {
        pageSeconds.values.reduce(0) { $0 + $1 }
    }

    private func row(_ page: AdmUsagePage) -> some View {
        let seconds = pageSeconds[page] ?? 0
        let visits = pageVisits[page] ?? 0
        let share = totalSeconds > 0 ? seconds / totalSeconds : 0
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(page.label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("\(AdmFormat.durationMinutes(seconds)) · \(visits) visites")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            DuelloProgressTrack(fraction: share, tint: Theme.primary, height: 7)
        }
    }
}

/// `Utilisateurs les plus engagés` : classement de la période sélectionnée.
struct AdmTopUsersPanel: View {
    let users: [AdmTopUser]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Utilisateurs les plus engagés")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Classement sur la période sélectionnée.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            if users.isEmpty {
                Text("Pas encore d’activité sur cette période.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(users.indices, id: \.self) { index in
                        row(users[index], rank: index + 1)
                    }
                }
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

    private func row(_ user: AdmTopUser, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(user.exercises) exercices terminés")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            Text(AdmFormat.durationMinutes(user.activeSeconds))
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.ink)
        }
        .frame(minHeight: 52)
    }
}
