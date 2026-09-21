//
//  EvEventAudience.swift
//  Duello
//
//  Public visé par un événement : filtre du catalogue selon la filière,
//  l'option de mathématiques ECG et l'année de programme du profil.
//
//  Fichier source Expo porté : `src/utils/eventAudience.ts`, avec les deux
//  dérivations de `src/data/tracks.ts` qu'il emploie (`ecgMathsOption`,
//  `toProgramYear`).
//  `profile.academicPath.currentTrack` n'est pas modélisé côté Swift
//  (`UserProfile` ne porte que `track`) : la filière courante est donc
//  `profile.track`.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventAudienceFilter {
    /// L'événement est-il visible pour ce profil ? Sans `audience`, il l'est.
    static func matches(_ audience: EvEventAudience?, profile: UserProfile) -> Bool {
        guard let audience else { return true }
        if let track = audience.track, profile.track != track { return false }
        if let option = audience.mathsOption, profile.track == "ECG" {
            if mathsOption(of: profile.specialty) != option { return false }
        }
        if let year = audience.year, profile.track == "ECG" {
            if programYear(of: profile.year) != year { return false }
        }
        return true
    }

    /// Événements du catalogue visibles pour ce profil, triés par date.
    static func visibleEvents(_ events: [EvEvent], profile: UserProfile) -> [EvEvent] {
        events
            .filter { matches($0.audience, profile: profile) }
            .sorted { $0.date < $1.date }
    }

    /// Option de mathématiques ECG d'une spécialité (`ecgMathsOption`).
    static func mathsOption(of specialty: String) -> String {
        normalized(specialty).contains("applique") ? "appliquees" : "approfondies"
    }

    /// Année de programme (`toProgramYear`) : seule « 1re année » vaut 1.
    static func programYear(of year: String) -> Int {
        year == "1re année" ? 1 : 2
    }

    /// `normalize` de `data/tracks.ts` : sans diacritiques, en minuscules.
    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
    }
}
