//
//  ReportPublicProfilePublisher+GuestSession.swift
//  Duello
//
//  Port de src/utils/serverSession.ts (RN) — `ensureGuestServerSession` : guards
//  d'identité invitée, réutilisation de la session existante, `POST /auth/guest`
//  puis enregistrement.
//
//  Découpage (24/09/2026) : section extraite de
//  `ReportPublicProfilePublisher.swift` (porté du même fichier source).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

// MARK: - Session invitée

/// `ensureGuestServerSession` (`serverSession.ts`) : garantit qu'un invité
/// dispose d'une session serveur, en réutilisant celle du compte si elle existe.
enum ReportGuestSession {

    /// Guards d'identité invariants de la source, appliqués avant tout réseau.
    static func validate(email: String, accountId: String) throws {
        guard RewStorageScope.isGuestEmail(email) else {
            throw ReportPublicProfileError.invalidGuestIdentity
        }
        guard !RewStorageScope.isLocalOnlyDemoAccountId(accountId),
              !RewStorageScope.isLocalOnlyDemoEmail(email) else {
            throw ReportPublicProfileError.localOnlyDemoAccount
        }
    }

    /// `ensureGuestServerSession` : session existante du compte, sinon
    /// `POST /auth/guest` puis enregistrement.
    static func ensure(
        accountId: String,
        email: String,
        registry: ReportServerSessionRegistry
    ) async throws -> ServerSession {
        try validate(email: email, accountId: accountId)
        if let existing = await registry.session(forAccount: accountId) { return existing }

        let body = try DuelloAPI.encodeBody(["email": email])
        let envelope = try await DuelloAPI.request(
            ReportGuestSessionEnvelope.self,
            "auth/guest",
            method: "POST",
            body: body
        )
        guard let payload = envelope.session else {
            throw ReportPublicProfileError.guestSessionUnavailable(
                envelope.error ?? "Participation invitée momentanément indisponible."
            )
        }
        let session = ServerSession(
            token: payload.token,
            expiresAt: payload.expiresAt,
            publicId: payload.publicId,
            email: payload.email.isEmpty ? email : payload.email
        )
        try await registry.save(session, forAccount: accountId)
        return session
    }
}

/// Enveloppe de `POST /auth/guest` (`{ session?, error? }`).
private struct ReportGuestSessionEnvelope: Decodable {
    var session: DuelloAPI.SessionPayload?
    var error: String?
}

/// Adaptateur de `ReportGuestSession` vers la couture `ReportGuestSessionEnsuring`.
struct ReportGuestSessionEnsurer: ReportGuestSessionEnsuring {
    let registry: ReportServerSessionRegistry

    func ensure(accountId: String, email: String) async throws -> ServerSession {
        try await ReportGuestSession.ensure(
            accountId: accountId,
            email: email,
            registry: registry
        )
    }
}
