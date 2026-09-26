//
//  ExGCorrectionSummaryViews.swift
//  Duello
//
//  Bilan de correction : appréciation de la note (`GradingRemarkBadge.tsx`),
//  tuiles de résultats, liste des questions, compte rendu et correction
//  attendue (`correction-summary/…`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/correction-summary/CorrectionOverview.tsx
//    - src/components/correction-summary/CorrectionResultTiles.tsx
//    - src/components/correction-summary/CorrectionQuestionList.tsx
//    - src/components/QuestionNumberBadge.tsx
//    - src/components/GradingRemarkBadge.tsx            (appréciation)
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - §3 — Appréciation de la note

/// `GradingRemarkBadge` : l'appréciation en pastille, casse d'origine.
///
/// Les majuscules restent visuelles (`textCase`) : le libellé lu par les
/// lecteurs d'écran garde sa casse, comme le commentaire de la source.
struct ExGRemarkBadge: View {
    let score: Double?

    private var remark: ExGRemark { ExGGrading.remark(score) }

    var body: some View {
        Text(remark.label)
            .font(.system(size: 13, weight: .bold))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(remark.tone.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(remark.tone.background)
            .clipShape(Capsule())
            .accessibilityLabel("Remarque : \(remark.label)")
    }
}

// MARK: - Bilan de correction : blocs

/// `CorrectionResultTiles` : l'appréciation, puis note, XP gagnés et rang
/// réunis dans un seul bloc à contour (PR #424, `pr-corr-contours-1024`).
///
/// Le bloc reprend `styles.block` de la source : bord `colors.border` de 1 pt,
/// rayon `radii.medium`, fond `colors.surface`. Chaque mesure est centrée avec
/// son icône, et un filet vertical les sépare (`styles.divider`).
/// `StyleSheet.hairlineWidth` devient 1 pt : le port n'utilise nulle part
/// ailleurs d'épaisseur dépendante de l'échelle, et l'écart est invisible.
struct ExGCorrectionResultTiles: View {
    var scoreOn20: Double? = nil
    var xp: Double = 0
    var exerciseRank: Int? = nil

    /// Une mesure du bloc (`ResultMetric`) : identifiant, icône, libellé, valeur.
    private struct ResultMetric: Identifiable {
        let id: String
        /// Équivalent SF Symbol de l'Ionicon de la source.
        let icon: String
        let label: String
        let value: String
    }

    /// `resultMetrics` : note, XP gagnés, rang, dans cet ordre.
    private var metrics: [ResultMetric] {
        [
            ResultMetric(
                id: "score",
                icon: "graduationcap",
                label: "Note",
                value: ExGFormat.score(scoreOn20)
            ),
            ResultMetric(
                id: "xp",
                icon: "sparkles",
                label: "XP gagnés",
                value: "+\(ExGFormat.xp(xp)) XP"
            ),
            ResultMetric(
                id: "rank",
                icon: "trophy",
                label: "Rang",
                value: ExGFormat.rank(exerciseRank)
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExGRemarkBadge(score: scoreOn20)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 { divider }
                    metricView(metric)
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `styles.divider` : filet vertical, en retrait de 12 pt en haut et en bas.
    private var divider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1)
            .padding(.vertical, 12)
    }

    /// `MetricView` : icône et libellé sur une ligne, valeur en dessous.
    private func metricView(_ metric: ResultMetric) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: metric.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                Text(metric.label)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
            // Trois colonnes sur un téléphone étroit : un gros total d'XP se
            // resserre plutôt que de déborder.
            Text(metric.value)
                .font(.system(size: 17, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.label) : \(metric.value)")
    }
}

/// `QuestionNumberBadge` : numéro de question, gris sur pastille grise.
private struct ExGQuestionNumberBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 6)
            .frame(minWidth: 26, minHeight: 26)
            .background(Theme.border)
            .clipShape(Capsule())
    }
}

/// `VerdictBadge` : le verdict d'une question, couleur par statut.
private struct ExGQuestionVerdictBadge: View {
    let status: ExGQuestionStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.background)
            .clipShape(Capsule())
    }
}

