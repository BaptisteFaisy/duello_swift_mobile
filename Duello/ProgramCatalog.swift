// [ProgramCatalog] Racine de DuelloProgram : répartition des matières par filière et fabrique partagée de chapitres.
// [ProgramCatalog] Les membres partagés (subjects, normalize, chapter) passent de `private` à interne pour rester visibles des extensions réparties par fichier — aucun type ni signature renommé.
import Foundation

/// Programmes officiels portés par Duello, repris de `src/data/tracks.ts` et
/// `src/data/ecgMathsProgram.ts`. Les identifiants de chapitres sont les clés
/// utilisées par le serveur pour l'appariement des défis : ils doivent rester
/// identiques à ceux de l'app Expo.
enum DuelloProgram {

    /// Matières du parcours choisi, dans l'ordre de l'app Expo.
    static func subjects(track: String, specialty: String, year: String) -> [TrackSubject] {
        let normalized = Self.normalize(track)
        let isFirstYear = !year.lowercased().contains("2")

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

    static func chapter(_ id: String, _ name: String, domain: String? = nil) -> TrackChapter {
        TrackChapter(id: id, name: name, domain: domain)
    }
}
