//
//  ReportPublicProfileSeams.swift
//  Duello
//
//  Port de src/components/PublicProfilePublisher.tsx (RN) — coutures du
//  coordinateur de publication du profil public.
//
//  Fichiers source Expo portés :
//    - src/storage/AccountStorage.tsx — `subscribeToAccountStorage`,
//      `notifyAccountStorageChanged` (bus de changement par compte) ;
//    - src/utils/publicProfileSnapshot.ts — forme de `PublicProfileSnapshot`
//      (`performance`, `details`, `xpAwards`, `premium`) et
//      `loadPublicProfileSnapshot` ;
//    - src/utils/serverSession.ts — `serverSessionForAccount`,
//      `saveServerSession` (registre de session serveur) ;
//    - src/utils/socialApi.ts — `publishSocialProfile` (déjà porté par
//      `ReportPublicProfile.publish`, ReportAPI.swift:127).
//
//  Doctrine « seam honnête » (SPEC §5) : les dépendances natives encore absentes
//  (instantané public complet, registre multi-comptes de sessions serveur) sont
//  des protocoles dont l'implémentation par défaut REFUSE clairement — jamais un
//  stub muet. Le bus de stockage, lui, est réellement fonctionnel.
//
//  Notes datées :
//    - 2026-09-24 — création (vague 2, unité U9).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Instantané public

/// `PublicProfileSnapshot` : toutes les données publiques d'un compte, tirées
/// d'une seule photographie locale. Les séries détaillées ne sont pas portées
/// (voir `ReportUnwiredSnapshotProvider`).
struct ReportPublicProfileSnapshot {
    var performance: ReportPublicPerformance
    var details: ReportPublicProfileDetails?
    /// Journal d'attribution XP (`xpAwards`), toujours vide côté téléphone.
    var xpAwards: [String]
    /// Abonnement en cours : seule information de paiement rendue publique.
    var premium: Bool

    init(
        performance: ReportPublicPerformance,
        details: ReportPublicProfileDetails? = nil,
        xpAwards: [String] = [],
        premium: Bool = false
    ) {
        self.performance = performance
        self.details = details
        self.xpAwards = xpAwards
        self.premium = premium
    }
}

// MARK: - Erreurs

/// Erreurs du coordinateur ; messages repris mot pour mot de la source quand ils
/// en viennent.
enum ReportPublicProfileError: LocalizedError, Equatable {
    /// `serverSession.ts` : `Identité invitée invalide.`
    case invalidGuestIdentity
    /// `serverSession.ts` : le compte de démonstration reste local au téléphone.
    case localOnlyDemoAccount
    /// `serverSession.ts` : `Participation invitée momentanément indisponible.`
    case guestSessionUnavailable(String)
    /// Couture non branchée : registre multi-comptes de sessions serveur absent.
    case serverSessionRegistryUnavailable
    /// Couture non branchée : instantané public complet non porté.
    case snapshotUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidGuestIdentity:
            return "Identité invitée invalide."
        case .localOnlyDemoAccount:
            return "Le compte de démonstration reste local au téléphone virtuel."
        case .guestSessionUnavailable(let message):
            return message
        case .serverSessionRegistryUnavailable:
            return "Le registre de sessions serveur par compte n’est pas encore porté sur iOS."
        case .snapshotUnavailable(let message):
            return message
        }
    }
}

// MARK: - Bus de changement de stockage

/// Jeton d'annulation rendu par `ReportPublicProfileStorageBus.subscribe`.
///
/// Combine (`AnyCancellable`) n'est pas disponible ici — l'abonnement réel passe
/// par `NotificationCenter.addObserver(forName:object:queue:using:)`, dont le
/// jeton d'annulation (`NSObjectProtocol`) est enveloppé localement.
protocol ReportSubscription {
    /// Détache l'écouteur de la source ; idempotent.
    func cancel()
}

/// `subscribeToAccountStorage` : notifie les écritures d'un compte. Couture
/// explicite : `AccountStorage` (Expo) n'a pas d'équivalent Swift unique.
protocol ReportPublicProfileStorageBus: AnyObject {
    /// Abonne un écouteur aux clés logiques écrites pour ce compte. L'objet
    /// rendu annule l'abonnement.
    func subscribe(
        accountId: String,
        _ listener: @escaping @Sendable ([String]) -> Void
    ) -> ReportSubscription
}

/// Bus réel, en mémoire, diffusé par `NotificationCenter`. La couche de stockage
/// annonce ses écritures via `post(accountId:logicalKeys:)` (voir wiring/U9.md) ;
/// un compte sans producteur branché n'émet simplement rien, sans erreur.
final class ReportNotificationStorageBus: ReportPublicProfileStorageBus {
    /// Nom de la notification de changement (`notifyAccountStorageChanged`).
    static let didChangeNotification = Notification.Name("ReportPublicProfileStorageDidChange")
    /// Clé `userInfo` de l'identifiant de compte.
    static let accountIdKey = "accountId"
    /// Clé `userInfo` des clés logiques écrites.
    static let logicalKeysKey = "logicalKeys"

