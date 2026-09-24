//
//  EvEventSeen.swift
//  Duello
//
//  Événements vus : identifiants des concours blancs déjà ouverts par le compte.
//  C'est le socle de la pastille « nouveau » de l'onglet Événements et de chaque
//  carte d'événement ajouté au catalogue depuis la dernière consultation.
//
//  Port de src/utils/eventSeen.ts (RN).
//    - `SEEN_EVENTS_STORAGE_KEY` = `ACCOUNT_STORAGE_KEYS.seenEvents`
//      (« prepapp-seen-events:v1 », src/storage/keys.ts) ;
//    - `parseSeenEventIds`, `serializeSeenEventIds`, `unseenEventIds`,
//      `loadSeenEventIds`, `storeSeenEventId` : règles reprises mot pour mot.
//
//  Adaptations assumées (pas d'`AccountStorage` ni d'`AsyncStorage` en Swift) :
//    - le stockage de compte d'Expo (clé logique préfixée par l'identifiant du
//      compte) est remplacé par `UserDefaults`, isolé par identifiant public de
//      compte — même motif que `ChalProgress` ;
//    - les entrées/sorties d'Expo sont asynchrones (`Promise`) ; `UserDefaults`
//      étant synchrone, les fonctions correspondantes le sont aussi. Le
//      comportement observable reste identique : amorçage à la première lecture
//      (les événements déjà au catalogue comptent comme vus), aucun doublon.
//    - `getItem` pouvant rejeter côté Expo, `loadSeenEventIds` y renvoyait `[]` ;
//      `UserDefaults` ne lève jamais, ce cas disparaît (réduction sans effet
//      observable, datée 2026-09-24).
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventSeen {
    /// Clé logique des événements vus (`ACCOUNT_STORAGE_KEYS.seenEvents`).
    static let storageKey = "prepapp-seen-events:v1"

    /// Relit les identifiants vus ; un contenu illisible vaut « rien de vu ».
    /// Non-tableau ou entrées non textuelles sont écartées, comme la source.
    static func parseSeenEventIds(_ raw: String?) -> [String] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else { return [] }
        guard let entries = parsed as? [Any] else { return [] }
        return entries.compactMap { $0 as? String }
    }

    /// Sérialise les identifiants vus pour le stockage du compte.
    static func serializeSeenEventIds(_ ids: [String]) -> String {
        guard let data = try? JSONEncoder().encode(ids),
              let text = String(data: data, encoding: .utf8)
        else { return "[]" }
        return text
    }

    /// Identifiants visibles jamais vus, dans l'ordre du catalogue.
    static func unseenEventIds(visibleIds: [String], seenIds: [String]) -> [String] {
        let seen = Set(seenIds)
        return visibleIds.filter { !seen.contains($0) }
    }

    /// Charge les événements vus. À la première lecture (clé absente), les
    /// événements déjà au catalogue sont considérés comme vus : seuls les ajouts
    /// suivants allument la pastille « nouveau ».
    static func loadSeenEventIds(accountId: String, visibleIds: [String]) -> [String] {
        let defaults = UserDefaults.standard
        let key = scopedKey(accountId: accountId)
        guard let raw = defaults.string(forKey: key) else {
            let seed = visibleIds
            defaults.set(serializeSeenEventIds(seed), forKey: key)
            return seed
        }
        return parseSeenEventIds(raw)
    }

    /// Ajoute un événement aux vus et persiste la liste, sans doublon.
    static func storeSeenEventId(
        accountId: String,
        seenIds: [String],
        eventId: String
    ) -> [String] {
        if seenIds.contains(eventId) { return seenIds }
        let next = seenIds + [eventId]
        UserDefaults.standard.set(
            serializeSeenEventIds(next),
            forKey: scopedKey(accountId: accountId)
        )
        return next
    }

    /// Clé de stockage isolée par compte, comme le stockage de compte d'Expo.
    static func scopedKey(accountId: String) -> String {
        let trimmed = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(storageKey):\(trimmed.isEmpty ? "local" : trimmed)"
    }
}
