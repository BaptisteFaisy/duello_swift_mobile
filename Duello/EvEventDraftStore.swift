//
//  EvEventDraftStore.swift
//  Duello
//
//  Brouillon de copie persisté par compte : une fermeture d'application pendant
//  l'épreuve ne perd jamais les réponses écrites, et les photos sélectionnées
//  restent référencées par leur URI de fichier.
//
//  Fichier source Expo porté : `src/utils/eventDrafts.ts` (clé
//  `ACCOUNT_STORAGE_KEYS.eventDrafts`). Le stockage de compte d'Expo est
//  remplacé par les préférences, scopées par identifiant public du compte.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventDraftStore {
    /// Brouillon enregistré, vide s'il n'y en a pas ou s'il est illisible.
    static func load(accountId: String, eventId: String) -> EvDraft {
        guard let data = UserDefaults.standard.data(forKey: key(accountId: accountId, eventId: eventId)),
              let draft = try? JSONDecoder().decode(EvDraft.self, from: data)
        else { return EvDraft() }
        return draft
    }

    /// Enregistre le brouillon ; un échec ne bloque jamais la copie en cours.
    static func save(_ draft: EvDraft, accountId: String, eventId: String) {
        var stamped = draft
        stamped.updatedAt = Date().timeIntervalSince1970 * 1000
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        UserDefaults.standard.set(data, forKey: key(accountId: accountId, eventId: eventId))
    }

    /// Efface le brouillon à la soumission définitive.
    static func clear(accountId: String, eventId: String) {
        UserDefaults.standard.removeObject(forKey: key(accountId: accountId, eventId: eventId))
    }

    /// Une copie devient soumissible dès un caractère ou une photo.
    static func hasContent(_ draft: EvDraft) -> Bool {
        let hasText = draft.answers.values.contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return hasText || !draft.photoUris.isEmpty
    }

    /// Clé de stockage, scopée par compte et par événement.
    private static func key(accountId: String, eventId: String) -> String {
        "com.duello.ios.event-draft.\(accountId).\(eventId)"
    }
}
