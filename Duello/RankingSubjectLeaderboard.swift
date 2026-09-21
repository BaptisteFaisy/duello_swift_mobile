import Foundation
import SwiftUI

// MARK: - Classement d'une matière (ligues Elo)

/// Classement d'une matière par cotes Elo, groupé par ligue.
///
/// Reprend `RankingsScreen.tsx` : chargement depuis
/// `DuelloAPI.subjectLeaderboard`, états chargement/erreur/vide, lignes
/// (rang, avatar à initiale, nom, prépa, cote) et surlignage du joueur
/// connecté, identifié par `DuelloAPI.publicProfileId(email:)` comme côté Expo.
///
/// Extrait de l'ancien `RankingsView.swift`. Dépend de `RankingLoadStateViews`
/// (`RankingLoadPhase`, `RankingStatusCard`), `RankingRowViews`
/// (`RankedLeaderboardRow`, `LeaderboardRowView`, `LeaderboardRowDivider`),
/// `RankingEloLeagues` (`EloLeague`, `eloLeagues(forTrack:)`,
/// `eloLeague(for:track:)`) et `RankingRowBuilder` (`rankedSubjectRows`,
/// `groupedNumber`) : aucun nom ni signature n'a changé.
struct SubjectLeaderboardView: View {
    @EnvironmentObject private var session: SessionStore

    /// Matière classée, transmise telle quelle à l'API (« Mathématiques »).
    let subject: String

    @State private var entries: [LeaderboardEntry] = []
    @State private var phase: RankingLoadPhase = .loading
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(title: "Classement matière", subtitle: subject)
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
                message: "Les cotes Elo sont en cours de récupération.",
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
                    icon: "trophy",
                    title: "Aucun joueur classé",
                    message: "Personne n'est encore classé sur \(subject). Reviens après ton premier défi."
                )
            } else {
                leagueSections
            }
        }
    }

    /// Lignes classées : rang, cote et surlignage du joueur connecté.
    private var rows: [RankedLeaderboardRow] {
        rankedSubjectRows(entries, currentId: DuelloAPI.publicProfileId(email: session.profile.email))
    }

    /// Sections de ligue, de la plus haute à la plus basse (`eloLeagues`
    /// inversée comme dans `RankingsScreen.tsx`). Une ligue sans joueur n'est
    /// pas affichée, le seuil restant porté par l'en-tête des ligues peuplées.
    private var leagueSections: some View {
        let leagues = eloLeagues(forTrack: session.profile.track)
        let currentRows = rows
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(leagues.reversed()) { league in
                let leagueRows = currentRows.filter {
                    eloLeague(for: $0.score, track: session.profile.track).id == league.id
                }
                if !leagueRows.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        leagueHeader(league, count: leagueRows.count)
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

    /// En-tête d'une ligue : libellé, effectif et seuil d'accès en Elo.
    private func leagueHeader(_ league: EloLeague, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                DuelloPill(text: league.label, tone: .ink, icon: "rosette")
                Spacer(minLength: 8)
                Text(count == 1 ? "1 joueur" : "\(count) joueurs")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
            }
            if league.minimumElo > 0 {
                Text("À partir de \(groupedNumber(league.minimumElo)) Elo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    /// Charge le classement de la matière pour la session ouverte.
    private func load() {
        guard let token = session.token else {
            errorMessage = "Ta session a expiré, reconnecte-toi."
            phase = .error
            return
        }
        phase = .loading
        errorMessage = ""
        let subject = self.subject
        Task {
            do {
                let result = try await DuelloAPI.subjectLeaderboard(subject: subject, token: token)
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
