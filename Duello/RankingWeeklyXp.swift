import Foundation
import SwiftUI

// MARK: - Classement XP de la semaine

/// Classement des XP de la semaine pour une matière, en **liste à plat**.
///
/// Reprend `WeeklyXpRankingScreen.tsx` : chargement de `/weekly-xp`, semaine
/// calculée par `WeeklyXP.weekKey()`, états chargement/erreur (avec la notice
/// locale d'erreur, variante « Prépas »), top 3 mis en avant puis le reste,
/// lignes en **cartes espacées** et dock « Moi · rang » du joueur connecté.
///
/// Le RN ne rend **ni** groupement par ligues, **ni** carte « Ma semaine »,
/// **ni** état vide, **ni** en-tête de section ou de ligue : ces éléments
/// (portés par une version antérieure) ont été retirés.
///
/// Extrait de l'ancien `RankingsView.swift`. Dépend de `RankingLoadStateViews`
/// (`RankingLoadPhase`, `RankingStatusCard`), `RankingRowViews`
/// (`RankedLeaderboardRow`, `LeaderboardRowView`) et `RankingRowBuilder`
/// (`rankedWeeklyRows`, `prepLeaderboardRows`, `groupedNumber`,
/// `leaderboardRankLabel`).
struct WeeklyXpRankingView: View {
    @EnvironmentObject private var session: SessionStore

