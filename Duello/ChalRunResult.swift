//
//  ChalRunResult.swift
//  Duello
//
//  Lot 11-C — déroulé d'un défi : écran de résultat et victoire par abandon.
//
//  Fichier source Expo porté (plage 2370-2697 de ChallengesScreen.tsx) :
//    - en-tête de bilan : retour, icône d'issue, titre, « n exercices ·
//      m minutes · matière » ;
//    - verdict nommé (`VERDICT DE L’IA` / `VERDICT` / `BILAN DU DÉFI`) ;
//    - énoncé repliable, notes des deux joueurs, réponses comparées, corrigé ;
//    - ligne d'ELO et actions (« Reprendre l’exercice », « Faire un autre
//      défi ») ;
//    - écran dédié « Défi gagné » quand l'adversaire a abandonné
//      (`opponentAbandoned`, lignes 2371-2434).
//
//  Réutilise sans les recréer : `ChalRunResult`, `ChalRunVerdictCard`,
//  `ChalRunProductionCard`, `ChalRunQuestionReviewCard`, `ChalRunSectionLabel`,
//  `ChalRunNotice`, `ChalRunEloLine`, `DuelloPrimaryButton`, `LatexToUnicode`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Bilan d'un défi arbitré (ou non arbitré) : notes, verdict, copies comparées
/// et corrigé. À ne pas confondre avec `ChallengePlayerView`, qui mène la copie
/// jusqu'au verdict ; ici, le verdict est déjà rendu.
struct ChalRunResultView: View {
    let result: ChalRunResult
    /// Initiale du joueur pour sa propre carte de note.
    let myInitial: String
    var onBack: () -> Void
    /// Reprise de l'exercice dans Entraînement, quand la copie peut continuer.
    var onContinueTraining: ((ChalRunTrainingTarget) -> Void)?

    @State private var promptExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ChalRunResultHeader(result: result, onBack: onBack)
                verdictSection
                notices
                promptSection
                notesSection
                reviewSection
                correctionSection
                ChalRunEloLine(text: ChalRunFormat.eloLine(result.eloAfter, subject: result.subject))
                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var verdictSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChalRunSectionLabel(text: result.verdictSectionLabel)
            ChalRunVerdictCard(result: result)
        }
    }

    @ViewBuilder
    private var notices: some View {
        if result.scorePenalty > 0 {
            ChalRunNotice(
                icon: "minus.circle",
                text: "Une pénalité de \(result.scorePenalty) points a été appliquée à ta note, car tu avais déjà commencé cet exercice avant le défi."
            )
        }
        if result.scoreBonus > 0 {
            ChalRunNotice(
                icon: "plus.circle",
                text: "Un bonus de \(result.scoreBonus) points a été appliqué à ta note, plafonnée à 100, car ton adversaire avait déjà commencé cet exercice avant le défi."
            )
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                promptExpanded.toggle()
            } label: {
                HStack {
                    ChalRunSectionLabel(text: "ÉNONCÉ")
                    Image(systemName: promptExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(promptExpanded ? "Replier l’énoncé" : "Déplier l’énoncé")
            if promptExpanded {
                Text(LatexToUnicode.toUnicodeMath(result.prompt))
                    .font(Theme.readingFont)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .duelloCard()
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChalRunSectionLabel(text: "NOTES DU DÉFI")
            ChalRunProductionCard(
                name: "Toi",
                initial: myInitial,
                assessment: result.verdict.me,
                production: nil,
                winner: result.verdict.ranked && result.verdict.outcome == .me
            )
            if let opponent = result.verdict.opponent {
                ChalRunProductionCard(
                    name: result.opponentName,
                    initial: result.opponentInitial,
                    assessment: opponent,
                    production: nil,
                    winner: result.verdict.ranked && result.verdict.outcome == .opponent
                )
            }
        }
    }

    @ViewBuilder
    private var reviewSection: some View {
        if !result.reviewedQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ChalRunSectionLabel(
                    text: result.hasOpponentSubmission ? "RÉPONSES DES DEUX JOUEURS" : "TA RÉPONSE"
                )
                Text(comparisonNote)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineSpacing(2)
                ForEach(result.reviewedQuestions) { question in
                    ChalRunQuestionReviewCard(
                        label: question.label,
                        myAnswer: question.myAnswer,
                        opponentName: result.opponentName,
                        opponentAnswer: question.opponentAnswer,
                        showOpponent: result.hasOpponentSubmission
                    )
                }
            }
        }
    }

    /// Note d'introduction de la comparaison des copies.
    private var comparisonNote: String {
        result.hasOpponentSubmission
            ? "Les copies sont dévoilées après la remise des deux joueurs. Pour chaque question, tu peux comparer ta réponse à celle de \(result.opponentName)."
            : "Retrouve ci-dessous la copie que tu as rendue."
    }

    @ViewBuilder
    private var correctionSection: some View {
        if let solution = result.solution, !solution.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ChalRunSectionLabel(text: "LE CORRIGÉ")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "graduationcap")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Corrigé de référence")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(LatexToUnicode.toUnicodeMath(solution))
                        .font(Theme.readingFont)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .duelloCard()
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if result.needsContinuation, let onContinueTraining = onContinueTraining {
                Button {
                    onContinueTraining(result.trainingTarget)
                } label: {
                    Text("Reprendre l’exercice").frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(DuelloPrimaryButton())
            }
            Button {
                onBack()
            } label: {
                Text("Faire un autre défi").frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(DuelloPrimaryButton())
        }
    }
}

/// En-tête du bilan : retour aux défis, icône d'issue, titre et méta.
struct ChalRunResultHeader: View {
    let result: ChalRunResult
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                    Text("Retour aux défis")
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Revenir à l’accueil des défis")
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text(result.headerMeta)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// L'icône dit d'abord si le défi a été arbitré, puis qui l'emporte.
    private var iconName: String {
        guard result.verdict.ranked else { return "questionmark.circle" }
        switch result.verdict.outcome {
        case .me: return "trophy.fill"
        case .draw: return "minus.circle"
        case .opponent: return "flag"
        }
    }
}

/// Écran de victoire par abandon (`opponentAbandoned`) : l'adversaire a plié
/// avant la fin du chrono, le défi est acquis immédiatement.
struct ChalRunAbandonVictoryView: View {
    let result: ChalRunResult
    var onBack: () -> Void
    var onContinueTraining: ((ChalRunTrainingTarget) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ChalRunSectionLabel(text: "VICTOIRE PAR ABANDON")
                verdictCard
                ChalRunEloLine(text: ChalRunFormat.eloLine(result.eloAfter, subject: result.subject))
                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Défi gagné")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("\(result.opponentName) a abandonné avant la fin du chrono.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verdictCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "flag")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Tu remportes immédiatement le défi. Ta réponse a été conservée pour que tu puisses terminer l’exercice dans Entraînement.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if let onContinueTraining = onContinueTraining {
                Button {
                    onContinueTraining(result.trainingTarget)
                } label: {
                    Text("Continuer l’exercice").frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(DuelloPrimaryButton())
            }
            Button {
                onBack()
            } label: {
                Text("Faire un autre défi").frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(DuelloPrimaryButton())
        }
    }
}
