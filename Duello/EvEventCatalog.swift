//
//  EvEventCatalog.swift
//  Duello
//
//  Catalogue des événements présentés dans l'onglet « Événements » : horaire,
//  titre, description, public de chaque concours blanc, plus la résolution du
//  sujet porté par un événement.
//
//  Fichiers source Expo portés :
//    - src/data/events.ts        (`upcomingEvents`, repris événement par
//      événement, dans l'ordre du fichier)
//    - src/data/eventSubjects.ts (`eventSubjectForEvent`, relu du catalogue
//      partagé `shared/event-catalog.mjs`, porté dans `EvEventSubjectCatalog`)
//
//  Calendrier des concours blancs 2026 : les maths approfondies passent le
//  dimanche 4 octobre, les maths appliquées le dimanche 18 octobre ; chaque
//  option a un créneau par année, 16h–17h pour les 1res années et 18h–19h pour
//  les 2es années. S'y ajoutent quatre défis test 22h/minuit (sans public :
//  visibles de tous les comptes) : soustractions faciles le 29/09 à 22h00,
//  multiplications faciles le 30/09 à 00h00, divisions faciles le 30/09 à
//  22h00 et opérations mixtes faciles le 01/10 à 00h00. Les anciens créneaux
//  de test (oral ESCP du 21/09, `evenementTEST` des 23-24/09, dix additions du
//  27/09) ont été retirés du catalogue le 30/09/2026.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventCatalog {
    /// Événements du catalogue, dans l'ordre du fichier source.
    static let upcoming: [EvEvent] = [
        // ——— Dimanche 4 octobre 2026 : maths approfondies ———
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
        // ——— Dimanche 18 octobre 2026 : maths appliquées ———
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
        // ——— Mardi 29 septembre 2026 : défi test 22h00 (visible de tous) ———
        // Sans `audience` : visible de tous les comptes.
        EvEvent(
            id: "test-soustractions-22h00-2026-09-29",
            title: "Soustractions faciles",
            description: "Defi test de 5 minutes : soustractions faciles.",
            date: "2026-09-29",
            startTime: "22:00",
            endTime: "22:05"
        ),
        // ——— Mercredi 30 septembre 2026 : défi test 00h00 (visible de tous) ———
        EvEvent(
            id: "test-multiplications-00h00-2026-09-30",
            title: "Multiplications faciles",
            description: "Defi test de 5 minutes : multiplications faciles.",
            date: "2026-09-30",
            startTime: "00:00",
            endTime: "00:05"
        ),
        // ——— Mercredi 30 septembre 2026 : défi test 22h00 (visible de tous) ———
        EvEvent(
            id: "test-divisions-22h00-2026-09-30",
            title: "Divisions faciles",
            description: "Defi test de 5 minutes : divisions faciles.",
            date: "2026-09-30",
            startTime: "22:00",
            endTime: "22:05"
        ),
        // ——— Jeudi 1er octobre 2026 : défi test 00h00 (visible de tous) ———
        EvEvent(
            id: "test-operations-mixtes-00h00-2026-10-01",
            title: "Operations mixtes faciles",
            description: "Defi test de 5 minutes : additions, soustractions, multiplications.",
            date: "2026-10-01",
            startTime: "00:00",
            endTime: "00:05"
        ),
    ]

    /// Sujet porté par un événement, ou `nil` s'il n'en a pas.
    static func subject(for eventId: String) -> EvEventSubject? {
        EvEventSubjectCatalog.all.first { $0.eventId == eventId }
    }
}
