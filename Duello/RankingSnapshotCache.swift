//
//  RankingSnapshotCache.swift
//  Duello
//
//  Port de src/utils/rankingsCacheStorage.ts (RN) — persistance des derniers
//  classements reçus, réutilisables dès le démarrage.
//
//  Les caches mémoire des classements meurent avec le processus : au premier
//  lancement après une fermeture, l'écran attendait la réponse réseau alors
//  qu'une copie datée de quelques heures reste largement affichable. La
//  dernière réponse validée est donc persistée par clé de cache et relue
//  depuis le disque au montage de l'écran, le rafraîchissement réseau restant
//  maître derrière.
//
//  Réductions assumées (2026-09-24) :
//  - `entries: unknown[]` (RN) → `[LeaderboardEntry]` : les deux caches
//    nommés (`subject-leaderboard`, `weekly-xp-leaderboard`) ne portent que
//    des lignes de classement, seul type de ligne du projet. Le champ
//    `currentTrack` d'une ligne hebdo n'est pas décodé par `LeaderboardEntry`
//    (il est relu à part depuis la réponse brute) : un instantané restauré ne
//    le restitue donc pas.
//  - `AsyncStorage` → `UserDefaults` via `RankingsSnapshotStorage`, comme les
//    autres préférences natives (`OfflUserDefaultsPrefetchStorage`).
//  - `savedAt` reste un nombre de millisecondes epoch (`Date.now()`).
//
//  Découpe (2026-09-29, ratchet Hermes) : le modèle persisté vit dans
//  `RankingsSnapshotModel.swift`, la couture de stockage dans
//  `RankingsSnapshotStorage.swift` et l'API de module dans
//  `RankingsSnapshotModule.swift` — le store seul reste ici.
//
//  Cible : iOS 16.
//
import Foundation

/// Enveloppe de format stocké (`{ version: 1, snapshots: [...] }`).
private struct StoredRankingsSnapshots: Encodable {
    let version: Int
    let snapshots: [RankingsSnapshotEntry]
}

/// En-tête lu du disque : `version` et `snapshots` sont optionnels pour
/// reproduire le rejet strict du RN (`version !== 1` ou tableau absent → rien).
private struct StoredRankingsSnapshotsHeader: Decodable {
    let version: Int?
    let snapshots: [Lenient<RankingsSnapshotEntry>]?
}

/// Décode un élément en avalant son échec, pour écarter une entrée corrompue
/// sans perdre les autres (`filter` du `parseStoredSnapshots` RN).
private struct Lenient<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

// MARK: - Store

/// Store des instantanés de classement (`rankingsCacheStorage.ts`).
///
/// Les écritures sont sérialisées par une file interne (analogue du
/// `writeQueue` RN) : deux rafraîchissements qui se terminent ensemble ne
/// doivent pas s'écraser.
final class RankingsSnapshotCache {
    /// Instance partagée : les instantanés sont communs à tous les écrans.
    static let shared = RankingsSnapshotCache()

    /// Une écriture sur deux suffit : une clé de cache, sa dernière réponse
    /// (`RANKINGS_SNAPSHOT_STORAGE_KEY`).
    static let storageKey = "prepapp-rankings-snapshots:v1"

    private let storage: RankingsSnapshotStorage
    private let lock = NSLock()
    private var writeTail: Task<Void, Never> = Task {}
    /// Cache mémoire (port de `subjectLeaderboardCache` /
    /// `weeklyXpLeaderboardCache` de `socialApi.ts`) : la dernière réponse
    /// validée reste affichable pendant que la réponse réseau suivante arrive,
    /// sans relire le disque.
    private var memory: [String: [LeaderboardEntry]] = [:]

    init(storage: RankingsSnapshotStorage = RankingsUserDefaultsSnapshotStorage()) {
        self.storage = storage
    }

    /// Clé mémoire : cache et clé de classement joints.
    private func memoryKey(_ cache: RankingsSnapshotCacheName, _ key: String) -> String {
        "\(cache.rawValue)|\(key)"
    }

