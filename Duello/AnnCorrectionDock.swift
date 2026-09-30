//
//  AnnCorrectionDock.swift
//  Duello
//
//  Dock d'attente de la correction du lecteur d'annale (P0 18#2) : le sablier et
//  le temps estimé restant, à la place du bouton de soumission pendant la
//  correction d'un exercice ou d'une colle.
//
//  Fichier source Expo porté : src/components/exercise-correction/ExerciseCorrectionDock.tsx
//  (`ExerciseCorrectionDock`), avec `utils/correctionCountdown.ts` et
//  `utils/correctionHourglass.ts`.
//
//  Le sablier et le décompte sont **réimplémentés ici** : `ExGCorrectionCountdown`
//  et `ExGCorrectionHourglass` sont privés à `ExGCorrectionCountdownAndBars.swift`,
//  que le lot S02 n'écrit pas. Seules les formes du verre (`ExGHourglassGlassShape`,
//  `ExGHourglassSandShape`, `ExGHourglassStreamShape`) sont réutilisées. Le
//  sablier se lit à 26 pt, comme la partie 3 de la source.
//
//  Cible : iOS 16.
//
import SwiftUI

// MARK: - Décompte de la correction

/// `CorrectionProgress` + `remainingCorrectionSeconds` (`correctionCountdown.ts`).
private struct AnnDockProgress {
    var startedAt: Double
    var total: Int
    var completedAt: [Double]
}

/// Portage direct de `utils/correctionCountdown.ts`.
private enum AnnDockCountdown {
    /// `MAX_CONCURRENT_QUESTION_CORRECTIONS` de `utils/correctionPerformance.ts`.
    static let concurrency = 4

    /// Départs des réponses soumises : la file en lance jusqu'à `concurrency`
    /// dès l'envoi, puis la suivante chaque fois qu'une correction se termine.
    static func inferredStarts(startedAt: Double, total: Int,
                              completedAt: [Double], concurrency: Int) -> [Double] {
        var starts = Array(repeating: startedAt, count: max(0, min(total, concurrency)))
        for finishedAt in completedAt {
            if starts.count >= total { break }
            starts.append(finishedAt)
        }
        return starts
    }

    /// Secondes restantes avant la dernière correction ; zéro signifie que les
    /// corrections encore ouvertes ont dépassé l'estimation.
    static func remainingSeconds(_ progress: AnnDockProgress,
                                 questionSeconds: Double, now: Double,
                                 concurrency: Int = 4) -> Double {
        let starts = inferredStarts(startedAt: progress.startedAt, total: progress.total,
                                    completedAt: progress.completedAt, concurrency: concurrency)
        let questionMs = questionSeconds * 1000
        var slots = starts.dropFirst(progress.completedAt.count).map { max(0, $0 + questionMs - now) }
        while slots.count < concurrency { slots.append(0) }

        var waiting = progress.total - starts.count
        while waiting > 0 {
            guard let earliest = slots.indices.min(by: { slots[$0] < slots[$1] }) else { break }
            slots[earliest] += questionMs
            waiting -= 1
        }
        return (slots.max() ?? 0) / 1000
    }

    /// `correctionHourglassProgress` : part du sablier déjà écoulée, entre 0 et 1.
    /// Vaut 1 quand l'estimation est dépassée ou sans objet.
    static func hourglassProgress(_ progress: AnnDockProgress,
                                  questionSeconds: Double, now: Double,
                                  concurrency: Int = 4) -> Double {
        let elapsed = max(0, now - progress.startedAt)
        let remaining = remainingSeconds(progress, questionSeconds: questionSeconds,
                                         now: now, concurrency: concurrency) * 1000
        let total = elapsed + remaining
        if !(total > 0) { return 1 }
        return min(1, elapsed / total)
    }
}

// MARK: - Sablier

/// `hourglassSand` de `utils/correctionHourglass.ts` : géométrie du sable dans
/// la boîte 24×32 du SVG. `progress` 0 remplit le haut, 1 remplit le bas.
private struct AnnHourglassSand {
    var top: [CGPoint]?
    var bottom: [CGPoint]?
    var streamY2: CGFloat

    private static let topEdgeY: CGFloat = 3
    private static let bottomEdgeY: CGFloat = 29
    private static let topApexY: CGFloat = 15
    private static let bottomApexY: CGFloat = 17
    private static let leftEdgeX: CGFloat = 6
    private static let rightEdgeX: CGFloat = 18
    private static let neckX: CGFloat = 12

