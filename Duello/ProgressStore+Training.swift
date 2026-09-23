import Foundation

// MARK: - Écriture

/// Méthodes d'écriture de `ProgressStore` : elles mutent l'état publié, puis
/// persistent. Extraites de `ProgressStore.swift` pour respecter la limite de
/// 10 fonctions par fichier ; le type et ses propriétés stockées restent dans
/// le fichier principal.
extension ProgressStore {

    /// Enregistre une tentative d'exercice ou de colle, puis persiste.
    ///
    /// La signature suit `recordOutcome` (Expo) : l'identifiant d'item suffit à
    /// tenir l'avancement. Une tentative compte pour un exercice terminé et
    /// marque la journée comme travaillée. La matière est facultative ; quand
    /// elle est fournie, les minutes rejoignent aussi son cumul, comme le fait
    /// une session d'entraînement côté Expo.
    func recordExercise(
        itemId: String,
        outcome: ItemOutcome,
        minutes: Int? = nil,
        subject: String? = nil,
        xp: Double = 0
    ) {
        let id = itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }

        items[id] = Self.applyOutcome(items[id], outcome: outcome, minutes: minutes)
        exercisesCompleted += 1
        credit(minutes: minutes, to: subject)
        creditXp(xp)
        markActiveDay()
        persist()
    }

    /// Enregistre un défi joué, gagné ou perdu, puis persiste : le compteur
    /// global, le bilan de la matière et la journée travaillée
    /// (voir `applySession` d'`activity.ts`).
    func recordDuel(subject: String, won: Bool, minutes: Int = 0, xp: Double = 0) {
        challengesCompleted += 1
        if won { challengesWon += 1 }

        if let name = Self.subjectKey(subject) {
            var stat = duels[name] ?? DuelStat()
            stat.played += 1
            if won { stat.won += 1 }
            duels[name] = stat
        }

        credit(minutes: minutes, to: subject)
        creditXp(xp)
        markActiveDay()
        persist()
    }

    /// Crédite une question réussie (voir `recordCorrectQuestionXp` d'Expo).
    func recordCorrectQuestion(xp: Double = 0) {
        correctQuestions += 1
        creditXp(xp)
        markActiveDay()
        persist()
    }

    /// Crédite un gain d'XP horodaté et le retient pour la courbe d'XP
    /// (`activity.history` / `activityXp` d'Expo).
    func recordXp(_ amount: Double) {
        creditXp(amount)
        persist()
    }

    /// Fixe la couverture du programme menant aux concours
    /// (`competitionProgramPercent`), bornée à [0, 100].
    func setCompetitionProgramPercent(_ percent: Int) {
        competitionProgramPercent = min(100, max(0, percent))
        persist()
    }

    /// Fixe la cote d'une matière. Le déplacement est calculé par l'arbitrage
    /// des défis (`developmentEloDelta` côté Expo) ; le store ne fait que la
    /// retenir pour l'affichage, par matière et par compte, et l'horodate pour
    /// la courbe d'Elo.
    func recordElo(subject: String, elo: Int) {
        guard let name = Self.subjectKey(subject) else { return }
        let clamped = max(0, elo)
        subjectElos[name] = clamped
        eloHistory.append(
            ProgressEloEntry(subject: name, elo: clamped, at: Self.nowMilliseconds())
        )
        persist()
    }

    // MARK: Outils internes

    /// Ajoute la journée locale à la série d'activité, au plus une fois par jour
    /// (voir `applyActiveDay` d'`activity.ts`).
    private func markActiveDay(at date: Date = Date()) {
        let day = Self.dayKey(at: date)
        guard !activeDays.contains(day) else { return }
        activeDays.append(day)
    }

    /// Applique un résultat à l'état d'un item et renvoie le nouvel état
    /// (voir `applyOutcome` d'`exerciseProgress.ts`). Le temps n'est capturé
    /// qu'à la toute première réussite complète.
    private static func applyOutcome(
        _ current: ItemProgress?,
        outcome: ItemOutcome,
        minutes: Int?
    ) -> ItemProgress {
        var next = current ?? ItemProgress()
        next.attempts += 1
        if outcome == .success { next.successes += 1 }
        if outcome == .partial { next.partials += 1 }

        // Le meilleur résultat ne redescend jamais ; -1 place un item encore
        // jamais tenté sous le pire des résultats.
        if outcome.rank > (next.bestOutcome?.rank ?? -1) {
            next.bestOutcome = outcome
        }

        if outcome == .success, next.firstSuccessMinutes == nil, let minutes = minutes {
            next.firstSuccessMinutes = minutes
        }
        return next
    }

    /// Ajoute des minutes au total et, quand la matière est connue, à son cumul.
    private func credit(minutes: Int?, to subject: String?) {
        let spent = max(0, minutes ?? 0)
        guard spent > 0 else { return }

        exerciseMinutes += spent
        guard let name = Self.subjectKey(subject) else { return }
        subjectMinutes[name, default: 0] += spent
    }

    /// Ajoute un gain d'XP au total et l'horodate pour la courbe d'XP.
    private func creditXp(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        totalXp += amount
        xpHistory.append(ProgressXpEntry(xp: amount, at: Self.nowMilliseconds()))
    }
}
