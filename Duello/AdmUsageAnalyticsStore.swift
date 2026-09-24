//
//  AdmUsageAnalyticsStore.swift
//  Duello
//
//  Journal d'usage local d'un compte : lecture, sérialisation et trois des six
//  écritures (session, visite d'écran, temps actif). Les trois autres écritures
//  (action, appui, exercice) sont dans `AdmUsageAnalyticsStore+Writes.swift`.
//
//  Fichier source Expo porté (règles reprises mot pour mot) :
//    - src/utils/usageAnalytics.ts
//        `AccountStorage` (`accountId`, `getItem`, `setItem`),
//        `loadUsageAnalytics`, `mutateUsage`, `scheduleUsageDrain`,
//        `drainUsageQueue`, `startUsageSession`, `recordScreenVisit`,
//        `recordActiveTime`, les libellés « Session ouverte » / « Page visitée »
//        et la section « Navigation principale ».
//
//  Notes (réduit / approché / limite assumée, 24/09/2026) :
//   - la source regroupe une rafale de mutations (`queue.pending`) et attend
//     `waitForContentInteractionIdle` avant un seul `JSON.parse` et une seule
//     écriture par rafale. Le portage sérialise une mutation à la fois (file par
//     instance, comme la file par compte de la source) : le contenu persistant
//     est identique, seule la fréquence d'écriture diffère ;
//   - la source garde un cache `queue.current` invalidé en cas d'échec
//     d'écriture ; ici, un échec d'encodage laisse simplement le journal en
//     mémoire tel quel (la prochaine mutation repart de la copie durable) ;
//   - `@MainActor` : l'app mobile écrit depuis le fil principal, un seul compte
//     à la fois ; la file évite toute perte de mise à jour entre deux `await`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Combine
import Foundation

/// Journal d'usage d'un compte : un seul compte par instance.
@MainActor
final class AdmUsageAnalyticsStore: ObservableObject {
    @Published private(set) var journal: AdmUsageJournal

    private let storage: AdmUsageStorage
    private var hasLoaded = false
    private var tail: Task<Void, Never>?

    init(storage: AdmUsageStorage) {
        self.storage = storage
        self.journal = AdmUsageJournal.empty(now: Date().timeIntervalSince1970 * 1000)
    }

    /// `loadUsageAnalytics` : lit la copie durable une seule fois, puis sert le cache.
    func load() async -> AdmUsageJournal {
        if hasLoaded { return journal }
        let raw = await storage.getItem(AdmUsageRules.storageKey)
        journal = AdmUsageJournal.decode(raw)
        hasLoaded = true
        return journal
    }

    /// `startUsageSession` : ouvre une session et compte une visite de page.
    func startSession(
        page: AdmUsagePage,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) async -> AdmUsageJournal {
        await mutate(now: now) { current, day in
            var next = current
            next.lastSeenAt = AdmUsageRules.iso(now)
            next.sessionCount += 1
            next.pageVisits[page] += 1
            next.events = AdmUsageJournal.appendingEvent(
                next.events,
                .make(kind: .pageView, page: page, label: "Session ouverte",
                      section: "Navigation principale", now: now)
            )
            var updatedDay = day
            updatedDay.sessions += 1
            updatedDay.pageVisits[page] += 1
            next.daily.append(updatedDay)
            return next
        }
    }

    /// `recordScreenVisit` : compte une visite de page (hors ouverture de session).
    func recordScreenVisit(
        page: AdmUsagePage,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) async -> AdmUsageJournal {
        await mutate(now: now) { current, day in
            var next = current
            next.lastSeenAt = AdmUsageRules.iso(now)
            next.pageVisits[page] += 1
            next.events = AdmUsageJournal.appendingEvent(
                next.events,
                .make(kind: .pageView, page: page, label: "Page visitée",
                      section: "Navigation principale", now: now)
            )
            var updatedDay = day
            updatedDay.pageVisits[page] += 1
            next.daily.append(updatedDay)
            return next
        }
    }

    /// `recordActiveTime` : ajoute du temps actif ; une durée nulle ne fait rien.
    func recordActiveTime(
        page: AdmUsagePage,
        elapsedMilliseconds: Double,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) async -> AdmUsageJournal {
        let elapsedSeconds = max(0, elapsedMilliseconds) / 1000
        if elapsedSeconds == 0 { return await load() }
        return await mutate(now: now) { current, day in
            var next = current
            next.lastSeenAt = AdmUsageRules.iso(now)
            next.totalActiveSeconds += elapsedSeconds
            next.pageSeconds[page] += elapsedSeconds
            var updatedDay = day
            updatedDay.activeSeconds += elapsedSeconds
            updatedDay.pageSeconds[page] += elapsedSeconds
            next.daily.append(updatedDay)
            return next
        }
    }

    // MARK: - Moteur de mutation

    /// `mutateUsage` : applique une transformation à la journée en cours, puis
    /// normalise et persiste une seule fois le journal obtenu.
    func mutate(
        now: Double,
        _ transform: @escaping (AdmUsageJournal, AdmUsageDayRecord) -> AdmUsageJournal
    ) async -> AdmUsageJournal {
        await enqueue {
            let base: AdmUsageJournal
            if self.hasLoaded {
                base = self.journal
            } else {
                base = await self.load()
            }
            let date = AdmUsageRules.localDayKey(now)
            let existing = base.daily.first { $0.date == date } ?? AdmUsageDayRecord(date: date)
            var stripped = base
            stripped.daily = base.daily.filter { $0.date != date }
            let updated = AdmUsageJournal.normalize(transform(stripped, existing), now: now)
            await self.persist(updated)
            self.journal = updated
            return updated
        }
    }

    /// Sérialise les mutations : chacune attend la précédente (file d'une instance).
    private func enqueue<T>(_ operation: @escaping @MainActor () async -> T) async -> T {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            return await operation()
        }
        tail = Task { @MainActor in _ = await task.value }
        return await task.value
    }

    /// Écrit le journal sous la clé d'usage ; un encodage impossible laisse le
    /// journal en mémoire tel quel.
    private func persist(_ journal: AdmUsageJournal) async {
        guard let raw = journal.encoded() else { return }
        await storage.setItem(AdmUsageRules.storageKey, raw)
    }
}

// MARK: - Couture de stockage

/// Stockage clé/valeur de compte (`AccountStorage` réduit au nécessaire).
protocol AdmUsageStorage {
    /// Cloisonne la file d'écriture par compte.
    var accountId: String { get }
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, _ value: String) async
}