    init(progress: Double) {
        let bounded = progress.isFinite ? min(1, max(0, progress)) : 0
        let amount = CGFloat(bounded)
        let topSurfaceY = Self.topEdgeY + amount * (Self.topApexY - Self.topEdgeY)
        let spread = (topSurfaceY - Self.topEdgeY) / (Self.topApexY - Self.topEdgeY)
        let topLeftX = Self.leftEdgeX + (Self.neckX - Self.leftEdgeX) * spread
        let topRightX = Self.rightEdgeX - (Self.rightEdgeX - Self.neckX) * spread
        let bottomSurfaceY = Self.bottomEdgeY - amount * (Self.bottomEdgeY - Self.bottomApexY)
        let pile = (bottomSurfaceY - Self.bottomApexY) / (Self.bottomEdgeY - Self.bottomApexY)
        let bottomLeftX = Self.neckX - (Self.neckX - Self.leftEdgeX) * pile
        let bottomRightX = Self.neckX + (Self.rightEdgeX - Self.neckX) * pile
        top = bounded >= 0.999 ? nil : [
            CGPoint(x: topLeftX, y: topSurfaceY),
            CGPoint(x: topRightX, y: topSurfaceY),
            CGPoint(x: Self.neckX, y: Self.topApexY),
        ]
        bottom = bounded <= 0.001 ? nil : [
            CGPoint(x: bottomLeftX, y: bottomSurfaceY),
            CGPoint(x: bottomRightX, y: bottomSurfaceY),
            CGPoint(x: Self.rightEdgeX, y: Self.bottomEdgeY),
            CGPoint(x: Self.leftEdgeX, y: Self.bottomEdgeY),
        ]
        streamY2 = bottomSurfaceY - 0.4
    }
}

/// `CorrectionHourglass` : le sable suit `progress` et le filet coule en boucle
/// linéaire de 700 ms tant que la correction dure.
private struct AnnCorrectionHourglass: View {
    let progress: Double
    var size: CGFloat = 26

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let loop: Double = 4.8
    private static let flowSeconds: Double = 0.7

    var body: some View {
        let sand = AnnHourglassSand(progress: progress)
        let scale = size / 32
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
            drawing(sand: sand, scale: scale, date: context.date)
        }
        .frame(width: size * 3 / 4, height: size)
        .accessibilityHidden(true)
    }

    private func drawing(sand: AnnHourglassSand, scale: CGFloat, date: Date) -> some View {
        ZStack {
            ExGHourglassGlassShape().fill(Theme.surface)
            ExGHourglassGlassShape()
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.6 * scale, lineJoin: .round))
            if let bottom = sand.bottom {
                ExGHourglassSandShape(points: bottom).fill(Theme.ink)
            }
            if let top = sand.top {
                ExGHourglassSandShape(points: top).fill(Theme.ink)
            }
            ExGHourglassStreamShape(streamY2: sand.streamY2)
                .stroke(Theme.ink, style: streamStyle(scale: scale, at: date))
        }
    }

    /// `strokeDashoffset = -fall` : le décalage décroît, les grains descendent du
    /// col vers le tas ; la boucle linéaire de 700 ms reprend à chaque tour.
    private func streamStyle(scale: CGFloat, at date: Date) -> StrokeStyle {
        let width = 1.4 * scale
        guard !reduceMotion else { return StrokeStyle(lineWidth: width, lineCap: .round) }
        let seconds = date.timeIntervalSinceReferenceDate
        let turn = seconds.truncatingRemainder(dividingBy: Self.flowSeconds) / Self.flowSeconds
        let phase = CGFloat(turn * Self.loop) * scale
        return StrokeStyle(lineWidth: width, lineCap: .round,
                           dash: [2.4 * scale, 2.4 * scale], dashPhase: -phase)
    }
}

// MARK: - Dock

/// `ExerciseCorrectionDock` : le sablier seul et le temps estimé restant, sur une
/// ligne centrée, à la place du bouton de soumission pendant la correction.
struct AnnCorrectionDock: View {
    let correction: ExGCorrection

    @State private var completedAt: [Double] = []

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let observed = AnnDockProgress(
                startedAt: correction.startedAt,
                total: correction.total,
                completedAt: completedAt
            )
            let now = ExGFormat.milliseconds(context.date)
            // `Math.ceil(useCorrectionCountdown(correction))` : arrondi à la
            // seconde supérieure, comme la valeur affichée.
            let seconds = AnnDockCountdown.remainingSeconds(
                observed,
                questionSeconds: correction.questionSeconds,
                now: now
            ).rounded(.up)
            let progress = AnnDockCountdown.hourglassProgress(
                observed,
                questionSeconds: correction.questionSeconds,
                now: now
            )
            let remaining = seconds > 0 ? ExGFormat.duration(seconds) : "quelques instants"
            HStack(spacing: 8) {
                AnnCorrectionHourglass(progress: progress, size: 26)
                Text(remaining)
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Correction complète dans \(seconds > 0 ? "environ \(remaining)" : remaining)")
        }
        .onAppear { syncCompleted() }
        .onChange(of: correction.done) { _ in syncCompleted() }
    }

    /// Chaque réponse terminée est datée pour replanifier la file.
    private func syncCompleted() {
        guard completedAt.count < correction.done else { return }
        let now = ExGFormat.milliseconds(Date())
        completedAt.append(contentsOf: Array(repeating: now,
                                            count: correction.done - completedAt.count))
    }
}
