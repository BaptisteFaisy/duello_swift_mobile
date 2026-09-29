//
//  DuelChallengePools.swift
//  Duello
//
//  Banques d'énoncés jouables d'un défi, chapitre par chapitre.
//
//  Fichiers source Expo portés (règles, ordres et constantes repris mot pour mot) :
//    - src/utils/challengeExercises.ts
//        `parseChallengeChapterKey`, `oralChallengeItems`,
//        `challengeExerciseIdsForPool`, `challengeExercisePoolsFor`,
//        `challengeExercisePoolsCanUseCatalogs`,
//        `challengeExercisePoolsForCooperatively`, `CooperativeChallengePoolOptions`,
//        `yieldChallengePoolWork`.
//    - src/data/chapterItemBasics.ts — `chapterItemScope` (`hasRealChapterBanks`).
//    - src/data/tracks.ts — `lyceeProgramScope`, `normalize` (spécialité du lycée).
//
//  Réutilise sans les recréer : `DuelloExerciseCatalog.pools` (snapshot figé du
//  catalogue servi, port de `challengeExerciseIdsForPool`), `TrainExercise`
//  (item servi : `key` = identifiant d'item, `chapterId`, `statement`).
//
//  Écarts assumés (datés 2026-09-29) :
//    - la source construit la banque **dynamiquement** depuis `chapterItems` /
//      `trainingCardCatalogs` ; le port lit le **snapshot** `DuelloExerciseCatalog`,
//      donc les identifiants d'oraux `escp-oral-*` (absents du snapshot) sont
//      fournis par l'hôte via le paramètre `orals` ;
//    - `challengeExercisePoolsCanUseCatalogs` : la source teste la présence des
//      index compacts (`hasCompleteTrainingCardContent`) pour différer la
//      reconstruction du socle hors ligne ; le snapshot Swift étant embarqué et
//      toujours complet, le signal se réduit à « clé lisible et scope résolu » ;
//    - `waitForContentInteractionIdle` de `yieldChallengePoolWork` : le portillon
//      Swift (`OfflInteractionGateController.waitForIdle`) est injectable par
//      l'appelant via `CooperativeOptions.yieldControl` ; le défaut rend la main.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Résolution des énoncés de défi depuis la banque (`challengeExercises.ts`).
enum DuelChallengePools {

    /// Clé d'un chapitre de défi : `<année>:<matière>:<chapitre>`
    /// (`parseChallengeChapterKey`). `year` vaut 1 ou 2, comme la source
    /// (`Number(match[1]) === 2 ? 2 : 1`).
    static func parseChallengeChapterKey(
        _ chapterKey: String
    ) -> (year: Int, subjectId: String, chapterId: String)? {
        guard let first = chapterKey.firstIndex(of: ":") else { return nil }
        let yearText = String(chapterKey[chapterKey.startIndex..<first])
        guard !yearText.isEmpty, yearText.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let afterYear = chapterKey.index(after: first)
        guard let second = chapterKey[afterYear...].firstIndex(of: ":") else { return nil }
        let subjectId = String(chapterKey[afterYear..<second])
        guard !subjectId.isEmpty else { return nil }
        let chapterId = String(chapterKey[chapterKey.index(after: second)...])
        guard !chapterId.isEmpty else { return nil }
        return (Int(yearText) == 2 ? 2 : 1, subjectId, chapterId)
    }

    /// Banque à servir pour l'année affichée (`chapterItemScope`), `nil` hors
    /// filière pourvue. Le lycée se lit dans la spécialité (`lyceeProgramScope`).
    static func chapterItemScope(track: String, year: Int, specialty: String = "") -> String? {
        guard track == "ECG" || track == "MPSI" || track == "Lycée" else { return nil }
        let option = normalizedSpecialty(specialty)
        if track == "Lycée" {
            if option.isEmpty { return "seconde" }
            if option.contains("expertes") { return option.contains("specialite") ? "terminale" : nil }
            if option.contains("complementaires") { return nil }
            if option.contains("+") { return "premiere" }
            return "terminale"
        }
        if track == "MPSI" { return year == 1 ? "mpsi-1" : "mp-2" }
        if option.contains("appliqu") { return year == 1 ? "ecg-appliquees-1" : "ecg-appliquees-2" }
        return year == 1 ? "ecg-approfondies-1" : "ecg-approfondies-2"
    }

    /// Spécialité repliée pour comparaison (`normalize` de `data/tracks.ts`) :
    /// accents retirés, minuscules. Le « fr-FR » de la source est visé.
    private static func normalizedSpecialty(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }

