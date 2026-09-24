import Foundation
import SwiftUI

// MARK: - Classement XP de la semaine

/// Classement des XP de la semaine pour une matière, en **liste à plat**.
///
/// Reprend `WeeklyXpRankingScreen.tsx` : chargement de `/weekly-xp`, semaine
/// calculée par `WeeklyXP.weekKey()`, états chargement/erreur (avec la notice
/// locale d'erreur), top 3 mis en avant puis le reste, et dock « Moi · rang »
/// du joueur connecté.
///
/// Le RN ne rend **ni** groupement par ligues, **ni** carte « Ma semaine »,
/// **ni** état vide, **ni** en-tête de section ou de ligue : ces éléments
/// (portés par une version antérieure) ont été retirés.
///
/// Extrait de l'ancien `RankingsView.swift`. Dépend de `RankingLoadStateViews`
/// (`RankingLoadPhase`, `RankingStatusCard`), `RankingRowViews`
/// (`RankedLeaderboardRow`, `LeaderboardRowView`, `LeaderboardRowDivider`) et
/// `RankingRowBuilder` (`rankedWeeklyRows`, `weeklyXpCurrentTracks`,
/// `groupedNumber`, `leaderboardRankLabel`).
struct WeeklyXpRankingView: View {
    @EnvironmentObject private var session: SessionStore

    /// Matière classée.
    let subject: String
    /// Lundi de la semaine classée, au format AAAA-MM-JJ.
    var week: String = WeeklyXP.weekKey()
    /// XP gagnés localement cette semaine dans cette matière (prop `weeklyXp`
    /// de `WeeklyXpRankingScreen.tsx`), pour la notice locale d'erreur.
    var weeklyXp: Int = 0

    @State private var entries: [LeaderboardEntry] = []
    @State private var currentTracks: [String: String] = [:]
    @State private var phase: RankingLoadPhase = .loading
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            stateContent
        }
        .overlay(alignment: .bottom) { currentUserDock }
        .onAppear { load() }
    }

    /// Contenu selon l'état de chargement : attente, panne ou classement.
    ///
    /// Aucun état vide global : le RN n'affiche rien quand la liste est vide.
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
            VStack(alignment: .leading, spacing: 8) {
                RankingStatusCard(
                    icon: "cloud.offline",
                    title: "Classement indisponible",
                    message: errorMessage.isEmpty
                        ? "Le classement est momentanément indisponible."
                        : errorMessage,
                    retry: { load() }
                )
                // Notice locale d'erreur (`WeeklyXpRankingScreen.tsx:334-337`).
                Text("Tes \(groupedNumber(localWeeklyXp)) XP de la semaine restent comptés.")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .ready:
            VStack(alignment: .leading, spacing: 12) {
                if !leadingRows.isEmpty {
                    rowsCard(leadingRows, featured: true)
                }
                if !remainingRows.isEmpty {
                    rowsCard(remainingRows, featured: false)
                }
            }
        }
    }

    /// Lignes classées : rang, XP et surlignage du joueur connecté.
    private var rows: [RankedLeaderboardRow] {
        rankedWeeklyRows(
            entries,
            currentId: DuelloAPI.publicProfileId(email: session.profile.email),
            currentTracks: currentTracks
        )
    }

    /// Top 3 mis en avant, puis le reste de la liste (`slice(0, 3)` / `slice(3)`).
    private var leadingRows: [RankedLeaderboardRow] { Array(rows.prefix(3)) }
    private var remainingRows: [RankedLeaderboardRow] { Array(rows.dropFirst(3)) }

    /// XP de la semaine du joueur connecté, pour la notice locale d'erreur :
    /// le total local quand il est fourni, sinon la ligne déjà chargée.
    private var localWeeklyXp: Int {
        weeklyXp > 0 ? weeklyXp : (rows.first(where: { $0.isCurrentUser })?.score ?? 0)
    }

    /// Carte d'un groupe de lignes, séparées par un filet fin.
    private func rowsCard(_ rows: [RankedLeaderboardRow], featured: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                LeaderboardRowView(
                    row: rows[index],
                    featured: featured,
                    showsPrivateIcon: true
                )
                if index < rows.count - 1 {
                    LeaderboardRowDivider()
                }
            }
        }
        .duelloCard()
    }

    /// Dock « Moi · rang » du joueur connecté (`WeeklyXpRankingScreen.tsx:367-390`).
    @ViewBuilder
    private var currentUserDock: some View {
        if phase == .ready, let row = rows.first(where: { $0.isCurrentUser }) {
            HStack(spacing: 10) {
                DuelloAvatar(
                    initial: row.initial,
                    size: 32,
                    background: Theme.ink,
                    foreground: Theme.surface
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Moi · \(leaderboardRankLabel(row.rank))")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                    Text(row.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if !row.meta.isEmpty {
                        Text(row.meta)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(groupedNumber(row.score))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("XP")
                        .font(.system(size: 8, weight: .heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.primary, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Moi, \(leaderboardRankLabel(row.rank)), \(groupedNumber(row.score)) XP"
            )
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
            // Rendu immédiat depuis l'instantané persisté, avant le réseau.
            if let snapshot = await loadRankingsSnapshots()?.first(where: {
                $0.cache == .weeklyXpLeaderboard
                    && $0.key == rankingsWeeklyXpLeaderboardCacheKey(subject: subject, week: week)
            }) {
                await MainActor.run { entries = snapshot.entries; phase = .ready }
            }
            do {
                let data = try await DuelloAPI.request(
                    "weekly-xp",
                    token: token,
                    query: [
                        URLQueryItem(name: "subject", value: subject),
                        URLQueryItem(name: "week", value: week),
                    ]
                )
                let response = try DuelloAPI.decoder.decode(
                    DuelloAPI.LeaderboardResponse.self,
                    from: data
                )
                let tracks = weeklyXpCurrentTracks(from: data)
                await MainActor.run {
                    entries = response.entries ?? []
                    currentTracks = tracks
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
