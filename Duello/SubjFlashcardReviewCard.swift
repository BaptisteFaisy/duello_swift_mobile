//
//  SubjFlashcardReviewCard.swift
//  Duello
//
//  Lot « Subj » (9-G) — cartes de la session de révision : une face (fond,
//  libellé de côté, zone défilante, aide au toucher) et la carte retournable
//  qui superpose recto et verso.
//
//  Fichier source Expo porté :
//    - src/screens/SubjectsScreen.tsx (lignes 2336-2973)
//        `FlashcardReviewModal` — faces RECTO / VERSO / QUESTION, `rotateY`,
//        `backfaceVisibility: 'hidden'`, aide « Touche la carte… ».
//    - styles `flashcardFullCard`, `flashcardFace`, `flashcardBackFace`,
//        `flashcardSelfCard`, `flashcardAiResultCard`, `flashcardFullSideLabel`,
//        `flashcardCardScroll(Content)`, `flashcardFullText`, `flashcardTapHint`.
//
//  Le retournement reprend le motif déjà employé dans ce dépôt
//  (`ChalFlippableBadge`, `Duello/ChalHomeBadge.swift`) : les deux faces sont
//  superposées, chacune tournée par `rotation3DEffect`, et seule la face tournée
//  vers l'écran est opaque — `backfaceVisibility` n'existe pas en SwiftUI.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Teinte d'une face

/// Teinte d'une face : neutre (recto), grisée (revers), ou teintée par le
/// verdict du correcteur IA.
enum SubjFlashcardFaceTint: Equatable {
    case plain
    case muted
    case ai(CollVerdict)

    var background: Color {
        switch self {
        case .plain: return Theme.surface
        case .muted: return Theme.surfaceMuted
        case .ai(let verdict):
            switch verdict {
            case .perfect: return SubjFlashcardReviewPalette.aiPerfectFill
            case .correct: return SubjFlashcardReviewPalette.aiCorrectFill
            case .partial: return SubjFlashcardReviewPalette.aiPartialFill
            case .incorrect: return SubjFlashcardReviewPalette.aiIncorrectFill
            }
        }
    }

    var border: Color {
        switch self {
        case .plain, .muted: return Theme.border
        case .ai(let verdict):
            switch verdict {
            case .perfect: return SubjFlashcardReviewPalette.aiPerfectBorder
            case .correct: return SubjFlashcardReviewPalette.aiCorrectBorder
            case .partial: return SubjFlashcardReviewPalette.aiPartialBorder
            case .incorrect: return SubjFlashcardReviewPalette.aiIncorrectBorder
            }
        }
    }
}

// MARK: - Face de carte

/// Une face de carte : fond teinté, libellé de côté en haut, contenu centré
/// dans une zone défilante, aide au toucher en bas.
struct SubjFlashcardFace<Content: View>: View {
    let sideLabel: String
    var tint: SubjFlashcardFaceTint = .plain
    var tapHint: String? = nil
    var minHeight: CGFloat = SubjFlashcardReviewMetrics.cardMinHeight
    var contentBottomPadding: CGFloat = SubjFlashcardReviewMetrics.cardContentVertical
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .frame(maxWidth: .infinity, minHeight: innerMinHeight, alignment: .center)
                    .padding(.horizontal, SubjFlashcardReviewMetrics.cardContentHorizontal)
                    .padding(.top, SubjFlashcardReviewMetrics.cardContentVertical)
                    .padding(.bottom, contentBottomPadding)
            }
            VStack(spacing: 0) {
                Text(sideLabel)
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, SubjFlashcardReviewMetrics.sideLabelInset)
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if let tapHint {
                    Text(tapHint)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.bottom, SubjFlashcardReviewMetrics.tapHintInset)
                }
            }
        }
        .frame(minHeight: minHeight)
        .background(tint.background)
        .clipShape(RoundedRectangle(cornerRadius: SubjFlashcardReviewMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: SubjFlashcardReviewMetrics.cardRadius)
                .stroke(tint.border, lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x0A0D0C).opacity(0.04), radius: 8, x: 0, y: 2)
    }

    /// Hauteur minimale du contenu, hors marges internes.
    private var innerMinHeight: CGFloat {
        max(0, minHeight
            - SubjFlashcardReviewMetrics.cardContentVertical
            - contentBottomPadding)
    }
}

// MARK: - Carte retournable

/// Carte à deux faces superposées : `showingBack` fait tourner le verso de
/// `180°` à `360°` pendant que le recto passe de `0°` à `180°`.
struct SubjFlashcardFlipCard<Front: View, Back: View>: View {
    let showingBack: Bool
    var minHeight: CGFloat = SubjFlashcardReviewMetrics.cardMinHeight
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back

    var body: some View {
        ZStack {
            front()
                .opacity(showingBack ? 0 : 1)
                .rotation3DEffect(
                    .degrees(showingBack ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
            back()
                .opacity(showingBack ? 1 : 0)
                .rotation3DEffect(
                    .degrees(showingBack ? 360 : 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
        }
        .frame(minHeight: minHeight)
    }
}

// MARK: - Texte mathématique

/// `MathStatementText` : LaTeX → notation Unicode, centré, comme le fait déjà
/// l'écran du défi. `fitWideContent` (mise à l'échelle des formules longues) et
/// la composition WebView de la source ne sont pas portées.
struct SubjFlashcardMathText: View {
    let text: String
    var size: CGFloat = 17
    var weight: Font.Weight = .heavy

    var body: some View {
        Text(LatexToUnicode.toUnicodeMath(text))
            .font(.system(size: size, weight: weight))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
