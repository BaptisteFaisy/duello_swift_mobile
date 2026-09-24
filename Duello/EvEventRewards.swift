//
//  EvEventRewards.swift
//  Duello
//
//  Récompenses d'un événement (concours blanc) créditées localement à la
//  publication du classement : XP de participation et delta Elo, **idempotents
//  par événement**.
//
//  Fichier source Expo porté (règles, libellés et clés repris mot pour mot) :
//    - src/utils/eventRewards.ts
//        `EventRewardResult`, `recordEventRewards`, `eventXpForDisplay`,
//        `rewardedEventIds`, le libellé « Concours blanc · <matière> » et le
//        détail « Épreuve de <n> min ».
//    - src/utils/eventConstants.ts (`SUBJECT_ELO`, `EVENT_XP_PER_HOUR`),
//      réutilisé via `RewEventConstants`.
//
//  Le serveur reste l'autorité (il recalcule note, XP et deltas Elo) ; les
//  compteurs locaux et la courbe Elo vivent sur le téléphone. Le crédit est
//  idempotent par événement : un relevé relu deux fois ne paie jamais deux fois,
//  grâce à `rewardedEventIds`.
//
//  Détail d'intégration (voir wiring/U14.md, 24/09/2026) : la source partage le **modèle
//  d'activité complet** entre tous les gains d'XP. Ici, `EvRewardActivity` est
//  la **projection** des champs touchés par `eventRewards.ts` ; `saveActivity`
//  fusionne ces champs dans l'objet brut persisté (clé `prepapp-xp-activity`)
//  pour ne pas écraser les autres champs écrits ailleurs. Le module existant
//  `RewCompletion.swift` écrit lui aussi cette clé avec sa propre projection :
//  les deux devront partager un modèle unique (câblage signalé, non fait ici).
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// `EventRewardResult`.
struct EvEventRewardResult: Equatable {
    var credited: Bool
    var xpGained: Int
    var eloDelta: Int
}

/// Entrée de `recordEventRewards`.
struct EvEventRewardsInput {
    var eventId: String
    var subjectTitle: String
    var durationMinutes: Double
    var xpAwarded: Double
    var eloDelta: Double
    /// Instant de publication, en millisecondes depuis l'époque.
    var at: Double
}

/// Projection d'activité consommée par `eventRewards.ts` (sous-ensemble de
/// `XpActivity`). Les autres champs du modèle complet sont préservés à l'écriture.
struct EvRewardActivity: Codable, Equatable {
    var exerciseMinutes: Int = 0
    var subjectMinutes: [String: Int] = [:]
    var activeDays: [String] = []
    var rewardedEventIds: [String] = []
    var history: [EvRewardEntry] = []

    enum CodingKeys: String, CodingKey {
        case exerciseMinutes, subjectMinutes, activeDays, rewardedEventIds, history
    }

    init() {}

    /// Décodage tolérant : un stockage partiel est complété champ par champ.
    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        exerciseMinutes = max(0, (try? c.decodeIfPresent(Int.self, forKey: .exerciseMinutes)) ?? 0)
        subjectMinutes = (try? c.decodeIfPresent([String: Int].self, forKey: .subjectMinutes)) ?? nil ?? [:]
        activeDays = (try? c.decodeIfPresent([String].self, forKey: .activeDays)) ?? nil ?? []
        rewardedEventIds = (try? c.decodeIfPresent([String].self, forKey: .rewardedEventIds)) ?? nil ?? []
        history = (try? c.decodeIfPresent([EvRewardEntry].self, forKey: .history)) ?? nil ?? []
    }
}

/// Gain d'XP (`XpEntry`), réduit aux champs relus par la récompense d'événement.
struct EvRewardEntry: Codable, Equatable {
    var id: String = ""
    var kind: String = "exercise"
    var subject: String = ""
    var label: String = ""
    var detail: String = ""
    var xp: Double = 0
    var at: Double = 0

    enum CodingKeys: String, CodingKey { case id, kind, subject, label, detail, xp, at }

    init() {}

    init(id: String, kind: String, subject: String, label: String, detail: String, xp: Double, at: Double) {
        self.id = id
        self.kind = kind
        self.subject = subject
        self.label = label
        self.detail = detail
        self.xp = xp
        self.at = at
    }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil ?? ""
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? nil ?? "exercise"
        subject = (try? c.decodeIfPresent(String.self, forKey: .subject)) ?? nil ?? ""
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? nil ?? ""
        detail = (try? c.decodeIfPresent(String.self, forKey: .detail)) ?? nil ?? ""
        xp = (try? c.decodeIfPresent(Double.self, forKey: .xp)) ?? nil ?? 0
        at = (try? c.decodeIfPresent(Double.self, forKey: .at)) ?? nil ?? 0
    }
}

