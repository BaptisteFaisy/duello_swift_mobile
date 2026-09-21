//
//  Ui2LoadingMark.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/DuelloLoadingMark.tsx (`DuelloLoadingMark`,
//      `DEFAULT_LOADING_MARK_DELAY_MS`)
//
//  Le rond de chargement revient partout (le remplacement temporaire par le
//  logo Duello tournant a été abandonné sur demande). Le délai évite de faire
//  clignoter l'indicateur sur un chargement instantané. Cible iOS 16.
//
import SwiftUI

/// Indicateur de chargement différé (`DuelloLoadingMark.tsx`).
///
/// Ne s'affiche qu'après `delayMs` millisecondes ; un délai nul l'affiche
/// immédiatement, comme la source (`useState(delayMs === 0)`).
struct Ui2LoadingMark: View {
    /// Délai par défaut de la source (`DEFAULT_LOADING_MARK_DELAY_MS`).
    static let defaultDelayMs = 180

    /// Côté du cadre carré qui centre l'indicateur.
    var size: CGFloat = 42
    /// Délai d'apparition, en millisecondes.
    var delayMs: Int = Ui2LoadingMark.defaultDelayMs

    @State private var isVisible: Bool

    init(size: CGFloat = 42, delayMs: Int = Ui2LoadingMark.defaultDelayMs) {
        self.size = size
        self.delayMs = delayMs
        _isVisible = State(initialValue: delayMs == 0)
    }

    var body: some View {
        Group {
            if isVisible {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.primary)
                    .scaleEffect(1.35)
                    .frame(width: size, height: size)
                    .accessibilityLabel("Chargement")
            }
        }
        .task(id: delayMs) {
            guard delayMs > 0 else { return }
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            isVisible = true
        }
    }
}
