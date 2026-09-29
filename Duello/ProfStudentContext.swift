//
//  ProfStudentContext.swift
//  Duello
//
//  Port de `src/utils/profStudentContext.ts` (RN) — fenêtre de contexte du prof
//  IA : qui est l'élève et quel texte il suit.
//
//  Toute page qui affiche le bouton prof passe par ici. Aucun écran ne formule
//  lui-même le nom du programme : c'est ici qu'on croise le parcours affiché
//  (`academicProgramSelection`) avec le catalogue des programmes officiels
//  (`OfficialMathsPrograms.swift`), pour que le prof s'adresse à l'élève par son
//  pseudo et ne sorte jamais du programme de sa filière et de son année.
//
//  `ProfContextInput`, `ProfTutorContext` et `profTutorContext` sont déjà portés
//  par `ProfTutorCore.swift` (contrat v2) ; ce fichier ne porte que la
//  construction de `student`, qui manquait (écart TR-08 #6 de `out/V08.md`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Règles pures de la fenêtre de contexte du prof (`profStudentContext.ts`).
enum ProfStudentContext {

    /// `ECG_TRACK_LABELS` : en ECG, le parcours de mathématiques fait partie du
    /// nom de la filière.
    static let ecgTrackLabels: [String: String] = [
        "appliquees": "ECG — mathématiques appliquées",
        "approfondies": "ECG — mathématiques approfondies",
    ]

    /// `ecgMathsOption` (`data/tracks.ts`) : parcours de mathématiques d'ECG.
    /// « applique » l'emporte ; à défaut, les approfondies.
    static func ecgMathsOption(_ specialty: String) -> String {
        normalized(specialty).contains("applique") ? "appliquees" : "approfondies"
    }

    /// `normalize` de `data/tracks.ts` : sans diacritiques, en minuscules.
    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }

    /// `academicProgramSelection` : filière et option réellement suivies pour
    /// l'année affichée. Un élève de MPI retrouve son programme de MP2I quand il
    /// consulte sa première année, sans modifier les champs historiques du
    /// compte. Le chemin normalisé vient de `OnbFlowAcademic.normalizePath`
    /// (port de `normalizeAcademicPath`).
    static func academicProgramSelection(
        _ profile: UserProfile,
        programYear: Int
    ) -> (programTrack: String, specialty: String) {
        let path = OnbFlowAcademic.normalizePath(profile)
        return programYear == 1
            ? (path.firstYearTrack, path.firstYearOption)
            : (path.currentTrack, path.currentOption)
    }

    /// `programFor` : programme officiel du parcours affiché, ou `nil` hors
    /// catalogue. En ECG, l'option de mathématiques distingue deux textes ; au
    /// lycée, la classe et la spécialité indexent l'entrée.
    static func programFor(
        track: String,
        programYear: Int,
        lyceeYear: String?,
        specialty: String
    ) -> OfficialMathsProgram? {
        findMathsProgram(OfficialMathsProgramQuery(
            track: track,
            programYear: programYear,
            lyceeYear: lyceeYear,
            mathsOption: track == "ECG" ? ecgMathsOption(specialty) : nil,
            lyceeOption: lyceeYear != nil ? specialty : nil
        ))
    }

    /// `programLabelDeRepli` : la filière et l'année, sans lien à un texte
    /// inventé, quand la filière est absente du catalogue.
    static func programLabelDeRepli(
        track: String,
        programYear: Int,
        lyceeYear: String?
    ) -> String {
        if let lyceeYear { return "\(track) — \(lyceeYear)" }
        return "\(track) \(HecJourneyCopy.yearLabels[programYear] ?? "")"
    }
}

/// `profStudentContext` : identité de l'élève et programme qu'il suit.
///
/// Le pseudo sert d'adresse directe dans la consigne du prof ; la filière et
/// l'année le situent dans son programme. Une filière absente du catalogue garde
/// un intitulé de repli plutôt qu'un lien à faux.
func profStudentContext(profile: UserProfile, programYear: Int) -> ProfStudent {
    let selection = ProfStudentContext.academicProgramSelection(
        profile, programYear: programYear)
    let lyceeYear = OnbFlowAcademic.isLyceeYear(profile.year) ? profile.year : nil
    let programme = ProfStudentContext.programFor(
        track: selection.programTrack,
        programYear: programYear,
        lyceeYear: lyceeYear,
        specialty: selection.specialty
    )
    let track = selection.programTrack == "ECG"
        ? (ProfStudentContext.ecgTrackLabels[
            ProfStudentContext.ecgMathsOption(selection.specialty)] ?? selection.programTrack)
        : selection.programTrack
    return ProfStudent(
        displayName: profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
        year: profile.year,
        track: track,
        program: programme?.label ?? ProfStudentContext.programLabelDeRepli(
            track: selection.programTrack,
            programYear: programYear,
            lyceeYear: lyceeYear
        ),
        programUrl: programme?.url
    )
}
