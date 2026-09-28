//
//  AdmAnalyticsPanels.swift
//  Duello
//
//  Panneaux de l'écran Analytics : temps actif quotidien, temps par page,
//  utilisateurs les plus engagés.
//
//  Fichier source Expo porté : src/admin/AdminAnalyticsScreen.tsx (panneaux
//  `Temps actif quotidien`, `Temps passé par page`, `Utilisateurs les plus
//  engagés`). Les libellés et les mesures sont repris mot pour mot.
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Temps actif quotidien")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("Cumul de tous les utilisateurs · 14 derniers jours maximum")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text(AdmFormat.durationMinutes(totalSeconds))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            chart
                .padding(.top, 18)
            Text("Le nombre au-dessus de chaque barre indique les utilisateurs actifs.")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
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
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(visibleDays) { day in
                column(day)
            }
        }
    }

    private func column(_ day: AdmAnalyticsDay) -> some View {
        VStack(spacing: 0) {
            // `day.activeUsers || ''` : une colonne sans chiffre garde la même
            // hauteur de bandeau (`height: 18` de la source).
            Text(day.activeUsers > 0 ? "\(day.activeUsers)" : "")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
                .frame(height: 18)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.surfaceMuted)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.ink)
                        .frame(height: barHeight(day, trackHeight: geo.size.height))
                }
                // `chartTrack width: '72%'` : la barre n'occupe que 72 % de la
                // colonne, centrée.
                .frame(width: geo.size.width * 0.72)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 136)
            Text(AdmFormat.shortDate(day.date))
                .font(.system(size: 7, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity)
    }

    /// `Math.max(activeSeconds > 0 ? 5 : 0, round(activeSeconds / max * 100))` %.
    private func barHeight(_ day: AdmAnalyticsDay, trackHeight: CGFloat) -> CGFloat {
        guard day.activeSeconds > 0, maxSeconds > 0 else { return 0 }
        let fraction = day.activeSeconds / maxSeconds
        let percent = max(0.05, (fraction * 100).rounded() / 100)
        return CGFloat(min(1, percent)) * trackHeight
    }
}

/// `Temps passé par page` : part du temps au premier plan, par page.
struct AdmPageTimePanel: View {
    let pageSeconds: [AdmUsagePage: Double]
    let pageVisits: [AdmUsagePage: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Temps passé par page")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Durée au premier plan, hors application inactive.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            VStack(spacing: 17) {
                ForEach(AdmUsagePage.allCases) { page in
                    row(page)
                }
            }
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }

    private var totalSeconds: Double {
        pageSeconds.values.reduce(0) { $0 + $1 }
    }

    private func row(_ page: AdmUsagePage) -> some View {
        let seconds = pageSeconds[page] ?? 0
        let visits = pageVisits[page] ?? 0
        let share = totalSeconds > 0 ? seconds / totalSeconds : 0
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(page.label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text("\(AdmFormat.durationMinutes(seconds)) · \(visits) visites")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
            }
            AdmProgressTrack(fraction: share, tint: Theme.ink, height: 8)
        }
    }
}

/// `Utilisateurs les plus engagés` : classement de la période sélectionnée.
struct AdmTopUsersPanel: View {
    let users: [AdmTopUser]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Utilisateurs les plus engagés")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Classement sur la période sélectionnée.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 4)
            if users.isEmpty {
                Text("Pas encore d’activité sur cette période.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(users.indices, id: \.self) { index in
                        row(users[index], rank: index + 1)
                    }
                }
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }

    /// `userRow` : trait sous **chaque** compte (`borderBottomWidth: 1`).
    private func row(_ user: AdmTopUser, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(user.exercises) exercices terminés")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 0)
            Text(AdmFormat.durationMinutes(user.activeSeconds))
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.ink)
        }
        .frame(minHeight: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }
}