    /// Dernier classement connu en mémoire (`cachedSubjectLeaderboard` /
    /// `cachedWeeklyXpLeaderboard`), sans attendre le réseau.
    func cachedEntries(
        _ cache: RankingsSnapshotCacheName,
        key: String
    ) -> [LeaderboardEntry]? {
        lock.lock()
        defer { lock.unlock() }
        return memory[memoryKey(cache, key)]
    }

    /// Persiste la dernière réponse validée d'un classement (échecs ignorés) :
    /// mémoire d'abord, puis disque (analogue de `socialApi.ts`, qui alimente
    /// son cache mémoire puis `saveRankingsSnapshot`).
    func save(
        _ cache: RankingsSnapshotCacheName,
        key: String,
        entries: [LeaderboardEntry]
    ) {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lock.lock()
        memory[memoryKey(cache, key)] = entries
        lock.unlock()
        enqueueWrite(
            RankingsSnapshotEntry(
                cache: cache,
                key: key,
                savedAt: Date().timeIntervalSince1970 * 1000,
                entries: entries
            )
        )
    }

    /// Dernier classement connu, mémoire puis disque
    /// (`restoreCachedSubjectLeaderboard` / `restoreCachedWeeklyXpLeaderboard`) :
    /// le premier rendu après un démarrage n'attend pas le réseau.
    func restore(
        _ cache: RankingsSnapshotCacheName,
        key: String
    ) async -> [LeaderboardEntry]? {
        if let cached = cachedEntries(cache, key: key) { return cached }
        guard let snapshots = await load() else { return nil }
        lock.lock()
        for snapshot in snapshots where memory[memoryKey(snapshot.cache, snapshot.key)] == nil {
            memory[memoryKey(snapshot.cache, snapshot.key)] = snapshot.entries
        }
        lock.unlock()
        return cachedEntries(cache, key: key)
    }

    /// Relit tous les instantanés persistés, ou `nil` si rien d'exploitable.
    func load() async -> [RankingsSnapshotEntry]? {
        guard let raw = await storage.getItem(Self.storageKey),
              let snapshots = Self.parseStored(raw),
              !snapshots.isEmpty
        else { return nil }
        return snapshots
    }

    /// Efface les instantanés, y compris une écriture en attente.
    func clear() async {
        lock.lock()
        memory.removeAll()
        lock.unlock()
        let removal = enqueue { [storage] in
            await storage.removeItem(Self.storageKey)
        }
        await removal.value
    }

    /// Chaîne une opération derrière la file d'écriture (`writeQueue`).
    @discardableResult
    private func enqueue(_ operation: @escaping () async -> Void) -> Task<Void, Never> {
        lock.lock()
        let previous = writeTail
        let next = Task {
            await previous.value
            await operation()
        }
        writeTail = next
        lock.unlock()
        return next
    }

    /// Lit, remplace l'entrée de même couple (cache, clé), puis réécrit le tout.
    private func enqueueWrite(_ snapshot: RankingsSnapshotEntry) {
        enqueue { [storage] in
            var stored: [RankingsSnapshotEntry] = []
            if let raw = await storage.getItem(Self.storageKey),
               let parsed = Self.parseStored(raw) {
                stored = parsed
            }
            stored.removeAll { $0.cache == snapshot.cache && $0.key == snapshot.key }
            stored.append(snapshot)
            guard let data = try? JSONEncoder().encode(
                StoredRankingsSnapshots(version: 1, snapshots: stored)
            ), let text = String(data: data, encoding: .utf8) else { return }
            await storage.setItem(Self.storageKey, text)
        }
    }

    /// Relit et valide le document stocké (`parseStoredSnapshots`) : tout ce qui
    /// n'est pas exactement la v1 est rejeté.
    static func parseStored(_ raw: String) -> [RankingsSnapshotEntry]? {
        guard let data = raw.data(using: .utf8),
              let header = try? JSONDecoder().decode(StoredRankingsSnapshotsHeader.self, from: data),
              header.version == 1,
              let wrapped = header.snapshots
        else { return nil }
        return wrapped.compactMap(\.value)
    }
}
