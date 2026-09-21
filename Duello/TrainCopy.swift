import Foundation

/// Libellés accordés du catalogue, repris mot pour mot de `SubjectsScreen.tsx`.
enum TrainCopy {
    /// « 12 exercices disponibles », « 3 colles disponibles ».
    static func availability(_ kind: TrainExerciseKind, count: Int) -> String {
        let feminine = kind.isFeminine ? "e" : ""
        let plural = count > 1 ? "s" : ""
        return "\(count) \(kind.noun(count: count)) disponible\(feminine)\(plural)"
    }

    /// « 0/32 exercices réussis », « 1/8 colles réussies » : le pluriel suit le
    /// nombre total annoncé par le dénominateur.
    static func success(
        _ kind: TrainExerciseKind,
        succeeded: Int,
        available: Int,
        withNoun: Bool = true
    ) -> String {
        let plural = available > 1 ? "s" : ""
        let noun = withNoun ? "\(kind.noun(count: available)) " : ""
        let feminine = kind.isFeminine ? "e" : ""
        return "\(succeeded)/\(available) \(noun)réussi\(feminine)\(plural)"
    }

    /// « 3/12 sujets réussis », en-tête d'une matière.
    static func subjectSuccess(succeeded: Int, total: Int) -> String {
        "\(succeeded)/\(total) sujets réussis"
    }

    /// « 3 corrigés » du résumé de chapitre.
    static func solutions(count: Int) -> String {
        "\(count) corrigé\(count > 1 ? "s" : "")"
    }
}
