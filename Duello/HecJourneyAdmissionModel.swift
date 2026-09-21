import Foundation

/// Admission finale du parcours HEC : catalogue des écoles, blason et
/// persistance locale.
///
/// Porté de `src/utils/hecJourneyAdmission.ts` — `HEC_JOURNEY_ADMISSION_SCHOOLS`,
/// `HEC_JOURNEY_ADMISSION_CONTEST_TRACKS`, `CONTEST_TRACK_ALIASES`,
/// `hecJourneyAdmissionSchool`, `hecJourneyAdmissionSchoolsForTrack`,
/// `hecJourneyAdmissionCrest`, `DEFAULT_HEC_JOURNEY_ADMISSION_CREST`,
/// `parseHecJourneyAdmission` et `serializeHecJourneyAdmission`.
///
/// Les blasons officiels sont des images `assets/league-badges/*.png`
/// (`leagueBadgeSourceForLeague`) absentes de l'app Swift : le repli de la
/// source — un rectangle de la couleur de l'école portant `crestLabel` — est
/// donc le rendu nominal ici (`HecJourneyCrestView`).

// MARK: - Filières

/// `HEC_JOURNEY_ADMISSION_CONTEST_TRACKS`.
enum HecJourneyAdmissionContestTrack: String, CaseIterable, Hashable {
    case ecg = "ECG"
    case mp = "MP"
    case mpi = "MPI"
    case pc = "PC"
    case psi = "PSI"
    case pt = "PT"
    case tsi = "TSI"
    case bcpst = "BCPST"
}

// MARK: - Écoles

/// Une école d'admission et les filières qui y mènent.
struct HecJourneyAdmissionSchool: Identifiable, Hashable {
    let id: String
    let name: String
    let crestLabel: String
    let colorHex: Int
    let contestTracks: [HecJourneyAdmissionContestTrack]
}

/// `HEC_JOURNEY_ADMISSION_SCHOOLS`, dans l'ordre de la source.
enum HecJourneyAdmissionCatalog {
    private static let ecgTracks: [HecJourneyAdmissionContestTrack] = [.ecg]
    private static let scientificTracks: [HecJourneyAdmissionContestTrack] = [
        .mp, .mpi, .pc, .psi, .pt, .tsi, .bcpst,
    ]

    static let schools: [HecJourneyAdmissionSchool] = [
        HecJourneyAdmissionSchool(id: "hec", name: "HEC Paris", crestLabel: "HEC", colorHex: 0x123B68, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "essec", name: "ESSEC", crestLabel: "ESSEC", colorHex: 0xD02B36, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "escp", name: "ESCP", crestLabel: "ESCP", colorHex: 0x111111, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "edhec", name: "EDHEC", crestLabel: "EDHEC", colorHex: 0x173A67, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "emlyon", name: "emlyon business school", crestLabel: "EM", colorHex: 0xD92D4B, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "x", name: "École polytechnique (X)", crestLabel: "X", colorHex: 0x0A4564, contestTracks: [.mp, .mpi, .pc, .psi, .pt, .bcpst]),
        HecJourneyAdmissionSchool(id: "ens-ulm", name: "ENS Ulm", crestLabel: "ENS", colorHex: 0x4B003B, contestTracks: [.mp, .mpi, .pc, .psi, .bcpst]),
        HecJourneyAdmissionSchool(id: "centralesupelec", name: "CentraleSupélec", crestLabel: "CS", colorHex: 0x171717, contestTracks: [.mp, .mpi, .pc, .psi, .tsi]),
        HecJourneyAdmissionSchool(id: "mines-paris-psl", name: "Mines Paris – PSL", crestLabel: "MINES", colorHex: 0x075EAA, contestTracks: scientificTracks),
        HecJourneyAdmissionSchool(id: "skema", name: "SKEMA Business School", crestLabel: "SKEMA", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "audencia", name: "Audencia", crestLabel: "AUDENCIA", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "neoma", name: "NEOMA Business School", crestLabel: "NEOMA", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "kedge", name: "KEDGE Business School", crestLabel: "KEDGE", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "gem", name: "Grenoble École de Management", crestLabel: "GEM", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "tbs", name: "TBS Education", crestLabel: "TBS", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "montpellier", name: "Montpellier Business School", crestLabel: "MONTPELLIER", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "rennes", name: "Rennes School of Business", crestLabel: "RENNES", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "imt-bs", name: "Institut Mines-Télécom Business School", crestLabel: "IMT-BS", colorHex: 0x737373, contestTracks: ecgTracks),
        HecJourneyAdmissionSchool(id: "other", name: "Autre école", crestLabel: "AUTRE ÉCOLE", colorHex: 0x737373, contestTracks: HecJourneyAdmissionContestTrack.allCases),
    ]

