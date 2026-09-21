//
//  SubjFlashcardReviewChrome.swift
//  Duello
//
//  Lot « Subj » (9-G) — chrome de la session de révision : gain XP flottant,
//  rangée des compteurs de session, bouton de sortie et barre de verdict.
//
//  Fichier source Expo porté :
//    - src/screens/SubjectsScreen.tsx (lignes 2336-2973)
//        `FlashcardReviewModal` — `flashcardXpGainSlot`, `flashcardReviewCounts`,
//        `flashcardExitButton`, `flashcardVerdictRow`.
//    - styles `flashcardXpGain*`, `flashcardReviewCount(s|Number)`,
//        `flashcardExitButton`, `flashcardVerdict(Row|Button|Text)`,
//        `flashcardCorrect|Partial|Wrong`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Gain XP flottant

/// `+n XP` affiché brièvement au-dessus des compteurs. La source l'anime en
/// opacité + translation sur 140/280/180 ms ; ici l'apparition/disparition est
/// animée par l'appelant (`SubjFlashcardReviewHeader`).
struct SubjFlashcardXpGainBadge: View {
    let xp: Double

    var body: some View {
        Text(SubjFlashcardReviewCopy.xpGain(xp))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .accessibilityLabel("Plus \(ExGFormat.xp(xp)) XP")
    }
}

// MARK: - Rangée des compteurs

/// Trois cases colorées : réussies, partielles, fausses.
struct SubjFlashcardCountsRow: View {
    let counts: CollFlashcardSessionCounts

    var body: some View {
        HStack(spacing: 8) {
            tile(counts.correct, fill: SubjFlashcardReviewPalette.correctFill)
            tile(counts.partial, fill: SubjFlashcardReviewPalette.partialFill)
            tile(counts.wrong, fill: SubjFlashcardReviewPalette.wrongFill)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SubjFlashcardReviewCopy.countsAccessibility(counts))
    }

    private func tile(_ value: Int, fill: Color) -> some View {
        Text("\(value)")
            .font(.system(size: 14))
            .foregroundStyle(Theme.ink)
            .frame(
                width: SubjFlashcardReviewMetrics.countTileSize,
                height: SubjFlashcardReviewMetrics.countTileSize
            )
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - En-tête

/// Emplacement du gain XP (hauteur fixe, pour que les compteurs ne sautent pas)
/// puis les compteurs de session.
struct SubjFlashcardReviewHeader: View {
    let counts: CollFlashcardSessionCounts
    let xpGain: Double?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let xpGain {
                    SubjFlashcardXpGainBadge(xp: xpGain)
                        .transition(.opacity.combined(with: .offset(y: 5)))
                }
            }
            .frame(minHeight: SubjFlashcardReviewMetrics.xpGainSlotMinHeight)
            .animation(.easeInOut(duration: 0.18), value: xpGain)
            SubjFlashcardCountsRow(counts: counts)
        }
    }
}

// MARK: - Sortie

/// Croix de fermeture, posée en haut à droite de l'écran.
struct SubjFlashcardExitButton: View {
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(
                    width: SubjFlashcardReviewMetrics.exitButtonSize,
                    height: SubjFlashcardReviewMetrics.exitButtonSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(SubjFlashcardReviewCopy.exitAccessibility)
    }
}

// MARK: - Barre de verdict

/// « Faux / Partiel / Réussi » : visible une fois le verso affiché.
struct SubjFlashcardVerdictRow: View {
    let pending: Bool
    let onVerdict: (CollFlashcardVerdict) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(SubjFlashcardVerdictOptions.all) { option in
                Button {
                    onVerdict(option.verdict)
                } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(SubjFlashcardReviewPalette.fill(for: option.verdict))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                }
                .buttonStyle(.plain)
                .disabled(pending)
            }
        }
        .padding(.top, 10)
    }
}
