import Foundation
import SwiftUI

// MARK: - Classement d'une matière (ligues Elo)

/// Classement d'une matière par cotes Elo, groupé par ligue.
///
/// Reprend `RankingsScreen.tsx` : chargement depuis
/// `DuelloAPI.subjectLeaderboard`, états chargement/erreur/vide, astuce de seuil
/// Elo (démonstration animée), **toutes** les ligues — y compris vides, avec le
/// seuil révélé au tap sur le blason —, lignes (rang, avatar, nom, année, cote)
/// et dock collant du joueur connecté quand sa ligne quitte l'écran.
///
/// Extrait de l'ancien `RankingsView.swift`. Dépend de `RankingLoadStateViews`
/// (`RankingLoadPhase`, `RankingStatusCard`), `RankingRowViews`
/// (`RankedLeaderboardRow`, `LeaderboardRowView`, `LeaderboardRowDivider`),
/// `RankingEloLeagues` (`EloLeague`, `eloLeagues(forTrack:)`,
/// `eloLeague(for:track:)`), `RankingRowBuilder` (`rankedSubjectRows`,
/// `prepLeaderboardRows`, `leaderboardEntriesForScope`, `groupedNumber`),
/// `LeagueBadges` (`LeagueBadgeImage`) et le suivi de visibilité partagé
/// (`SwipeScreenFrameReader`, `swipeCurrentRowVisibility`).
struct SubjectLeaderboardView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    /// Matière classée, transmise telle quelle à l'API (« Mathématiques »).
    let subject: String
    /// Portée du classement : « Moi » par défaut, la barre de portée restant
    /// masquée comme dans `LeaderboardScreen.tsx`.
    var scope: LeaderboardScope = .me

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
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)

                if let current = dockEntry {
                    currentUserDock(current)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
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
        eloLeagues(forTrack: session.profile.track).last
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
                icon: "cloud.offline",
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
    /// distant est indisponible.
    private var localElo: Int {
        progress.subjectElo(for: subject)
    }

    // MARK: Ligues (C4)

    /// Toutes les ligues, de la plus haute à la plus basse (`eloLeagues`
    /// inversée comme `RankingsScreen.tsx`), vides comprises.
    private var leagueSections: some View {
        let leagues = eloLeagues(forTrack: session.profile.track)
        let currentRows = rows
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(leagues.reversed()) { league in
                let leagueRows = currentRows.filter {
                    eloLeague(for: $0.score, track: session.profile.track).id == league.id
                }
                leagueSection(league, rows: leagueRows)
            }
            if participantCount == 1 && scope == .preps {
                prepsOpeningCard
            }
        }
    }

    /// Une ligue : blason dépliable (seuil Elo) puis lignes, ou message de ligue
    /// vide (« Aucun joueur dans cette ligue[ pour le moment]. »).
    @ViewBuilder
    private func leagueSection(_ league: EloLeague, rows leagueRows: [RankedLeaderboardRow]) -> some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            leagueHeader(league)
            leagueRowsContent(league, leagueRows)
        }

        if leagueRows.isEmpty {
            content
        } else {
            content.duelloCard()
        }
    }

    /// En-tête d'une ligue : blason dépliable (tap) et seuil Elo révélé.
    private func leagueHeader(_ league: EloLeague) -> some View {
        VStack(spacing: 5) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedLeagueId = expandedLeagueId == league.id ? nil : league.id
                }
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
    }

    /// Corps d'une ligue : message de ligue vide, ou lignes classées.
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
            VStack(spacing: 0) {
                ForEach(leagueRows.indices, id: \.self) { index in
                    if leagueRows[index].isCurrentUser {
                        LeaderboardRowView(row: leagueRows[index])
                            .swipeCurrentRowVisibility($currentRowVisible)
                    } else {
                        LeaderboardRowView(row: leagueRows[index])
                    }
                    if index < leagueRows.count - 1 {
                        LeaderboardRowDivider()
                    }
                }
            }
        }
    }

    /// Carte « Ta prépa ouvre ce classement » (portée Prépas, premier
    /// établissement classé).
    private var prepsOpeningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Ta prépa ouvre ce classement. Les prochains établissements apparaîtront avec leurs élèves classés.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    // MARK: Lignes et dock (C6, C8)

    /// Lignes classées : rang, avatar, cote et surlignage du joueur connecté.
    private var rows: [RankedLeaderboardRow] {
        let currentId = DuelloAPI.publicProfileId(email: session.profile.email)
        switch scope {
        case .preps:
            return prepLeaderboardRows(
                entries,
                currentPrepName: session.profile.prepName,
                scoreFor: { max(0, $0.elo ?? 0) },
                aggregation: .average
            )
        case .me, .classScope:
            let scoped = leaderboardEntriesForScope(
                entries,
                prepName: session.profile.prepName,
                track: session.profile.track,
                year: session.profile.year,
                scope: scope
            )
            var built = rankedSubjectRows(scoped, currentId: currentId)
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

    /// Barre collante « Moi · rang », ancrée en bas de l'écran.
    private func currentUserDock(_ current: RankedLeaderboardRow) -> some View {
        HStack(spacing: 10) {
            if !current.isAnonymous {
                SocialAvatarPresence(online: SocPresenceStore.shared.isOnline(current.id)) {
                    LeaderboardAvatar(
                        initial: current.initial,
                        photoUri: current.photoUri,
                        size: 32,
                        background: Theme.ink,
                        foreground: Theme.surface
                    )
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Moi · \(leaderboardRankLabel(current.rank))")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(current.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(groupedNumber(current.score))
                    .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
                Text(current.valueLabel)
                    .font(.system(size: 9, weight: .heavy))
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
                .stroke(Theme.ink, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Moi, \(leaderboardRankLabel(current.rank)), \(current.displayName), \(groupedNumber(current.score)) \(current.valueLabel)")
    }

    // MARK: Chargement

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
            // Rendu immédiat depuis l'instantané persisté, avant le réseau.
            if let snapshot = await subjectLeaderboardSnapshotEntries(subject: subject) {
                await MainActor.run { entries = snapshot; phase = .ready }
            }
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

// MARK: - Astuce de seuil Elo (EloLeagueThresholdHint)

/// Segment d'animation : plage `[start, start + duration)` et courbe.
private struct EloHintSegment {
    let start: Double
    let duration: Double
    let from: Double
    let to: Double
    let ease: (Double) -> Double
}

/// `Easing.out(Easing.quad)`.
private func eloHintQuadOut(_ t: Double) -> Double {
    let x = LeagueAnimation.clamp01(t)
    return 1 - (1 - x) * (1 - x)
}

/// Durée d'un tour de boucle, en secondes (`Animated.loop` de la source).
private let eloHintLoopDuration: Double = 4.76

/// `demoHandPosition` : approche de la main vers le blason, puis retrait.
private let eloHintHandPositionSegments: [EloHintSegment] = [
    EloHintSegment(start: 0.45, duration: 0.52, from: 0, to: 1, ease: LeagueAnimation.cubicOut),
    EloHintSegment(start: 1.77, duration: 0.36, from: 1, to: 0, ease: LeagueAnimation.cubicInOut),
    EloHintSegment(start: 2.78, duration: 0.52, from: 0, to: 1, ease: LeagueAnimation.cubicOut),
    EloHintSegment(start: 3.95, duration: 0.36, from: 1, to: 0, ease: LeagueAnimation.cubicInOut),
]

/// `demoHandPress` : appui de la main (échelle).
private let eloHintHandPressSegments: [EloHintSegment] = [
    EloHintSegment(start: 0.97, duration: 0.13, from: 0, to: 1, ease: LeagueAnimation.quadIn),
    EloHintSegment(start: 1.10, duration: 0.22, from: 1, to: 0, ease: LeagueAnimation.quadIn),
    EloHintSegment(start: 3.30, duration: 0.13, from: 0, to: 1, ease: LeagueAnimation.quadIn),
    EloHintSegment(start: 3.43, duration: 0.22, from: 1, to: 0, ease: LeagueAnimation.quadIn),
]

/// `demoThresholdOpacity` : apparition puis disparition du seuil affiché.
private let eloHintThresholdSegments: [EloHintSegment] = [
    EloHintSegment(start: 1.10, duration: 0.18, from: 0, to: 1, ease: eloHintQuadOut),
    EloHintSegment(start: 3.43, duration: 0.18, from: 1, to: 0, ease: eloHintQuadOut),
]

/// Échantillonne une suite de segments à l'instant `time`, en boucle.
private func eloHintSample(_ time: Double, _ segments: [EloHintSegment]) -> Double {
    guard let first = segments.first else { return 0 }
    let looped = max(0, time).truncatingRemainder(dividingBy: eloHintLoopDuration)
    var value = first.from
    for segment in segments {
        if looped < segment.start { return value }
        if looped < segment.start + segment.duration {
            let local = (looped - segment.start) / segment.duration
            return segment.from + (segment.to - segment.from) * segment.ease(local)
        }
        value = segment.to
    }
    return value
}

/// Astuce de seuil Elo (`EloLeagueThresholdHint`) : une main approche du
/// blason, l'appuie, et le seuil Elo apparaît puis disparaît, en boucle.
///
/// La boucle `Animated.loop` de la source est transposée par
/// `TimelineView(.animation)` : la position de la main, l'appui et l'opacité du
/// seuil sont échantillonnés à chaque image depuis une table de segments
/// (durées identiques à la séquence de `RankingsScreen.tsx:82-158`).
struct EloLeagueThresholdHint: View {
    /// Ligue dont on montre le seuil (`highestEloLeague`).
    let league: EloLeague
    /// Fermeture persistée de l'astuce.
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                VStack(spacing: 0) {
                    demo(time: time)
                    thresholdValue(time: time)
                }
            }
            closeButton
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Appuie sur un blason pour afficher ou masquer l’Elo minimum de sa ligue. Exemple : \(league.label), \(groupedNumber(league.minimumElo)) Elo.")
    }

    /// Blason et main animée (`eloThresholdHintInteraction`).
    private func demo(time: Double) -> some View {
        let position = eloHintSample(time, eloHintHandPositionSegments)
        let press = eloHintSample(time, eloHintHandPressSegments)
        return ZStack {
            LeagueBadgeImage(leagueId: league.id, size: 68)
            Image(systemName: "hand.point.left.fill")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .opacity(LeagueAnimation.interpolate(position, [0, 0.18, 1], [0.35, 1, 1], clamped: true))
                .scaleEffect(1 - 0.14 * press)
                .offset(x: -67 + 39 * position, y: 2)
        }
        .frame(width: 68, height: 68)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 90)
    }

    /// Seuil Elo révélé (`eloThresholdHintValue`).
    private func thresholdValue(time: Double) -> some View {
        let opacity = eloHintSample(time, eloHintThresholdSegments)
        return Text("\(groupedNumber(league.minimumElo)) Elo")
            .font(.system(size: 11, weight: .heavy).monospacedDigit())
            .foregroundStyle(Theme.ink)
            .opacity(opacity)
            .offset(y: LeagueAnimation.interpolate(opacity, [0, 1], [-3, 0], clamped: true))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 18)
    }

    /// Fermeture définitive (`eloThresholdHintClose`).
    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .padding(.top, 5)
        .padding(.trailing, 6)
        .accessibilityLabel("Masquer définitivement l’explication des seuils Elo")
    }
}
