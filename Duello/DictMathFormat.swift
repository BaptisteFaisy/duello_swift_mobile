//
//  DictMathFormat.swift
//  Duello
//
//  Portage de `src/utils/mathDictation.ts` : seconde passe de la dictée, côté
//  serveur (`formatMathDictation`). Le téléphone n'embarque ni session de
//  fournisseur ni clé : il envoie le texte déjà transcrit et, s'il existe,
//  l'énoncé affiché au relais, avec son jeton habituel.
//
//  Le POST vise une URL de relais absolue, comme le `fetch(endpoint, …)` de la
//  source ; le corps JSON passe par `DuelloAPI.encodeBody`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Contexte fourni à la seconde passe — `MathDictationContext`.
struct DictMathContext {
    let subject: String
    /// Énoncé affiché pendant la dictée, utilisé seulement pour lever une ambiguïté.
    let exercise: String?
}

/// Passage ambigu conservé tel qu'entendu — `MathDictationAmbiguity`.
struct DictMathAmbiguity {
    let source: String
    let reason: String
}

/// Sortie structurée de la seconde passe — `MathDictationFormatting`.
struct DictMathFormatting {
    /// Transcription du moteur vocal, inchangée par le relais.
    let rawText: String
    /// Même texte, avec les seuls passages mathématiques délimités en LaTeX.
    let text: String
    let hasMath: Bool
    let ambiguities: [DictMathAmbiguity]
    let source: String
    let model: String
}

/// Corps JSON de la requête de mise en forme.
private struct DictMathRequestBody: Encodable {
    let action: String
    let text: String
    let subject: String?
    let exercise: String?
}

/// Appel de la seconde passe de dictée — `formatMathDictation`.
enum DictMathFormatter {
    /// Envoie la transcription au relais et valide sa sortie structurée.
    static func format(
        relayEndpoint: String,
        token: String,
        rawText: String,
        context: DictMathContext?
    ) async throws -> DictMathFormatting {
        guard let url = URL(string: relayEndpoint) else {
            throw DictError.badResponse("réponse [OI] de dictée invalide")
        }
        var requete = URLRequest(url: url)
        requete.httpMethod = "POST"
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            requete.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        requete.httpBody = try DuelloAPI.encodeBody(DictMathRequestBody(
            action: "format-math-dictation",
            text: rawText,
            subject: propre(context?.subject),
            exercise: propre(context?.exercise)
        ))

        let (data, reponse) = try await URLSession.shared.data(for: requete)
        guard let http = reponse as? HTTPURLResponse else {
            throw DictError.badResponse("réponse [OI] de dictée invalide")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw DictError.badResponse("accès [OI] refusé par le relais")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DictError.badResponse("mise en forme [OI] indisponible (\(http.statusCode))")
        }
        return try decode(rawText: rawText, data: data)
    }

    /// Valide la réponse du relais — la transcription brute doit être conservée.
    static func decode(rawText: String, data: Data) throws -> DictMathFormatting {
        guard let objet = try? JSONSerialization.jsonObject(with: data),
              let dict = objet as? [String: Any] else {
            throw DictError.badResponse("réponse [OI] de dictée invalide")
        }
        guard (dict["rawText"] as? String) == rawText,
              let texte = dict["text"] as? String, !texte.isEmpty,
              let hasMath = dict["hasMath"] as? Bool,
              (dict["source"] as? String) == "openai-math",
              let model = dict["model"] as? String, !model.isEmpty,
              let brutes = dict["ambiguities"] as? [Any] else {
            throw DictError.badResponse("réponse [OI] de dictée invalide")
        }

        let ambiguites = try brutes.map { element -> DictMathAmbiguity in
            guard let item = element as? [String: Any],
                  let source = item["source"] as? String,
                  let reason = item["reason"] as? String else {
                throw DictError.badResponse("ambiguïté [OI] de dictée invalide")
            }
            return DictMathAmbiguity(source: source, reason: reason)
        }
        return DictMathFormatting(
            rawText: rawText, text: texte, hasMath: hasMath,
            ambiguities: ambiguites, source: "openai-math", model: model
        )
    }

    /// Réduit un champ facultatif à sa valeur nettoyée, ou `nil`.
    private static func propre(_ texte: String?) -> String? {
        guard let texte else { return nil }
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        return propre.isEmpty ? nil : propre
    }
}
