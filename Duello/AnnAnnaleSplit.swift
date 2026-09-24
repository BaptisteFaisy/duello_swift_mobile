// Port de src/utils/annaleSplit.ts (RN) — hauteur de l'énoncé au-dessus du
// champ de réponse, exercice par exercice.
//
// Fichiers source Expo portés (noms et constantes repris mot pour mot) :
//   - `src/utils/annaleSplit.ts` — `AnnaleSplitMap`, `DEFAULT_ANNALE_SPLIT`,
//     `MIN_ANNALE_SPLIT`, `MAX_ANNALE_SPLIT`, `KEYBOARD_MAX_ANNALE_SPLIT`,
//     `STATEMENT_PANE_MIN_HEIGHT`, `WORKSPACE_MIN_HEIGHT`, `clampAnnaleSplit`,
//     `annaleSplitBounds`, `effectiveAnnaleSplit`, `loadAnnaleSplits`,
//     `loadAnnaleSplit`, `saveAnnaleSplit` ;
//   - `src/storage/keys.ts` — `ACCOUNT_STORAGE_KEYS.annaleSplits`
//     (`prepapp-annale-splits:v1`).
//
// Limite assumée (24/09/2026) : la source passe par `AccountStorage`
// (asynchrone, cloisonné par compte, synchronisé serveur). Le portage écrit
// dans `UserDefaults` sous la clé logique conservée telle quelle, comme
// `CollStorage`/`CtdStorage` : les helpers sont donc synchrones et le
// cloisonnement par compte n'est pas reproduit ici (portée = appareil).
//
// Cible : iOS 16, aucune dépendance externe (CoreFoundation est un framework
// système, utilisé seulement pour distinguer un vrai booléen JSON d'un nombre).
//
import Foundation
import CoreFoundation

/// Réglages de hauteur d'énoncé par exercice (`AnnaleSplitMap`).
///
/// L'atelier de réponse (champ de réponse, clavier, tableau blanc) est
/// explicitement hors périmètre (`AnnReaderCore.swift`) : ces helpers ne
/// dessinent aucun panneau, ils calculent seulement la hauteur à donner à
/// l'énoncé et persistent le choix de l'élève.
enum AnnaleSplit {
    /// `DEFAULT_ANNALE_SPLIT` : position d'origine de la ligne, celle qui
    /// convient à la plupart des sujets.
    static let DEFAULT_ANNALE_SPLIT = 0.46

    /// `MIN_ANNALE_SPLIT` : borne basse du déplacement de la ligne.
    static let MIN_ANNALE_SPLIT = 0.08

    /// `MAX_ANNALE_SPLIT` : borne haute du déplacement de la ligne.
    static let MAX_ANNALE_SPLIT = 0.92

    /// `KEYBOARD_MAX_ANNALE_SPLIT` : quand un clavier occupe le bas de l'écran,
    /// la réponse garde l'essentiel de la hauteur restante.
    static let KEYBOARD_MAX_ANNALE_SPLIT = 0.28

    /// `STATEMENT_PANE_MIN_HEIGHT` : amorce d'énoncé laissée visible.
    static let STATEMENT_PANE_MIN_HEIGHT = 32.0

    /// `WORKSPACE_MIN_HEIGHT` : amorce de réponse laissée visible.
    static let WORKSPACE_MIN_HEIGHT = 32.0

    /// `ACCOUNT_STORAGE_KEYS.annaleSplits` : clé logique conservée à l'identique
    /// dans les préférences.
    static let STORAGE_KEY = "prepapp-annale-splits:v1"

    /// `clampAnnaleSplit` : la ligne reste toujours dans ses bornes relatives ;
    /// une valeur non finie revient à la position d'origine.
    static func clampAnnaleSplit(_ ratio: Double) -> Double {
        guard ratio.isFinite else { return DEFAULT_ANNALE_SPLIT }
        return min(MAX_ANNALE_SPLIT, max(MIN_ANNALE_SPLIT, ratio))
    }

