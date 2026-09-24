import Foundation

/// Correspondance entre une banque servie et le scope de parcours
/// (`ChapterItemScope`) — port de `src/data/chapterItems.ts`,
/// `src/data/trainingCardCatalogs.ts` et `src/data/chapterItemBasics.ts`.
///
/// La source RN indexe scope → `bundleId` (`EXERCISE_BUNDLE_IDS`) et résout le
/// scope depuis le parcours (`chapterItemScope`). L'application, elle, part du
/// `bundleId` du descripteur servi : `exerciseScope(forBundleId:)` en est
/// l'inverse. Le lycée n'a pas de banque servie (`profileBundleIds` rend `[]`) :
/// son niveau se lit dans la spécialité (`lyceeScope(forSpecialty:)`), jamais
/// dans un `bundleId`.
extension TrainContent {

    /// Scope du parcours dont la banque d'énoncés est servie sous ce `bundleId`,
    /// `nil` quand aucune banque servie ne correspond (colles, annales, oral).
    static func exerciseScope(forBundleId bundleId: String) -> String? {
        switch bundleId {
        case "mpsi-statements": return "mpsi-1"
        case "mp-statements": return "mp-2"
        case "ecg-applied-1-statements": return "ecg-appliquees-1"
        case "ecg-applied-2-statements": return "ecg-appliquees-2"
        case "ecg-advanced-1-statements": return "ecg-approfondies-1"
        case "ecg-advanced-2-statements": return "ecg-approfondies-2"
        default: return nil
        }
    }

    /// `lyceeProgramScope` (`tracks.ts`) : niveau du lycée désigné par la
    /// spécialité du compte, recopié à l'identique. `nil` pour les options sans
    /// corpus (maths expertes seules, maths complémentaires) ; « spécialité +
    /// maths expertes » suit le programme de Terminale.
    static func lyceeScope(forSpecialty specialty: String) -> String? {
        let option = normalize(specialty)
        if option.isEmpty { return "seconde" }
        if option.contains("expertes") {
            return option.contains("specialite") ? "terminale" : nil
        }
        if option.contains("complementaires") { return nil }
        if option.contains("+") { return "premiere" }
        return "terminale"
    }
}
