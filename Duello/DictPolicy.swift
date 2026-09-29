//
//  DictPolicy.swift
//  Duello
//
//  Portage de `src/utils/dictationAccess.ts` et `src/utils/dictationLanguage.ts` :
//  autorisation du microphone/reconnaissance (`resolveDeviceDictationAccess`) et
//  garde-fou de langue (`isSupportedDictationTranscript`).
//
//  Le module de reconnaissance vocale simule une permission accordée sur le
//  Web : on vérifie donc séparément la présence de la reconnaissance puis on
//  demande réellement l'accès au microphone. Le garde-fou de langue bloque les
//  hallucinations dans un alphabet étranger au produit : le français et
//  l'anglais partagent l'alphabet latin, le grec et les lettres mathématiques
//  du script commun restent permis pour les formules.
//
//  Les fonctions de découpage/normalisation de la dictée sont dans
//  `DictTranscript.swift` (extension de `DictPolicy`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Résultat de la résolution d'accès — `DeviceDictationAccess` de la source.
enum DictAccess: String {
    case granted
    case denied
    case unavailable
}

/// Politique de dictée : autorisation, langue, découpage (fonctions pures).
enum DictPolicy {
    /// Résout l'accès à la dictée selon la plateforme et les demandes de permission.
    ///
    /// La source rattrape toute exception et rend `denied`
    /// (`try { … } catch { return 'denied' }`) : une demande qui échoue est donc
    /// refusée, jamais propagée.
    static func resolveAccess(
        isWeb: Bool,
        recognitionAvailable: () -> Bool,
        requestWebMicrophonePermission: () async throws -> Bool,
        requestNativeSpeechPermission: () async throws -> Bool
    ) async -> DictAccess {
        do {
            if isWeb && !recognitionAvailable() { return .unavailable }
            let granted = isWeb
                ? try await requestWebMicrophonePermission()
                : try await requestNativeSpeechPermission()
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    /// Bloque les hallucinations dans un alphabet étranger au produit.
    static func isSupportedTranscript(_ text: String) -> Bool {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        for scalaire in text.unicodeScalars where estLettre(scalaire) {
            if !estLettreSupportee(scalaire) { return false }
        }
        return true
    }

    /// Le scalaire appartient-il à la catégorie Unicode « lettre » ?
    private static func estLettre(_ scalaire: Unicode.Scalar) -> Bool {
        switch scalaire.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            return true
        default:
            return false
        }
    }

    /// Lettre d'un script admis : latin, grec ou commun (lettres mathématiques).
    ///
    /// La source filtre par propriété de **script** Unicode
    /// (`SUPPORTED_LETTER_SCRIPT`, `dictationLanguage.ts:2-3`).
    /// `Unicode.Scalar.Properties` n'expose pas le script sur iOS 16, mais
    /// `NSRegularExpression` (ICU, fourni par Foundation) l'expose via
    /// `\p{Script=…}` : les mêmes scripts sont donc admis, sans approximation
    /// par plages de points de code. Tout autre script (cyrillique, CJK,
    /// arabe…) est refusé.
    private static func estLettreSupportee(_ scalaire: Unicode.Scalar) -> Bool {
        let texte = String(scalaire)
        let plage = NSRange(texte.startIndex..<texte.endIndex, in: texte)
        return scriptRegex?.firstMatch(in: texte, options: [], range: plage) != nil
    }

    /// `SUPPORTED_LETTER_SCRIPT` : latin, grec, commun ou hérité.
    private static let scriptRegex = try? NSRegularExpression(
        pattern: "^(?:\\p{Script=Latin}|\\p{Script=Greek}|\\p{Script=Common}|\\p{Script=Inherited})$"
    )
}
