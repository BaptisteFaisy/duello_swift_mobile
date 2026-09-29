//
//  ExGCorrectionCountdownAndBars.swift
//  Duello
//
//  Barres du bilan de correction : décompte du temps restant
//  (`useCorrectionCountdown.ts`), barre haute (`CorrectionTopBar.tsx`) et pied
//  de page des actions (`confirmRestartCorrection.ts`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/correction-summary/useCorrectionCountdown.ts
//    - src/components/correction-summary/CorrectionTopBar.tsx
//    - src/components/correction-summary/CorrectionHourglass.tsx
//    - src/components/correction-summary/confirmRestartCorrection.ts
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
//  Écarts assumés (2026-09-29, parité ANIM-01) :
//    - `react-native-svg` → `Shape` SwiftUI : mêmes points du verre
//      (`GLASS_POINTS`) et mêmes polygones de sable (`hourglassSand`), portés
//      dans la boîte 24×32 du `viewBox` puis mis à l'échelle du cadre ;
//      épaisseurs et motif de tirets multipliés par ce facteur, comme le rendu
//      SVG du `viewBox`.
//    - `Reanimated` `withRepeat(withTiming(4.8, 700 ms, linear), -1)` →
//      `TimelineView(.animation)` + `dashPhase` recalculé par modulo : boucle
//      linéaire de 700 ms équivalente.
//    - `useReducedMotion()` → `@Environment(\.accessibilityReduceMotion)` :
//      filet plein (sans tirets) et animation en pause.
//    - `strokeDashoffset = -fall` → `StrokeStyle.dashPhase = -phase` (même
//      convention de signe que SVG : le motif avance du col vers le tas).
//
import Foundation
import SwiftUI

// MARK: - Décompte de la correction

/// `CorrectionProgress` + `remainingCorrectionSeconds` de
/// `utils/correctionCountdown.ts`.
private struct ExGCorrectionProgress {
    var startedAt: Double
    var total: Int
    var completedAt: [Double]
}

