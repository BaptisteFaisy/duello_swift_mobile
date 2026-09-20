import Foundation
import SwiftUI

/// Écran de classements Duello : ligues Elo d'une matière et XP de la semaine.
///
/// Portage SwiftUI de `src/screens/LeaderboardScreen.tsx`,
/// `src/screens/RankingsScreen.tsx` et `src/screens/WeeklyXpRankingScreen.tsx`
/// (ainsi que de la fenêtre `src/components/LeaderboardModal.tsx`). Les
/// libellés, les seuils de ligue et la mise en avant du joueur connecté
/// reprennent les mêmes règles que l'application Expo : `utils/subjectElo.ts`,
/// `utils/subjectLeaderboard.ts` et `utils/weeklyXpLeaderboard.ts`.
///
/// Le kit partagé (`DuelloUI.swift`) fournit les cartes, pastilles, avatars et
/// barres de progression ; ce fichier n'ajoute que la logique de classement et
/// ses lignes. Les données viennent de `DuelloAPI` (voir `socialApi.ts`) avec
/// la session ouverte dans l'environnement.
///
/// Matière classée : « Mathématiques », seule matière ouverte aux défis, comme
/// `MATH_SUBJECT` côté Expo.

// MARK: - Écran à onglets

/// Écran à onglets « Matière » / « XP hebdo », équivalent de
/// `LeaderboardScreen.tsx` : les deux classements d'une même matière dans une
/// seule vue, sans barre de portée (le classement reste sur « Moi »).
struct RankingsView: View {
    /// Onglets de l'écran, dans l'ordre de `SECTIONS` de `LeaderboardScreen.tsx`.
    enum RankingsTab: String, CaseIterable, Identifiable {
        case subject
        case weeklyXp

        var id: String { rawValue }

        /// Libellé affiché dans la barre d'onglets.
        var label: String {
            switch self {
            case .subject: return "Matière"
            case .weeklyXp: return "XP hebdo"
            }
        }
    }

    /// Matière classée (« Mathématiques »).
    var subject: String = "Mathématiques"

    @State private var selectedTab: RankingsTab

    /// - Parameters:
    ///   - initialTab: onglet ouvert au premier affichage.
    ///   - subject: matière classée.
    init(initialTab: RankingsTab = .subject, subject: String = "Mathématiques") {
        self.subject = subject
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .subject:
                        SubjectLeaderboardView(subject: subject)
                    case .weeklyXp:
                        WeeklyXpRankingView(subject: subject)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
        .background(Theme.background)
    }

