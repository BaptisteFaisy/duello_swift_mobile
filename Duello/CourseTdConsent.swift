import Foundation

/// Autorisation de partage avec les prestataires d'IA, versionnée.
///
/// Porté de `src/utils/aiDataSharingConsent.ts` et de `AI_CONSENT_POLICY`
/// (`src/legal/privacyPolicy.generated.ts`). L'analyse d'une feuille de TD
/// transmet le document au relais : elle exige donc l'accord explicite de
/// l'élève, comme côté Expo (`requireAiDataSharingConsent`).
enum CtdAiConsent {
    /// `AI_CONSENT_POLICY.version` : une nouvelle version redemande l'accord.
    static let version = "2026-08-30"
    /// `AI_CONSENT_POLICY.title`.
    static let title = "Autoriser le traitement par l’IA ?"
    /// `AI_CONSENT_POLICY.message`.
    static let message = "Pour la correction, la transcription ou la génération demandée, Duello transmet uniquement le contenu que tu choisis — texte, copie, photo, audio ou document — aux prestataires nécessaires parmi [OI], Anthropic, Mathpix, z.ai, Alibaba Cloud et ElevenLabs. Ces données servent seulement à produire le résultat demandé, jamais à la publicité de Duello. Tu peux refuser et continuer sans lancer cette fonction, ou retirer ton autorisation dans la politique de confidentialité."
    /// `AI_CONSENT_POLICY.allowLabel`.
    static let allowLabel = "Autoriser"
    /// `AI_CONSENT_POLICY.denyLabel`.
    static let denyLabel = "Continuer sans IA"
    /// `AI_CONSENT_POLICY.declinedLabel` : message affiché quand l'accord est
    /// refusé — l'analyse n'est alors pas lancée.
    static let declinedLabel = "La fonction IA n’a pas été lancée."

    /// `ACCOUNT_STORAGE_KEYS.aiDataSharingConsent`.
    private static let storageKey = "prepapp-ai-data-sharing-consent:v1"

    /// `hasAiDataSharingConsent` : accord enregistré pour la version courante.
    static var isGranted: Bool {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let data = raw.data(using: .utf8),
              let stored = try? JSONDecoder().decode(StoredConsent.self, from: data)
        else { return false }
        return stored.version == version
    }

    /// `requestNewConsent` : enregistre l'accord et sa date.
    static func grant() {
        let stored = StoredConsent(
            version: version,
            acceptedAt: ISO8601DateFormatter().string(from: Date())
        )
        guard let data = try? JSONEncoder().encode(stored),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }

    /// `revokeAiDataSharingConsent`.
    static func revoke() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Forme persistée (`StoredAiConsent`).
    private struct StoredConsent: Codable {
        var version: String
        var acceptedAt: String
    }
}
