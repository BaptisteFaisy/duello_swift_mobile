//
//  EvEventPhotoRelay.swift
//  Duello
//
//  Transcription photo d'un champ de réponse : le relais premium lit la photo
//  et rend le texte, corrigible à la main dans le champ ciblé.
//
//  Fichiers source Expo portés : `src/utils/eventPhotoTranscription.ts` et
//  `src/utils/eventPhotoRelay.ts` (action `transcribe-photo`, mode `question`,
//  exercice « Concours blanc Duello »). Même chemin que le relais premium des
//  exercices : `POST relay/transcribe-photo` sur l'origine de l'API.
//  Le texte est renvoyé tel quel : le serveur a déjà converti le LaTeX en
//  caractères affichables, comme pour `PhotoTranscriptionView`.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventPhotoRelay {
    /// Réponse du relais pour une lecture photo réussie.
    struct Response: Decodable {
        let text: String
    }

    /// Matière annoncée au relais (`EventAnswerFields.tsx`).
    static let subject = "Mathématiques"
    /// Contexte de sujet annoncé au relais.
    static let exercise = "Concours blanc Duello"

    /// Envoie la photo au relais et rend le texte transcrit.
    static func transcribe(imageBase64: String, token: String?) async throws -> String {
        let body: [String: Any] = [
            "action": "transcribe-photo",
            "image": imageBase64,
            "mimeType": "image/jpeg",
            "subject": subject,
            "exercise": exercise,
            "transcriptionMode": "question",
        ]
        let payload = try JSONSerialization.data(withJSONObject: body, options: [])
        do {
            let response = try await DuelloAPI.request(
                Response.self,
                "relay/transcribe-photo",
                method: "POST",
                token: token,
                body: payload
            )
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw DirectoryError(message: "La transcription est vide, réessaie.")
            }
            return text
        } catch let error as DirectoryError where error.status == 401 || error.status == 403 {
            throw DirectoryError(message: "accès premium refusé")
        }
    }
}
