import Foundation

/// Calcul de la revue de prérequis des exercices chargés d'un chapitre.
///
/// Port du calcul de `chapterItems.ts` : le scope se lit dans le `bundleId` du
/// descripteur servi (`TrainContent.exerciseScope(forBundleId:)`), l'empreinte
/// de banque est celle de la filière (`…signature(_:)`) et la revue est
/// aiguillée par `ProgPrereq.review(_:)`. Aucun état n'est inventé : un scope
/// inconnu laisse `prerequisiteReview` à `nil`.
///
/// Coutures documentées (aucune donnée fabriquée) :
///   - `questionSolutions` reste vide : le contenu servi (`ChapterExercise`) ne
///     porte qu'un corrigé global, pas de corrigé par question ; la ventilation
///     s'appuie donc sur le seul énoncé, comme la source lorsque les corrigés
///     par question manquent ;
///   - la source retire de l'empreinte les sujets qui portent leurs propres
///     `requiredChapters` (`seeds.filter(…)`) ; ce champ n'est pas servi à
///     l'application, l'empreinte porte donc sur toute la liste chargée.
enum TrainExercisePrereq {

    /// Renseigne `prerequisiteReview` de chaque exercice. Laisse les items
    /// intacts quand la filière n'est pas servie (scope inconnu).
    static func apply(_ items: inout [TrainExercise], descriptor: DuelloAPI.ContentChapterDescriptor) {
        guard let scope = TrainContent.exerciseScope(forBundleId: descriptor.bundleId) else { return }
        let chapterId = descriptor.chapterId
        let exercises = items.map(progExercise)
        let signature = bankSignature(
            scope: scope, exercises: exercises, items: items, chapterId: chapterId
        )
        for index in items.indices {
            items[index].prerequisiteReview = review(
                scope: scope, chapterId: chapterId, signature: signature, item: items[index]
            )
        }
    }

    /// `ProgPrereq.Exercise` d'un sujet chargé.
    private static func progExercise(_ item: TrainExercise) -> ProgPrereq.Exercise {
        ProgPrereq.Exercise(
            key: item.key,
            title: item.title,
            statement: item.statement,
            solution: item.solution,
            prerequisiteBankSignature: nil,
            difficulty: item.difficulty
        )
    }

    /// Empreinte de la banque du chapitre, par filière. Les appliquées n'ont pas
    /// d'empreinte dans la source (relecture attestée par `REVIEWED_APPLIED_…`) :
    /// la chaîne vide est ignorée par `ProgPrereqEcgApplied`.
    private static func bankSignature(
        scope: String, exercises: [ProgPrereq.Exercise], items: [TrainExercise], chapterId: String
    ) -> String {
        switch scope {
        case "mpsi-1": return ProgPrereqMpsi.signature(exercises)
        case "mp-2": return ProgPrereqMp.signature(exercises)
        case "seconde": return ProgPrereqLycee.secondePrerequisiteSignature(exercises)
        case "premiere": return ProgPrereqLycee.premierePrerequisiteSignature(exercises)
        case "terminale": return ProgPrereqLycee.terminalePrerequisiteSignature(exercises)
        case "ecg-approfondies-1", "ecg-approfondies-2":
            return ProgPrereqEcgAdvanced.signature(
                items.map { advancedSignatureItem($0, chapterId: chapterId) }
            )
        default: return ""
        }
    }

    /// `AdvancedSignatureItem` d'un sujet : `id` = identifiant d'item
    /// (`chapitre::exercice::clé`, comme la banque de la source), corrigé omis
    /// (une contre-correction ne change pas les prérequis) et questions de
    /// l'énoncé dans l'ordre du texte.
    private static func advancedSignatureItem(
        _ item: TrainExercise, chapterId: String
    ) -> AdvancedSignatureItem {
        AdvancedSignatureItem(
            id: TrainItemID.make(chapterId: chapterId, key: item.key),
            title: item.title,
            statement: item.statement,
            solution: nil,
            questionIds: questionIds(item.statement)
        )
    }

    /// Revue d'un sujet, aiguillée par filière (`ProgPrereq.review(_:)`).
    private static func review(
        scope: String, chapterId: String, signature: String, item: TrainExercise
    ) -> ProgPrereqReview? {
        ProgPrereq.review(ProgPrereq.ReviewInput(
            bankId: "\(scope):exercice:\(chapterId)",
            bankSignature: signature,
            chapterId: chapterId,
            exercise: progExercise(item),
            questionIds: questionIds(item.statement),
            questionPrompts: StmtQuestions.extractStatementQuestionPrompts(item.statement),
            questionSolutions: [:]
        ))
    }

    /// Identifiants de question d'un énoncé, dans l'ordre du texte
    /// (`statementQuestions` de la source).
    private static func questionIds(_ statement: String) -> [String] {
        StmtQuestions.extractStatementQuestions(statement).map(\.id)
    }
}
