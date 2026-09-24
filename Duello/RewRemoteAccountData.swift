//
//  RewRemoteAccountData.swift
//  Duello
//
//  Port de src/storage/remoteAccountData.ts (RN) — synchronisation distante des
//  données de compte : client des routes `GET/PUT/DELETE /account-data` et
//  `POST /account-data/batch`, résolution de la session serveur d'un compte et
//  politique des clés réellement synchronisées.
//
//  Fichiers source Expo portés (constantes, libellés et message repris mot pour
//  mot) :
//    - src/storage/remoteAccountData.ts
//        `REQUEST_TIMEOUT_MS`, `request`, `readRemoteAccountData`,
//        `MAX_BATCH_KEYS`, `BATCH_TIMEOUT_MS`, `readRemoteAccountDataBatch`,
//        `writeRemoteAccountData`, `removeRemoteAccountData`.
//    - src/utils/serverSession.ts
//        `serverSessionForAccount` (session du compte courant uniquement).
//    - src/storage/keys.ts
//        `isServerSyncedAccountKey`, `SERVER_SYNCED_EXACT_KEYS`,
//        `SERVER_SYNCED_PREFIXES`.
//
//  Seam honnête (24/09/2026) : la session serveur Swift vit dans le trousseau
//  (`SessionStore.swift`) et ne porte PAS `localAccountId`, alors que la source
//  lit `@prepapp/server-session-v1` (`AsyncStorage`) dont l'objet contient ce
//  champ. Le réseau passe par `DuelloAPI`. Les deux dépendances sont donc
//  derrière des protocoles — `RewRemoteAccountSessionProviding` et
//  `RewRemoteAccountDataTransport` — avec une implémentation par défaut qui lit
//  la clé RN (`DevRegSessions.serverSessionStorageKey`) et un transport
//  `URLSession`. Tant que `SessionStore` n'écrit pas cette clé,
//  `serverSessionForAccount` répond `nil` (jamais le jeton d'un autre compte) :
//  aucune donnée ne part vers l'API tant que le câblage n'est pas fait. Voir
//  `wiring/U8.md`.
//
//  Limites assumées (24/09/2026) : `request` de la source n'utilise pas la
//  couche `DuelloAPI` (dont `DirectoryError` imposerait un autre message) — le
//  message exact `Synchronisation Duello refusée (<status>).` est conservé via
//  `RewRemoteAccountDataError`. Le décodage `{ item?: { value } | null }` reste
//  inchangé.
//
//
//  Découpage (24/09/2026) : ce fichier porte les erreurs, les charges utiles et
//  le client `/account-data`. La session serveur vit dans
//  `RewRemoteAccountData+Session.swift`, le transport HTTP dans
//  `RewRemoteAccountData+Transport.swift`, le lot dans
//  `RewRemoteAccountData+Batch.swift` et la politique des clés dans
//  `RewRemoteAccountData+SyncedKeys.swift`.
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Erreurs

/// Erreur réseau du client `/account-data`, alignée sur le message de la source.
enum RewRemoteAccountDataError: LocalizedError, Equatable {
    /// `Synchronisation Duello refusée (${response.status}).`
    case syncRefused(status: Int)

    var errorDescription: String? {
        switch self {
        case .syncRefused(let status):
            return "Synchronisation Duello refusée (\(status))."
        }
    }
}

// MARK: - Charge utile

/// `{ item?: { value: string } | null }` de `request`.
private struct RewRemoteAccountDataPayload: Decodable {
    struct Item: Decodable { var value: String }
    var item: Item?
}

/// Corps `JSON.stringify({ value })` d'une écriture (`PUT`).
private struct RewRemoteAccountDataPutBody: Encodable { var value: String }

// MARK: - Client

/// `remoteAccountData.ts` : lecture/écriture distante des données d'un compte.
enum RewRemoteAccountData {
    /// `REQUEST_TIMEOUT_MS`.
    static let requestTimeout: TimeInterval = 4
    /// `MAX_BATCH_KEYS`.
    static let maxBatchKeys = 40
    /// `BATCH_TIMEOUT_MS`.
    static let batchTimeout: TimeInterval = 6

    /// `serverSessionForAccount` : une portée purement locale n'a jamais de
    /// session ; sinon la session n'est servie que pour son propre compte.
    static func serverSessionForAccount(
        _ accountId: String,
        provider: RewRemoteAccountSessionProviding = RewUserDefaultsAccountSessionProvider()
    ) -> RewRemoteAccountSession? {
        if RewStorageScope.isLocalOnlyDemoAccountId(accountId) { return nil }
        return provider.session(forAccountId: accountId)
    }

    /// `readRemoteAccountData` : valeur distante d'une clé, ou `nil` (session
    /// absente ou valeur inexistante). Un refus serveur lève une erreur.
    static func readRemoteAccountData(
        accountId: String,
        key: String,
        provider: RewRemoteAccountSessionProviding = RewUserDefaultsAccountSessionProvider(),
        transport: RewRemoteAccountDataTransport = RewURLSessionAccountDataTransport()
    ) async throws -> String? {
        let payload = try await request(
            accountId: accountId, key: key, method: "GET", value: nil,
            provider: provider, transport: transport
        )
        return payload?.item?.value
    }

    /// `writeRemoteAccountData` : pose la valeur distante d'une clé.
    static func writeRemoteAccountData(
        accountId: String,
        key: String,
        value: String,
        provider: RewRemoteAccountSessionProviding = RewUserDefaultsAccountSessionProvider(),
        transport: RewRemoteAccountDataTransport = RewURLSessionAccountDataTransport()
    ) async throws {
        _ = try await request(
            accountId: accountId, key: key, method: "PUT", value: value,
            provider: provider, transport: transport
        )
    }

    /// `removeRemoteAccountData` : efface la valeur distante d'une clé.
    static func removeRemoteAccountData(
        accountId: String,
        key: String,
        provider: RewRemoteAccountSessionProviding = RewUserDefaultsAccountSessionProvider(),
        transport: RewRemoteAccountDataTransport = RewURLSessionAccountDataTransport()
    ) async throws {
        _ = try await request(
            accountId: accountId, key: key, method: "DELETE", value: nil,
            provider: provider, transport: transport
        )
    }

    /// `request` : un aller-retour pour une clé. Sans session, ne fait rien et
    /// renvoie `nil` ; un refus serveur devient `syncRefused`.
    private static func request(
        accountId: String,
        key: String,
        method: String,
        value: String?,
        provider: RewRemoteAccountSessionProviding,
        transport: RewRemoteAccountDataTransport
    ) async throws -> RewRemoteAccountDataPayload? {
        guard let session = serverSessionForAccount(accountId, provider: provider) else {
            return nil
        }
        let body = method == "PUT"
            ? try JSONEncoder().encode(RewRemoteAccountDataPutBody(value: value ?? ""))
            : nil
        do {
            let data = try await transport.send(
                path: "account-data",
                method: method,
                token: session.token,
                query: [URLQueryItem(name: "key", value: key)],
                body: body,
                timeout: requestTimeout
            )
            return try JSONDecoder().decode(RewRemoteAccountDataPayload.self, from: data)
        } catch let error as RewRemoteHTTPError {
            throw RewRemoteAccountDataError.syncRefused(status: error.status)
        }
    }
}
