import Foundation
import SwiftUI

// MARK: - Classement d'une matière (ligues Elo)

/// Classement d'une matière par cotes Elo, groupé par ligue.
///
/// Reprend `RankingsScreen.tsx` : chargement depuis
/// `DuelloAPI.subjectLeaderboard` **avec la cohorte du profil**, états
/// chargement/erreur/vide, astuce de seuil Elo (démonstration animée),
/// **toutes** les ligues — y compris vides, avec le seuil révélé au tap sur le
/// blason —, lignes en **cartes espacées** (rang, avatar, nom, année, cote),
/// joueur connecté fusionné (compte privé masqué) et dock collant quand sa
/// ligne quitte l'écran.
///
/// Extrait de l'ancien `RankingsView.swift`. Dépend de `RankingLoadStateViews`
/// (`RankingLoadPhase`, `RankingStatusCard`), `RankingRowViews`
/// (`RankedLeaderboardRow`, `LeaderboardRowView`), `RankingEloLeagues`
/// (`EloLeague`, `eloLeagues(forTrack:)`, `eloLeague(for:track:)`),
/// `RankingRowBuilder` (`rankedSubjectRows`, `prepLeaderboardRows`,
/// `leaderboardEntriesForScope`, `groupedNumber`), `RankingEloCohort`
/// (`eloLeaderboardCohortForProfile`), `LeagueBadges` (`LeagueBadgeImage`) et
/// l'astuce de seuil (`RankingEloThresholdHint.swift`,
/// `EloLeagueThresholdHint`).
struct SubjectLeaderboardView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    /// Matière classée, transmise telle quelle à l'API (« Mathématiques »).
    let subject: String
    /// Portée du classement : « Moi » par défaut, la barre de portée restant
    /// masquée comme dans `LeaderboardScreen.tsx`.
    var scope: LeaderboardScope = .me
    /// Ouvre la fiche d'un joueur (`onOpenProfile`) ; `nil` laisse les lignes
    /// inertes, faute d'écran cible fourni par l'appelant.
    var onOpenProfile: ((String) -> Void)? = nil

    @State private var entries: [LeaderboardEntry] = []
    @State private var phase: RankingLoadPhase = .loading
    @State private var errorMessage = ""
    @State private var expandedLeagueId: String? = nil
    @State private var currentRowVisible = SwipeRowVisibility.defaultVisible

    /// Préférence persistée : l'astuce de seuil Elo est masquée définitivement
    /// quand le compte la ferme (`eloLeagueThresholdHintDismissed`).
    @AppStorage("com.duello.ios.ranking.eloLeagueThresholdHintDismissed")
    private var hintDismissed = false

    var body: some View {
        SwipeScreenFrameReader {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        hintCard
                        stateContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)

                if let current = dockEntry {
                    currentUserDock(current)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                }
            }
        }
        .onAppear { load() }
    }

    // MARK: Astuce de seuil Elo (C5)

    /// Encart de démonstration : la main appuie sur le blason, le seuil
    /// apparaît. Masquable définitivement (`EloLeagueThresholdHint`).
    @ViewBuilder
    private var hintCard: some View {
        if !hintDismissed, let league = highestEloLeague {
            EloLeagueThresholdHint(league: league) { hintDismissed = true }
        }
    }

    /// Ligue la plus haute de la filière (`highestEloLeague`), support de la
    /// démonstration.
    private var highestEloLeague: EloLeague? {
        eloLeagues(forTrack: session.profile.followedTrack).last
    }

    // MARK: Cohorte (subjectLeaderboard.ts)

    /// Option académique lisible du compte (`accountAcademicOptionLabel`),
    /// transmise à la cohorte comme `currentSpecialty` de la source.
    private var currentSpecialty: String {
        LoginScrProviderReuse.accountAcademicOptionLabel(
            track: session.profile.track,
            currentOption: session.profile.specialty,
            legacySpecialty: ""
        )
    }

    /// Cohorte Elo du profil (`eloLeaderboardCohortForProfile`) : filtre du
    /// serveur **et** rejeu côté client.
    private var eloCohort: String? {
        eloLeaderboardCohortForProfile(
            EloLeaderboardAcademicProfile(
                track: session.profile.track,
                year: session.profile.year,
                specialty: currentSpecialty,
                currentTrack: session.profile.academicPath?.currentTrack
            )
        )
    }

    // MARK: États (C10, C11, C12)

    /// Contenu selon l'état de chargement : attente, panne ou classement. Pas
    /// d'état vide global : une ligue vide porte son propre message.
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
                icon: "cloud-offline-outline",
                title: "Classement indisponible",
                message: errorMessage.isEmpty
                    ? "Le classement est momentanément indisponible."
                    : errorMessage,
                notice: "Ta cote locale de \(groupedNumber(localElo)) Elo reste affichée.",
                retry: { load() }
            )
        case .ready:
            leagueSections
        }
    }

    /// Cote locale de la matière (`getSubjectElo`), affichée quand le classement
    /// distant est indisponible et utilisée comme cote fraîche du joueur.
    private var localElo: Int {
        progress.subjectElo(for: subject)
    }

    // MARK: Ligues (C4)

    /// Toutes les ligues, de la plus haute à la plus basse (`eloLeagues`
    /// inversée comme `RankingsScreen.tsx`), vides comprises.
    private var leagueSections: some View {
        let leagues = eloLeagues(forTrack: session.profile.followedTrack)
        let currentRows = rows
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(leagues.reversed()) { league in
                let leagueRows = currentRows.filter {
                    eloLeague(for: $0.score, track: session.profile.followedTrack).id == league.id
                }
                leagueSection(league, rows: leagueRows)
            }
            if participantCount == 1 && scope == .preps {
                prepsOpeningCard
            }
        }
    }

    /// Une ligue : blason dépliable (seuil Elo) puis lignes en cartes, ou
    /// message de ligue vide (« Aucun joueur dans cette ligue[ pour le moment]. »).
    @ViewBuilder
    private func leagueSection(_ league: EloLeague, rows leagueRows: [RankedLeaderboardRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            leagueHeader(league)
            leagueRowsContent(league, leagueRows)
        }
    }

    /// En-tête d'une ligue : blason dépliable (tap) et seuil Elo révélé. La
    /// révélation est **instantanée**, comme la source (`RankingsScreen.tsx:548-573`).
    private func leagueHeader(_ league: EloLeague) -> some View {
        VStack(spacing: 5) {
            Button {
                expandedLeagueId = expandedLeagueId == league.id ? nil : league.id
            } label: {
                LeagueBadgeImage(leagueId: league.id, size: 88)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Afficher le seuil Elo de la ligue \(league.label)")

            if expandedLeagueId == league.id {
                Text("\(groupedNumber(league.minimumElo)) Elo")
                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
    }

    /// Corps d'une ligue : message de ligue vide, ou lignes en cartes espacées
    /// (`leaderboardList`, `LEADERBOARD_ROW_GAP`).
    @ViewBuilder
    private func leagueRowsContent(_ league: EloLeague, _ leagueRows: [RankedLeaderboardRow]) -> some View {
        if leagueRows.isEmpty {
            Text(league.id == "ecricome"
                 ? "Aucun joueur dans cette ligue."
                 : "Aucun joueur dans cette ligue pour le moment.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 14)
        } else {
            VStack(spacing: 8) {
                ForEach(leagueRows) { row in
                    if row.isCurrentUser {
                        LeaderboardRowView(row: row, kind: .elo, onOpenProfile: onOpenProfile)
                            .swipeCurrentRowVisibility($currentRowVisible)
                    } else {
                        LeaderboardRowView(row: row, kind: .elo, onOpenProfile: onOpenProfile)
                    }
                }
            }
        }
    }

    /// Carte « Ta prépa ouvre ce classement » (portée Prépas, premier
    /// établissement classé).
    private var prepsOpeningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            IonIcon(name: "sparkles-outline", size: 19, color: Theme.ink)
            Text("Ta prépa ouvre ce classement. Les prochains établissements apparaîtront avec leurs élèves classés.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    // MARK: Lignes et dock (C6, C8)

    /// Joueur connecté fusionné au classement (`currentUser`).
    private var currentUser: RankingCurrentUser {
        let name = session.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return RankingCurrentUser(
            id: DuelloAPI.publicProfileId(email: session.profile.email),
            displayName: name.isEmpty ? "Moi" : name,
            prepName: session.profile.prepName.trimmingCharacters(in: .whitespacesAndNewlines),
            track: session.profile.track,
            currentTrack: session.profile.academicPath?.currentTrack,
            specialty: currentSpecialty,
            year: session.profile.year,
            score: localElo,
            photoUri: session.profile.photoUri
        )
    }

    /// Lignes classées : rang, avatar, cote et fusion du joueur connecté. Un
    /// compte privé (`!isPublic`) n'est jamais relié à sa ligne anonyme.
    private var rows: [RankedLeaderboardRow] {
        switch scope {
        case .preps:
            return prepLeaderboardRows(
                entries,
                currentPrepName: session.profile.prepName,
                scoreFor: { max(0, $0.elo ?? 0) },
                aggregation: .average,
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
            var built = rankedSubjectRows(
                scoped,
                currentUser: currentUser,
                hideCurrentUserIdentity: !session.profile.isPublic,
                ensureAnonymousCurrentUser: scope == .classScope,
                currentUserScoreLoaded: true
            )
            if let index = built.firstIndex(where: { $0.isCurrentUser }) {
                built[index].photoUri = session.profile.photoUri
            }
            return built
        }
    }

    /// Nombre de participants classés (`participantCount`).
    private var participantCount: Int {
        rows.count
    }

    /// Ligne du joueur connecté (`currentEntry`).
    private var currentEntry: RankedLeaderboardRow? {
        rows.first { $0.isCurrentUser }
    }

    /// Dock affiché dès que la ligne du joueur connecté quitte l'écran
    /// (`showCurrentUserDock`).
    private var dockEntry: RankedLeaderboardRow? {
        guard SwipeRowVisibility.shouldShowCurrentUserDock(
            loadStateReady: phase == .ready,
            hasCurrentEntry: currentEntry != nil,
            isRowVisible: currentRowVisible
        ) else { return nil }
        return currentEntry
    }

    /// Barre collante « Moi · rang », ancrée en bas de l'écran
    /// (`currentUserDock` : bord primaire, fond primaire clair).
    private func currentUserDock(_ current: RankedLeaderboardRow) -> some View {
        HStack(spacing: 10) {
            if !current.isAnonymous {
                SocialAvatarPresence(online: SocPresenceStore.shared.isOnline(current.id)) {
                    LeaderboardAvatar(
                        initial: current.initial,
                        photoUri: current.photoUri,
                        size: 32,
                        background: Theme.primary,
                        foreground: Theme.surface
                    )
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Moi · \(leaderboardRankLabel(current.rank))")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.primary)
                Text(current.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(groupedNumber(current.score))
                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
                Text(current.valueLabel)
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
        .accessibilityLabel("Moi, \(leaderboardRankLabel(current.rank)), \(current.displayName), \(groupedNumber(current.score)) \(current.valueLabel)")
    }

    // MARK: Chargement

    /// Charge le classement de la matière pour la session ouverte, cohorte du
    /// profil comprise. La copie en cache (mémoire puis disque) rend la liste
    /// immédiatement ; la réponse réseau la remplace et l'instantané est
    /// réécrit (`saveRankingsSnapshot`).
    private func load() {
        phase = .loading
        errorMessage = ""
        let subject = self.subject
        let cohort = eloCohort
        let token = session.token
        Task {
            // Rendu immédiat : mémoire d'abord, puis disque, avant le réseau.
            if let cached = cachedSubjectLeaderboardSnapshotEntries(subject: subject, cohort: cohort) {
                await MainActor.run { entries = cached; phase = .ready }
            } else if let snapshot = await subjectLeaderboardSnapshotEntries(subject: subject, cohort: cohort) {
                await MainActor.run { entries = snapshot; phase = .ready }
            }
            do {
                let result = try await DuelloAPI.subjectLeaderboard(
                    subject: subject,
                    cohort: cohort,
                    token: token
                )
                // Le démarrage suivant affichera cette réponse sans le réseau.
                saveRankingsSnapshot(
                    .subjectLeaderboard,
                    key: rankingsSubjectLeaderboardCacheKey(subject: subject, cohort: cohort),
                    entries: result
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
