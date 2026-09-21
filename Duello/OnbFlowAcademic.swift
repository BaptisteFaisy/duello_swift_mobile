//
//  OnbFlowAcademic.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : le chemin scolaire.
//
//  Fichiers source Expo portés :
//    - src/utils/academicPath.ts (`FIRST_YEAR_TRACKS`, `SECOND_YEAR_TRACKS`,
//      `FIRST_YEAR_ORIGINS`, `TRACK_OPTIONS`, `FIRST_YEAR_OPTIONS`,
//      `onboardingMathOptionChoices`, `originChoices`, `programTrackFor`,
//      `defaultCurrentTrack`, `normalizeAcademicPath`,
//      `synchronizeLegacyAcademicFields`)
//    - src/screens/OnboardingScreen.tsx (`chooseYear` / `chooseCurrentTrack` /
//      `chooseOrigin` pour la règle de repli, et le filtre « ECG seulement »
//      des lignes 1087-1108)
//
//  ⚠️ Écart de modèle assumé : le `UserProfile` Swift (Models.swift) ne porte
//  pas le champ `academicPath` de la source. Les quatre champs dérivés
//  (`currentTrack`, `firstYearTrack`, `currentOption`, `firstYearOption`) vivent
//  donc dans `OnbFlowAcademicPath`, tenu par le coordinateur, et seuls
//  `track` / `year` / `specialty` sont écrits dans le profil. Conséquence : les
//  champs `academicPath.currentTrack` / `firstYearTrack` d'un profil existant ne
//  peuvent pas être restaurés (ils sont recalculés), seules les options sont
//  relues depuis `specialty`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// Chemin scolaire (`AcademicPath`) : les quatre champs que la source garde à
/// côté des champs historiques du profil.
struct OnbFlowAcademicPath: Equatable {
    var currentTrack: String = ""
    var firstYearTrack: String = ""
    var currentOption: String = ""
    var firstYearOption: String = ""
}

/// Une option de filière (`onboardingMathOptionChoices`) : libellé affiché et
/// valeur enregistrée dans le profil.
struct OnbFlowOption: Identifiable, Equatable {
    let label: String
    let value: String
    var id: String { value }
}

/// Règles pures du chemin scolaire (`utils/academicPath.ts`).
enum OnbFlowAcademic {
    /// `FIRST_YEAR_TRACKS`.
    static let firstYearTracks = ["MPSI", "MP2I", "PCSI", "PTSI", "BCPST", "B/L", "ECG"]

    /// `SECOND_YEAR_TRACKS`.
    static let secondYearTracks = ["MP", "MPI", "PC", "PT", "PSI", "BCPST", "B/L", "ECG"]

    /// `TRACK_OPTIONS` ; `Lycée` reste vide, les niveaux lycée étant hors
    /// périmètre de l'inscription.
    static let trackOptions: [String: [String]] = [
        "MPSI": ["Sciences industrielles", "Informatique"],
        "MP2I": ["Informatique", "Sciences industrielles"],
        "PCSI": [],
        "PTSI": [],
        "MP": ["Sciences industrielles", "Informatique"],
        "MPI": ["Informatique"],
        "PC": [],
        "PT": [],
        "PSI": ["Sciences industrielles"],
        "BCPST": [],
        "B/L": [],
        "ECG": [
            "Maths approfondies + ESH",
            "Maths approfondies + HGG",
            "Maths appliquées + ESH",
            "Maths appliquées + HGG",
        ],
        "Lycée": [],
    ]

    /// `FIRST_YEAR_ORIGINS` : filières de 1re année menant à une 2e année.
    static let firstYearOrigins: [String: [String]] = [
        "MP": ["MPSI", "MP2I"],
        "MPI": ["MP2I"],
        "PC": ["PCSI"],
        "PT": ["PTSI"],
        "PSI": ["MPSI", "MP2I", "PCSI", "PTSI"],
    ]

    /// `FIRST_YEAR_OPTIONS`.
    static let firstYearOptions: [String: [String]] = [
        "MPSI": trackOptions["MPSI"] ?? [],
        "MP2I": trackOptions["MP2I"] ?? [],
        "PCSI": [],
        "PTSI": [],
        "BCPST": [],
        "B/L": [],
        "ECG": trackOptions["ECG"] ?? [],
        "Lycée": [],
    ]

