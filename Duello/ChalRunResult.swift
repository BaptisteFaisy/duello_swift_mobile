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
    @EnvironmentObject private var session: SessionStore

    let result: ChalRunResult
    /// Initiale du joueur pour sa propre carte de note.
    let myInitial: String
    var onBack: () -> Void
    /// Reprise de l'exercice dans Entraînement, quand la copie peut continuer.
    var onContinueTraining: ((ChalRunTrainingTarget) -> Void)?

    @State private var promptExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                ChalRunResultHeader(result: result)
                verdictSection
                notices
                promptSection
                notesSection
                reviewSection
                correctionSection
                ChalRunEloLine(text: ChalRunFormat.eloLine(result.eloAfter, subject: result.subject))
                    .padding(.top, 10)
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 34)
        }
        .background(Theme.background)
    }

    /// Retour aux défis (`resultBackButton`) : composant partagé
    /// `DuelloBackButton` (port de `components/BackButton.tsx`). Il porte la boîte
    /// 40, le chevron `iconSize 19` et son décalage `translateX(-4)`. Le style
    /// d'écran `resultBackButton` déclare fond `surface`, bord `border` et rayon
    /// `radii.medium`, mais `styles.button` du composant RN les **neutralise**
    /// (appliqué après le style d'écran) : le rendu réel est un chevron nu, sans
    /// décoration — les retirer ici. Seuls le libellé et le `paddingHorizontal: 11`
    /// du style d'écran restent (le composant réimpose `gap: 4`).
    private var backButton: some View {
        DuelloBackButton(
            iconSize: 19,
            accessibilityLabel: "Revenir à l’accueil des défis",
            action: { onBack() }
        ) {
            Text("Retour aux défis")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 11)
    }

    private var verdictSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChalRunSectionLabel(text: result.verdictSectionLabel)
                .padding(.bottom, 10)
            ChalRunVerdictCard(result: result)
            ChalRunVerdictNote(result: result)
                .padding(.top, 9)
        }
        .padding(.top, 27)
    }

    @ViewBuilder
    private var notices: some View {
        if result.scorePenalty > 0 {
            ChalRunNotice(
                icon: "minus.circle",
                text: "Une pénalité de \(result.scorePenalty) points a été appliquée à ta note, car tu avais déjà commencé cet exercice avant le défi."
            )
            .padding(.top, 12)
        }
        if result.scoreBonus > 0 {
            ChalRunNotice(
                icon: "plus.circle",
                text: "Un bonus de \(result.scoreBonus) points a été appliqué à ta note, plafonnée à 100, car ton adversaire avait déjà commencé cet exercice avant le défi."
            )
            .padding(.top, 12)
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                promptExpanded.toggle()
            } label: {
                HStack {
                    ChalRunSectionLabel(text: "ÉNONCÉ")
                    Image(systemName: promptExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                        .background(Theme.primaryLight)
                        .clipShape(Capsule())
                }
                .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(promptExpanded ? "Replier l’énoncé" : "Déplier l’énoncé")
            if promptExpanded {
                VStack(alignment: .trailing, spacing: 6) {
                    ReportExerciseButton.make(
                        profile: session.profile,
                        target: .statement,
                        source: .challenge,
                        exerciseId: result.trainingTarget.itemId,
                        exerciseTitle: result.trainingTarget.itemTitle,
                        subject: result.subject,
                        compact: true
                    )
                    Text(LatexToUnicode.toUnicodeMath(result.prompt))
                        .font(Theme.readingFont(size: Theme.readingSizeCompact))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChalRunSectionLabel(text: "NOTES DU DÉFI")
                .padding(.bottom, 10)
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
                .padding(.top, 12)
            }
        }
        .padding(.top, 27)
    }

    @ViewBuilder
    private var reviewSection: some View {
        if !result.reviewedQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ChalRunSectionLabel(
                    text: result.hasOpponentSubmission ? "RÉPONSES DES DEUX JOUEURS" : "TA RÉPONSE"
                )
                .padding(.bottom, 10)
                Text(comparisonNote)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, -2)
                    .padding(.bottom, 11)
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
            .padding(.top, 27)
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
            VStack(alignment: .leading, spacing: 0) {
                ChalRunSectionLabel(text: "LE CORRIGÉ")
                    .padding(.bottom, 10)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "graduationcap")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 30, height: 30)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        Text("Corrigé de référence")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        ReportExerciseButton.make(
                            profile: session.profile,
                            target: .correction,
                            source: .challenge,
                            exerciseId: result.trainingTarget.itemId,
                            exerciseTitle: result.trainingTarget.itemTitle,
                            subject: result.subject,
                            compact: true
                        )
                    }
                    .padding(.bottom, 12)
                    Text(LatexToUnicode.toUnicodeMath(solution))
                        .font(Theme.readingFont)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            }
            .padding(.top, 27)
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            if result.needsContinuation, let onContinueTraining = onContinueTraining {
                Button {
                    onContinueTraining(result.trainingTarget)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "graduationcap")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Reprendre l’exercice")
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(DuelloPrimaryButton(radius: 17, weight: .heavy))
                .padding(.top, 17)
            }
            Button {
                onBack()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .semibold))
                    Text("Faire un autre défi")
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton(radius: 17, weight: .heavy))
            .padding(.top, 17)
        }
    }
}

/// En-tête du bilan : icône d'issue dans un encart, titre et méta, centrés.
struct ChalRunResultHeader: View {
    let result: ChalRunResult

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 58, height: 58)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            Text(result.title)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.top, 14)
            Text(result.headerMeta)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 14)
        .padding(.bottom, 20)
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
            VStack(alignment: .leading, spacing: 0) {
                header
                ChalRunSectionLabel(text: "VICTOIRE PAR ABANDON")
                    .padding(.top, 27)
                    .padding(.bottom, 10)
                verdictCard
                ChalRunEloLine(text: ChalRunFormat.eloLine(result.eloAfter, subject: result.subject))
                    .padding(.top, 10)
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 34)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(spacing: 0) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 58, height: 58)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            Text("Défi gagné")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.top, 14)
            Text("\(result.opponentName) a abandonné avant la fin du chrono.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 14)
        .padding(.bottom, 20)
    }

    private var verdictCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "flag")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 30, height: 30)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text("Tu remportes immédiatement le défi. Ta réponse a été conservée pour que tu puisses terminer l’exercice dans Entraînement.")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 0) {
            if let onContinueTraining = onContinueTraining {
                Button {
                    onContinueTraining(result.trainingTarget)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "graduationcap")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continuer l’exercice")
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(DuelloPrimaryButton(radius: 17, weight: .heavy))
                .padding(.top, 17)
            }
            Button {
                onBack()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .semibold))
                    Text("Faire un autre défi")
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton(radius: 17, weight: .heavy))
            .padding(.top, 17)
        }
    }
}