/// Une ligne du bilan : numéro, verdict, puis l'emplacement du compte rendu.
private struct ExGCorrectionQuestionRow: View {
    let question: ExGQuestion
    var onOpenQuestionReport: ((String) -> Void)? = nil
    /// Vrai quand la ligne peut déplier le compte rendu (app de bureau) : la
    /// version mobile se contente du verdict centré, comme la source.
    var inline: Bool = false
    var ongoing: Bool = false

    private var available: Bool {
        question.reportAvailable && onOpenQuestionReport != nil
    }

    private var accessibilityText: String {
        if ongoing {
            return "Question \(question.label) : \(question.status.label)"
        }
        return available
            ? "Voir le compte rendu de la question \(question.label)"
            : "Question \(question.label) : \(question.status.label), compte rendu indisponible"
    }

    var body: some View {
        Button(action: { if available { onOpenQuestionReport?(question.id) } }) {
            HStack(spacing: 10) {
                ExGQuestionNumberBadge(label: question.label)

                if inline {
                    ExGQuestionVerdictBadge(status: question.status)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(question.feedback
                             ?? (available ? "Voir le compte rendu" : "Compte rendu indisponible"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let pointsText = question.pointsText {
                            Text(pointsText)
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ExGQuestionVerdictBadge(status: question.status)
                        if let pointsText = question.pointsText {
                            Text(pointsText)
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if question.status == .pending {
                    // Correction en cours : l'emplacement du compte rendu porte
                    // l'indicateur d'activité, comme `OngoingQuestion`.
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 30, height: 30)
                } else if ongoing {
                    // Pendant la correction, l'emplacement reste vide : aucun
                    // compte rendu n'est encore ouvert (`reportSlot` 30×30).
                    Color.clear.frame(width: 30, height: 30)
                } else {
                    Image(systemName: "eye")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(available ? Theme.ink : Theme.inkFaint)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                        .opacity(available ? 1 : 0.45)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .background(Theme.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityLabel(accessibilityText)
    }
}

/// `CorrectionQuestionList` : toutes les questions, dans l'ordre du sujet.
struct ExGCorrectionQuestionList: View {
    let correction: ExGCorrection
    var onOpenQuestionReport: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(correction.questions) { question in
                ExGCorrectionQuestionRow(
                    question: question,
                    onOpenQuestionReport: onOpenQuestionReport,
                    ongoing: !correction.completed
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// `CorrectionOverview` : les résultats, puis les réponses à relancer.
struct ExGCorrectionOverview: View {
    let correction: ExGCorrection
    var scoreOn20: Double? = nil
    var xp: Double = 0
    var exerciseRank: Int? = nil

    private var errorCount: Int {
        correction.questions.filter { $0.status == .error }.count
    }

    private var errorText: String {
        errorCount > 1
            ? "\(errorCount) réponses n’ont pas pu être corrigées. Reprends la copie pour les relancer."
            : "\(errorCount) réponse n’a pas pu être corrigée. Reprends la copie pour les relancer."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExGCorrectionResultTiles(scoreOn20: scoreOn20, xp: xp, exerciseRank: exerciseRank)

            if errorCount > 0 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.like)
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.like)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(exgLikeLight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compte rendu du correcteur et correction attendue.
///
/// Les libellés « Compte rendu » et « Correction » sont la reprise des termes
/// de la source (`Voir le compte rendu`, étape `Correction` du parcours
/// d'entraînement) ; le texte attendu s'affiche en serif, comme un manuel.
struct ExGAssessmentCard: View {
    var assessment: ProductionAssessment? = nil
    var expectedAnswer: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let assessment {
                VStack(alignment: .leading, spacing: 6) {
                    DuelloSectionHeader(title: "Compte rendu")
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(assessment.score)/100")
                            .font(.system(size: 15, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                        Text(assessment.note)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if let expectedAnswer, !expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    DuelloSectionHeader(title: "Correction")
                    Text(expectedAnswer)
                        .font(Theme.readingFont)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .duelloCard()
    }
}
