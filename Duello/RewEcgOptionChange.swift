//
//  RewEcgOptionChange.swift
//  Duello
//
//  Portage du module Expo `src/utils/ecgOptionChange.ts` : compteur des
//  changements d'option ECG et purge des données d'entraînement de l'ancienne
//  option avant d'activer la nouvelle.
//
//  Fichier source Expo porté (libellés, constantes et seuils repris mot pour mot) :
//    - src/utils/ecgOptionChange.ts
//        `MAX_ECG_OPTION_CHANGES` (= 6),
//        `normalizeEcgOptionChangeCount`, `loadEcgOptionChangeCount`,
//        `withoutRecordEntries`, `withoutCorrectionGradeEntries`,
//        `commitEcgOptionChange` (dont le filtre `parsedCorrections` des
//        brouillons de copie).
//
//  Limite assumée (à raccorder, vague 5) : `optionItemAndChapterIds(previousOption)`
//  de la source énumère les identifiants d'items et les chapitres d'une option
//  via `chapterItemScope` / `getOpenTrackSubjects` / `getChapterItems` d'Expo ;
//  cet énumérateur n'a pas d'équivalent Swift ici. `commitEcgOptionChange`
//  reçoit donc cette énumération en paramètres :
//    - `items: Set<String>`           : identifiants d'items de l'ancienne option ;
//    - `chapters: [String: Set<Int>]` : chapitre -> années (1 / 2) concernées.
//  La purge elle-même (filtrage des entrées par identifiant, retrait des clés
//  par chapitre, incrément du compteur) est portée intégralement.
//
//  Stockage : pas d'`AccountStorage` en Swift. Comme `ChalProgress.swift`, on
//  utilise `UserDefaults.standard` avec une clé isolée par compte (`scopedKey`).
//  Les clés logiques restent identiques à la source (`keys.ts`) :
//    - `prepapp-exercise-progress`,
//    - `prepapp-annale-attempts:v1`,
//    - `prepapp-annale-copy-corrections:v1`,
//    - `prepapp-correction-grade-history:v1`,
//    - `prepapp-maths-program-placement:v1`,
//    - `prepapp-ecg-option-change-count:v1`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// `src/utils/ecgOptionChange.ts` : compteur et purge des changements d'option ECG.
enum RewEcgOptionChange {
    /// `MAX_ECG_OPTION_CHANGES` : nombre maximal de changements d'option comptés.
    static let maxEcgOptionChanges = 6

    /// `PROGRAM_YEARS` (`src/data/tracks.ts:135`) : années du programme.
    private static let programYears = [1, 2]

    /// `ACCOUNT_STORAGE_KEYS.ecgOptionChangeCount` (`prepapp-ecg-option-change-count:v1`).
    private static let countStorageKey = RewStorageKeys.Account.ecgOptionChangeCount

    // MARK: - Compteur

    /// `normalizeEcgOptionChangeCount` : lit un entier base 10 puis le borne à
    /// `[0, MAX_ECG_OPTION_CHANGES]`. Une valeur absente ou illisible vaut `0`.
    static func normalizeEcgOptionChangeCount(_ value: String?) -> Int {
        guard let value, let parsed = parseIntBase10(value) else { return 0 }
        return min(maxEcgOptionChanges, max(0, parsed))
    }

    /// `loadEcgOptionChangeCount` : relit le compteur persisté du compte.
    static func loadEcgOptionChangeCount(accountId: String) -> Int {
        normalizeEcgOptionChangeCount(
            UserDefaults.standard.string(
                forKey: scopedKey(countStorageKey, accountId: accountId)
            )
        )
    }

    // MARK: - Filtrage des entrées

