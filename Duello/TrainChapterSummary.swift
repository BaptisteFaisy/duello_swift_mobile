import Foundation

/// Avancement d'un chapitre dans le mode ouvert (`ChapterModeSummary`) : seuls
/// les sujets réellement servis entrent dans le dénominateur.
struct TrainChapterSummary: Equatable {
    /// Sujets servis pour ce chapitre.
    var available: Int = 0
    /// Sujets connus du catalogue mais pas encore chargés sur l'appareil.
    var catalogued: Int? = nil
    /// Sujets disposant d'un corrigé.
    var withSolution: Int = 0
    /// Sujets entièrement réussis : c'est ce que la barre du chapitre remplit.
    var succeeded: Int = 0

    /// Dénominateur d'avancement (`chapterModeProgressTotal`) : les colles
    /// comptent aussi les sujets seulement catalogués.
    func progressTotal(kind: TrainExerciseKind) -> Int {
        kind == .colle ? max(available, catalogued ?? 0) : available
    }
}
