//
//  EvEventCatalog.swift
//  Duello
//
//  Catalogue des événements présentés dans l'onglet « Événements » : horaire,
//  titre et public de chaque concours blanc, plus la résolution du sujet porté
//  par un événement.
//
//  Fichiers source Expo portés :
//    - src/data/events.ts        (`upcomingEvents`)
//    - src/data/eventSubjects.ts (`eventSubjectForEvent`, relu du catalogue
//      partagé `shared/event-catalog.mjs`, porté dans `EvEventSubjectCatalog`)
//
//  Calendrier des concours blancs 2026 : les maths approfondies passent le
//  dimanche 4 octobre, les maths appliquées le dimanche 18 octobre ; chaque
//  option a un créneau par année, 16h–17h pour les 1res années et 18h–19h pour
//  les 2es années.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventCatalog {
    /// Événements du catalogue, dans l'ordre du fichier source.
    static let upcoming: [EvEvent] = [
        EvEvent(
            id: "concours-blanc-maths-appro-1a-2026-10-04",
            title: "Maths approfondies — 1re année",
            date: "2026-10-04",
            startTime: "16:00",
            endTime: "17:00",
            audience: EvEventAudience(track: "ECG", mathsOption: "approfondies", year: 1)
        ),
        EvEvent(
            id: "concours-blanc-maths-appro-2a-2026-10-04",
            title: "Maths approfondies — 2e année",
            date: "2026-10-04",
            startTime: "18:00",
            endTime: "19:00",
            audience: EvEventAudience(track: "ECG", mathsOption: "approfondies", year: 2)
        ),
        EvEvent(
            id: "concours-blanc-maths-appli-1a-2026-10-18",
            title: "Maths appliquées — 1re année",
            date: "2026-10-18",
            startTime: "16:00",
            endTime: "17:00",
            audience: EvEventAudience(track: "ECG", mathsOption: "appliquees", year: 1)
        ),
        EvEvent(
            id: "concours-blanc-maths-appli-2a-2026-10-18",
            title: "Maths appliquées — 2e année",
            date: "2026-10-18",
            startTime: "18:00",
            endTime: "19:00",
            audience: EvEventAudience(track: "ECG", mathsOption: "appliquees", year: 2)
        ),
    ]

    /// Sujet porté par un événement, ou `nil` s'il n'en a pas.
    static func subject(for eventId: String) -> EvEventSubject? {
        EvEventSubjectCatalog.all.first { $0.eventId == eventId }
    }
}
