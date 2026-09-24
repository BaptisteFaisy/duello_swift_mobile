//
//  ExGCorrectionGeneralReport.swift
//  Duello
//
//  Port de src/utils/correctionGeneralReport.ts (RN) — compte rendu général du
//  bilan terminé : une phrase de synthèse des verdicts rendus par l'IA, question
//  par question.
//  Port de src/components/correction-summary/CorrectionGeneralReport.tsx (RN)
//  — la carte grise du compte rendu (micro-titre + phrase), rendue dans
//  `CorrectionOverview.tsx:17` après les tuiles de résultats et l'alerte des
//  réponses à relancer.
//
//  Réutilise sans les redéfinir :
//    - `ExGCorrection` / `ExGQuestion` / `ExGQuestionStatus`
//      (ExGCorrectionModels.swift) = `SuccessSummaryCorrection` /
//      `SuccessSummaryQuestion` / `SuccessSummaryQuestionStatus`.
//    - `Theme` (Theme.swift) pour les couleurs et rayons de la source.
//    - `LatexToUnicode.toUnicodeMath` (LatexToUnicodeCore.swift).
//
//  Notes (2026-09-24) :
//  - `MathStatementText` de la source n'est pas composé en WebView : le port
//    passe par `LatexToUnicode.toUnicodeMath`, comme `SubjFlashcardMathText`.
//    `fitWideContent` (mise à l'échelle des formules longues) n'est pas porté.
//  - `lineHeight` de la source (14 pour le titre, 18 pour le corps) n'a pas
//    d'équivalent direct ; la taille de police seule est reprise, comme dans les
//    autres blocs portés.
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Compte rendu général

/// `generalCorrectionReport` : synthèse des verdicts, ou `nil` sans question.
///
/// Le libellé assemble un en-tête (« Toutes les questions sont validées », « x
/// questions validées sur n », « Aucune question validée ») et le détail des
/// verdicts joints par « et », dans l'ordre fixe de la source.
enum ExGCorrectionGeneralReport {
    static func report(_ questions: [ExGQuestion]) -> String? {
        let total = questions.count
        guard total > 0 else { return nil }

        var counts: [ExGQuestionStatus: Int] = [:]
        for question in questions { counts[question.status, default: 0] += 1 }
        func count(_ status: ExGQuestionStatus) -> Int { counts[status] ?? 0 }

        let validated = count(.perfect) + count(.correct)
        let head: String
        if validated == total {
            head = total == 1 ? "Question validée" : "Toutes les questions sont validées"
        } else if validated == 0 {
            head = "Aucune question validée"
        } else {
            head = "\(pluralize(validated, "question validée", "questions validées")) sur \(total)"
        }

        var parts: [String] = []
        if count(.perfect) > 0 { parts.append(pluralize(count(.perfect), "parfaite", "parfaites")) }
        if count(.correct) > 0 { parts.append(pluralize(count(.correct), "juste", "justes")) }
        if count(.partial) > 0 { parts.append("\(count(.partial)) à ajuster") }
        if count(.incorrect) > 0 {
            parts.append(pluralize(count(.incorrect), "incorrecte", "incorrectes"))
        }
        if count(.error) > 0 { parts.append("\(count(.error)) à relancer") }
        if count(.unanswered) > 0 { parts.append("\(count(.unanswered)) sans réponse") }
        if count(.pending) > 0 { parts.append("\(count(.pending)) en correction") }

        let detail = parts.count > 1
            ? "\(parts.dropLast().joined(separator: ", ")) et \(parts[parts.count - 1])"
            : parts[0]
        return "\(head) : \(detail)."
    }

    /// `pluralize` de la source : « 2 questions », « 1 question ».
    private static func pluralize(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(count) \(count > 1 ? plural : singular)"
    }
}

// MARK: - Bloc d'affichage

/// `CorrectionGeneralReport` : carte grise du compte rendu général, entre les
/// résultats et la première question. Même carte que le compte rendu de
/// l'animation correction de /home : fond `surfaceMuted`, micro-titre en
/// majuscules, sans contour. `nil` sans question → aucun bloc rendu.
struct ExGCorrectionGeneralReportBlock: View {
    let correction: ExGCorrection

    var body: some View {
        if let report = ExGCorrectionGeneralReport.report(correction.questions) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Compte rendu général")
                    .font(.system(size: 11, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(Theme.inkFaint)
                Text(LatexToUnicode.toUnicodeMath(report))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Compte rendu général : \(report)")
        }
    }
}
