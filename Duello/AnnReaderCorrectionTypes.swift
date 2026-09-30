//
//  AnnReaderCorrectionTypes.swift
//  Duello
//
//  Types d'état de la soumission du lecteur d'annale (P0 18#2).
//
//  Portés de `AnnaleViewer.tsx` : `CorrectionSummaryState` (suivi de la copie
//  envoyée), `batchProgress` (avancement du lot de corrections) et `pythonBlocked`
//  (programme en échec qui retient la correction).
//
//  Cible : iOS 16.
//
import Foundation

/// `CorrectionSummaryState` : la copie envoyée et l'avancement de sa correction.
struct AnnCorrectionState {
    var submissionId: String
    /// Instant de l'envoi, en millisecondes (`Date.now()`).
    var startedAt: Double
    /// Questions envoyées ensemble.
    var submittedQuestionIds: [String]
    /// Temps passé sur la copie au moment de l'envoi.
    var spentSeconds: Int
    /// Vrai quand toutes les corrections du lot sont rentrées.
    var completed: Bool = false
}

/// `batchProgress` : réponses terminées sur le lot en cours.
struct AnnBatchProgress {
    var done: Int
    var total: Int
}

/// `pythonBlocked` : la question dont le programme a retenu la correction.
struct AnnPythonBlocked {
    var questionId: String
    var result: PyConRunResult
}

extension AnnVerdict {
    /// Conversion depuis le verdict du correcteur partagé (`CollVerdict`), qui
    /// porte les mêmes valeurs brutes.
    init?(_ verdict: CollVerdict) {
        guard let value = AnnVerdict(rawValue: verdict.rawValue) else { return nil }
        self = value
    }
}
