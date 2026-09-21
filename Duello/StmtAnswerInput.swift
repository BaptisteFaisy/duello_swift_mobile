import Foundation

/// Mode de saisie d'une réponse d'exercice — port de
/// `src/utils/exerciseAnswerInput.ts`.
///
/// Les chapitres Python ECG portent un préfixe stable dans les programmes
/// appliqué et approfondi. Le mode dépend uniquement du chapitre, afin que les
/// applications stable et de développement aient le même comportement.
enum StmtAnswerInput {
    /// `'python'` pour un chapitre `python-appliquees-*` ou
    /// `python-approfondies-*`, `'math'` sinon.
    static func mode(chapterId: String?) -> StmtAnswerInputMode {
        guard let chapterId else { return .math }
        if StmtRegex.contains("^python-(?:appliquees|approfondies)-", in: chapterId) {
            return .python
        }
        return .math
    }
}