    /// Sujets d'oral ESCP retranscrits de la section Annales de l'année demandée
    /// (`oralChallengeItems`). La source lit `getTrackAnnaleItems` ; le port
    /// reçoit la banque servie (`items`) et garde le même filtre : identifiant
    /// `escp-oral-*` **et** énoncé non vide. Les Annales appliquées (DS) et les
    /// filières sans banque d'annales ne sont jamais parcourues.
    static func oralChallengeItems(
        year: Int = 1,
        track: String = "ECG",
        specialty: String = "",
        items: [TrainExercise]
    ) -> [TrainExercise] {
        if track != "ECG" || normalizedSpecialty(specialty).contains("appliqu") { return [] }
        return items.filter { item in
            item.key.hasPrefix("escp-oral-")
                && !item.statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Identifiants nécessaires à la file sans construire les fiches détaillées
    /// (`challengeExerciseIdsForPool`) : banque du chapitre, plus les oraux
    /// `maths` du même chapitre, dédoublonnés puis triés.
    private static func challengeExerciseIdsForPool(
        _ chapterKey: String,
        track: String,
        specialty: String,
        orals: [TrainExercise]
    ) -> [String] {
        guard let parsed = parseChallengeChapterKey(chapterKey),
              let scope = chapterItemScope(track: track, year: parsed.year, specialty: specialty)
        else { return [] }
        let trainingIds = DuelloExerciseCatalog.pools[scope]?[parsed.chapterId] ?? []
        let oralIds = parsed.subjectId == "maths"
            ? oralChallengeItems(year: parsed.year, track: track, specialty: specialty, items: orals)
                .filter { $0.chapterId == parsed.chapterId }
                .map(\.key)
            : []
        return Array(Set(trainingIds + oralIds)).sorted()
    }

    /// Identifiants jouables annoncés au serveur pour chaque chapitre
    /// sélectionné (`challengeExercisePoolsFor`). Un chapitre sans identifiant
    /// est omis, comme la source.
    static func challengeExercisePoolsFor(
        chapterKeys: [String],
        track: String,
        specialty: String = "",
        orals: [TrainExercise] = []
    ) -> [String: [String]] {
        var pools: [String: [String]] = [:]
        for chapterKey in chapterKeys {
            let ids = challengeExerciseIdsForPool(
                chapterKey,
                track: track,
                specialty: specialty,
                orals: orals
            )
            if !ids.isEmpty { pools[chapterKey] = ids }
        }
        return pools
    }

    /// Vrai lorsque tous les chapitres peuvent lire uniquement les index compacts
    /// (`challengeExercisePoolsCanUseCatalogs`).
    static func challengeExercisePoolsCanUseCatalogs(
        chapterKeys: [String],
        track: String,
        specialty: String = ""
    ) -> Bool {
        chapterKeys.allSatisfy { chapterKey in
            guard let parsed = parseChallengeChapterKey(chapterKey) else { return false }
            return chapterItemScope(track: track, year: parsed.year, specialty: specialty) != nil
        }
    }

    /// Options de la préparation coopérative (`CooperativeChallengePoolOptions`).
    struct CooperativeOptions {
        /// Annule proprement le calcul lorsque l'écran n'est plus actif.
        var shouldContinue: () -> Bool = { true }
        /// Point de reprise injectable ; par défaut, rend la main entre chapitres.
        var yieldControl: () async -> Void = { await DuelChallengePools.yieldChallengePoolWork() }
    }

    /// Prépare les banques un chapitre à la fois en rendant la main entre chacun
    /// (`challengeExercisePoolsForCooperatively`) : chaque tranche laisse passer
    /// les appuis et s'interrompt dès que l'écran devient inactif.
    static func challengeExercisePoolsForCooperatively(
        chapterKeys: [String],
        track: String,
        specialty: String = "",
        orals: [TrainExercise] = [],
        options: CooperativeOptions = CooperativeOptions()
    ) async -> [String: [String]] {
        var pools: [String: [String]] = [:]
        for chapterKey in chapterKeys {
            if !options.shouldContinue() { break }
            await options.yieldControl()
            if !options.shouldContinue() { break }
            let pool = challengeExercisePoolsFor(
                chapterKeys: [chapterKey],
                track: track,
                specialty: specialty,
                orals: orals
            )
            if let ids = pool[chapterKey], !ids.isEmpty { pools[chapterKey] = ids }
        }
        return pools
    }

    /// Rend la main entre deux chapitres (`yieldChallengePoolWork`). La source
    /// attend en plus la fin d'un swipe (`waitForContentInteractionIdle`) ; le
    /// portillon Swift est injecté via `CooperativeOptions.yieldControl`.
    private static func yieldChallengePoolWork() async {
        await Task.yield()
    }
}
