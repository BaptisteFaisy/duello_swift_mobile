import Foundation

// Port de App.tsx (RN, bloc `completePasswordReset`) — alerte affichée après
// une complétion de réinitialisation.
//
// La source n'affiche une alerte que pour deux issues ; `authenticated` et
// `superseded` sont silencieuses. Les textes sont repris mot pour mot,
// apostrophes typographiques comprises.
//
// Cible : iOS 16. Aucune dépendance externe.

/// Alerte présentée à l'élève (titre + message).
struct AcctSecResetAlert: Equatable {
    var title: String
    var message: String
}

/// `AppAlert.alert(...)` du bloc de complétion.
enum AcctSecResetCompletionAlert {

    /// Alerte à afficher pour un résultat, ou `nil` si l'issue est silencieuse
    /// (`authenticated`, `superseded`).
    static func alert(for result: PasswordResetCompletionResult) -> AcctSecResetAlert? {
        switch result {
        case .authenticated, .superseded:
            return nil
        case .outcomeUnknown:
            return AcctSecResetAlert(
                title: "Résultat à vérifier",
                message: "La réponse du serveur s’est perdue. Essaie de te reconnecter avec le nouveau mot de passe ; s’il est refusé, rouvre le lien reçu."
            )
        case .loginRequired:
            return AcctSecResetAlert(
                title: "Mot de passe modifié",
                message: "Ton mot de passe a bien changé. Reconnecte-toi avec le nouveau."
            )
        }
    }
}
