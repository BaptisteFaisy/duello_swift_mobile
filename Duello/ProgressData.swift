import SwiftUI

/// Socle embarqué des colles, par parcours puis par chapitre : les clés des
/// colles retranscrites (`colleBanks.floor.*.generated.ts` d'Expo, `BUNDLE_IDS`
/// de `colleBanks.ts`). L'app Expo complète ce socle par la banque publiée,
/// servie séparément ; cette version ne portant pas encore cette banque, le
/// socle embarqué est le dénominateur des colles — exactement ce qu'Expo compte
/// sans contenu téléchargé (`servedChapterEntries` retombe alors sur le socle).
enum ProgressColleSocle {
    /// Parcours → identifiant de chapitre → clés de colle.
    static let banks: [String: [String: [String]]] = [
        "ecg-appliquees-1": [
            "appliquees-1-logique": ["clement-marot-semaine-40-sujet-a-exercice-2", "clement-marot-semaine-40-sujet-b-exercice-2", "clement-marot-semaine-40-sujet-c-exercice-2", "clement-marot-semaine-42-sujet-b-exercice-2"],
            "appliquees-1-nombres-reels": ["fontaine-colle-1-exercice-4", "fontaine-colle-1-exercice-5", "fontaine-colle-1-exercice-6", "fontaine-colle-1-exercice-7", "fontaine-colle-1-exercice-8", "fontaine-colle-2-exercice-12", "clement-marot-semaine-38-sujet-a-exercice-1", "clement-marot-semaine-38-sujet-b-exercice-2", "clement-marot-semaine-38-sujet-c-exercice-1", "clement-marot-semaine-38-sujet-c-exercice-3"],
        ],
        "ecg-appliquees-2": [
            "appliquees-2-applications-lineaires": ["lecluse-ecg2-exercice-69", "lecluse-ecg2-exercice-70", "lecluse-ecg2-exercice-71", "lecluse-ecg2-exercice-80", "lecluse-ecg2-exercice-83", "jobin-colle-semaine-7-exercice-11", "jobin-colle-semaine-7-exercice-34", "jobin-colle-semaine-10-exercice-1", "jobin-colle-semaine-10-exercice-3", "jobin-colle-semaine-10-exercice-26", "jobin-colle-semaine-10-exercice-27", "jobin-colle-semaine-10-exercice-28", "jobin-colle-semaine-10-exercice-29", "jobin-colle-semaine-10-exercice-30", "jobin-colle-semaine-10-exercice-31", "jobin-colle-semaine-10-exercice-32", "jobin-colle-semaine-10-exercice-33", "jobin-colle-semaine-10-exercice-34", "jobin-colle-semaine-10-exercice-37", "jobin-colle-semaine-11-exercice-1", "jobin-colle-semaine-11-exercice-2", "jobin-colle-semaine-11-exercice-3", "jobin-colle-semaine-11-exercice-4", "jobin-colle-semaine-11-exercice-5", "jobin-colle-semaine-11-exercice-6", "jobin-colle-semaine-11-exercice-7", "jobin-colle-semaine-11-exercice-8", "jobin-colle-semaine-11-exercice-9", "jobin-colle-semaine-11-exercice-10", "jobin-colle-semaine-11-exercice-11", "jobin-colle-semaine-11-exercice-12", "jobin-colle-semaine-11-exercice-13", "jobin-colle-semaine-11-exercice-16", "jobin-colle-semaine-12-exercice-2", "jobin-colle-semaine-12-exercice-3", "jobin-colle-semaine-12-exercice-4", "jobin-colle-semaine-12-exercice-5", "jobin-colle-semaine-12-exercice-6", "jobin-colle-semaine-12-exercice-7", "jobin-colle-semaine-12-exercice-8", "jobin-colle-semaine-12-exercice-9", "jobin-colle-semaine-12-exercice-10", "jobin-colle-semaine-14-exercice-39", "jobin-colle-semaine-16-exercice-19", "jobin-colle-semaine-17-exercice-19", "hec-canu-2021-esp-4", "hec-canu-2021-esp-15"],
            "appliquees-2-fonctions": ["lecluse-ecg2-exercice-85", "lecluse-ecg2-exercice-86", "lecluse-ecg2-exercice-87", "lecluse-ecg2-exercice-92", "jobin-colle-semaine-4-exercice-1", "jobin-colle-semaine-4-exercice-2", "jobin-colle-semaine-4-exercice-16", "jobin-colle-semaine-5-exercice-16", "jobin-colle-semaine-6-exercice-26"],
            "appliquees-2-suites": ["lecluse-ecg2-exercice-89", "lecluse-ecg2-exercice-94", "lecluse-ecg2-exercice-95", "lecluse-ecg2-exercice-96", "lecluse-ecg2-exercice-97", "lecluse-ecg2-exercice-98", "lecluse-ecg2-exercice-99", "lecluse-ecg2-exercice-100", "lecluse-ecg2-exercice-103", "lecluse-ecg2-exercice-104", "jobin-colle-semaine-4-exercice-3", "jobin-colle-semaine-4-exercice-9", "jobin-colle-semaine-4-exercice-11", "jobin-colle-semaine-4-exercice-12", "jobin-colle-semaine-4-exercice-13", "jobin-colle-semaine-4-exercice-14", "jobin-colle-semaine-4-exercice-19", "jobin-colle-semaine-4-exercice-24", "jobin-colle-semaine-5-exercice-9", "jobin-colle-semaine-5-exercice-11", "jobin-colle-semaine-5-exercice-12", "jobin-colle-semaine-5-exercice-13", "jobin-colle-semaine-5-exercice-14", "jobin-colle-semaine-5-exercice-19", "jobin-colle-semaine-5-exercice-24", "jobin-colle-semaine-6-exercice-29", "jobin-colle-semaine-6-exercice-31", "jobin-colle-semaine-6-exercice-34", "jobin-colle-semaine-16-exercice-18", "jobin-colle-semaine-17-exercice-18", "hec-canu-2021-esp-38"],
        ],
        "ecg-approfondies-1": [
            "raisonnement": ["exo-30-injectivite-surjectivite", "somme-manuscrite", "audeval-colle-2-exercice-1", "audeval-colle-2-exercice-3", "audeval-colle-2-exercice-4", "audeval-colle-3-exercice-2", "audeval-colle-3-exercice-5", "audeval-colle-6-exercice-3", "colles-approfondies-ecg1-385-chapitre-01-exercice-001", "colles-approfondies-ecg1-385-chapitre-01-exercice-002", "colles-approfondies-ecg1-385-chapitre-01-exercice-003", "colles-approfondies-ecg1-385-chapitre-01-exercice-005", "colles-approfondies-ecg1-385-chapitre-01-exercice-006", "colles-approfondies-ecg1-385-chapitre-01-exercice-007", "colles-approfondies-ecg1-385-chapitre-01-exercice-012", "colles-approfondies-ecg1-385-chapitre-01-exercice-014", "colles-approfondies-ecg1-385-chapitre-01-exercice-015", "colles-approfondies-ecg1-385-chapitre-02-exercice-001", "colles-approfondies-ecg1-385-chapitre-02-exercice-003", "colles-approfondies-ecg1-385-chapitre-02-exercice-006", "colles-approfondies-ecg1-385-chapitre-02-exercice-008", "colles-approfondies-ecg1-385-chapitre-02-exercice-009", "colles-approfondies-ecg1-385-chapitre-02-exercice-010", "colles-approfondies-ecg1-385-chapitre-02-exercice-012", "colles-approfondies-ecg1-385-chapitre-02-exercice-014", "colles-approfondies-ecg1-385-chapitre-02-exercice-015", "colles-approfondies-ecg1-385-chapitre-03-exercice-003", "colles-approfondies-ecg1-385-chapitre-04-exercice-001", "colles-approfondies-ecg1-385-chapitre-04-exercice-002", "colles-approfondies-ecg1-385-chapitre-04-exercice-003", "colles-approfondies-ecg1-385-chapitre-04-exercice-004", "colles-approfondies-ecg1-385-chapitre-04-exercice-005", "colles-approfondies-ecg1-385-chapitre-04-exercice-006", "colles-approfondies-ecg1-385-chapitre-04-exercice-008", "colles-approfondies-ecg1-385-chapitre-04-exercice-009", "colles-approfondies-ecg1-385-chapitre-04-exercice-010", "colles-approfondies-ecg1-385-chapitre-04-exercice-011", "colles-approfondies-ecg1-385-chapitre-04-exercice-012", "colles-approfondies-ecg1-385-chapitre-05-exercice-002", "colles-approfondies-ecg1-385-chapitre-05-exercice-008"],
            "suites": ["exo-21-suite-arithmetico-geometrique", "exo-3-recurrence-lineaire-ordre-2", "exo-4-suite-recurrente-divergente", "somme-suites-adjacentes-manuscrite", "audeval-colle-2-exercice-2", "audeval-colle-2-exercice-5", "audeval-colle-3-exercice-1", "audeval-colle-3-exercice-3", "audeval-colle-5-exercice-1", "audeval-colle-5-exercice-3", "audeval-colle-5-exercice-4", "audeval-colle-8-exercice-1", "audeval-colle-11-exercice-1", "audeval-colle-13-exercice-2", "audeval-colle-15-exercice-4", "audeval-colle-17-exercice-4", "audeval-colle-21-exercice-4", "hec-oral-2021-esp-s9", "hec-oral-2021-esp-s11", "hec-oral-2023-esp-11", "hec-oral-2023-esp-14", "hec-oral-2023-esp-16", "hec-oral-2023-esp-19", "colles-approfondies-ecg1-385-chapitre-01-exercice-004", "colles-approfondies-ecg1-385-chapitre-01-exercice-009", "colles-approfondies-ecg1-385-chapitre-01-exercice-013", "colles-approfondies-ecg1-385-chapitre-01-exercice-017", "colles-approfondies-ecg1-385-chapitre-01-exercice-018", "colles-approfondies-ecg1-385-chapitre-02-exercice-011", "colles-approfondies-ecg1-385-chapitre-11-exercice-001", "colles-approfondies-ecg1-385-chapitre-11-exercice-002", "colles-approfondies-ecg1-385-chapitre-11-exercice-003", "colles-approfondies-ecg1-385-chapitre-11-exercice-004", "colles-approfondies-ecg1-385-chapitre-11-exercice-005", "colles-approfondies-ecg1-385-chapitre-11-exercice-007", "colles-approfondies-ecg1-385-chapitre-11-exercice-008", "colles-approfondies-ecg1-385-chapitre-11-exercice-009", "colles-approfondies-ecg1-385-chapitre-11-exercice-010", "colles-approfondies-ecg1-385-chapitre-11-exercice-011", "colles-approfondies-ecg1-385-chapitre-11-exercice-012", "colles-approfondies-ecg1-385-chapitre-11-exercice-013", "colles-approfondies-ecg1-385-chapitre-12-exercice-001", "colles-approfondies-ecg1-385-chapitre-12-exercice-002", "colles-approfondies-ecg1-385-chapitre-12-exercice-003", "colles-approfondies-ecg1-385-chapitre-12-exercice-005", "colles-approfondies-ecg1-385-chapitre-12-exercice-006", "colles-approfondies-ecg1-385-chapitre-12-exercice-007", "colles-approfondies-ecg1-385-chapitre-12-exercice-008", "colles-approfondies-ecg1-385-chapitre-12-exercice-009", "colles-approfondies-ecg1-385-chapitre-12-exercice-010", "colles-approfondies-ecg1-385-chapitre-12-exercice-011", "colles-approfondies-ecg1-385-chapitre-12-exercice-012", "colles-approfondies-ecg1-385-chapitre-12-exercice-013", "colles-approfondies-ecg1-385-chapitre-15-exercice-007", "colles-approfondies-ecg1-385-chapitre-15-exercice-009", "colles-approfondies-ecg1-385-chapitre-31-exercice-004"],
        ],
        "ecg-approfondies-2": [
            "couples-vecteurs": ["hec-oral-2019-esp-s295"],
            "familles-sommables": ["clemenceau-ecg2-2025-semaine-09-exercice-1"],
        ],
    ]
}

