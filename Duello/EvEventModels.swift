//
//  EvEventModels.swift
//  Duello
//
//  Modèles d'un concours blanc « Événement » : fiche du catalogue, public visé,
//  sujet (questions notées) et état local de la copie en cours.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/types.ts                  (`DuelloEvent`, `DuelloEventAudience`)
//    - src/data/events.ts            (catalogue `upcomingEvents`)
//    - src/data/eventSubjects.ts     (`EventQuestion`, `EventSubject`)
//    - src/utils/eventSchedule.ts    (`EventPhase`, `EventCountdownSegment`)
//    - src/utils/eventDrafts.ts      (`EventDraft`)
//    - src/hooks/useEventSession.ts  (`EventSubmissionState`)
//
//  Cible : iOS 16. Aucun type, propriété ni libellé renommé.
//
import Foundation

/// Événement affiché dans l'onglet « Événements » (`DuelloEvent`).
struct EvEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var description: String?
    /// Jour au format AAAA-MM-JJ, interprété dans le fuseau local.
    var date: String
    var startTime: String?
    var endTime: String?
    var location: String?
    /// Lien d'inscription ou de détail ouvert dans le navigateur.
    var linkUrl: String?
    /// Public visé ; `nil` rend l'événement visible de tout le monde.
    var audience: EvEventAudience?
}

/// Public visé par un événement, par filière et par année de programme.
struct EvEventAudience: Equatable {
    /// Filière visée (« ECG », « MP »…) ; `nil` ne filtre pas.
    var track: String?
    /// Option de mathématiques ECG visée (« approfondies » ou « appliquees »).
    var mathsOption: String?
    /// Année de programme visée (1 ou 2).
    var year: Int?
}

/// Question d'un sujet d'événement (`EventQuestion`).
struct EvEventQuestion: Identifiable, Equatable {
    var id: String
    var label: String
    var points: Int
    var statement: String
    /// Corrigé retranscrit, révélé après la fin réelle de l'événement.
    var solution: String
}

/// Sujet porté par un événement (`EventSubject`).
struct EvEventSubject: Identifiable, Equatable {
    var id: String
    var eventId: String
    var title: String
    var durationMinutes: Int
    var questions: [EvEventQuestion]
}

/// Barème d'une question tel que le serveur le renvoie
/// (`Pick<EventQuestion, 'id' | 'label' | 'points'>`).
struct EvQuestionSummary: Identifiable, Equatable {
    var id: String
    var label: String
    var points: Int
}

/// Phases d'un événement, décidées par le seul horaire affiché (`EventPhase`).
enum EvEventPhase: String, Equatable {
    case upcoming, waiting, live, finished
}

/// État d'envoi de la copie (`EventSubmissionState`).
enum EvSubmissionState: Equatable {
    case draft, submitting, submitted
}

/// Brouillon de copie persisté par compte (`EventDraft`).
struct EvDraft: Codable, Equatable {
    /// Réponses transcrites question par question.
    var answers: [String: String] = [:]
    /// Photos rendues avec la copie : jamais transcrites pendant l'épreuve.
    var photoUris: [String] = []
    /// Instant du dernier ajout, en millisecondes depuis l'époque.
    var updatedAt: Double = 0
}

/// Segment du décompte (`EventCountdownSegment`).
struct EvCountdownSegment: Identifiable, Equatable {
    var value: Int
    var unit: String
    var id: String { unit }
}
