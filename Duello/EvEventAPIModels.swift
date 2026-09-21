//
//  EvEventAPIModels.swift
//  Duello
//
//  Types partagés de l'API événement : verdict par question, copie d'un
//  participant, ligne de classement, inscription en salle d'attente, état de
//  correction et compteurs d'interactions.
//
//  Fichier source Expo porté : `src/utils/eventTypes.ts`.
//
//  Cible : iOS 16. Aucun champ renommé.
//
import Foundation

/// Verdict du correcteur pour une question (`EventQuestionVerdict`).
enum EvQuestionVerdict: String, Equatable {
    case perfect, correct, partial, incorrect
}

/// Question corrigée par le relais, avec son compte rendu
/// (`EventQuestionResult` de `src/utils/eventTypes.ts`). Le corrigé officiel
/// n'est pas porté ici : il vient du sujet du catalogue, jamais de la copie.
struct EvQuestionResult: Equatable {
    var verdict: EvQuestionVerdict
    var feedback: String
}

/// Copie d'un participant, telle que stockée et corrigée côté serveur
/// (`EventParticipation`).
struct EvParticipation: Equatable {
    var eventId: String
    var displayName: String
    /// Réponses transcrites question par question (les photos sont séparées).
    var answers: [String: String]
    /// Photos rendues avec la copie : jamais transcrites pendant l'épreuve.
    var photoUris: [String]
    var submittedAt: Double?
    /// Vrai dès que la correction a tourné ; la note devient alors visible.
    var graded: Bool
    var score: Double?
    var results: [String: EvQuestionResult]?
    var xpAwarded: Int
    var eloDelta: Double?
}

/// Ligne du classement publié d'un événement (`EventLeaderboardEntry`).
struct EvLeaderboardEntry: Identifiable, Equatable {
    var id: String
    var displayName: String
    var score: Double
    var rank: Int
    var eloDelta: Double
    var xpAwarded: Int
    var photoUri: String?
}

/// Réponse du serveur à une inscription en salle d'attente (`EventJoinState`).
struct EvJoinState: Equatable {
    var eventId: String
    var participants: Int
}

/// État de correction de l'événement et classement éventuellement publié
/// (`EventResultsState`).
struct EvResultsState: Equatable {
    var eventId: String
    var finished: Bool
    var participants: Int
    var gradedParticipants: Int
    var own: EvParticipation?
    var leaderboard: [EvLeaderboardEntry]?
    /// Corrigé officiel dévoilé seulement après la fin réelle de l'épreuve.
    var solutionsAvailable: Bool
    var questions: [EvQuestionSummary]
}

/// Compteurs d'interactions d'un événement (`EventInteractionCounts`).
struct EvInteractionCounts: Equatable {
    /// Personnes ayant ouvert l'événement depuis la section Événements.
    var viewers: Int
    /// Personnes ayant partagé l'événement au moins une fois.
    var shares: Int
}