    /// `CONTEST_TRACK_ALIASES` : « MPSI » désigne la filière « MP », etc.
    private static let aliases: [String: HecJourneyAdmissionContestTrack] = [
        "ECG": .ecg,
        "MPSI": .mp, "MP": .mp,
        "MP2I": .mpi, "MPI": .mpi,
        "PCSI": .pc, "PC": .pc,
        "PSI": .psi,
        "PTSI": .pt, "PT": .pt,
        "TSI": .tsi,
        "BCPST": .bcpst,
    ]

    /// `hecJourneyAdmissionSchool`.
    static func school(id: String?) -> HecJourneyAdmissionSchool? {
        guard let id, !id.isEmpty else { return nil }
        return schools.first { $0.id == id }
    }

    /// `hecJourneyAdmissionSchoolsForTrack` : école vide si la filière est
    /// inconnue, comme la source.
    static func schools(forTrack track: String) -> [HecJourneyAdmissionSchool] {
        guard let contestTrack = aliases[track] else { return [] }
        return schools.filter { $0.contestTracks.contains(contestTrack) }
    }
}

// MARK: - Admission enregistrée

/// `HecJourneyAdmission` : école, rang et nom libre éventuel.
struct HecJourneyAdmission: Hashable, Encodable {
    var schoolId: String
    var rank: Int
    var customSchoolName: String? = nil

    enum CodingKeys: String, CodingKey { case schoolId, rank, customSchoolName }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(rank, forKey: .rank)
        try container.encodeIfPresent(customSchoolName, forKey: .customSchoolName)
    }
}

/// `HecJourneyAdmissionCrest` : ce que la frise dessine à la fin du parcours.
struct HecJourneyAdmissionCrest: Hashable {
    let schoolId: String
    let schoolName: String
    let crestLabel: String
    let colorHex: Int

    /// `DEFAULT_HEC_JOURNEY_ADMISSION_CREST`.
    static let `default` = HecJourneyAdmissionCrest(
        schoolId: "hec",
        schoolName: "HEC Paris",
        crestLabel: "HEC",
        colorHex: 0x123B68
    )
}

/// Règles de blason et de persistance de l'admission.
enum HecJourneyAdmissionCodec {
    /// `hecJourneyAdmissionCrest`.
    static func crest(for admission: HecJourneyAdmission?) -> HecJourneyAdmissionCrest {
        guard let school = HecJourneyAdmissionCatalog.school(id: admission?.schoolId) else {
            return .default
        }
        let customName = admission?.customSchoolName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCustom = school.id == "other" && !(customName ?? "").isEmpty
        return HecJourneyAdmissionCrest(
            schoolId: school.id,
            schoolName: isCustom ? (customName ?? school.name) : school.name,
            crestLabel: isCustom ? crestLabel(fromCustomName: customName ?? "") : school.crestLabel,
            colorHex: school.colorHex
        )
    }

    /// Repli de `crestLabel` pour une école libre : accents retirés, capitales
    /// françaises, seules les lettres A–Z conservées, cinq au plus, sinon
    /// « ECOLE ».
    static func crestLabel(fromCustomName name: String) -> String {
        let folded = name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        let letters = folded
            .uppercased(with: Locale(identifier: "fr_FR"))
            .filter { $0.isASCII && $0.isLetter }
        let trimmed = String(letters.prefix(5))
        return trimmed.isEmpty ? "ECOLE" : trimmed
    }

    /// `parseHecJourneyAdmission` : école connue, rang entier entre 1 et
    /// 100 000, nom libre obligatoire pour « Autre école ».
    static func parse(_ raw: String?) -> HecJourneyAdmission? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any]
        else { return nil }

        guard let school = HecJourneyAdmissionCatalog.school(id: payload["schoolId"] as? String)
        else { return nil }

        let rank = (payload["rank"] as? NSNumber)?.intValue
        guard let rank, rank >= 1, rank <= 100_000 else { return nil }

        let rawName = payload["customSchoolName"] as? String
        let customName = rawName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        let name = (customName?.isEmpty ?? true) ? nil : String(customName ?? "")

        if school.id == "other" && name == nil { return nil }
        return HecJourneyAdmission(
            schoolId: school.id,
            rank: rank,
            customSchoolName: school.id == "other" ? name : nil
        )
    }

    /// `serializeHecJourneyAdmission`.
    static func serialize(_ admission: HecJourneyAdmission) -> String {
        guard let data = try? JSONEncoder().encode(admission),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }
}
