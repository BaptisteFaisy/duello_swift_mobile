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
    /// La source rattrape toute exception et rend `denied` : l'appelant passe des
    /// demandes non lancantes et traduit un échec en `false`.
    static func resolveAccess(
        isWeb: Bool,
        recognitionAvailable: () -> Bool,
        requestWebMicrophonePermission: () async -> Bool,
        requestNativeSpeechPermission: () async -> Bool
    ) async -> DictAccess {
        if isWeb && !recognitionAvailable() { return .unavailable }
        let granted = isWeb
            ? await requestWebMicrophonePermission()
            : await requestNativeSpeechPermission()
        return granted ? .granted : .denied
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
    /// La source s'appuie sur les propriétés de script Unicode ; Swift ne les
    /// expose pas, ces plages couvrent le latin, le grec et les lettres du
    /// script commun (lettres modificatrices, symboles de type lettre, lettres
    /// mathématiques alphanumériques). Tout autre script (cyrillique, CJK,
    /// arabe…) est refusé.
    private static func estLettreSupportee(_ scalaire: Unicode.Scalar) -> Bool {
        switch scalaire.value {
        case 0x0041...0x005A, 0x0061...0x007A, 0x00AA...0x00BA,
             0x00C0...0x00D6, 0x00D8...0x00F6, 0x00F8...0x02FF,
             0x0370...0x03FF, 0x1D00...0x1D7F, 0x1E00...0x1EFF,
             0x1F00...0x1FFF, 0x2070...0x209F, 0x2100...0x214F,
             0x2C60...0x2C7F, 0xA720...0xA7FF, 0x1D400...0x1D7FF:
            return true
        default:
            return false
        }
    }
}