    /// `withoutRecordEntries` : retire d'un objet JSON les entrées dont la clé
    /// est un identifiant d'item supprimé. Un contenu illisible ou qui n'est pas
    /// un objet est rendu tel quel ; `nil` ou vide donne `nil`.
    static func withoutRecordEntries(raw: String?, removedIds: Set<String>) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let object = parsed as? [String: Any] else { return raw }
        let filtered = object.filter { !removedIds.contains($0.key) }
        guard let encoded = try? JSONSerialization.data(withJSONObject: filtered),
              let text = String(data: encoded, encoding: .utf8) else { return raw }
        return text
    }

    /// `withoutCorrectionGradeEntries` : retire d'un tableau JSON les entrées de
    /// correction dont l'un des `itemIds` est un identifiant d'item supprimé.
    static func withoutCorrectionGradeEntries(
        raw: String?,
        removedIds: Set<String>
    ) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let array = parsed as? [Any] else { return raw }
        let filtered = array.filter { value in
            guard let entry = value as? [String: Any],
                  let itemIds = entry["itemIds"] as? [Any] else { return true }
            return !itemIds.contains { ($0 as? String).map(removedIds.contains) ?? false }
        }
        guard let encoded = try? JSONSerialization.data(withJSONObject: filtered),
              let text = String(data: encoded, encoding: .utf8) else { return raw }
        return text
    }

    /// `parsedCorrections` de `commitEcgOptionChange` : retire d'un tableau JSON
    /// les brouillons de copie dont l'`itemId` est un identifiant supprimé.
    static func withoutCopyCorrectionJobs(raw: String?, removedIds: Set<String>) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let array = parsed as? [Any] else { return raw }
        let filtered = array.filter { value in
            guard let job = value as? [String: Any],
                  let itemId = job["itemId"] as? String else { return true }
            return !removedIds.contains(itemId)
        }
        guard let encoded = try? JSONSerialization.data(withJSONObject: filtered),
              let text = String(data: encoded, encoding: .utf8) else { return raw }
        return text
    }

    // MARK: - Purge

    /// `commitEcgOptionChange` : purge les données d'entraînement de l'ancienne
    /// option, puis incrémente et persiste le compteur. Au seuil atteint, ne
    /// touche à rien et renvoie le compteur inchangé.
    @discardableResult
    static func commitEcgOptionChange(
        accountId: String,
        previousOption: String,
        currentCount: Int,
        items: Set<String>,
        chapters: [String: Set<Int>]
    ) -> Int {
        if currentCount >= maxEcgOptionChanges { return currentCount }
        let defaults = UserDefaults.standard
        let stored: (String) -> String? = { base in
            defaults.string(forKey: scopedKey(base, accountId: accountId))
        }
        let write: (String?, String) -> Void = { value, base in
            if let value {
                defaults.set(value, forKey: scopedKey(base, accountId: accountId))
            }
        }

        let progressRaw = stored(RewStorageKeys.Account.exerciseProgress)
        let attemptsRaw = stored(RewStorageKeys.Account.annaleAttempts)
        let correctionsRaw = stored(RewStorageKeys.Account.annaleCopyCorrections)
        let gradeHistoryRaw = stored(RewStorageKeys.Account.correctionGradeHistory)

        for key in removedKeys(previousOption: previousOption, chapters: chapters) {
            defaults.removeObject(forKey: scopedKey(key, accountId: accountId))
        }

        write(
            withoutRecordEntries(raw: progressRaw, removedIds: items),
            RewStorageKeys.Account.exerciseProgress
        )
        write(
            withoutRecordEntries(raw: attemptsRaw, removedIds: items),
            RewStorageKeys.Account.annaleAttempts
        )
        write(
            withoutCopyCorrectionJobs(raw: correctionsRaw, removedIds: items),
            RewStorageKeys.Account.annaleCopyCorrections
        )
        write(
            withoutCorrectionGradeEntries(raw: gradeHistoryRaw, removedIds: items),
            RewStorageKeys.Account.correctionGradeHistory
        )

        let nextCount = currentCount + 1
        defaults.set(
            String(nextCount),
            forKey: scopedKey(countStorageKey, accountId: accountId)
        )
        return nextCount
    }

    /// Clés logiques retirées par la purge (`keysToRemove` de la source) :
    /// position maths, progression par matière, et toutes les clés par chapitre
    /// de l'ancienne option. Les constructeurs réels du projet sont réutilisés
    /// (`TrainCourseDocument`, `TrainChapterFlashcards`, `CtdStorage`,
    /// `ChapterNotebookStorage`, `CollStorage`, `TrainCourseKnowledge`).
    private static func removedKeys(
        previousOption: String,
        chapters: [String: Set<Int>]
    ) -> Set<String> {
        var keys: Set<String> = [RewStorageKeys.Account.mathsProgramPlacement]
        for year in programYears {
            let legacy = RewStorageKeys.subjectProgramStorageKey(track: "ECG", year: year)
            keys.insert(
                previousOption.lowercased().contains("appliqu")
                    ? "\(legacy):maths-appliquees"
                    : legacy
            )
        }
        for (chapterId, years) in chapters {
            keys.insert(TrainCourseDocument.legacyDocumentKey(chapterId: chapterId))
            keys.insert(TrainChapterFlashcards.storageKey(chapterId: chapterId))
            keys.insert(CtdStorage.documentKey(chapterId: chapterId))
            keys.insert(ChapterNotebookStorage.chapterNotebookKey(chapterId: chapterId))
            keys.insert(CollStorage.completionKey(chapterId: chapterId))
            for year in years {
                keys.insert(TrainCourseDocument.documentKey(year: year, chapterId: chapterId))
                keys.insert(TrainCourseKnowledge.storageKey(year: year, chapterId: chapterId))
                keys.insert(TrainCourseKnowledge.jobStorageKey(year: year, chapterId: chapterId))
            }
        }
        return keys
    }

    // MARK: - Utilitaires

    /// `Number.parseInt(value, 10)` : saute les espaces de tête et un signe
    /// optionnel, puis lit les chiffres ASCII jusqu'au premier non-chiffre.
    /// Renvoie `nil` si aucun chiffre n'est lu (comme `NaN` en JS).
    private static func parseIntBase10(_ value: String) -> Int? {
        var rest = Substring(value)
        while let first = rest.first, first.isWhitespace { rest = rest.dropFirst() }
        var sign = 1
        if let first = rest.first, first == "+" || first == "-" {
            if first == "-" { sign = -1 }
            rest = rest.dropFirst()
        }
        var magnitude = 0
        var found = false
        for character in rest {
            guard let ascii = character.asciiValue, ascii >= 48, ascii <= 57 else { break }
            found = true
            magnitude = min(magnitude * 10 + Int(ascii - 48), 1_000_000_000)
        }
        return found ? sign * magnitude : nil
    }

    /// Clé isolée par compte, comme le stockage de compte d'Expo.
    private static func scopedKey(_ base: String, accountId: String) -> String {
        let trimmed = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(base):\(trimmed.isEmpty ? "local" : trimmed)"
    }
}
