//
//  PhotoExerciseTranscription.swift
//  Duello
//
//  Port de src/utils/photoExerciseTranscription.ts (RN) — repères de questions
//  transmis au modèle de transcription photo et découpage d'une copie
//  d'exercice entier question par question.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/photoExerciseTranscription.ts
//        `PhotoExerciseQuestion`, `transcriptionRepere`,
//        `normalizedQuestionLabel`, `headingLabel`,
//        `splitFullExerciseTranscription`.
//
//  Notes datées (24/09/2026) :
//    - `normalizedQuestionLabel` était privée dans la source ; elle est exposée
//      ici (contrat de test) et garde exactement la même normalisation.
//    - `toLocaleUpperCase('fr-FR')` → `uppercased(with: Locale("fr-FR"))` ;
//      `toLocaleLowerCase('fr')` → `lowercased(with: Locale("fr"))`.
//    - Le découpage est une translation directe : la répartition reste un
//      dictionnaire `questionId → texte` ; la présentation et l'insertion
//      restent à la charge de l'appelant (feuille de transcription).
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

/// Question d'un exercice photographié (`PhotoExerciseQuestion`).
struct PhotoExerciseQuestion: Equatable, Hashable, Identifiable {
    var id: String
    var label: String
}

/// `photoExerciseTranscription.ts` : repères et découpage d'une copie complète.
enum PhotoExerciseTranscription {

    // MARK: - Repères

    /// `transcriptionRepere` : repère transmis au modèle de transcription pour
    /// une question. Les libellés sont uniques entre parties (« I.1 », « II.1 ») ;
    /// quand deux questions partagent malgré tout le même libellé normalisé
    /// (exercices distincts sans portée de partie), le repère est qualifié par sa
    /// section pour rester unique.
    static func transcriptionRepere(
        _ question: PhotoExerciseQuestion,
        _ questions: [PhotoExerciseQuestion]
    ) -> String {
        let normalized = normalizedQuestionLabel(question.label)
        let collision = questions.contains { other in
            other.id != question.id && normalizedQuestionLabel(other.label) == normalized
        }
        guard collision else { return question.label }
        let tag = sectionTag(of: question.id)
        return tag.isEmpty ? question.label : "\(tag) – \(question.label)"
    }

