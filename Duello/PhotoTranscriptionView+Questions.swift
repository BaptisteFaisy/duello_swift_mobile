//
//  PhotoTranscriptionView+Questions.swift
//  Duello
//
//  Câblage « exercice entier » de la transcription photo — port des props
//  `exerciseQuestions` / `onInsertExercise` de `PhotoTranscriptionModalProps`
//  (`src/components/photo-transcription/photoTranscriptionTypes.ts`) et de leur
//  emploi dans `usePhotoTranscriptionController.ts` :
//    - `transcribePhotos` (l. 138-147) : les repères de questions partent avec la
//      requête `full-exercise` (`questionLabels: transcriptionRepere(...)`) ;
//    - `useInsertHandler` (l. 305-330) : `splitFullExerciseTranscription` répartit
//      la copie relue question par question au moment de l'insertion.
//
//  Cible : iOS 16, Foundation seul (le découpage vit dans
//  `PhotoExerciseTranscription.swift`).
//

import Foundation

/// Réglage d'insertion d'une copie d'exercice entier, porté par le contrôleur.
///
/// `questions` est le pendant de `props.exerciseQuestions` ; `onInsert` celui de
/// `props.onInsertExercise` (répartition `questionId → texte de la réponse`). Les
/// deux sont facultatifs : sans eux, la feuille se comporte comme pour une
/// question isolée.
struct PhotoTxExerciseWiring {
    var questions: [PhotoExerciseQuestion] = []
    var onInsert: (([String: String]) -> Void)?

    /// Repères transmis au relais (`transcriptionRepere`), dans l'ordre des
    /// questions. `nil` — clé absente du corps — quand aucune question n'est
    /// fournie, comme le `undefined` de la source.
    var labels: [String]? {
        questions.isEmpty ? nil : questions.map { PhotoExerciseTranscription.transcriptionRepere($0, questions) }
    }

    /// Répartit la copie relue par question puis l'insère. Renvoie `false` quand
    /// le découpage est incertain (dictionnaire vide) ou qu'aucun récepteur n'est
    /// branché : l'appelant conserve alors le texte entier dans le champ actif,
    /// exactement comme `useInsertHandler`.
    func insert(_ text: String) -> Bool {
        guard let onInsert, !questions.isEmpty else { return false }
        let answers = PhotoExerciseTranscription.splitFullExerciseTranscription(text, questions)
        guard !answers.isEmpty else { return false }
        onInsert(answers)
        return true
    }
}