    /// Matière classée.
    let subject: String
    /// Lundi de la semaine classée, au format AAAA-MM-JJ.
    var week: String = WeeklyXP.weekKey()
    /// XP gagnés localement cette semaine dans cette matière (prop `weeklyXp`
    /// de `WeeklyXpRankingScreen.tsx`), pour la notice locale d'erreur.
    var weeklyXp: Int = 0
    /// Le total local a fini de charger et peut remplacer la ligne distante
    /// (`weeklyXpLoaded`). Faute de source locale d'XP de la semaine côté natif,
    /// l'appelant laisse `false` : la ligne distante du joueur reste intacte,
    /// comme la source avant la résolution de `loadActivity`.
    var weeklyXpLoaded: Bool = false
    /// Portée du classement : « Moi » par défaut.
    var scope: LeaderboardScope = .me
    /// Ouvre la fiche d'un joueur (`onOpenProfile`).
    var onOpenProfile: ((String) -> Void)? = nil

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
            RankingStatusCard(
                icon: "cloud-offline-outline",
                title: "Classement indisponible",
                message: errorMessage.isEmpty
                    ? "Le classement est momentanément indisponible."
                    : errorMessage,
                notice: localNotice,
                retry: { load() }
            )
        case .ready:
            VStack(alignment: .leading, spacing: 12) {
                if !leadingRows.isEmpty {
                    rowsList(leadingRows, featured: true)
                }
                if !remainingRows.isEmpty {
                    rowsList(remainingRows, featured: false)
                        .padding(.top, 12)
                }
            }
        }
    }

    /// Notice locale d'erreur (`localNotice`) : le total de la prépa en portée
    /// « Prépas », sinon les XP locaux de la semaine.
    private var localNotice: String {
        scope == .preps
            ? "Le total de ta prépa réapparaîtra dès que le classement sera disponible."
            : "Tes \(groupedNumber(weeklyXp)) XP de la semaine restent comptés."
    }

    /// Joueur connecté fusionné au classement (`currentUser`).
    private var currentUser: RankingCurrentUser {
        let name = session.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let specialty = session.profile.academicPath?.currentOption ?? session.profile.specialty
        return RankingCurrentUser(
            id: DuelloAPI.publicProfileId(email: session.profile.email),
            displayName: name.isEmpty ? "Moi" : name,
            prepName: session.profile.prepName.trimmingCharacters(in: .whitespacesAndNewlines),
            track: session.profile.track,
            currentTrack: session.profile.followedTrack,
            specialty: specialty.isEmpty ? nil : specialty,
            year: session.profile.year,
            score: weeklyXp,
            photoUri: session.profile.photoUri
        )
    }

    /// Lignes classées : rang, XP et fusion du joueur connecté.
    private var rows: [RankedLeaderboardRow] {
        switch scope {
        case .preps:
            return prepLeaderboardRows(
                entries,
                currentPrepName: session.profile.prepName,
                scoreFor: { max(0, Int(($0.xp ?? 0).rounded())) },
                aggregation: .sum,
                currentUser: currentUser
            )
        case .me, .classScope:
            let scoped = leaderboardEntriesForScope(
                entries,
                prepName: session.profile.prepName,
                track: session.profile.track,
                year: session.profile.year,
                scope: scope
            )
            var built = rankedWeeklyRows(
                scoped,
                currentUser: currentUser,
                currentTracks: currentTracks,
                hideCurrentUserIdentity: !session.profile.isPublic,
                currentUserScoreLoaded: weeklyXpLoaded
            )
            if let index = built.firstIndex(where: { $0.isCurrentUser }) {
                built[index].photoUri = session.profile.photoUri
            }
            return built
        }
    }

    /// Top 3 mis en avant, puis le reste de la liste (`slice(0, 3)` / `slice(3)`).
    private var leadingRows: [RankedLeaderboardRow] { Array(rows.prefix(3)) }
    private var remainingRows: [RankedLeaderboardRow] { Array(rows.dropFirst(3)) }

    /// Liste de lignes en cartes espacées (`leaderboardList`,
    /// `LEADERBOARD_ROW_GAP`) : chaque ligne est sa propre carte, sans filet.
    private func rowsList(_ rows: [RankedLeaderboardRow], featured: Bool) -> some View {
        VStack(spacing: 8) {
            ForEach(rows) { row in
                LeaderboardRowView(
                    row: row,
                    kind: .xp,
                    featured: featured,
                    showsPrivateIcon: true,
                    onOpenProfile: onOpenProfile
                )
            }
        }
    }

    /// Dock « Moi · rang » du joueur connecté (`WeeklyXpRankingScreen.tsx:367-390`).
    @ViewBuilder
    private var currentUserDock: some View {
        if phase == .ready, let row = rows.first(where: { $0.isCurrentUser }) {
            HStack(spacing: 10) {
                SocialAvatarPresence(online: SocPresenceStore.shared.isOnline(row.id)) {
                    LeaderboardAvatar(
                        initial: row.initial,
                        photoUri: row.photoUri,
                        size: 32,
                        background: Theme.primary,
                        foreground: Theme.surface
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
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
                .padding(.horizontal, 10)

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(groupedNumber(row.score))
                        .font(.system(size: 13, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                    Text("XP")
                        .font(.system(size: 7, weight: .heavy))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
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

    /// Charge le classement XP de la semaine pour la session ouverte. La copie
    /// en cache (mémoire puis disque) rend la liste immédiatement ; la réponse
    /// réseau la remplace et l'instantané est réécrit (`saveRankingsSnapshot`).
    private func load() {
        phase = .loading
        errorMessage = ""
        let subject = self.subject
        let week = self.week
        let token = session.token
        Task {
            // Rendu immédiat : mémoire d'abord, puis disque, avant le réseau.
            if let cached = cachedWeeklyXpLeaderboardSnapshotEntries(subject: subject, week: week) {
                await MainActor.run { entries = cached; phase = .ready }
            } else if let snapshot = await weeklyXpLeaderboardSnapshotEntries(subject: subject, week: week) {
                await MainActor.run { entries = snapshot; phase = .ready }
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
                let loaded = response.entries ?? []
                // Le démarrage suivant affichera cette réponse sans le réseau.
                saveRankingsSnapshot(
                    .weeklyXpLeaderboard,
                    key: rankingsWeeklyXpLeaderboardCacheKey(subject: subject, week: week),
                    entries: loaded
                )
                await MainActor.run {
                    entries = loaded
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
