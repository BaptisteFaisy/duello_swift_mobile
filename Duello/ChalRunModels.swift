//
//  ChalRunModels.swift
//  Duello
//
//  Lot 11-C — déroulé d'un défi : modèles du bilan affiché après le match.
//
//  Fichiers source Expo portés (champs et libellés repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx (plage 2370-2697) : forme du `result`
//      consommé par l'écran de résultat (`outcome`, `opponentName`,
//      `opponentInitial`, `opponentAbandoned`, `eloAfter`, `prompt`,
//      `solution`, `answers`, `opponentAnswers`, `scorePenalty`, `scoreBonus`,
//      `needsContinuation`, `exerciseCount`, `minutes`, `subject`,
//      `trainingTarget`) et `ChallengeTrainingTarget` pour la reprise ;
//    - src/screens/ChallengesScreen.tsx (lignes 2436-2445, 2494-2500,
//      2513-2526) : dérivations `reviewedQuestions`, titre, libellé de section
//      et notes d'arbitrage.
//
//  Réutilise sans les recréer : `DuelVerdict`, `DuelExercise`,
//  `duelQuestionLabel`, `joinDuelAnswers`, `DuelResultState`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Cible de reprise d'un exercice après un défi (`ChallengeTrainingTarget`).
struct ChalRunTrainingTarget: Equatable {
    var itemId: String
    var itemTitle: String
    var subjectId: String
    var chapterId: String
    var year: String
    /// `exercice`, `colle` ou `annale`, selon la nature de l'énoncé.
    var activity: String
}

/// Une question comparée dans le bilan (`reviewedQuestions`) : la réponse du
/// joueur, et celle d'en face lorsqu'elle est dévoilée.
struct ChalRunReviewedQuestion: Equatable, Identifiable {
    var id: String
    /// Repère affiché de la question (« 1. », « a) »).
    var label: String
    var myAnswer: String
    var opponentAnswer: String?
}

/// Bilan d'un défi, tel que l'écran de résultat le lit (le `result` de
/// `ChallengesScreen.tsx`). Seul le sous-ensemble réellement affiché est porté.
struct ChalRunResult {
    var verdict: DuelVerdict
    /// Nom affiché de l'adversaire (`opponentName`).
    var opponentName: String
    /// Initiale affichée de l'adversaire (`opponentInitial`).
    var opponentInitial: String
    /// Vrai quand la victoire vient d'un abandon adverse (`opponentAbandoned`).
    var opponentAbandoned: Bool
    /// Cote après le défi (`eloAfter`), en pied de bilan.
    var eloAfter: Int?
    /// Énoncé rendu (`prompt`), repliable dans le bilan.
    var prompt: String
    /// Corrigé de référence (`solution`), rendu après les deux notes.
    var solution: String?
    /// Questions de l'exercice, dans l'ordre (`questions`).
    var questions: [DuelExercise.Question]
    /// Réponses rendues par le joueur, indexées par question (`answers`).
    var answers: [String: String]
    /// Réponses adverses, absentes tant que l'adversaire n'a pas rendu
    /// (`opponentAnswers`).
    var opponentAnswers: [String: String]
    /// Pénalité appliquée pour un exercice déjà commencé (`scorePenalty`).
    var scorePenalty: Int
    /// Bonus accordé quand l'adversaire avait déjà commencé (`scoreBonus`).
    var scoreBonus: Int
    /// Vrai quand la copie peut être poursuivie dans Entraînement.
    var needsContinuation: Bool
    /// Nombre d'exercices joués dans la série (`exerciseCount`).
    var exerciseCount: Int
    /// Durée du défi, en minutes (`minutes`).
    var minutes: Int
    /// Matière du défi (`subject`).
    var subject: String
    var trainingTarget: ChalRunTrainingTarget

    /// L'adversaire a rendu sa copie : ses réponses sont dévoilées.
    var hasOpponentSubmission: Bool { verdict.opponentAnswers != nil }

    /// Questions réellement rédigées, avec la réponse d'en face : les questions
    /// laissées vides ne sont pas montrées (`reviewedQuestions`).
    var reviewedQuestions: [ChalRunReviewedQuestion] {
        questions.enumerated().compactMap { index, question in
            let answer = answers[question.id] ?? ""
            guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return ChalRunReviewedQuestion(
                id: question.id,
                label: duelQuestionLabel(question, index),
                myAnswer: answer,
                opponentAnswer: opponentAnswers[question.id]
            )
        }
    }

    /// Titre de l'en-tête : « Défi non arbitré », « Défi gagné », « Égalité »
    /// ou « Défi perdu », selon l'arbitrage puis l'issue.
    var title: String {
        guard verdict.ranked else { return "Défi non arbitré" }
        switch verdict.outcome {
        case .me: return "Défi gagné"
        case .draw: return "Égalité"
        case .opponent: return "Défi perdu"
        }
    }

    /// Libellé de la section verdict : le juge est nommé, pour qu'un défi
    /// départagé par le barème local ne se présente pas comme une note de l'IA.
    var verdictSectionLabel: String {
        guard verdict.ranked else { return "BILAN DU DÉFI" }
        return verdict.source == .ai ? "VERDICT DE L’IA" : "VERDICT"
    }

    /// Sous-titre de l'en-tête : « n exercices · m minutes · matière ».
    var headerMeta: String {
        "\(exerciseCount) exercice\(exerciseCount > 1 ? "s" : "") · \(minutes) minutes · \(subject)"
    }
}

/// Mise en forme de la cote : séparateur de milliers par espace, sans dépendre
/// d'`Intl` (le `formatElo` de `ChallengesScreen.tsx`).
enum ChalRunFormat {
    static func elo(_ value: Int?) -> String {
        guard let value else { return "—" }
        var grouped = ""
        for (offset, digit) in String(value).reversed().enumerated() {
            if offset > 0 && offset % 3 == 0 { grouped.append(" ") }
            grouped.append(digit)
        }
        return String(grouped.reversed())
    }

    /// Ligne d'ELO affichée en pied de bilan : « 1 234 Elo en Mathématiques ».
    static func eloLine(_ value: Int?, subject: String) -> String {
        "\(elo(value)) Elo en \(subject)"
    }

    /// Date limite affichée, à partir d'un horodatage en millisecondes
    /// (`formatDeadline`) : l'heure seule suffit, le défi se joue le jour même.
    static func deadline(_ milliseconds: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH'h'mm"
        return formatter.string(from: Date(timeIntervalSince1970: milliseconds / 1000))
    }
}
