//
//  ChalAPI.swift
//  Duello
//
//  Lot « Extras de défi » — points d'entrée réseau des invitations de défi.
//
//  Fichiers source Expo portés (chemins, méthodes et corps repris mot pour mot) :
//    - src/utils/socialApi.ts
//      (`fetchIncomingChallengeInvitations`, `respondToDirectChallengeInvitation`,
//       `createDirectChallengeInvitation`, `pollDirectChallengeInvitation`,
//       `cancelDirectChallengeInvitation`, `fetchRemoteCorrectionQuota`,
//       `parseChallengeInvitationState`, `parseIncomingChallengeInvitation`)
//
//  Endpoints absents de `DuelloAPI.swift` : ils vivent ici en helpers locaux,
//  `DuelloAPI.swift` n'étant jamais modifié. Aucune réponse douteuse n'est
//  inventée : un état illisible vaut `expired`, un quota illisible lève une
//  erreur (`correctionQuotaFromResponse`), une invitation illisible est écartée
//  (`parseIncomingChallengeInvitation` renvoie `null`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Invitations de défi (`socialApi.ts`).
enum ChalAPI {
    /// Forme brute d'une invitation, tous les champs optionnels
    /// (`parseIncomingChallengeInvitation`).
    private struct RawInvitation: Decodable {
        struct Challenger: Decodable {
            var id: String?
            var displayName: String?
            var prepName: String?
            var track: String?
            var year: String?
        }
        struct Challenge: Decodable {
            var subject: String?
            var chapterKeys: [String]?
            var chapterNames: [String]?
            var durationMinutes: Double?
        }
        var id: String?
        var challenger: Challenger?
        var challenge: Challenge?
        var createdAt: Double?
        var expiresAt: Double?
    }

    /// Enveloppe de `GET /challenge-invitations?userId=…`.
    private struct IncomingEnvelope: Decodable {
        var invitations: [RawInvitation]?
    }

    /// Enveloppe d'une invitation créée (`POST /challenge-invitations`).
    private struct CreatedEnvelope: Decodable {
        var state: String?
        var invitationId: String?
    }

    /// Enveloppe d'un état d'invitation (`ChallengeInvitationState`).
    private struct StateEnvelope: Decodable {
        var state: String?
        var match: MatchView?
    }

    /// Enveloppe du quota de corrections : `{ "quota": { "allowed": … } }`.
    private struct QuotaEnvelope: Decodable {
        struct Quota: Decodable { var allowed: Bool? }
        var quota: Quota?
    }

    private struct RespondBody: Encodable {
        var invitationId: String
        var userId: String
        var decision: String
        var target: QueueRequest?
    }

    private struct CreateBody: Encodable {
        var challenger: QueueRequest
        var targetId: String
        var chapterNames: [String]
    }

