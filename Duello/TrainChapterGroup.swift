import Foundation

/// Domaines d'un programme de mathématiques, dans l'ordre de `CHAPTER_DOMAINS`
/// (`src/data/tracks.ts`).
enum TrainDomain: String, CaseIterable {
    case fondements
    case analyse
    case algebre
    case geometrie
    case probabilites
    case synthese
    case informatique

    /// Libellé affiché (`CHAPTER_DOMAIN_LABELS`).
    var label: String {
        switch self {
        case .fondements: return "Fondements"
        case .analyse: return "Analyse"
        case .algebre: return "Algèbre"
        case .geometrie: return "Géométrie"
        case .probabilites: return "Probabilités"
        case .synthese: return "Synthèse"
        case .informatique: return "Informatique"
        }
    }
}

/// Groupe de chapitres d'un domaine. Le groupe final de `groupChaptersByDomain`
/// n'a pas de domaine : son titre de repli est « Autres chapitres ».
struct TrainChapterGroup: Identifiable {
    let domain: TrainDomain?
    let chapters: [TrackChapter]

    var id: String { domain?.rawValue ?? "sans-domaine" }

    /// Titre affiché ; `nil` pour le groupe sans domaine, que le rendu coiffe
    /// de « Autres chapitres ».
    var title: String? { domain?.label }

    /// Port de `groupChaptersByDomain` : domaines connus dans l'ordre du
    /// programme, puis un groupe sans domaine pour les chapitres restants.
    ///
    /// Correction de fidélité (lot « onb-lycee-rn », 2026-09-23) : les
    /// programmes portés nomment leurs domaines avec leur **libellé** affiché
    /// (« Analyse », « Probabilités »…, `CHAPTER_DOMAIN_LABELS` de la source),
    /// là où `TrainDomain.rawValue` est la clé minuscule. La comparaison est
    /// donc faite sans tenir compte de la casse : sans cela, tous les chapitres
    /// tombaient dans « Autres chapitres » et plus aucun titre de domaine ne
    /// s'affichait (écart visible sur « Matières », `SubjectsScreen.tsx`).
    static func grouped(_ chapters: [TrackChapter]) -> [TrainChapterGroup] {
        func domainKey(_ value: String) -> String {
            value.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
                .lowercased()
        }
        var groups: [TrainChapterGroup] = TrainDomain.allCases.compactMap { domain -> TrainChapterGroup? in
            let matching = chapters.filter { chapter in
                guard let value = chapter.domain else { return false }
                return domainKey(value) == domainKey(domain.label)
            }
            return matching.isEmpty ? nil : TrainChapterGroup(domain: domain, chapters: matching)
        }
        let others = chapters.filter { chapter in
            guard let domain = chapter.domain else { return true }
            return !TrainDomain.allCases.contains { domainKey($0.label) == domainKey(domain) }
        }
        if !others.isEmpty {
            groups.append(TrainChapterGroup(domain: nil, chapters: others))
        }
        return groups
    }
}
