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
//  les 2es années. S'y ajoutent l'événement test d'oral ESCP (21/09, sans
//  public) et les créneaux de test `evenementTEST` des 23 (20h00) et 24
//  (15h00) septembre, un par filière.
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
        // ——— Lundi 21 septembre 2026 : événement test (oral ESCP, algèbre) ———
        // Sans public : visible de tous les comptes, comme un vrai défi ouvert.
        EvEvent(
            id: "test-oral-escp-algebre-2026-09-21",
            title: "Test — Oral ESCP : algèbre",
            description: "Question sans préparation n° 1 des annales ESCP 2024. Défi test de 10 minutes.",
            date: "2026-09-21",
            startTime: "23:00",
            endTime: "23:10"
        ),
        // ——— Mercredi 23 septembre 2026 : evenementTEST 20h00, toutes filières ———
        testEvent("mpsi", "MPSI", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("mp2i", "MP2I", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("pcsi", "PCSI", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("ptsi", "PTSI", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("mp", "MP", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("mpi", "MPI", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("pc", "PC", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("pt", "PT", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("psi", "PSI", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("bcpst", "BCPST", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("bl", "B/L", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("ecg", "ECG", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        testEvent("lycee", "Lycée", "2026-09-23", start: "20:00", end: "20:10", slot: "20h00"),
        // ——— Jeudi 24 septembre 2026 : evenementTEST 15h00, filières prépa ———
        testEvent("bcpst", "BCPST", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("bl", "B/L", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("ecg", "ECG", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("mp", "MP", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("mp2i", "MP2I", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("mpi", "MPI", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("mpsi", "MPSI", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("pc", "PC", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("pcsi", "PCSI", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("psi", "PSI", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("pt", "PT", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
        testEvent("ptsi", "PTSI", "2026-09-24", start: "15:00", end: "15:10", slot: "15h00"),
    ]

    /// Sujet porté par un événement, ou `nil` s'il n'en a pas.
    static func subject(for eventId: String) -> EvEventSubject? {
        EvEventSubjectCatalog.all.first { $0.eventId == eventId }
    }

    /// Créneau de test `evenementTEST`, identique pour chaque filière :
    /// titre et description mot pour mot de la source, public par filière.
    private static func testEvent(
        _ slug: String,
        _ track: String,
        _ date: String,
        start: String,
        end: String,
        slot: String
    ) -> EvEvent {
        EvEvent(
            id: "test-evenement-\(slot)-\(slug)-\(date)",
            title: "evenementTEST",
            description: "Défi test de 10 minutes, créneau \(slot).",
            date: date,
            startTime: start,
            endTime: end,
            audience: EvEventAudience(track: track)
        )
    }
}