    /// Partie « section » de `transcriptionRepere` : chaque segment d'identifiant
    /// (`--` sépare les niveaux) devient « Exercice n », « Partie X » ou reste tel
    /// quel.
    private static func sectionTag(of id: String) -> String {
        guard let cut = id.lastIndex(of: "-"), cut != id.startIndex else { return "" }
        let section = String(id[id.startIndex..<cut])
        return section
            .components(separatedBy: "--")
            .map(segmentTag(_:))
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// `segment` de `sectionTag` : « exercice-1 » → « Exercice 1 »,
    /// « partie-ii » → « Partie II », sinon le segment inchangé.
    private static func segmentTag(_ segment: String) -> String {
        if let number = firstCapture(#"^exercice-(\d+)$"#, in: segment) {
            return "Exercice \(number)"
        }
        if let name = firstCapture(#"^partie-(.+)$"#, in: segment) {
            return "Partie \(name.uppercased(with: Locale(identifier: "fr-FR")))"
        }
        return segment
    }

    /// `normalizedQuestionLabel` : rend comparables « 2.a », « 2 - a » et leurs
    /// variantes Markdown (sans diacritiques ni ponctuation, en minuscules, sans
    /// préfixe « Question »).
    static func normalizedQuestionLabel(_ label: String) -> String {
        let folded = label.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "fr"))
        let lowered = folded.lowercased(with: Locale(identifier: "fr"))
        let withoutPrefix = lowered.replacingOccurrences(
            of: #"^question\s+"#, with: "", options: .regularExpression)
        return withoutPrefix.replacingOccurrences(
            of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    /// `headingLabel` : libellé d'un intertitre « Question … » d'une ligne (titre
    /// Markdown, gras, deux-points facultatifs), sinon `nil`.
    private static func headingLabel(_ line: String) -> String? {
        let pattern = #"^\s*(?:#{1,6}\s*)?(?:\*\*\s*)?question\s+(.+?)(?:\s*\*\*)?\s*:?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let capture = Range(match.range(at: 1), in: line)
        else { return nil }
        let label = String(line[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
    }

    // MARK: - Découpage

    /// `splitFullExerciseTranscription` : découpe la transcription relue suivant
    /// les intertitres imposés au modèle. Un intertitre qui ne correspond à
    /// aucune question du sujet fait échouer tout le découpage (dictionnaire
    /// vide) : l'appelant conserve alors le texte entier dans le champ actif,
    /// ce qui évite de perdre ou de mal attribuer une réponse incertaine.
    static func splitFullExerciseTranscription(
        _ text: String,
        _ questions: [PhotoExerciseQuestion]
    ) -> [String: String] {
        guard let index = labelIndex(questions) else { return [:] }
        guard let scan = scan(text: text, index: index) else { return [:] }
        return assemble(scan)
    }

    /// `questionsByLabel` : index des questions par libellé normalisé. `nil` dès
    /// qu'un même libellé normalisé revient (répartition incertaine).
    private static func labelIndex(
        _ questions: [PhotoExerciseQuestion]
    ) -> [String: PhotoExerciseQuestion]? {
        var index: [String: PhotoExerciseQuestion] = [:]
        for question in questions {
            let normalized = normalizedQuestionLabel(transcriptionRepere(question, questions))
            if normalized.isEmpty { continue }
            if index[normalized] != nil { return nil }
            index[normalized] = question
        }
        return index
    }

    /// Résultat du balayage ligne à ligne : sections par question, préambule
    /// avant le premier intertitre, et question ouverte en premier.
    private struct ScanResult {
        var sections: [String: [String]]
        var preamble: [String]
        var firstQuestionId: String
    }

    /// `for (const line of …)` de la source : répartit les lignes sous la
    /// question courante ; `nil` si un intertitre reste inconnu ou s'il n'y en a
    /// aucun.
    private static func scan(
        text: String,
        index: [String: PhotoExerciseQuestion]
    ) -> ScanResult? {
        var sections: [String: [String]] = [:]
        var preamble: [String] = []
        var currentQuestionId: String?
        var firstQuestionId: String?

        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for rawLine in rawLines {
            let line = rawLine.last == "\r" ? String(rawLine.dropLast()) : String(rawLine)
            if let candidate = headingLabel(line) {
                guard let question = index[normalizedQuestionLabel(candidate)] else { return nil }
                currentQuestionId = question.id
                if firstQuestionId == nil { firstQuestionId = question.id }
                if sections[question.id] == nil { sections[question.id] = [] }
                continue
            }
            if let currentQuestionId {
                sections[currentQuestionId, default: []].append(line)
            } else {
                preamble.append(line)
            }
        }

        guard let first = firstQuestionId else { return nil }
        return ScanResult(sections: sections, preamble: preamble, firstQuestionId: first)
    }

    /// Assemblage final : le préambule ouvre la première question, chaque section
    /// est rognée et les sections vides sont écartées.
    private static func assemble(_ scan: ScanResult) -> [String: String] {
        var sections = scan.sections
        let leadingText = scan.preamble
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !leadingText.isEmpty {
            var lines = sections[scan.firstQuestionId] ?? []
            lines.insert(contentsOf: [leadingText, ""], at: 0)
            sections[scan.firstQuestionId] = lines
        }
        var result: [String: String] = [:]
        for (id, lines) in sections {
            let sectionText = lines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sectionText.isEmpty { result[id] = sectionText }
        }
        return result
    }

    // MARK: - Utilitaires

    /// Premier groupe capturé d'un motif, ou `nil`.
    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[capture])
    }
}