/// Lecture des données de l'écran « Progression » : parcours de l'élève,
/// banque d'items réellement servie, avancement, défis et cote Elo. Extension
/// de `DuelloProgressView` — membres partagés par l'en-tête, les quatre onglets
/// et le résumé embarqué (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Données

    /// Matières du parcours choisi, dans l'ordre de l'app Expo.
    var subjects: [TrackSubject] {
        DuelloProgram.subjects(
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year
        )
    }

    /// Noms des matières du parcours, dans l'ordre affiché.
    var subjectNames: [String] {
        subjects.map(\.name)
    }

    /// Matières cochées dans le filtre, dans l'ordre du parcours. Le getter
    /// repasse par `activeSubjectNames` : repartir de tout le parcours tant que
    /// l'élève n'a rien décoché, comme `selectedSubjects` initialisé sur toutes.
    var visibleSubjects: [TrackSubject] {
        let selection = activeSubjectNames
        return subjects.filter { selection.contains($0.name) }
    }

    /// Banque d'items servie pour ce profil, repliée en `matière:chapitre`. Les
    /// clés du catalogue sont `<année>:<matière>:<chapitre>` : une année 2 porte
    /// les banques des deux années, on réunit donc les chapitres homonymes.
    var itemPool: [String: [String]] {
        var merged: [String: Set<String>] = [:]
        for (key, ids) in DuelloExerciseCatalog.forProfile(session.profile) {
            let parts = key.split(separator: ":", maxSplits: 2)
            guard parts.count == 3 else { continue }
            merged["\(parts[1]):\(parts[2])", default: []].formUnion(ids)
        }
        return merged.mapValues { $0.sorted() }
    }

    /// Périmètre de la banque servie pour le profil (`chapterItemScope` d'Expo) :
    /// « ecg-approfondies-1 », « ecg-appliquees-2 », « mpsi-1 » ou « mp-2 ».
    var chapterScope: String {
        let isSecondYear = session.profile.year.lowercased().contains("2")
        if session.profile.track.uppercased().contains("MPSI") {
            return isSecondYear ? "mp-2" : "mpsi-1"
        }
        let applied = session.profile.specialty.lowercased().contains("appliqu")
        if applied {
            return isSecondYear ? "ecg-appliquees-2" : "ecg-appliquees-1"
        }
        return isSecondYear ? "ecg-approfondies-2" : "ecg-approfondies-1"
    }

    /// Items d'exercice servis pour toute la matière, tous chapitres confondus.
    private func exerciseItemIds(for subject: TrackSubject) -> [String] {
        let pool = itemPool
        var ids = Set<String>()
        for chapter in subject.chapters {
            if let chapterIds = pool["\(subject.id):\(chapter.id)"] {
                ids.formUnion(chapterIds)
            }
        }
        return ids.sorted()
    }

    /// Items de colle servis pour la matière : le socle embarqué du parcours
    /// (`getChapterItems(chapitre, 'colle', scope)` d'Expo).
    private func colleItemIds(for subject: TrackSubject) -> [String] {
        let socle = ProgressColleSocle.banks[chapterScope] ?? [:]
        var ids: [String] = []
        for chapter in subject.chapters {
            for key in socle[chapter.id] ?? [] {
                ids.append("\(chapter.id)::colle::\(key)")
            }
        }
        return ids
    }

    /// Items servis pour une matière et un type d'entraînement.
    func itemIds(for subject: TrackSubject, kind: ProgressItemKind) -> [String] {
        switch kind {
        case .exercises: return exerciseItemIds(for: subject)
        case .colles: return colleItemIds(for: subject)
        }
    }

    /// Avancement d'une matière pour un type d'entraînement.
    func trainingStat(for subject: TrackSubject, kind: ProgressItemKind) -> TrainingStat {
        progress.trainingStat(forItemIds: itemIds(for: subject, kind: kind))
    }

    /// Défis joués et gagnés d'une matière.
    func duelStat(for subject: TrackSubject) -> DuelStat {
        progress.duelStat(for: subject.name)
    }

    /// Cote Elo d'une matière.
    func elo(for subject: TrackSubject) -> Int {
        progress.subjectElo(for: subject.name)
    }

    /// Défis joués sur toutes les matières affichées : l'invitation de l'onglet
    /// « Défis » n'apparaît que si aucune matière visible n'a de défi joué
    /// (`totalPlayed` d'Expo).
    var visibleDuelPlayed: Int {
        visibleSubjects.reduce(0) { $0 + duelStat(for: $1).played }
    }
}
