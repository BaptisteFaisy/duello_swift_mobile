//
//  OnbDataPrepas.swift
//  Duello
//
//  Recherche dans le répertoire de classes préparatoires. Porté de l'app Expo :
//    - src/data/prepas.ts (`Prepa`, `normalizeSearch`, `searchPrepas`)
//
//  La liste officielle vient du serveur (`PrepaSearchModal.tsx` la charge puis
//  filtre) : ce module ne porte que le modèle et le filtre de recherche.
//  Aucune dépendance externe. Cible : iOS 16.
//

import Foundation

/// Modèle et recherche d'une prépa (`Prepa`, `searchPrepas`).
enum OnbDataPrepas {
    /// Nature de l'établissement (`Prepa.type` : `'public' | 'private'`).
    enum Kind: String, Codable, CaseIterable {
        case publicPrep = "public"
        case privatePrep = "private"
    }

    /// Une classe préparatoire (`Prepa`).
    struct Prepa: Identifiable, Hashable, Codable {
        let id: String
        let name: String
        let city: String
        let country: String
        let type: Kind
    }

    /// `searchPrepas` : filtre « contient » sur nom, ville et pays réunis,
    /// insensible aux accents et à la casse. Une requête vide renvoie tout.
    static func search(_ prepas: [Prepa], query: String) -> [Prepa] {
        let needle = normalizeSearch(query)
        if needle.isEmpty { return prepas }
        return prepas.filter { prepa in
            let haystack = [prepa.name, prepa.city, prepa.country].joined(separator: " ")
            return normalizeSearch(haystack).contains(needle)
        }
    }

    /// `normalizeSearch` : NFD, sans diacritiques, minuscules, élagué.
    private static func normalizeSearch(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
