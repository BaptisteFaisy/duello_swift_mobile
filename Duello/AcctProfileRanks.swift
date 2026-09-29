//
//  AcctProfileRanks.swift
//  Duello
//
//  Rangs « Moi » de la personne affichée sur le profil consulté.
//
//  Fichier source Expo porté : `src/hooks/useProfileLeaderboardRanks.ts`
//  (`useProfileLeaderboardRanks`). Les fusions et le formatage purs vivent dans
//  `RankingProfileRanks.swift` (port de `utils/profileLeaderboardRanks.ts`) ;
//  ce fichier ne porte que le **chargement** des deux classements.
//
//  Les deux classements suivent la règle des écrans de classements : mémoire
//  puis disque pour le premier affichage, puis réponse réseau. Les rangs se
//  recalculent quand les scores locaux bougent, sans recharger le réseau. Faux
//  hors développement (`enabled`), aucun chargement n'est lancé et les rangs
//  restent nuls.
//
//  La source relit les instantanés par les fonctions de `socialApi` ; le portage
//  s'appuie sur les mêmes fonctions déjà posées par les écrans de classements
//  (`RankingSubjectLeaderboard+Cache.swift`, `DuelloAPI`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Combine
import Foundation

/// Chargement des rangs du profil consulté (`useProfileLeaderboardRanks`).
@MainActor
final class AcctProfileRanksController: ObservableObject {

    /// `ProfileLeaderboardRankInput` : entrée du calcul.
    struct Input: Equatable {
        /// Faux hors développement : aucun chargement, rangs toujours nuls.
        var enabled: Bool
        /// Cohorte Elo de la personne affichée, comme sur l'écran de classements.
        var cohort: String?
        /// Lundi de la semaine classée, au format AAAA-MM-JJ.
        var week: String
        /// Identité minimale de la personne affichée.
        var viewed: RankingProfileRanks.Viewed
        /// Vrai pour soi-même en compte privé : la ligne anonyme reste anonyme.
        var hideIdentity: Bool
        /// Cote de maths de la personne affichée, `nil` tant qu'elle manque.
        var mathElo: Double?
        /// XP de la semaine dans la matière classée, `nil` tant qu'ils manquent.
        var weeklyXp: Double?
        /// Les sources des scores ont fini de charger (même sans score).
        var scoresReady: Bool
        /// Jeton de session, pour la réponse réseau.
        var token: String?

        static let empty = Input(
            enabled: false,
            cohort: nil,
            week: "",
            viewed: RankingProfileRanks.Viewed(id: "", displayName: "", prepName: ""),
            hideIdentity: false,
            mathElo: nil,
            weeklyXp: nil,
            scoresReady: false,
            token: nil
        )
    }

    @Published private(set) var eloRank: Int?
    @Published private(set) var xpRank: Int?
    @Published private(set) var eloSettled = false
    @Published private(set) var xpSettled = false

    private var input = Input.empty
    private var eloEntries: [LeaderboardEntry]?
    private var xpEntries: [LeaderboardEntry]?
    /// Incrémenté à chaque chargement : une réponse tardive ne réécrit rien.
    private var generation = 0

    /// `xpLoading` : faux tant que le classement et les scores locaux ne sont pas
    /// tous deux arrivés.
    var xpLoading: Bool { input.enabled && (!xpSettled || !input.scoresReady) }

    /// `eloLoading` : même contrat que `xpLoading`.
    var eloLoading: Bool { input.enabled && (!eloSettled || !input.scoresReady) }

    /// Applique une nouvelle entrée : relance le chargement quand la cohorte, la
    /// semaine ou l'activation changent (`useEffect` de la source).
    func update(_ newInput: Input) {
        let reload = newInput.enabled != input.enabled
            || newInput.cohort != input.cohort
            || newInput.week != input.week
        input = newInput
        if reload { load() } else { recompute() }
    }

    /// Met à jour les scores locaux sans relancer le réseau (`useMemo`).
    func updateScores(mathElo: Double?, weeklyXp: Double?, scoresReady: Bool) {
        input.mathElo = mathElo
        input.weeklyXp = weeklyXp
        input.scoresReady = scoresReady
        recompute()
    }

    /// Relit les deux classements (mémoire, puis disque, puis réseau).
    func load() {
        generation += 1
        let current = generation
        eloEntries = nil
        xpEntries = nil
        eloSettled = false
        xpSettled = false
        recompute()
        guard input.enabled else { return }
        loadElo(generation: current)
        loadXp(generation: current)
    }

    /// Charge le classement Elo : mémoire puis disque pour l'affichage immédiat,
    /// puis la réponse réseau qui prend la main.
    private func loadElo(generation current: Int) {
        let subject = RankingProfileRanks.subject
        let cohort = input.cohort
        let token = input.token
        if let cached = cachedSubjectLeaderboardSnapshotEntries(subject: subject, cohort: cohort) {
            eloEntries = cached
            eloSettled = true
            recompute()
        } else {
            Task { [weak self] in
                let restored = await subjectLeaderboardSnapshotEntries(subject: subject, cohort: cohort)
                guard let self, self.generation == current, let restored else { return }
                self.eloEntries = restored
                self.eloSettled = true
                self.recompute()
            }
        }
        Task { [weak self] in
            let entries = try? await DuelloAPI.subjectLeaderboard(
                subject: subject, cohort: cohort, token: token
            )
            guard let self, self.generation == current else { return }
            if let entries { self.eloEntries = entries }
            self.eloSettled = true
            self.recompute()
        }
    }

    /// Charge le classement XP de la semaine, selon la même règle.
    private func loadXp(generation current: Int) {
        let subject = RankingProfileRanks.subject
        let week = input.week
        let token = input.token
        if let cached = cachedWeeklyXpLeaderboardSnapshotEntries(subject: subject, week: week) {
            xpEntries = cached
            xpSettled = true
            recompute()
        } else {
            Task { [weak self] in
                let restored = await weeklyXpLeaderboardSnapshotEntries(subject: subject, week: week)
                guard let self, self.generation == current, let restored else { return }
                self.xpEntries = restored
                self.xpSettled = true
                self.recompute()
            }
        }
        Task { [weak self] in
            let entries = try? await DuelloAPI.weeklyXpLeaderboard(
                subject: subject, week: week, token: token
            )
            guard let self, self.generation == current else { return }
            if let entries { self.xpEntries = entries }
            self.xpSettled = true
            self.recompute()
        }
    }

    /// Recalcule les deux rangs depuis les entrées chargées et les scores locaux.
    private func recompute() {
        if input.enabled, eloSettled, let eloEntries, let mathElo = input.mathElo {
            eloRank = RankingProfileRanks.resolveViewedEloRank(
                eloEntries, viewed: input.viewed, elo: mathElo, hideIdentity: input.hideIdentity
            )
        } else {
            eloRank = nil
        }
        if input.enabled, xpSettled, let xpEntries, let weeklyXp = input.weeklyXp {
            xpRank = RankingProfileRanks.resolveViewedXpRank(
                xpEntries, viewed: input.viewed, xp: weeklyXp, hideIdentity: input.hideIdentity
            )
        } else {
            xpRank = nil
        }
    }
}
