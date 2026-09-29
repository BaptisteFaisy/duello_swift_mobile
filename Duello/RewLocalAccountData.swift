//
//  RewLocalAccountData.swift
//  Duello
//
//  Effacement de la copie locale complète d'un compte : suppression de toutes
//  les clés physiques cloisonnées par compte dans le stockage local.
//
//  Fichier source Expo porté : src/storage/AccountStorage.tsx — removeLocalAccountData
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `AccountStorage.tsx` : effacement local complet d'un compte.
enum RewLocalAccountData {
    /// `removeLocalAccountData` : efface la copie locale complète d'un compte
    /// après confirmation de sa suppression serveur. Cette voie n'appelle
    /// volontairement pas l'API : le compte et sa session n'existent déjà plus
    /// à ce stade.
    ///
    /// `AsyncStorage` est ici `UserDefaults.standard` et `getAllKeys` devient
    /// `dictionaryRepresentation().keys`.
    ///
    /// - Parameters:
    ///   - accountId: identifiant du compte dont on purge les données locales.
    ///   - defaults: stockage local interrogé (surchargeable pour les tests).
    /// - Returns: le nombre de clés physiques supprimées (`physicalKeys.length`).
    @discardableResult
    static func removeLocalAccountData(
        accountId: String,
        defaults: UserDefaults = .standard
    ) -> Int {
        let prefix = RewStorageScope.accountStoragePrefix(accountId: accountId)
        let physicalKeys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(prefix)
        }
        if physicalKeys.isEmpty { return 0 }

        for key in physicalKeys {
            defaults.removeObject(forKey: key)
        }

        // Coupure assumée : la notification en mémoire
        // `notifyAccountStorageChanged` (abonnés d'un compte) n'a pas
        // d'équivalent Swift — il n'existe pas de registre d'abonnés de stockage
        // de compte côté iOS. La suppression physique, elle, est identique :
        // `multiRemove` retire toutes les clés préfixées, y compris celles
        // finissant par `:pending-sync` (RN les retire aussi).
        return physicalKeys.count
    }
}
