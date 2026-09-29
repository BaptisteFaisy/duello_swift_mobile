//
//  ProfCourseText.swift
//  Duello
//
//  Port de `src/utils/profCourseTextCache.ts` (RN) — mémo du texte extrait d'un
//  cours uploadé.
//
//  L'extraction passe par le relais et lui envoie le fichier entier : la garder
//  en mémoire, le temps de la session, évite de renvoyer plusieurs fois le même
//  PDF — une fois pour la première question, plus jamais pour les suivantes.
//
//  Un cours est identifié par son URI et la date de son import : réimporter le
//  même fichier à une autre date donne une clé différente, donc un texte
//  réextrait. Un échec n'est jamais mémorisé, pour qu'une page suivante puisse
//  réessayer. Le résultat vide est une réponse valide (un cours sans couche de
//  texte) et reste donc absent du mémo, pour qu'un cours photo ne soit jamais
//  confondu avec un cours dont la lecture a échoué.
//
//  Écart assumé : la source partage une `Promise` déjà lancée
//  (`shareProfCourseExtraction(document, relayCourseText(...))`) ; le portage
//  reçoit une closure asynchrone et ne la lance qu'une fois, quand aucun envoi
//  n'est déjà en vol. Le comportement observable (un seul envoi, même texte pour
//  tous les appelants, échec jamais mémorisé) est identique.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Mémo de session du texte extrait d'un cours (`profCourseTextCache.ts`).
enum ProfCourseTextCache {

    private static let lock = NSLock()
    /// Texte déjà extrait, par clé de cours.
    private static var extracted: [String: String] = [:]
    /// Extractions en vol, partagées entre pages (`pending`).
    private static var pending: [String: Task<String, Error>] = [:]

    /// `profCourseTextKey` : clé de mémoire d'un cours — son fichier et la date
    /// de son import.
    static func profCourseTextKey(_ document: CtdStoredCourseDocument) -> String {
        "\(document.uri)::\(document.uploadedAt)"
    }

    /// `cachedProfCourseText` : texte déjà extrait pour ce cours, s'il existe.
    static func cachedProfCourseText(_ document: CtdStoredCourseDocument?) -> String? {
        guard let document else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let text = extracted[profCourseTextKey(document)], !text.isEmpty else {
            return nil
        }
        return text
    }

    /// `rememberProfCourseText` : retient le texte extrait, pour les questions
    /// qui suivent. Un texte blanc ne remplit pas le mémo.
    static func rememberProfCourseText(_ document: CtdStoredCourseDocument, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        extracted[profCourseTextKey(document)] = trimmed
    }

    /// `shareProfCourseExtraction` : deux pages qui sollicitent le prof pendant
    /// que le relais travaille ne font partir qu'un envoi. Un cours déjà lu ne
    /// repart pas ; un échec n'est jamais mémorisé.
    static func shareProfCourseExtraction(
        _ document: CtdStoredCourseDocument,
        extraction: @escaping () async throws -> String
    ) async throws -> String {
        let key = profCourseTextKey(document)
        lock.lock()
        if let dejaLa = extracted[key], !dejaLa.isEmpty {
            lock.unlock()
            return dejaLa
        }
        if let enCours = pending[key] {
            lock.unlock()
            return try await enCours.value
        }
        let task = Task<String, Error> { try await extraction() }
        pending[key] = task
        lock.unlock()

        do {
            let text = try await task.value
            lock.lock()
            pending[key] = nil
            lock.unlock()
            rememberProfCourseText(document, text: text)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lock.lock()
            pending[key] = nil
            lock.unlock()
            throw error
        }
    }
}
