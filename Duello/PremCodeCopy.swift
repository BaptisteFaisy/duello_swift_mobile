//
//  PremCodeCopy.swift
//  Duello
//
//  Libellés et transformations du formulaire « code d’affiliation » Premium.
//
//  Fichiers source Expo portés :
//    - `src/utils/premiumCodeRedemption.ts` (normalisation de la saisie,
//      messages de succès et de refus) ;
//    - `src/hooks/usePremiumCodeRedemption.ts` (messages de refus locaux) ;
//    - `src/utils/affiliateProgram.ts` (`AFFILIATE_PAYMENT_REWARD_LABEL`).
//
//  Cible : iOS 16.
//
import Foundation

/// Textes du formulaire de code d’affiliation et fonctions pures associées.
enum PremCodeCopy {
    /// `PREMIUM_CODE_INPUT_MAX_LENGTH` : longueur maximale de la saisie.
    static let inputMaxLength = 64

    /// `AFFILIATE_PAYMENT_REWARD_MINOR` de `src/utils/affiliateProgram.ts`.
    static let paymentRewardMinor = 300

    /// `AFFILIATE_PAYMENT_REWARD_LABEL` : `${MINOR / 100} €`.
    static var paymentRewardLabel: String { "\(paymentRewardMinor / 100) €" }

    /// `PREMIUM_CODE_ERROR_MESSAGE`.
    static let genericFailure =
        "Impossible d’utiliser ce code d’affiliation pour le moment. Vérifie ta connexion, puis réessaie."

    /// `normalizePremiumCodeInput` : minuscules françaises, diacritiques
    /// retirés, seuls `a-z0-9-` conservés, tronqué à `inputMaxLength`.
    static func normalize(_ value: String) -> String {
        let locale = Locale(identifier: "fr-FR")
        let folded = value
            .lowercased(with: locale)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        var cleaned = ""
        for scalar in folded.unicodeScalars where allowed.contains(scalar) {
            cleaned.unicodeScalars.append(scalar)
        }
        return String(cleaned.prefix(inputMaxLength))
    }

    /// `premiumCodeForSubmission` : identifiant public tel qu’il part au
    /// serveur (le tiret de `member-…` est conservé).
    static func forSubmission(_ value: String) -> String { normalize(value) }

    /// `premiumCodeSuccessMessage`.
    static func successMessage(applied: Bool) -> String {
        if !applied {
            return "Ce code d’affiliation est déjà enregistré. Aucun montant n’est ajouté avant un paiement Premium validé."
        }
        return "Code enregistré. Les \(paymentRewardLabel) seront ajoutés à l’affilié uniquement après validation de ton paiement Premium."
    }

    /// `premiumCodeFailureMessage` : traduit les refus connus sans exposer de
    /// détail technique de la réponse.
    ///
    /// ⚠️ Le `DirectoryError` du portage ne conserve pas le champ `code` du
    /// serveur (`DuelloAPI.request` ne décode que `error` et le statut HTTP) :
    /// le classement se fait donc sur le statut, puis sur le message renvoyé.
    /// Les refus `affiliate-code-already-used` et `affiliate-self-referral`,
    /// qui partageaient le statut 400, se replient sur le message du serveur.
    static func failureMessage(_ error: Error) -> String {
        if let directory = error as? DirectoryError {
            switch directory.status {
            case 403:
                return "Connecte-toi à un compte Duello pour utiliser un code d’affiliation."
            case 400:
                return "Ce code d’affiliation est invalide ou n’est plus disponible."
            case 429:
                return "Trop de tentatives ont été effectuées. Attends un instant, puis réessaie."
            default:
                let message = directory.message.trimmingCharacters(in: .whitespacesAndNewlines)
                return message.isEmpty ? genericFailure : message
            }
        }
        if let description = (error as? LocalizedError)?.errorDescription,
           !description.isEmpty {
            return description
        }
        return genericFailure
    }
}