/// Point de la courbe Elo (`EloPoint`).
struct EvEloPoint: Codable, Equatable {
    var subject: String = ""
    var elo: Int = 0
    var at: Double = 0
    /// `'match'` (défaut) ou `'decay'`.
    var kind: String?

    init(subject: String, elo: Int, at: Double, kind: String? = nil) {
        self.subject = subject
        self.elo = elo
        self.at = at
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subject = (try? c.decodeIfPresent(String.self, forKey: .subject)) ?? nil ?? ""
        elo = (try? c.decodeIfPresent(Int.self, forKey: .elo)) ?? nil ?? 0
        at = (try? c.decodeIfPresent(Double.self, forKey: .at)) ?? nil ?? 0
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? nil
    }

    enum CodingKeys: String, CodingKey { case subject, elo, at, kind }
}

/// Carte des cotes par matière (`SubjectEloMap`).
typealias EvSubjectEloMap = [String: Int]

/// `eventRewards.ts` : crédit idempotent des récompenses d'un événement.
enum EvEventRewards {
    /// `SUBJECT_ELO` : sujet Elo crédité par un concours blanc.
    static let subjectElo = RewEventConstants.subjectElo
    /// `EVENT_XP_PER_HOUR` : XP de participation pour un sujet d'une heure.
    static let eventXpPerHour = RewEventConstants.eventXpPerHour
    /// `INITIAL_SUBJECT_ELO` : cote d'une matière jamais jouée.
    static let initialSubjectElo = 1100

    /// File d'écriture par compte (`activityMutationQueues` / `enqueueActivityMutation`).
    private static let queue = RewMutationQueue()

    /// `eventXpForDisplay` : XP de participation d'un événement, pour l'affichage seul.
    static func eventXpForDisplay(durationMinutes: Double) -> Int {
        let hours = max(0, durationMinutes) / 60
        return Int((hours * Double(eventXpPerHour)).rounded())
    }

    /// `getSubjectElo` : cote d'une matière, 1100 avant le premier défi.
    static func getSubjectElo(_ subjectElos: EvSubjectEloMap, subject: String) -> Int {
        subjectElos[subject] ?? initialSubjectElo
    }

    /// `recordEventRewards` : crédite XP et delta Elo une seule fois par événement.
    static func record(
        storage: EvEventRewardsStorage,
        input: EvEventRewardsInput
    ) async throws -> EvEventRewardResult {
        try await queue.enqueue(accountId: storage.accountId) {
            let activity = await EvEventRewardsStore.loadActivity(storage)
            if activity.rewardedEventIds.contains(input.eventId) {
                return EvEventRewardResult(credited: false, xpGained: 0, eloDelta: 0)
            }

            let minutes = max(0, Int(input.durationMinutes.rounded()))
            let entryXp = max(0, Int(input.xpAwarded.rounded()))
            var updated = activity
            updated.exerciseMinutes += minutes
            updated.subjectMinutes[input.subjectTitle, default: 0] += minutes
            let day = EvEventRewardsStore.dayKey(input.at)
            if !updated.activeDays.contains(day) { updated.activeDays.append(day) }
            updated.rewardedEventIds.append(input.eventId)
            updated.history = Array(
                ([EvEventRewardsStore.eventEntry(input: input, minutes: minutes, xp: entryXp)]
                 + updated.history).prefix(2_000)
            )
            await EvEventRewardsStore.saveActivity(storage, updated)

            let elos = await EvEventRewardsStore.loadSubjectElos(storage)
            let before = getSubjectElo(elos, subject: subjectElo)
            let after = max(0, Int((Double(before) + input.eloDelta).rounded()))
            var nextElos = elos
            nextElos[subjectElo] = after
            await EvEventRewardsStore.saveSubjectElos(storage, nextElos)
            await EvEventRewardsStore.recordEloPoint(
                storage,
                point: EvEloPoint(subject: subjectElo, elo: after, at: input.at, kind: "match")
            )

            return EvEventRewardResult(credited: true, xpGained: entryXp, eloDelta: after - before)
        }
    }
}
