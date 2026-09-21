//
//  KbSupOcrSettings.swift
//  Duello
//
//  Réglages de la lecture mathématique des photos : mode local ou relais
//  premium, adresse dédiée et jeton de session.
//
//  Fichiers source Expo portés :
//    - `src/utils/mathOcrSettings.ts` — `MathOcrMode`, `MathOcrSettings`,
//      `MATH_OCR_SETTINGS_SCHEMA_VERSION`, `MATH_OCR_SETTINGS_KEY`,
//      `DEFAULT_MATH_OCR_SETTINGS`, `loadMathOcrSettings`, `saveMathOcrSettings`
//      (les deux fonctions vivent dans `KbSupOcrSettingsStore`, le modèle dans
//      `KbSupOcrSettings`) ;
//    - `src/utils/serverSessionToken.ts` — `currentServerSessionToken` : le
//      jeton vient de la session serveur (`dus_…`), jamais d'une clé de
//      fournisseur ; `SessionStore` porte déjà la règle d'expiration ;
//    - `src/storage/keys.ts` — `ACCOUNT_STORAGE_KEYS.mathOcrSettings`
//      (`prepapp-math-ocr-settings`) ; `src/storage/AccountStorage.tsx` cloisonne
//      la donnée par compte, ce que reproduit le préfixe physique de
//      `RewStorageScope` (déjà porté par le lot 7-C).
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

// MARK: - Mode

/// Mode de lecture d'une photo de mathématiques (`MathOcrMode`).
enum KbSupOcrMode: String, CaseIterable, Codable {
    /// Lecture sur l'appareil.
    case local
    /// Lecture par le relais Duello, seul détenteur de la clé du fournisseur.
    case premium
}

// MARK: - Réglages

/// Réglages de lecture d'une photo mathématique (`MathOcrSettings`).
struct KbSupOcrSettings: Codable, Equatable {

    /// `MATH_OCR_SETTINGS_SCHEMA_VERSION`.
    static let currentSchemaVersion = 2

    /// Clé logique de la source (`MATH_OCR_SETTINGS_KEY`), cloisonnée par compte
    /// au moment de l'écriture.
    static let storageKey = "prepapp-math-ocr-settings"

    /// `DEFAULT_MATH_OCR_SETTINGS` : les nouvelles installations profitent
    /// immédiatement de la lecture vision, puis un choix local explicite
    /// l'emporte.
    static let defaultSettings = KbSupOcrSettings()

    var schemaVersion: Int = KbSupOcrSettings.currentSchemaVersion
    var mode: KbSupOcrMode = .premium
    /// URL dédiée facultative. Vide = relais Duello permanent du build.
    var endpoint: String = ""
    /// Jeton de l'élève auprès du relais, jamais la clé du fournisseur.
    var token: String = ""
}

// MARK: - Persistance

/// `mathOcrSettings.ts` : chargement et enregistrement des réglages.
enum KbSupOcrSettingsStore {

    /// `loadMathOcrSettings` : réglages du compte, migrés une fois si la version
    /// enregistrée est antérieure. Toute lecture en échec rend les valeurs par
    /// défaut, sans jeton.
    ///
    /// - Parameters:
    ///   - accountId: compte local propriétaire de la donnée.
    ///   - token: jeton de session serveur, lu par
    ///     `currentServerSessionToken(store:)`.
    static func load(
        accountId: String,
        token: String?,
        defaults: UserDefaults = .standard
    ) -> KbSupOcrSettings {
        let sessionToken = token ?? ""
        do {
            guard let raw = defaults.string(forKey: physicalKey(accountId: accountId)) else {
                var fresh = KbSupOcrSettings.defaultSettings
                fresh.token = sessionToken
                return fresh
            }
            let stored = try parse(raw, token: sessionToken)
            if stored.legacy {
                // Une écriture qui échoue n'a pas de conséquence : la préférence
                // chargée reste utilisable pour cette session, et une prochaine
                // lecture retentera la migration.
                try? save(stored.settings, accountId: accountId, defaults: defaults)
            }
            return stored.settings
        } catch {
            return KbSupOcrSettings.defaultSettings
        }
    }

    /// `saveMathOcrSettings` : enregistre les réglages tels quels.
    static func save(
        _ settings: KbSupOcrSettings,
        accountId: String,
        defaults: UserDefaults = .standard
    ) throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: physicalKey(accountId: accountId))
    }

    /// `currentServerSessionToken` : jeton de session serveur encore valide,
    /// sinon chaîne vide. `SessionStore` porte déjà la règle (`isTokenValid` :
    /// préfixe `dus_` et échéance non dépassée) — à lire depuis le fil
    /// principal, comme tout état d'un `ObservableObject`.
    static func currentServerSessionToken(store: SessionStore) -> String {
        guard store.isTokenValid, let token = store.token else { return "" }
        return token
    }

    /// Clé physique de la donnée de compte (`AccountStorage` côté Expo) :
    /// préfixe de compte puis clé logique. Sans compte, la portée est celle des
    /// écrans d'avant-session.
    private static func physicalKey(accountId: String) -> String {
        let scope = accountId.isEmpty ? RewStorageScope.onboardingAccountStorageId : accountId
        let key = try? RewStorageScope.accountStorageKey(
            accountId: scope,
            logicalKey: KbSupOcrSettings.storageKey
        )
        return key ?? KbSupOcrSettings.storageKey
    }

    /// `JSON.parse` puis migration v2 : les anciennes versions enregistraient
    /// `local` par défaut, puis l'écran permettant de repasser en premium a
    /// disparu. Cette valeur sans version est donc migrée une fois vers le
    /// relais ; un choix local enregistré en v2 reste ensuite respecté. Le jeton
    /// de session est toujours repris : une ancienne clé technique conservée
    /// localement ne l'est jamais.
    private static func parse(
        _ raw: String,
        token: String
    ) throws -> (settings: KbSupOcrSettings, legacy: Bool) {
        let decoded = try JSONSerialization.jsonObject(
            with: Data(raw.utf8),
            options: .fragmentsAllowed
        )
        let object = decoded as? [String: Any] ?? [:]
        let legacy = intValue(object["schemaVersion"]) != KbSupOcrSettings.currentSchemaVersion
        let storedMode = object["mode"] as? String

        let settings = KbSupOcrSettings(
            schemaVersion: KbSupOcrSettings.currentSchemaVersion,
            mode: legacy || storedMode != KbSupOcrMode.local.rawValue ? .premium : .local,
            endpoint: (object["endpoint"] as? String) ?? KbSupOcrSettings.defaultSettings.endpoint,
            token: token
        )
        return (settings, legacy)
    }

    /// `schemaVersion` lu comme nombre JSON : `2` et `2.0` valent tous deux la
    /// version courante.
    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? Double { return Int(number) }
        return nil
    }
}