    /// Deux puces d'onglet : la sélection reprend le motif encre sur clair du kit.
    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(RankingsTab.allCases) { tab in
                DuelloChip(title: tab.label, selected: selectedTab == tab) {
                    selectedTab = tab
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Classement d'une matière (ligues Elo)

/// Classement d'une matière par cotes Elo, groupé par ligue.
///
/// Reprend `RankingsScreen.tsx` : chargement depuis
/// `DuelloAPI.subjectLeaderboard`, états chargement/erreur/vide, lignes
/// (rang, avatar à initiale, nom, prépa, cote) et surlignage du joueur
/// connecté, identifié par `DuelloAPI.publicProfileId(email:)` comme côté Expo.
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

// MARK: - Classement XP de la semaine

/// Classement des XP de la semaine pour une matière, groupé par ligue.
///
/// Reprend `WeeklyXpRankingScreen.tsx` : chargement depuis
/// `DuelloAPI.weeklyXpLeaderboard`, semaine calculée par `WeeklyXP.weekKey()`,
/// états chargement/erreur/vide, et carte « Ma semaine » déduite du rang du
/// joueur connecté (ligue atteinte et progression, `weeklyXpLeagueProgress`).
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

// MARK: - Feuille de classement

/// Version feuille du classement, présentée par les écrans qui affichent un
/// classement (coupes Maths et Défis). Portage de
/// `src/components/LeaderboardModal.tsx` : contenu plein écran, en-tête de
/// fermeture et classements identiques à `RankingsView`.
struct LeaderboardModalView: View {
    @Environment(\.dismiss) private var dismiss

    /// Onglet ouvert à l'ouverture de la feuille.
    var initialTab: RankingsView.RankingsTab = .subject
    /// Matière classée.
    var subject: String = "Mathématiques"

    /// - Parameters:
    ///   - initialTab: onglet ouvert à l'ouverture de la feuille.
    ///   - subject: matière classée.
    init(initialTab: RankingsView.RankingsTab = .subject, subject: String = "Mathématiques") {
        self.initialTab = initialTab
        self.subject = subject
    }

    var body: some View {
        NavigationStack {
            RankingsView(initialTab: initialTab, subject: subject)
                .navigationTitle("Classements")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - État de chargement

/// Étapes du chargement d'un classement (voir `LoadState` de
/// `RankingsScreen.tsx`). Nommée pour ne pas entrer en conflit avec le
/// `LoadState` partagé de `ChallengesView.swift`.
private enum RankingLoadPhase {
    case loading
    case ready
    case error
}

// MARK: - Carte d'état

/// Carte d'état d'un classement : attente, panne et bouton de réessai.
private struct RankingStatusCard: View {
    let icon: String
    let title: String
    var message: String? = nil
    var showsProgress: Bool = false
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surfaceMuted)
                    .frame(width: 34, height: 34)
                if showsProgress {
                    ProgressView().tint(Theme.ink)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let message {
                    Text(message)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let retry {
                Button(action: retry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Réessayer de charger le classement")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }
}

// MARK: - Lignes de classement

/// Ligne prête à afficher, calculée après fusion et tri côté client.
private struct RankedLeaderboardRow: Identifiable {
    let id: String
    let rank: Int
    let displayName: String
    let initial: String
    let meta: String
    let score: Int
    let valueLabel: String
    let isCurrentUser: Bool
    let isAnonymous: Bool

    /// Libellé d'accessibilité : rang, nom, contexte puis valeur.
    var accessibilityLabel: String {
        let rankText = leaderboardRankLabel(rank)
        let valueText = "\(groupedNumber(score)) \(valueLabel)"
        return [rankText, displayName, meta, valueText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// Ligne de classement : rang, avatar à initiale, nom, contexte et valeur.
private struct LeaderboardRowView: View {
    let row: RankedLeaderboardRow

    var body: some View {
        HStack(spacing: 10) {
            Text("\(row.rank)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(row.rank <= 3 ? Theme.ink : Theme.inkFaint)
                .frame(width: 26, alignment: .center)

            DuelloAvatar(
                initial: row.isAnonymous ? "" : row.initial,
                size: 32,
                background: row.isCurrentUser ? Theme.ink : Theme.primaryLight,
                foreground: row.isCurrentUser ? Theme.surface : Theme.inkSoft
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if row.isCurrentUser {
                        DuelloPill(text: "Moi", tone: .ink)
                    }
                }
                if !row.meta.isEmpty {
                    Text(row.meta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(groupedNumber(row.score))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(row.valueLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(row.isCurrentUser ? Theme.primaryLight : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

/// Séparateur fin entre deux lignes, à la couleur de bordure du thème.
private struct LeaderboardRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}

// MARK: - Ligues Elo (subjectElo.ts)

/// Ligues Elo d'une filière : identifiant, libellé et seuil d'accès.
private struct EloLeague: Identifiable, Hashable {
    let id: String
    let label: String
    let minimumElo: Int
}

/// Ligues de commerce de Duello Dev (`ELO_LEAGUES`), du plus bas au plus haut.
private let ecricomeEloLeagues: [EloLeague] = [
    EloLeague(id: "ecricome", label: "ECRICOME", minimumElo: 0),
    EloLeague(id: "emlyon", label: "EMLYON", minimumElo: 1000),
    EloLeague(id: "edhec", label: "EDHEC", minimumElo: 1200),
    EloLeague(id: "escp", label: "ESCP", minimumElo: 1400),
    EloLeague(id: "essec", label: "ESSEC", minimumElo: 1600),
    EloLeague(id: "hec", label: "HEC", minimumElo: 1800),
]

/// Ligues des filières scientifiques (`ENGINEERING_ELO_LEAGUES`).
private let engineeringEloLeagues: [EloLeague] = [
    EloLeague(id: "ensae-paris", label: "ENSAE Paris", minimumElo: 0),
    EloLeague(id: "telecom-paris", label: "Télécom Paris", minimumElo: 1000),
    EloLeague(id: "ponts-paristech", label: "Ponts ParisTech", minimumElo: 1200),
    EloLeague(id: "mines-paris-psl", label: "Mines Paris – PSL", minimumElo: 1400),
    EloLeague(id: "centralesupelec", label: "CentraleSupélec", minimumElo: 1600),
    EloLeague(id: "ens-ulm", label: "ENS Ulm", minimumElo: 1700),
    EloLeague(id: "x", label: "École polytechnique", minimumElo: 1800),
]

/// Ligues propres à B/L (`BL_ELO_LEAGUES`).
private let blEloLeagues: [EloLeague] = [
    EloLeague(id: "ensae-paris", label: "ENSAE", minimumElo: 0),
    EloLeague(id: "ens-paris-saclay", label: "ENS Paris-Saclay", minimumElo: 1000),
    EloLeague(id: "essec", label: "ESSEC", minimumElo: 1200),
    EloLeague(id: "ens-lyon", label: "ENS de Lyon", minimumElo: 1400),
    EloLeague(id: "hec", label: "HEC Paris", minimumElo: 1600),
    EloLeague(id: "ens-ulm", label: "ENS Ulm", minimumElo: 1800),
]

/// Ligues propres à BCPST (`BCPST_ELO_LEAGUES`).
private let bcpstEloLeagues: [EloLeague] = [
    EloLeague(id: "vetagro-sup", label: "VetAgro Sup", minimumElo: 0),
    EloLeague(id: "institut-agro", label: "Institut Agro", minimumElo: 1000),
    EloLeague(id: "enva", label: "ENVA", minimumElo: 1200),
    EloLeague(id: "agroparistech-bcpst", label: "AgroParisTech", minimumElo: 1400),
    EloLeague(id: "ens-ulm", label: "ENS Ulm", minimumElo: 1600),
    EloLeague(id: "x", label: "École polytechnique", minimumElo: 1800),
]

/// Filière réduite à ses lettres et chiffres, en capitales, pour comparer
/// « B/L » et « BL » sans dépendre de la casse ou de la ponctuation.
private func compactAcademicTrack(_ track: String?) -> String {
    let normalized = (track ?? "").uppercased()
    return String(normalized.filter { $0.isLetter || $0.isNumber })
}

/// Série de ligues correspondant à la famille académique du compte
/// (`eloLeaguesForTrack`) : B/L, BCPST, commerce (ECG ou vide) puis sciences.
private func eloLeagues(forTrack track: String?) -> [EloLeague] {
    let compact = compactAcademicTrack(track)
    if compact.hasPrefix("BL") { return blEloLeagues }
    if compact.hasPrefix("BCPST") { return bcpstEloLeagues }
    let keepsCommerce = compact.isEmpty || compact.hasPrefix("ECG")
    return keepsCommerce ? ecricomeEloLeagues : engineeringEloLeagues
}

/// Ligue atteinte pour une cote et une filière (`eloLeagueFor`) : la plus haute
/// dont le seuil est franchi, la plus basse à défaut.
private func eloLeague(for elo: Int, track: String?) -> EloLeague {
    let rounded = max(0, elo)
    let leagues = eloLeagues(forTrack: track)
    return leagues.reversed().first { rounded >= $0.minimumElo } ?? leagues[0]
}

// MARK: - Ligues XP hebdo (weeklyXpLeaderboard.ts)

/// Ligue hebdo : identifiant, libellé et seuil d'accès en XP.
private struct WeeklyXpLeague: Identifiable, Hashable {
    let id: String
    let label: String
    let minimumXp: Int
}

/// Ligues de la semaine (`WEEKLY_XP_LEAGUES`), du plus bas au plus haut.
private let weeklyXpLeagues: [WeeklyXpLeague] = [
    WeeklyXpLeague(id: "ecricome", label: "ECRICOME", minimumXp: 0),
    WeeklyXpLeague(id: "emlyon", label: "emlyon", minimumXp: 100),
    WeeklyXpLeague(id: "edhec", label: "EDHEC", minimumXp: 250),
    WeeklyXpLeague(id: "escp", label: "ESCP", minimumXp: 500),
    WeeklyXpLeague(id: "essec", label: "ESSEC", minimumXp: 900),
    WeeklyXpLeague(id: "hec", label: "HEC", minimumXp: 1500),
]

/// Ligue atteinte avec les XP de la semaine courante (`weeklyXpLeagueFor`).
private func weeklyXpLeague(for xp: Int) -> WeeklyXpLeague {
    let total = max(0, xp)
    return weeklyXpLeagues.reversed().first { total >= $0.minimumXp } ?? weeklyXpLeagues[0]
}

/// Progression bornée dans la ligue hebdo courante, jusqu'au seuil suivant.
private struct WeeklyXpLeagueProgress {
    let league: WeeklyXpLeague
    let nextLeague: WeeklyXpLeague?
    let xpToNext: Int
    let fraction: Double
}

/// Progression d'un total d'XP vers la ligue suivante
/// (`weeklyXpLeagueProgress`) : fraction 1 une fois la plus haute atteinte.
private func weeklyXpLeagueProgress(for xp: Int) -> WeeklyXpLeagueProgress {
    let total = max(0, xp)
    let league = weeklyXpLeague(for: total)
    guard let index = weeklyXpLeagues.firstIndex(where: { $0.id == league.id }),
          index + 1 < weeklyXpLeagues.count
    else {
        return WeeklyXpLeagueProgress(league: league, nextLeague: nil, xpToNext: 0, fraction: 1)
    }

    let next = weeklyXpLeagues[index + 1]
    let span = next.minimumXp - league.minimumXp
    let earned = min(span, max(0, total - league.minimumXp))
    return WeeklyXpLeagueProgress(
        league: league,
        nextLeague: next,
        xpToNext: max(0, next.minimumXp - total),
        fraction: span > 0 ? Double(earned) / Double(span) : 1
    )
}

// MARK: - Fusion et tri des lignes

/// Comptes d'équipe tenus hors classement (`LEADERBOARD_EXCLUDED_IDS`).
private let excludedLeaderboardIds: Set<String> = ["member-e21172e2", "member-766117b4"]

/// Libellé d'option ECG repris de `accountAcademicOptionLabel` : les anciennes
/// spécialités « maths appliquées/approfondies » gardent leur nom lisible.
private func academicOptionLabel(track: String, specialty: String) -> String {
    let option = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !option.isEmpty, track == "ECG" else { return option }
    let normalized = option.lowercased()
    if normalized.contains("appliqu") { return "Maths appliquées" }
    if normalized.contains("approfond") { return "Maths approfondies" }
    return option
}

/// Filière, année et, en ECG, option d'une ligne publique
/// (`formatWeeklyXpAcademicLabel`). Vide quand filière ou année manque.
private func weeklyAcademicLabel(track: String?, specialty: String?, year: String?) -> String {
    let trackValue = (track ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let yearValue = (year ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trackValue.isEmpty, !yearValue.isEmpty else { return "" }

    var parts = [trackValue, yearValue]
    let option = academicOptionLabel(track: trackValue, specialty: specialty ?? "")
    if trackValue == "ECG", !option.isEmpty {
        parts.append(option)
    }
    return parts.joined(separator: " · ")
}

/// Nombre groupé par milliers avec une espace, comme `formatElo`/`formatXp`
/// d'Expo (séparateur stable, indépendant de la locale du système).
private func groupedNumber(_ value: Int) -> String {
    let digits = String(abs(value))
    var grouped = ""
    for (index, character) in digits.reversed().enumerated() {
        if index > 0 && index % 3 == 0 { grouped.append(" ") }
        grouped.append(character)
    }
    return (value < 0 ? "-" : "") + String(grouped.reversed())
}

/// Rang français compact : « 1er », puis « 2e », « 3e »… (`formatLeaderboardRank`).
private func leaderboardRankLabel(_ rank: Int) -> String {
    rank == 1 ? "1er" : "\(rank)e"
}

/// Prépare les lignes du classement Elo : filtre les comptes exclus, écarte les
/// identifiants vides, trie par cote décroissante puis par nom, et marque le
/// joueur connecté (`buildSubjectLeaderboard`).
private func rankedSubjectRows(_ entries: [LeaderboardEntry], currentId: String) -> [RankedLeaderboardRow] {
    let sorted = entries
        .filter { !$0.id.isEmpty && !excludedLeaderboardIds.contains($0.id) }
        .map { entry in (entry: entry, score: max(0, entry.elo ?? 0)) }
        .sorted { first, second in
            if first.score != second.score { return first.score > second.score }
            return first.entry.displayName.localizedCaseInsensitiveCompare(second.entry.displayName) == .orderedAscending
        }

    return sorted.enumerated().map { index, item in
        let anonymous = item.entry.isAnonymous == true
        let name = anonymous
            ? "Anonyme"
            : (item.entry.displayName.isEmpty ? "Élève" : item.entry.displayName)
        return RankedLeaderboardRow(
            id: item.entry.id,
            rank: index + 1,
            displayName: name,
            initial: String(name.prefix(1)).uppercased(),
            meta: anonymous
                ? "Compte privé"
                : (item.entry.prepName.isEmpty ? "—" : item.entry.prepName),
            score: item.score,
            valueLabel: "Elo",
            isCurrentUser: !anonymous && item.entry.id == currentId,
            isAnonymous: anonymous
        )
    }
}

/// Prépare les lignes du classement XP hebdo : même filtre et même tri que le
/// classement Elo, sur les XP, avec la filière et l'année en contexte
/// (`buildWeeklyXpLeaderboard`).
private func rankedWeeklyRows(_ entries: [LeaderboardEntry], currentId: String) -> [RankedLeaderboardRow] {
    let sorted = entries
        .filter { !$0.id.isEmpty && !excludedLeaderboardIds.contains($0.id) }
        .map { entry in (entry: entry, score: max(0, Int((entry.xp ?? 0).rounded()))) }
        .sorted { first, second in
            if first.score != second.score { return first.score > second.score }
            return first.entry.displayName.localizedCaseInsensitiveCompare(second.entry.displayName) == .orderedAscending
        }

    return sorted.enumerated().map { index, item in
        let anonymous = item.entry.isAnonymous == true
        let name = anonymous
            ? "Anonyme"
            : (item.entry.displayName.isEmpty ? "Élève" : item.entry.displayName)
        let academic = weeklyAcademicLabel(
            track: item.entry.track,
            specialty: item.entry.specialty,
            year: item.entry.year
        )
        let meta: String
        if anonymous {
            meta = "Compte privé"
        } else if !academic.isEmpty {
            meta = academic
        } else {
            meta = item.entry.prepName.isEmpty ? "—" : item.entry.prepName
        }
        return RankedLeaderboardRow(
            id: item.entry.id,
            rank: index + 1,
            displayName: name,
            initial: String(name.prefix(1)).uppercased(),
            meta: meta,
            score: item.score,
            valueLabel: "XP",
            isCurrentUser: !anonymous && item.entry.id == currentId,
            isAnonymous: anonymous
        )
    }
}
