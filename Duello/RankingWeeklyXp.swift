import Foundation
import SwiftUI

// MARK: - Classement XP de la semaine

/// Classement des XP de la semaine pour une matière, groupé par ligue.
///
/// Reprend `WeeklyXpRankingScreen.tsx` : chargement depuis
/// `DuelloAPI.weeklyXpLeaderboard`, semaine calculée par `WeeklyXP.weekKey()`,
/// états chargement/erreur/vide, et carte « Ma semaine » déduite du rang du
/// joueur connecté (ligue atteinte et progression, `weeklyXpLeagueProgress`).
///
/// Extrait de l'ancien `RankingsView.swift`. Dépend de `RankingLoadStateViews`,
/// `RankingRowViews`, `RankingWeeklyXpLeagues` (`WeeklyXpLeague`,
/// `weeklyXpLeagues`, `weeklyXpLeague(for:)`, `weeklyXpLeagueProgress(for:)`)
/// et `RankingRowBuilder` (`rankedWeeklyRows`, `groupedNumber`) : aucun nom ni
/// signature n'a changé.
struct WeeklyXpRankingView: View {
    @EnvironmentObject private var session: SessionStore

    /// Matière classée.
    let subject: String
    /// Lundi de la semaine classée, au format AAAA-MM-JJ.
    var week: String = WeeklyXP.weekKey()

    @State private var entries: [LeaderboardEntry] = []
    @State private var phase: RankingLoadPhase = .loading
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(title: "Classement XP hebdo", subtitle: subject)
            stateContent
        }
        .onAppear { load() }
    }

    /// Contenu selon l'état de chargement : attente, panne, vide ou classement.
    @ViewBuilder
    private var stateContent: some View {
        switch phase {
        case .loading:
            RankingStatusCard(
                icon: "hourglass",
                title: "Chargement du classement…",
                message: "Les XP de la semaine sont en cours de récupération.",
                showsProgress: true
            )
        case .error:
            RankingStatusCard(
                icon: "cloud.offline",
                title: "Classement indisponible",
                message: errorMessage.isEmpty
                    ? "Le classement est momentanément indisponible."
                    : errorMessage,
                retry: { load() }
            )
        case .ready:
            if rows.isEmpty {
                DuelloEmptyState(
                    icon: "flame",
                    title: "Aucun XP cette semaine",
                    message: "Personne n'a encore gagné d'XP sur \(subject) cette semaine."
                )
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if let myRow = rows.first(where: { $0.isCurrentUser }) {
                        myWeekCard(row: myRow)
                    }
                    leagueSections
                }
            }
        }
    }

    /// Lignes classées : rang, XP et surlignage du joueur connecté.
    private var rows: [RankedLeaderboardRow] {
        rankedWeeklyRows(entries, currentId: DuelloAPI.publicProfileId(email: session.profile.email))
    }

    /// Carte « Ma semaine » : ligue atteinte et progression vers la suivante.
    private func myWeekCard(row: RankedLeaderboardRow) -> some View {
        let progress = weeklyXpLeagueProgress(for: row.score)
        return VStack(alignment: .leading, spacing: 10) {
            DuelloSectionHeader(title: "Ma semaine", subtitle: "Semaine du \(week)")
            HStack(spacing: 10) {
                DuelloPill(text: progress.league.label, tone: .ink, icon: "rosette")
                Spacer(minLength: 8)
                Text("\(groupedNumber(row.score)) XP")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            if let next = progress.nextLeague {
                DuelloProgressTrack(fraction: progress.fraction)
                Text("Encore \(groupedNumber(progress.xpToNext)) XP pour la ligue \(next.label)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text("Ligue \(progress.league.label) atteinte : la plus haute de la semaine.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .duelloCard()
    }

    /// Sections de ligue hebdo, de la plus haute à la plus basse.
    private var leagueSections: some View {
        let currentRows = rows
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(weeklyXpLeagues.reversed()) { league in
                let leagueRows = currentRows.filter { weeklyXpLeague(for: $0.score).id == league.id }
                if !leagueRows.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        weeklyLeagueHeader(league, count: leagueRows.count)
                        VStack(spacing: 0) {
                            ForEach(leagueRows.indices, id: \.self) { index in
                                LeaderboardRowView(row: leagueRows[index])
                                if index < leagueRows.count - 1 {
                                    LeaderboardRowDivider()
                                }
                            }
                        }
                    }
                    .duelloCard()
                }
            }
        }
    }

    /// En-tête d'une ligue hebdo : libellé, effectif et seuil d'accès en XP.
    private func weeklyLeagueHeader(_ league: WeeklyXpLeague, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                DuelloPill(text: league.label, tone: .ink, icon: "flame")
                Spacer(minLength: 8)
                Text(count == 1 ? "1 élève" : "\(count) élèves")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
            }
            if league.minimumXp > 0 {
                Text("À partir de \(groupedNumber(league.minimumXp)) XP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    /// Charge le classement XP de la semaine pour la session ouverte.
    private func load() {
        guard let token = session.token else {
            errorMessage = "Ta session a expiré, reconnecte-toi."
            phase = .error
            return
        }
        phase = .loading
        errorMessage = ""
        let subject = self.subject
        let week = self.week
        Task {
            do {
                let result = try await DuelloAPI.weeklyXpLeaderboard(
                    subject: subject,
                    week: week,
                    token: token
                )
                await MainActor.run {
                    entries = result
                    phase = .ready
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    errorMessage = message
                    phase = .error
                }
            }
        }
    }
}
