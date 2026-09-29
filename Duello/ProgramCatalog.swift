// [ProgramCatalog] Racine de DuelloProgram : répartition des matières par filière et fabrique partagée de chapitres.
// [ProgramCatalog] Les membres partagés (subjects, normalize, chapter) passent de `private` à interne pour rester visibles des extensions réparties par fichier — aucun type ni signature renommé.
// [ProgramCatalog] Port de src/data/tracks.ts (getTrackSubjects, toProgramYear) et src/data/ecgMathsProgram.ts.
// [ProgramCatalog] V2 (2026-09-29, écart 12#4) : l'année est résolue par `isFirstProgramYear` (règle `toProgramYear` : seule la 1re année vaut 1) — « 3e année » (cube, 5/2) retombe sur le programme de 2e année au lieu de la 1re.
// [ProgramCatalog] Écarts assumés : les appelants du port passent l'année sous trois formes (libellé du profil « 1re année », abrégé de TrainingView « 1re », année programme numérique « 1 »/« 2 » de SocChallengeChapters) ; `isFirstProgramYear` les normalise toutes au lieu d'exiger le seul libellé RN.
import Foundation

/// Programmes officiels portés par Duello, repris de `src/data/tracks.ts` et
/// `src/data/ecgMathsProgram.ts`. Les identifiants de chapitres sont les clés
/// utilisées par le serveur pour l'appariement des défis : ils doivent rester
/// identiques à ceux de l'app Expo.
enum DuelloProgram {

    /// Matières du parcours choisi, dans l'ordre de l'app Expo.
    static func subjects(track: String, specialty: String, year: String) -> [TrackSubject] {
        let normalized = Self.normalize(track)
        let isFirstYear = Self.isFirstProgramYear(year)

        // Le lycée n'a qu'une matière, dont le programme dépend de la
        // spécialité (et non de `year`) : `lyceeProgram` de la source.
        if normalized.contains("lycee") { return lyceeSubjects(specialty: specialty) }
        if normalized.contains("ecg") {
            return ecgSubjects(
                isFirstYear: isFirstYear,
                mathsApplied: Self.normalize(specialty).contains("applique")
            )
        }
        if normalized.contains("mpsi") { return mpsiSubjects() }
        if normalized.contains("psi") { return psiSubjects() }
        if normalized == "mp" || normalized.contains("mp2") || normalized.contains("mpi") {
            return mpSubjects()
        }
        // Sans parcours connu, l'ECG 1re année s'affiche : le parcours le plus
        // courant, aucune matière du programme ECG n'est masquée.
        return ecgSubjects(isFirstYear: true, mathsApplied: false)
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `toProgramYear` (`tracks.ts:2140-2142`) : seule la 1re année vaut 1, tout
    /// le reste (2e, 3e année / cube / 5-2) vaut 2.
    ///
    /// Les appelants du port passent l'année sous trois formes — le libellé du
    /// profil (« 1re année » / « 2e année »), l'abrégé de `TrainingView`
    /// (« 1re ») et l'année programme numérique (« 1 » / « 2 ») de
    /// `SocChallengeChapters` et `memberProgramChapterKeys` — d'où la
    /// normalisation : elle conserve la règle « seule la 1re année vaut 1 » et
    /// corrige « 3e année » classée à tort en 1re année.
    static func isFirstProgramYear(_ year: String) -> Bool {
        switch year.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1re année", "1re", "1":
            return true
        default:
            return false
        }
    }

    static func chapter(_ id: String, _ name: String, domain: String? = nil) -> TrackChapter {
        TrackChapter(id: id, name: name, domain: domain)
    }
}
