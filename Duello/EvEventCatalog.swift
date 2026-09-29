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
//  (15h00) septembre, un par filière, puis les dix défis d'additions du
//  dimanche 27 septembre (`test-addition-*-2026-09-27`, un toutes les dix
//  minutes de 22h10 à 23h45, sans public).
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
        // ——— Dimanche 27 septembre 2026 : dix défis d'additions (5 min) ———
        // Série de test : un sujet différent à chaque créneau, dix additions
        // très faciles par sujet, un créneau toutes les dix minutes de 22h10 à
        // 23h45. Sans `audience` : visible de tous les comptes.
        additionEvent("entiers", "22h10", "Additions d’entiers naturels",
                      "Défi test de 5 minutes : Additions d’entiers naturels.",
                      start: "22:10", end: "22:15"),
        additionEvent("decimaux", "22h20", "Additions de nombres décimaux",
                      "Défi test de 5 minutes : Additions décimales, dix calculs très faciles.",
                      start: "22:20", end: "22:25"),
        additionEvent("fractions", "22h30", "Additions de fractions",
                      "Défi test de 5 minutes : Fractions de même dénominateur, dix additions simples.",
                      start: "22:30", end: "22:35"),
        additionEvent("parentheses", "22h40", "Additions avec parenthèses",
                      "Défi test de 5 minutes : Parenthèses et priorités, dix additions guidées.",
                      start: "22:40", end: "22:45"),
        additionEvent("durees", "22h50", "Additions de durées",
                      "Défi test de 5 minutes : Heures et minutes, dix additions de durées.",
                      start: "22:50", end: "22:55"),
        additionEvent("argent", "23h00", "Additions d’argent",
                      "Défi test de 5 minutes : Euros et centimes, dix additions très faciles.",
                      start: "23:00", end: "23:05"),
        additionEvent("unites", "23h10", "Additions avec des unités",
                      "Défi test de 5 minutes : Longueurs et masses, dix additions très faciles.",
                      start: "23:10", end: "23:15"),
        additionEvent("relatifs", "23h20", "Additions de nombres relatifs",
                      "Défi test de 5 minutes : Positifs et négatifs, dix additions très faciles.",
                      start: "23:20", end: "23:25"),
        additionEvent("multiples", "23h30", "Additions de multiples",
                      "Défi test de 5 minutes : Sommer des multiples, dix additions très faciles.",
                      start: "23:30", end: "23:35"),
        additionEvent("moyenne", "23h40", "Additions et moyenne",
                      "Défi test de 5 minutes : Additionner puis diviser, dix moyennes faciles.",
                      start: "23:40", end: "23:45"),
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

    /// Créneau de test « additions » du 27/09/2026 : titre et description mot
    /// pour mot de la source, cinq minutes, sans public (visible de tous).
    private static func additionEvent(
        _ slug: String,
        _ slot: String,
        _ title: String,
        _ description: String,
        start: String,
        end: String
    ) -> EvEvent {
        EvEvent(
            id: "test-addition-\(slug)-\(slot)-2026-09-27",
            title: title,
            description: description,
            date: "2026-09-27",
            startTime: start,
            endTime: end
        )
    }
}