    /// `annaleSplitBounds` : course réelle de la ligne sur un écran donné. Les
    /// hauteurs minimales des deux panneaux arrêtent le doigt là où la mise en
    /// page s'arrêterait de toute façon. Un écran trop court pour les deux
    /// minimums rend la course relative.
    static func annaleSplitBounds(contentHeight: Double) -> (min: Double, max: Double) {
        guard contentHeight.isFinite, contentHeight > 0 else {
            return (MIN_ANNALE_SPLIT, MAX_ANNALE_SPLIT)
        }
        let low = max(MIN_ANNALE_SPLIT, STATEMENT_PANE_MIN_HEIGHT / contentHeight)
        let high = min(MAX_ANNALE_SPLIT, 1 - WORKSPACE_MIN_HEIGHT / contentHeight)
        return high <= low ? (MIN_ANNALE_SPLIT, MAX_ANNALE_SPLIT) : (low, high)
    }

    /// `effectiveAnnaleSplit` : hauteur réellement appliquée à l'énoncé, réglage
    /// de l'exercice et course disponible sur l'écran. Le clavier réduit déjà la
    /// hauteur du conteneur ; il ne comprime pas une seconde fois le choix de
    /// l'utilisateur (celui-ci revient dès que le clavier se ferme).
    static func effectiveAnnaleSplit(
        ratio: Double,
        keyboardOpen: Bool,
        contentHeight: Double = 0
    ) -> Double {
        let clamped = clampAnnaleSplit(ratio)
        let bounds = annaleSplitBounds(contentHeight: contentHeight)
        let availableMax = keyboardOpen
            ? max(bounds.min, min(bounds.max, KEYBOARD_MAX_ANNALE_SPLIT))
            : bounds.max
        return min(availableMax, max(bounds.min, clamped))
    }
}

// MARK: - Persistance locale

extension AnnaleSplit {
    /// `loadAnnaleSplits` : `JSON.parse` puis filtrage entrée par entrée (une
    /// valeur illisible ou hors bornes ne casse pas la lecture). Une enveloppe
    /// illisible rend une carte vide.
    static func loadAnnaleSplits() -> [String: Double] {
        guard let raw = UserDefaults.standard.string(forKey: STORAGE_KEY),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any]
        else { return [:] }

        var splits: [String: Double] = [:]
        for (itemId, value) in payload {
            // `typeof ratio === 'number'` : un booléen JSON arrive aussi en
            // `NSNumber`, on l'écarte comme la source le fait avec `typeof`
            // (`is Bool` est traître : `NSNumber(1)` y répond `true`).
            guard let number = value as? NSNumber, !isJSONBoolean(number) else { continue }
            let ratio = number.doubleValue
            guard ratio.isFinite else { continue }
            splits[itemId] = clampAnnaleSplit(ratio)
        }
        return splits
    }

    /// `loadAnnaleSplit` : hauteur de l'exercice, ou position d'origine.
    static func loadAnnaleSplit(itemId: String) -> Double {
        loadAnnaleSplits()[itemId] ?? DEFAULT_ANNALE_SPLIT
    }

    /// `saveAnnaleSplit` : une ligne remise à sa position d'origine n'a plus
    /// rien à enregistrer — la clé est retirée pour ne pas faire grossir la
    /// mémoire pour un réglage par défaut.
    static func saveAnnaleSplit(itemId: String, ratio: Double) {
        var splits = loadAnnaleSplits()
        let clamped = clampAnnaleSplit(ratio)
        if abs(clamped - DEFAULT_ANNALE_SPLIT) < 0.005 {
            guard splits[itemId] != nil else { return }
            splits[itemId] = nil
        } else {
            guard splits[itemId] != clamped else { return }
            splits[itemId] = clamped
        }
        guard let data = try? JSONSerialization.data(withJSONObject: splits),
              let text = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(text, forKey: STORAGE_KEY)
    }

    /// Vrai si `number` est un booléen JSON (`true`/`false`) et non un nombre :
    /// `NSNumber(1)` répondrait `true` à `is Bool`, on interroge donc le type
    /// CoreFoundation sous-jacent.
    private static func isJSONBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