    func subscribe(
        accountId: String,
        _ listener: @escaping @Sendable ([String]) -> Void
    ) -> ReportSubscription {
        let token = NotificationCenter.default.addObserver(
            forName: Self.didChangeNotification,
            object: nil,
            queue: .main
        ) { note in
            guard note.userInfo?[Self.accountIdKey] as? String == accountId else { return }
            guard let keys = note.userInfo?[Self.logicalKeysKey] as? [String] else { return }
            listener(keys)
        }
        return ReportNotificationSubscription(token: token)
    }

    /// `notifyAccountStorageChanged` : annonce les clés logiques écrites pour un
    /// compte. À appeler par la couche de stockage après chaque écriture.
    static func post(accountId: String, logicalKeys: [String]) {
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: [accountIdKey: accountId, logicalKeysKey: logicalKeys]
        )
    }
}

/// `ReportSubscription` adossée à un observateur `NotificationCenter` :
/// `cancel()` retire l'observateur, ce qui suffit à l'idempotence (retirer deux
/// fois le même jeton est sans effet).
private final class ReportNotificationSubscription: ReportSubscription {
    private let token: NSObjectProtocol

    init(token: NSObjectProtocol) {
        self.token = token
    }

    func cancel() {
        NotificationCenter.default.removeObserver(token)
    }
}

// MARK: - Lecture de l'instantané

/// `loadPublicProfileSnapshot` : relit toutes les sources du compte avant une
/// publication distante. Couture : le port Swift de ces sources (activité,
/// progression, cotes, séries) appartient aux lots graphiques/données.
protocol ReportPublicProfileSnapshotProviding {
    func load(
        accountId: String,
        profile: UserProfile,
        registeredAt: Double
    ) async throws -> ReportPublicProfileSnapshot
}

/// Implémentation par défaut : refuse clairement plutôt que de publier des
/// statistiques de repli (`FALLBACK_PUBLIC_PERFORMANCE`) qui écraseraient les
/// valeurs réelles déjà présentes dans l'annuaire.
struct ReportUnwiredSnapshotProvider: ReportPublicProfileSnapshotProviding {
    func load(
        accountId: String,
        profile: UserProfile,
        registeredAt: Double
    ) async throws -> ReportPublicProfileSnapshot {
        throw ReportPublicProfileError.snapshotUnavailable(
            "L’instantané public complet n’est pas encore porté sur iOS."
        )
    }
}

// MARK: - Registre de session serveur

/// `serverSessionForAccount` / `saveServerSession` : session serveur propre à un
/// compte local. La source tient un registre multi-comptes
/// (`serverSessionRegistry`) ; le port Swift n'a qu'une session courante
/// (`SessionStore`), d'où la couture.
protocol ReportServerSessionRegistry {
    func session(forAccount accountId: String) async -> ServerSession?
    func save(_ session: ServerSession, forAccount accountId: String) async throws
}

/// Implémentation par défaut : refuse clairement l'enregistrement (aucun registre
/// multi-comptes n'est porté), sans échouer en silence.
struct ReportUnwiredServerSessionRegistry: ReportServerSessionRegistry {
    func session(forAccount accountId: String) async -> ServerSession? { nil }

    func save(_ session: ServerSession, forAccount accountId: String) async throws {
        throw ReportPublicProfileError.serverSessionRegistryUnavailable
    }
}

// MARK: - Session invitée

/// `ensureGuestServerSession` : garantit une session serveur à un invité.
protocol ReportGuestSessionEnsuring {
    @discardableResult
    func ensure(accountId: String, email: String) async throws -> ServerSession
}

/// Implémentation par défaut : refuse clairement, faute de registre de sessions
/// serveur par compte (voir `ReportUnwiredServerSessionRegistry`).
struct ReportUnwiredGuestSessions: ReportGuestSessionEnsuring {
    func ensure(accountId: String, email: String) async throws -> ServerSession {
        throw ReportPublicProfileError.serverSessionRegistryUnavailable
    }
}

// MARK: - Publication

/// `publishSocialProfile` : `PUT /profiles`. Couture fine autour de
/// `ReportPublicProfile.publish` (déjà porté) pour l'injection dans le
/// coordinateur.
protocol ReportPublicProfilePublishing {
    func publish(
        _ payload: ReportPublicProfilePayload,
        token: String?
    ) async -> ReportDirectoryPublication
}

/// Implémentation réelle : délègue au client local déjà porté.
struct ReportLiveProfilePublisher: ReportPublicProfilePublishing {
    func publish(
        _ payload: ReportPublicProfilePayload,
        token: String?
    ) async -> ReportDirectoryPublication {
        await ReportPublicProfile.publish(payload, token: token)
    }
}
