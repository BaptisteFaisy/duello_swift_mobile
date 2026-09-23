//
//  OnbFlowAcademicLycee.swift
//  Duello
//
//  LOT « onb-lycee-rn » (2026-09-23) — le monde lycée du chemin scolaire.
//
//  Fichier source Expo porté : `src/utils/academicPath.ts` (`LYCEE_LEVELS`,
//  `LYCEE_YEARS`, `isLyceeTrack`, `isLyceeYear`, `LYCEE_LEVEL_OPTIONS`,
//  `LYCEE_SPE_PLUS_EXPERTES_VALUE`, `TRACK_OPTIONS['Lycée']`,
//  `onboardingLyceeSpecialtyChoices`, `onboardingSpecialtyChoices`).
//
//  Découpé de `OnbFlowAcademic.swift` (limite de 10 fonctions par fichier du
//  projet) : mêmes types, aucune redéfinition — `trackOptions['Lycée']` et
//  `firstYearOptions['Lycée']` du fichier principal lisent `lyceeTrackOptions`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

extension OnbFlowAcademic {

    /// `LYCEE_YEARS` (`academicPath.ts`, repris par `OnboardingScreen.tsx`) :
    /// niveaux du lycée couverts par la filière `Lycée`. Le champ `year` du
    /// profil porte le niveau ; les années de prépa gardent leurs libellés.
    static let lyceeYears = ["2de", "1re", "Terminale"]

    /// `isLyceeYear` : l'année appartient au monde lycée.
    static func isLyceeYear(_ year: String) -> Bool { lyceeYears.contains(year) }

    /// `isLyceeTrack` : la filière choisie est le monde lycée.
    static func isLyceeTrack(_ track: String) -> Bool { track == "Lycée" }

    /// `LYCEE_LEVEL_OPTIONS` : spécialités suivies au lycée, par niveau. La 2de
    /// (tronc commun) n'en propose aucune.
    static let lyceeLevelOptions: [String: [String]] = [
        "2de": [],
        "1re": [
            "Mathématiques + physique-chimie",
            "Mathématiques + SVT",
            "Mathématiques + sciences de l’ingénieur",
            "Mathématiques + SES",
        ],
        "Terminale": [
            "Spécialité mathématiques",
            "Maths complémentaires",
            "Maths expertes",
        ],
    ]

    /// `LYCEE_SPE_PLUS_EXPERTES_VALUE` : valeur portée par le compte quand la
    /// spécialité et l'option de terminale sont choisies ensemble.
    static let lyceeSpePlusExpertesValue = "Spécialité mathématiques + Maths expertes"

    /// `TRACK_OPTIONS['Lycée']` : paires de 1re, options de terminale, puis le
    /// cumul « Spé Maths & Maths Expertes ».
    static let lyceeTrackOptions: [String] =
        (lyceeLevelOptions["1re"] ?? [])
        + (lyceeLevelOptions["Terminale"] ?? [])
        + [lyceeSpePlusExpertesValue]

    /// `onboardingLyceeSpecialtyChoices` / `onboardingSpecialtyChoices` : choix
    /// de la page « TA SPÉCIALITÉ ». La 1re choisit sa paire de spécialités ; la
    /// terminale choisit l'option de mathématiques suivie ; la 2de n'a pas de
    /// page (aucun choix).
    static func lyceeSpecialtyChoices(year: String) -> [OnbFlowOption] {
        guard isLyceeYear(year) else { return [] }
        if year == "1re" {
            // Le programme de maths de 1re est commun à toutes les paires de
            // spécialités : un seul choix, porté par une valeur canonique
            // reconnue par la résolution du programme (paire avec « + »).
            return [
                OnbFlowOption(label: "Spé Maths", value: "Mathématiques + physique-chimie"),
            ]
        }
        if year == "Terminale" {
            return [
                OnbFlowOption(label: "Spé Maths", value: "Spécialité mathématiques"),
                OnbFlowOption(label: "Maths Complémentaire", value: "Maths complémentaires"),
                OnbFlowOption(
                    label: "Spé Maths & Maths Expertes",
                    value: lyceeSpePlusExpertesValue
                ),
            ]
        }
        return []
    }

}
