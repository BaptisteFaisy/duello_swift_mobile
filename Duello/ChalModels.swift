//
//  ChalModels.swift
//  Duello
//
//  Lot « Extras de défi » — modèles et énumérations des extras de défi :
//  invitation reçue, état de réponse, invitation privée suivie, cible.
//
//  Fichiers source Expo portés (formes et champs repris mot pour mot) :
//    - src/utils/socialApi.ts
//      (`IncomingChallengeInvitation`, `ChallengeInvitationState`,
//       `createDirectChallengeInvitation` / `pollDirectChallengeInvitation`)
//    - src/hooks/useChallengeQueue.ts
//      (`ChallengeQueueStatus`, `ChallengeSearchMode`, `ChallengeInviteOutcome`,
//       `ActiveInvitation`, et la cible `{ id, displayName, chapterNames }`)
//
//  La lecture tolérante des invitations (champs manquants) vit dans `ChalAPI` :
//  ces modèles ne portent que des champs présents, comme après
//  `parseIncomingChallengeInvitation`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Invitation de défi reçue (`IncomingChallengeInvitation`).
struct ChalIncomingInvitation: Identifiable, Equatable {
    /// Émetteur du défi (`challenger`).
    struct Challenger: Equatable {
        var id: String
        var displayName: String
        var prepName: String
        var track: String
        var year: String
    }

    /// Réglages du défi proposé (`challenge`).
    struct Challenge: Equatable {
        var subject: String
        /// Clés complètes `<année>:<matière>:<chapitre>` des chapitres joués.
        var chapterKeys: [String]
        /// Noms affichés des chapitres joués.
        var chapterNames: [String]
        /// Durée du défi, en minutes.
        var durationMinutes: Double

        /// Durée arrondie (`Math.round(number(durationMinutes, 20))`), au moins 1.
        var minutes: Int { max(1, Int(durationMinutes.rounded())) }
        /// Clés de chapitres.
        var keys: [String] { chapterKeys }
        /// Noms de chapitres affichés.
        var names: [String] { chapterNames }
    }

    var id: String
    var challenger: Challenger
    var challenge: Challenge
    var createdAt: Double?
    var expiresAt: Double?
}

/// État d'une invitation directe (`ChallengeInvitationState`).
enum ChalInvitationState: Equatable {
    case pending
    case declined
    case unavailable
    case expired
    /// La partie est formée : à jouer telle quelle.
    case accepted(MatchView)
}

/// Décision du destinataire d'une invitation (`'accepted' | 'declined'`).
enum ChalInvitationDecision: String {
    case accepted
    case declined
}

/// Invitation créée côté émetteur (`createDirectChallengeInvitation`).
struct ChalCreatedInvitation: Equatable {
    /// `'pending'` ou `'unavailable'`.
    var state: String
    var invitationId: String
}

/// Invitation privée encore ouverte, suivie jusqu'à sa réponse
/// (`ActiveInvitation`).
struct ChalActiveInvitation: Equatable {
    var invitationId: String
    var displayName: String
}

/// Une personne invitée à un défi privé (cible de `invite`).
struct ChalInviteTarget: Equatable {
    var id: String
    var displayName: String
    var chapterNames: [String]
}
