//
//  OnbDataTargetSchools.swift
//  Duello
//
//  Répertoire des établissements cibles du parcours d'inscription. Porté de
//  l'app Expo :
//    - src/data/targetSchools.ts (`TARGET_SCHOOLS`, `LYCEE_SCHOOLS`)
//    - src/screens/OnboardingScreen.tsx (`schoolSuggestions`, `normalize`)
//
//  Les grandes listes vivent dans `OnbDataEngineeringSchools` (MPSI) et
//  `OnbDataBusinessSchools` (ECG) pour respecter la limite de 500 lignes par
//  fichier. Aucune dépendance externe. Cible : iOS 16.
//

import Foundation

/// Établissements proposés à l'élève selon sa filière, alignés sur le
/// dictionnaire `TARGET_SCHOOLS` (`src/data/targetSchools.ts`).
enum OnbDataTargetSchools {
    /// Lycées du secondaire proposant une CPGE (clé `Lycée` de
    /// `TARGET_SCHOOLS`). Liste volontairement courte, étendue au fil des
    /// retours.
    static let lyceeSchools: [String] = [
        "Lycée Henri-IV",
        "Lycée Louis-le-Grand",
        "Lycée Stanislas",
        "Lycée Sainte-Geneviève",
        "Lycée Kléber",
        "Lycée Pasteur",
        "Lycée Janson-de-Sailly",
        "Lycée Blaise Pascal",
    ]

    /// Filières scientifiques servies par le répertoire d'écoles d'ingénieurs.
    /// `MPSI` est la clé Expo ; les autres filières scientifiques du profil
    /// Swift (`MP`, `MPI`, `PSI`, `MP2I`, `PCSI`, `PTSI`, `BCPST`, `B/L`…)
    /// sont rattachées au même répertoire.
    private static let scientificFamilies: Set<String> = [
        "mpsi", "mp2i", "mp", "mpi", "psi", "pc", "pt", "pcsi", "ptsi",
        "bcpst", "b/l", "bl", "tsi",
    ]

    /// Établissements cibles de la filière, dans l'ordre de `TARGET_SCHOOLS`.
    /// Une filière inconnue ne propose rien, comme la clé absente côté Expo.
    static func schools(for track: String) -> [String] {
        switch normalize(track) {
        case "ecg": return OnbDataBusinessSchools.all
        case "lycee": return lyceeSchools
        case "mpsi": return OnbDataEngineeringSchools.all
        default:
            return scientificFamilies.contains(normalize(track))
                ? OnbDataEngineeringSchools.all
                : []
        }
    }

    /// Suggestions d'écoles pour la saisie, comme `schoolSuggestions` de
    /// `OnboardingScreen.tsx` : filtre « contient » sur la requête élaguée,
    /// `limit` résultats au plus (7 par défaut).
    static func suggestions(for track: String, query: String, limit: Int = 7) -> [String] {
        let needle = normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return [] }
        let matches = schools(for: track).filter { normalize($0).contains(needle) }
        return Array(matches.prefix(limit))
    }

    /// `normalize` de `OnboardingScreen.tsx` : retire les accents et la casse.
    private static func normalize(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }
}
