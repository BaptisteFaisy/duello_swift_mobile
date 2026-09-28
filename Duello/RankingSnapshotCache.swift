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
//  Cible : iOS 16.
//
import Foundation

// MARK: - Modèle persisté

/// Cache de classement persistable (`RANKINGS_SNAPSHOTTED_CACHES`).
enum RankingsSnapshotCacheName: String, CaseIterable, Codable {
    case subjectLeaderboard = "subject-leaderboard"
    case weeklyXpLeaderboard = "weekly-xp-leaderboard"
}

/// Réponse d'un classement persistée pour un démarrage suivant
/// (`RankingsSnapshotEntry`).
struct RankingsSnapshotEntry: Codable, Equatable {
    let cache: RankingsSnapshotCacheName
    let key: String
    /// Millisecondes epoch, comme `Date.now()` côté RN.
    let savedAt: Double
    let entries: [LeaderboardEntry]

    /// Date de sauvegarde, pour un éventuel affichage « il y a … ».
    var savedDate: Date { Date(timeIntervalSince1970: savedAt / 1000) }

    init(
        cache: RankingsSnapshotCacheName,
        key: String,
        savedAt: Double,
        entries: [LeaderboardEntry]
    ) {
        self.cache = cache
        self.key = key
        self.savedAt = savedAt
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case cache, key, savedAt, entries
    }

    /// Format stocké : rejeter tout ce qui ne respecte pas exactement la v1
    /// (`parseStoredSnapshots`) — le décodage tolérant laisse `Lenient` écarter
    /// l'entrée sans faire échouer la relecture entière.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawCache = try container.decode(String.self, forKey: .cache)
        guard let cache = RankingsSnapshotCacheName(rawValue: rawCache) else {
            throw DecodingError.dataCorruptedError(
                forKey: .cache,
                in: container,
                debugDescription: "Cache de classement inconnu : \(rawCache)"
            )
        }
        let key = try container.decode(String.self, forKey: .key)
        let savedAt = try container.decode(Double.self, forKey: .savedAt)
        guard savedAt.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .savedAt,
                in: container,
                debugDescription: "savedAt non fini"
            )
        }
        let entries = try container.decode([LeaderboardEntry].self, forKey: .entries)
        self.init(cache: cache, key: key, savedAt: savedAt, entries: entries)
    }
}

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

// MARK: - Couture de stockage

/// Stockage clé/valeur des instantanés (analogue d'`AsyncStorage`).
protocol RankingsSnapshotStorage {
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, _ value: String) async
    func removeItem(_ key: String) async
}

/// Stockage `UserDefaults`, comme les autres préférences de l'application.
final class RankingsUserDefaultsSnapshotStorage: RankingsSnapshotStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func getItem(_ key: String) async -> String? {
        defaults.string(forKey: key)
    }

    func setItem(_ key: String, _ value: String) async {
        defaults.set(value, forKey: key)
    }

    func removeItem(_ key: String) async {
        defaults.removeObject(forKey: key)
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

// MARK: - Fonctions de module (API de `rankingsCacheStorage.ts`)

/// Persiste la dernière réponse validée d'un classement (échecs ignorés).
func saveRankingsSnapshot(
    _ cache: RankingsSnapshotCacheName,
    key: String,
    entries: [LeaderboardEntry]
) {
    RankingsSnapshotCache.shared.save(cache, key: key, entries: entries)
}

/// Relit tous les instantanés persistés, ou `nil` si rien d'exploitable.
func loadRankingsSnapshots() async -> [RankingsSnapshotEntry]? {
    await RankingsSnapshotCache.shared.load()
}

/// Dernier classement connu en mémoire, sans attendre le réseau.
func cachedRankingsSnapshotEntries(
    _ cache: RankingsSnapshotCacheName,
    key: String
) -> [LeaderboardEntry]? {
    RankingsSnapshotCache.shared.cachedEntries(cache, key: key)
}

/// Dernier classement connu, mémoire puis disque (relecture d'un démarrage).
func restoreRankingsSnapshotEntries(
    _ cache: RankingsSnapshotCacheName,
    key: String
) async -> [LeaderboardEntry]? {
    await RankingsSnapshotCache.shared.restore(cache, key: key)
}

/// Efface les instantanés : le classement repart d'une copie réseau franche.
func clearRankingsSnapshots() async {
    await RankingsSnapshotCache.shared.clear()
}