/// Portage direct de `utils/correctionCountdown.ts`.
private enum ExGCorrectionCountdown {
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
    static func remainingSeconds(_ progress: ExGCorrectionProgress,
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

    /// `correctionHourglassProgress` de `utils/correctionCountdown.ts` : part du
    /// sablier déjà écoulée, entre 0 et 1. Vaut 1 quand l'estimation est
    /// dépassée ou sans objet : le sable est alors complètement descendu.
    static func hourglassProgress(_ progress: ExGCorrectionProgress,
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

// MARK: - Sablier de la correction

/// `hourglassSand` de `utils/correctionHourglass.ts` : géométrie du sable dans
/// la boîte 24×32 du SVG. `progress` 0 remplit le haut, 1 remplit le bas.
private struct ExGHourglassSand {
    /// Triangle du sable haut, absent quand le sablier est vide.
    var top: [CGPoint]?
    /// Trapèze du sable bas, absent quand le sablier est plein.
    var bottom: [CGPoint]?
    /// Bas du filet de sable, entre le col et le fond.
    var streamY2: CGFloat

    // Bornes intérieures du verre, trait déduit.
    private static let topEdgeY: CGFloat = 3
    private static let bottomEdgeY: CGFloat = 29
    private static let topApexY: CGFloat = 15
    private static let bottomApexY: CGFloat = 17
    private static let leftEdgeX: CGFloat = 6
    private static let rightEdgeX: CGFloat = 18
    private static let neckX: CGFloat = 12

    /// Une progression aberrante montre le sablier plein, comme au début d'une
    /// correction.
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

/// Port de `components/correction-summary/CorrectionHourglass.tsx` : le sable
/// suit `progress` (0 plein, 1 vide) et le filet coule en boucle linéaire de
/// 700 ms tant que la correction dure. Sans mouvement demandé, le filet reste
/// plein et seul le niveau rend l'attente.
private struct ExGCorrectionHourglass: View {
    let progress: Double
    var size: CGFloat = 22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Longueur du motif répété : le raccord de boucle reste invisible.
    private static let loop: Double = 4.8
    /// Chute du sable : visible sans distraire de la lecture du temps.
    private static let flowSeconds: Double = 0.7

    var body: some View {
        let sand = ExGHourglassSand(progress: progress)
        let scale = size / 32
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
            drawing(sand: sand, scale: scale, date: context.date)
        }
        .frame(width: size * 3 / 4, height: size)
        .accessibilityHidden(true)
    }

    private func drawing(sand: ExGHourglassSand, scale: CGFloat, date: Date) -> some View {
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

    private func streamStyle(scale: CGFloat, at date: Date) -> StrokeStyle {
        let width = 1.4 * scale
        guard !reduceMotion else { return StrokeStyle(lineWidth: width, lineCap: .round) }
        return StrokeStyle(lineWidth: width, lineCap: .round,
                           dash: [2.4 * scale, 2.4 * scale], dashPhase: -phase(at: date) * scale)
    }

    /// `strokeDashoffset = -fall` : le décalage décroît, les grains descendent du
    /// col vers le tas ; la boucle linéaire de 700 ms reprend à chaque tour.
    private func phase(at date: Date) -> CGFloat {
        let seconds = date.timeIntervalSinceReferenceDate
        let turn = seconds.truncatingRemainder(dividingBy: Self.flowSeconds) / Self.flowSeconds
        return CGFloat(turn * Self.loop)
    }
}

/// Sablier et temps restant avant la correction complète.
private struct ExGCorrectionCountdownView: View {
    let correction: ExGCorrection

    @State private var completedAt: [Double] = []

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let observed = ExGCorrectionProgress(
                startedAt: correction.startedAt,
                total: correction.total,
                completedAt: completedAt
            )
            let now = ExGFormat.milliseconds(context.date)
            // `Math.ceil(useCorrectionCountdown(correction))` : le décompte est
            // arrondi à la seconde supérieure, comme la valeur affichée.
            let seconds = ExGCorrectionCountdown.remainingSeconds(
                observed,
                questionSeconds: correction.questionSeconds,
                now: now
            ).rounded(.up)
            let progress = ExGCorrectionCountdown.hourglassProgress(
                observed,
                questionSeconds: correction.questionSeconds,
                now: now
            )
            let remaining = seconds > 0
                ? ExGFormat.duration(seconds)
                : "quelques instants"
            HStack(spacing: 8) {
                ExGCorrectionHourglass(progress: progress, size: 22)
                Text(remaining)
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
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

// MARK: - §1 — Barre haute du bilan

/// `CorrectionTopBar` : la barre fixe du bilan, pendant puis après la
/// correction.
struct ExGCorrectionTopBar: View {
    let correction: ExGCorrection
    var trophy: ExGTrophy? = nil
    var onResume: (() -> Void)? = nil
    /// Signalement d'un énoncé ou d'un corrigé faux. La fenêtre complète
    /// (`ExerciseReportButton`) est hors périmètre : elle appartient au
    /// lecteur d'exercice, pas au bilan.
    var onReport: (() -> Void)? = nil

    var body: some View {
        Group {
            if correction.completed {
                completedBar
            } else {
                ongoingBar
            }
        }
    }

    /// Bilan terminé : le classement de l'exercice, puis le signalement.
    private var completedBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            if let trophy {
                ExGTrophyButton(trophy: trophy)
            }
            if let onReport {
                Button(action: onReport) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 32, height: 32)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Signaler un exercice incorrect ou faux")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// Pendant la correction : la croix seule, puis le temps restant centré.
    /// La croix rend la copie sans rien interrompre — les corrections lancées
    /// continuent.
    private var ongoingBar: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer(minLength: 0)
                if let onResume {
                    Button(action: onResume) {
                        Image(systemName: "xmark")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 42, height: 42)
                            .background(Theme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Revenir à l'exercice")
                }
            }
            ExGCorrectionCountdownView(correction: correction)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Pied de page du bilan

/// `CorrectionActions` : trois boutons noirs de même poids sur la même ligne,
/// de la reprise vers la sortie.
///
/// « Recommencer » vide la copie mais garde le meilleur résultat ; « Quitter »
/// referme le sujet sans rien toucher.
struct ExGCorrectionActions: View {
    var onResume: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    var onQuit: (() -> Void)? = nil

    @State private var confirmRestart = false

    var body: some View {
        if onResume != nil || onRetry != nil || onQuit != nil {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if let onResume {
                        actionButton("Reprendre", action: onResume)
                    }
                    if onRetry != nil {
                        actionButton("Recommencer") { confirmRestart = true }
                    }
                    if let onQuit {
                        actionButton("Quitter", action: onQuit)
                    }
                }
                .frame(maxWidth: 880)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .background(Theme.surface)
            .alert("Recommencer la copie ?", isPresented: $confirmRestart) {
                Button("Annuler", role: .cancel) { }
                Button("Recommencer", role: .destructive) { onRetry?() }
            } message: {
                Text("Repartir d’une copie vide efface les réponses de cette copie ; le meilleur résultat est conservé.")
            }
        }
    }

    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                // Sur un téléphone étroit, chaque libellé se resserre au lieu
                // de passer sur deux lignes (PR #424, `adjustsFontSizeToFit`).
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Theme.surface)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
    }
}
