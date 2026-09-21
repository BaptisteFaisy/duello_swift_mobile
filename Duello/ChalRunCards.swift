//
//  ChalRunCards.swift
//  Duello
//
//  Lot 11-C — déroulé d'un défi : cartes du bilan (verdict, notes, comparaison).
//
//  Fichier source Expo porté (plage 2494-2668 et 3146-3280 de
//  ChallengesScreen.tsx) :
//    - `verdictCard` + notes d'arbitrage (barème local, défi non arbitré) ;
//    - `ProductionCard` : initiale, nom, pastille « Vainqueur », note /100,
//      commentaire et copie rendue (ou « — Aucune réponse rendue — ») ;
//    - `QuestionReviewCard` : réponse du joueur, puis réponse adverse dévoilée ;
//    - ligne d'ELO de pied de bilan.
//
//  Réutilise sans les recréer : `ProductionAssessment`, `DuelVerdict`,
//  `LatexToUnicode`, `Theme`, `.duelloCard()`.
//
//  Limite assumée : le rendu composé des matrices multilignes
//  (`containsMultilineMatrix` du lot Stmt) n'est pas repris — la copie est
//  rendue en texte unifié LaTeX, comme les écrans existants.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Intitulé de section en petites capitales, motif récurrent des écrans Expo
/// (`sectionLabel`).
struct ChalRunSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Carte du verdict (`verdictCard`), avec les notes d'arbitrage qui
/// l'accompagnent : barème local de secours, ou défi non arbitré.
struct ChalRunVerdictCard: View {
    let result: ChalRunResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: result.verdict.source == .ai ? "sparkles" : "calculator")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(LatexToUnicode.toUnicodeMath(result.verdict.summary))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if result.verdict.source == .local && result.verdict.ranked {
                Text("Service de notation IA injoignable : les deux copies ont été départagées par le barème local de l’application.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineSpacing(2)
            }
            if !result.verdict.ranked {
                Text(unrankedNote)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var unrankedNote: String {
        let base = result.verdict.opponent != nil
            ? "Les deux notes restent affichées, mais elles ne sont pas comparables : ce défi ne désigne pas de vainqueur et les cotes restent inchangées."
            : "Faute d’une seconde note, ce défi ne désigne pas de vainqueur et ta cote reste inchangée."
        return "\(base) Ton XP, elle, est acquise."
    }
}

/// Carte de note d'un joueur (`ProductionCard`). Une copie absente
/// (`production == nil`) n'est pas remplacée : on ne montre pas le texte d'un
/// autre joueur à sa place.
struct ChalRunProductionCard: View {
    let name: String
    let initial: String
    let assessment: ProductionAssessment
    let production: String?
    let winner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                avatar
                Text(name)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if winner { winnerBadge }
                Spacer(minLength: 8)
                score
            }
            Text(LatexToUnicode.toUnicodeMath(assessment.note))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(2)
            if let production { productionBody(production) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Theme.primaryLight).frame(width: 30, height: 30)
            Text(initial)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var winnerBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "trophy")
                .font(.system(size: 10, weight: .bold))
            Text("Vainqueur")
                .font(.system(size: 11, weight: .heavy))
        }
        .foregroundStyle(Theme.ink)
    }

    private var score: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(assessment.score)")
                .font(.system(size: 18, weight: .black))
            Text("/100")
                .font(.system(size: 11, weight: .heavy))
        }
        .foregroundStyle(Theme.ink)
    }

    private func productionBody(_ raw: String) -> some View {
        let rendered = LatexToUnicode.toUnicodeMath(raw)
        let empty = rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Text(empty ? "— Aucune réponse rendue —" : rendered)
            .font(.system(size: 14))
            .foregroundStyle(empty ? Theme.inkFaint : Theme.ink)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }
}

/// Comparaison post-défi d'une question (`QuestionReviewCard`), y compris
/// lorsqu'un joueur l'a laissée vide.
struct ChalRunQuestionReviewCard: View {
    let label: String
    let myAnswer: String
    let opponentName: String
    let opponentAnswer: String?
    let showOpponent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question \(label)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
            answerBlock(author: "Ta réponse", answer: myAnswer)
            if showOpponent {
                Divider().padding(.vertical, 4)
                answerBlock(author: "Réponse de \(opponentName)", answer: opponentAnswer ?? "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private func answerBlock(author: String, answer: String) -> some View {
        let rendered = LatexToUnicode.toUnicodeMath(answer)
        let empty = rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 2) {
            Text(author)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
            Text(empty ? "Aucune réponse rendue pour cette question." : rendered)
                .font(.system(size: 14))
                .foregroundStyle(empty ? Theme.inkFaint : Theme.ink)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Ligne d'ELO de pied de bilan (`resultElo`).
struct ChalRunEloLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
