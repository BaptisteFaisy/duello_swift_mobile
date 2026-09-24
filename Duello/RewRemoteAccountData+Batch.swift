//
//  RewRemoteAccountData+Batch.swift
//  Duello
//
//  Port de src/storage/remoteAccountData.ts (RN) — `readRemoteAccountDataBatch` :
//  lecture de plusieurs clés en un aller-retour, par pages de `MAX_BATCH_KEYS`.
//
//  Découpage (24/09/2026) : section extraite de `RewRemoteAccountData.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Charges utiles du lot

/// `{ items?: { key: string; value: string | null }[] }` du lot.
private struct RewRemoteAccountDataBatchPayload: Decodable {
    struct Item: Decodable {
        var key: String
        var value: String?
    }
    var items: [Item]?
}

/// Corps `JSON.stringify({ keys })` d'un lot (`POST /account-data/batch`).
private struct RewRemoteAccountDataBatchBody: Encodable { var keys: [String] }

// MARK: - Lot

extension RewRemoteAccountData {
    /// `readRemoteAccountDataBatch` : lit plusieurs clés en un aller-retour,
    /// par pages de `MAX_BATCH_KEYS`. Toute panne (réseau, serveur ancien sans
    /// route lot) résout chaque clé à `nil` : le lecteur retombe sur sa copie
    /// locale, comme en mode hors ligne.
    static func readRemoteAccountDataBatch(
        accountId: String,
        keys: [String],
        provider: RewRemoteAccountSessionProviding = RewUserDefaultsAccountSessionProvider(),
        transport: RewRemoteAccountDataTransport = RewURLSessionAccountDataTransport()
    ) async -> [String?] {
        if keys.isEmpty { return [] }
        if keys.count > maxBatchKeys {
            return await readInPages(
                accountId: accountId, keys: keys, provider: provider, transport: transport
            )
        }
        guard let session = serverSessionForAccount(accountId, provider: provider) else {
            return keys.map { _ in nil }
        }
        return await sendBatch(
            keys: keys, session: session, transport: transport
        )
    }

    /// Découpe une liste trop longue en pages de `MAX_BATCH_KEYS`, puis
    /// concatène les résultats dans l'ordre des clés.
    private static func readInPages(
        accountId: String,
        keys: [String],
        provider: RewRemoteAccountSessionProviding,
        transport: RewRemoteAccountDataTransport
    ) async -> [String?] {
        var values: [String?] = []
        var index = 0
        while index < keys.count {
            let upper = min(index + maxBatchKeys, keys.count)
            let page = Array(keys[index..<upper])
            values += await readRemoteAccountDataBatch(
                accountId: accountId, keys: page, provider: provider, transport: transport
            )
            index += maxBatchKeys
        }
        return values
    }

    /// `POST /account-data/batch` pour une page ; toute erreur rend `nil` partout.
    private static func sendBatch(
        keys: [String],
        session: RewRemoteAccountSession,
        transport: RewRemoteAccountDataTransport
    ) async -> [String?] {
        do {
            let body = try JSONEncoder().encode(RewRemoteAccountDataBatchBody(keys: keys))
            let data = try await transport.send(
                path: "account-data/batch",
                method: "POST",
                token: session.token,
                query: [],
                body: body,
                timeout: batchTimeout
            )
            let payload = try JSONDecoder().decode(RewRemoteAccountDataBatchPayload.self, from: data)
            var valuesByKey: [String: String?] = [:]
            for item in payload.items ?? [] { valuesByKey[item.key] = item.value }
            return keys.map { valuesByKey[$0] ?? nil }
        } catch {
            return keys.map { _ in nil }
        }
    }
}