    /// Relève les invitations du compte ; `busy` interdit toute apparition.
    static func fetchIncoming(
        email: String,
        busy: Bool,
        token: String?
    ) async throws -> [ChalIncomingInvitation] {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let userId = DuelloAPI.publicProfileId(email: trimmed)
        let data = try await DuelloAPI.request(
            "challenge-invitations",
            token: token,
            query: [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "busy", value: busy ? "true" : "false"),
            ]
        )
        let envelope = try? DuelloAPI.decoder.decode(IncomingEnvelope.self, from: data)
        return (envelope?.invitations ?? []).compactMap { invitation(from: $0) }
    }

    /// Accepte ou refuse l'invitation affichée au destinataire.
    static func respond(
        invitationId: String,
        userId: String,
        decision: ChalInvitationDecision,
        target: QueueRequest?,
        token: String?
    ) async throws -> ChalInvitationState {
        let body = try DuelloAPI.encodeBody(RespondBody(
            invitationId: invitationId,
            userId: userId,
            decision: decision.rawValue,
            target: target
        ))
        let data = try await DuelloAPI.request(
            "challenge-invitations",
            method: "PUT",
            token: token,
            body: body
        )
        return state(from: data)
    }

    /// Crée une invitation directe pour un profil inscrit.
    static func create(
        challenger: QueueRequest,
        targetId: String,
        chapterNames: [String],
        token: String?
    ) async throws -> ChalCreatedInvitation {
        let body = try DuelloAPI.encodeBody(CreateBody(
            challenger: challenger,
            targetId: targetId,
            chapterNames: chapterNames
        ))
        let envelope = try await DuelloAPI.request(
            CreatedEnvelope.self,
            "challenge-invitations",
            method: "POST",
            token: token,
            body: body
        )
        guard let id = envelope.invitationId, let state = envelope.state else {
            throw DirectoryError(message: "Réponse d’invitation illisible")
        }
        return ChalCreatedInvitation(state: state, invitationId: id)
    }

    /// Prend des nouvelles de l'acceptation côté émetteur.
    static func poll(
        invitationId: String,
        userId: String,
        token: String?
    ) async throws -> ChalInvitationState {
        let data = try await DuelloAPI.request(
            "challenge-invitations",
            token: token,
            query: [
                URLQueryItem(name: "invitationId", value: invitationId),
                URLQueryItem(name: "userId", value: userId),
            ]
        )
        return state(from: data)
    }

    /// Retire une invitation lorsque l'émetteur annule son attente.
    static func cancel(invitationId: String, userId: String, token: String?) async {
        _ = try? await DuelloAPI.request(
            "challenge-invitations",
            method: "DELETE",
            token: token,
            query: [
                URLQueryItem(name: "invitationId", value: invitationId),
                URLQueryItem(name: "userId", value: userId),
            ]
        )
    }

    /// Vrai si le compte peut encore lancer un défi
    /// (`fetchRemoteCorrectionQuota` → `access.allowed`). Une réponse douteuse
    /// lève, jamais ne devine.
    static func correctionQuotaAllows(userId: String, token: String?) async throws -> Bool {
        let data = try await DuelloAPI.request(
            "correction-quota",
            token: token,
            query: [URLQueryItem(name: "userId", value: userId)]
        )
        guard let envelope = try? DuelloAPI.decoder.decode(QuotaEnvelope.self, from: data),
              let allowed = envelope.quota?.allowed else {
            throw DirectoryError(message: "Réponse de quota de défis illisible")
        }
        return allowed
    }

    // MARK: Lecture tolérante

    /// Met en forme une invitation brute, ou `nil` si elle est illisible
    /// (`parseIncomingChallengeInvitation`).
    private static func invitation(from raw: RawInvitation) -> ChalIncomingInvitation? {
        guard let id = text(raw.id),
              let challenger = raw.challenger,
              let challengerId = text(challenger.id),
              let displayName = text(challenger.displayName),
              let challenge = raw.challenge,
              let subject = text(challenge.subject) else {
            return nil
        }
        return ChalIncomingInvitation(
            id: id,
            challenger: ChalIncomingInvitation.Challenger(
                id: challengerId,
                displayName: displayName,
                prepName: text(challenger.prepName) ?? "",
                track: text(challenger.track) ?? "",
                year: text(challenger.year) ?? ""
            ),
            challenge: ChalIncomingInvitation.Challenge(
                subject: subject,
                chapterKeys: (challenge.chapterKeys ?? []).filter { !$0.isEmpty },
                chapterNames: (challenge.chapterNames ?? []).filter { !$0.isEmpty },
                durationMinutes: max(1, challenge.durationMinutes ?? 20)
            ),
            createdAt: raw.createdAt,
            expiresAt: raw.expiresAt
        )
    }

    /// Relit un état d'invitation ; tout ce qui n'est pas lisible vaut `expired`
    /// (`parseChallengeInvitationState`).
    private static func state(from data: Data) -> ChalInvitationState {
        guard let envelope = try? DuelloAPI.decoder.decode(StateEnvelope.self, from: data) else {
            return .expired
        }
        switch envelope.state {
        case "accepted":
            return envelope.match.map { ChalInvitationState.accepted($0) } ?? .expired
        case "pending": return .pending
        case "declined": return .declined
        case "unavailable": return .unavailable
        default: return .expired
        }
    }

    /// Chaîne nettoyée, `nil` si vide (`text()` de `socialApi.ts`).
    private static func text(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