    /// `onboardingCurrentTrackChoices` : filières proposées pour une année.
    static func currentTrackChoices(year: String) -> [String] {
        year == "1re année" ? firstYearTracks : secondYearTracks
    }

    /// `originChoices` : filières de 1re année compatibles avec la filière
    /// courante (une filière de 1re année se répond elle-même).
    static func originChoices(currentTrack: String) -> [String] {
        if firstYearTracks.contains(currentTrack) { return [currentTrack] }
        return firstYearOrigins[currentTrack] ?? [currentTrack]
    }

    /// `onboardingMathOptionChoices` : l'onboarding ne demande que le niveau de
    /// mathématiques, et seulement en ECG.
    static func mathOptionChoices(currentTrack: String) -> [OnbFlowOption] {
        guard currentTrack == "ECG" else { return [] }
        return [
            OnbFlowOption(label: "Maths appliquées", value: "Maths appliquées + ESH"),
            OnbFlowOption(label: "Maths approfondies", value: "Maths approfondies + ESH"),
        ]
    }

    /// `programTrackFor` : filière de programme correspondante.
    static func programTrackFor(_ currentTrack: String) -> String {
        if currentTrack == "ECG" { return "ECG" }
        if currentTrack == "Lycée" { return "Lycée" }
        return "MPSI"
    }

    /// `defaultCurrentTrack` : filière de repli d'un profil enregistré.
    static func defaultCurrentTrack(track: String, year: String) -> String {
        if track == "ECG" { return "ECG" }
        if track == "Lycée" { return "Lycée" }
        return year == "1re année" ? "MPSI" : "MP"
    }

    /// Repli de `chooseYear` : un changement d'année qui invalide la filière
    /// courante repart de la filière par défaut de l'année. Le monde lycée
    /// (<-> prépa) reste hors périmètre : seules les années prépa sont offertes.
    static func fallbackTrack(year: String, previous: String) -> String {
        if previous == "ECG" { return "ECG" }
        if previous == "PT" && year == "1re année" { return "PTSI" }
        return year == "1re année" ? "MPSI" : "MP"
    }

    /// `normalizedOption` + `canonicalEcgOption` : ramène une option libre
    /// historique à sa forme canonique, ou vide si elle n'est pas reconnue.
    static func normalizedOption(track: String, candidate: String, firstYear: Bool) -> String {
        let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        let allowed = (firstYear ? firstYearOptions[track] : trackOptions[track]) ?? []
        if allowed.contains(value) { return value }
        guard track == "ECG" else { return "" }
        // Anciennes versions : « Mathématiques appliquées », « Maths appliquées »…
        let normalized = value.lowercased()
        let maths: String
        if normalized.contains("appliqu") {
            maths = "Maths appliquées"
        } else if normalized.contains("approfond") {
            maths = "Maths approfondies"
        } else {
            return ""
        }
        return "\(maths) + \(normalized.contains("hgg") ? "HGG" : "ESH")"
    }

    /// `normalizeAcademicPath` : reconstruit un chemin cohérent depuis le
    /// profil. Les champs `academicPath` de la source étant absents du profil
    /// Swift, filière et origine sont dérivées, et seules les options sont
    /// relues depuis `specialty`.
    static func normalizePath(_ profile: UserProfile) -> OnbFlowAcademicPath {
        let allowed = currentTrackChoices(year: profile.year)
        let fallback = defaultCurrentTrack(track: profile.track, year: profile.year)
        let currentTrack = allowed.contains(fallback) ? fallback : (allowed.first ?? "")
        let origins = originChoices(currentTrack: currentTrack)
        let firstYearTrack = origins.first ?? currentTrack
        return OnbFlowAcademicPath(
            currentTrack: currentTrack,
            firstYearTrack: firstYearTrack,
            currentOption: normalizedOption(
                track: currentTrack, candidate: profile.specialty, firstYear: false),
            firstYearOption: normalizedOption(
                track: firstYearTrack, candidate: profile.specialty, firstYear: true)
        )
    }

    /// `synchronizeLegacyAcademicFields` : reporte le chemin sur les champs
    /// historiques du profil (`track`, `specialty`).
    static func synchronizedProfile(
        _ profile: UserProfile,
        path: OnbFlowAcademicPath
    ) -> UserProfile {
        var result = profile
        result.track = programTrackFor(path.currentTrack)
        result.specialty = path.currentOption
        return result
    }
}
