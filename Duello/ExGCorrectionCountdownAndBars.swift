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
//    - src/components/correction-summary/AnimatedHourglass.tsx
//    - src/components/correction-summary/confirmRestartCorrection.ts
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
//  Écarts assumés (2026-09-30, parité W7 I7-02) :
//    - `react-native-svg` → `Shape` SwiftUI : mêmes points du verre (`GLASS`),
//      du sable (`SAND_TOP`/`SAND_BOTTOM`) et du filet, portés dans le repère
//      64×64 de `AnimatedHourglass.tsx` puis mis à l'échelle du cadre carré ;
//    - `Animated.loop(Animated.timing(…, linear), -1)` → `TimelineView(.animation)`
//      + phase recalculée par modulo : boucles linéaires équivalentes (vidage du
//      sable 2,6 s, filet 450 ms) ;
//    - `AccessibilityInfo.isReduceMotionEnabled()` → `@Environment(\.accessibilityReduceMotion)` :
//      sable plein et filet immobile, comme la boucle jamais démarrée.
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
}

// MARK: - Sablier animé de la correction

/// Les tracés du sablier animé (`AnimatedHourglass.tsx`), tous portés dans le
/// repère 64×64 de la source puis mis à l'échelle du cadre carré : le verre
/// (`GLASS`), le sable du haut (`AnimatedRect`), le tas du bas (`AnimatedG`) et
/// le filet (`AnimatedLine`).
private struct ExGAnimatedHourglassShape: Shape {
    /// Quel tracé dessiner.
    enum Kind {
        /// Le contour de verre, tracé par-dessus le sable.
        case glass
        /// Le sable du haut : sa surface descend, ancrée au col (y = 33).
        case topSand(surfaceY: CGFloat)
        /// Le tas du bas : triangle du col et rectangle du fond.
        case bottomSand
        /// Le filet de sable, du col (y = 31) au fond (y = 52).
        case stream
    }

    var kind: Kind

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        switch kind {
        case .glass:
            path.move(to: p(17, 8))
            path.addLine(to: p(47, 8))
            path.addCurve(to: p(34, 30), control1: p(47, 22), control2: p(37.5, 26.5))
            path.addLine(to: p(34, 34))
            path.addCurve(to: p(47, 56), control1: p(37.5, 37.5), control2: p(47, 42))
            path.addLine(to: p(17, 56))
            path.addCurve(to: p(30, 34), control1: p(17, 42), control2: p(26.5, 37.5))
            path.addLine(to: p(30, 30))
            path.addCurve(to: p(17, 8), control1: p(26.5, 26.5), control2: p(17, 22))
            path.closeSubpath()
        case let .topSand(surfaceY):
            path.move(to: p(12, surfaceY))
            path.addLine(to: p(52, surfaceY))
            path.addLine(to: p(52, 33))
            path.addLine(to: p(12, 33))
            path.closeSubpath()
        case .bottomSand:
            path.move(to: p(32, 32))
            path.addLine(to: p(37, 41))
            path.addLine(to: p(27, 41))
            path.closeSubpath()
            path.move(to: p(12, 39))
            path.addLine(to: p(52, 39))
            path.addLine(to: p(52, 56))
            path.addLine(to: p(12, 56))
            path.closeSubpath()
        case .stream:
            path.move(to: p(32, 31))
            path.addLine(to: p(32, 52))
        }
        return path
    }
}

/// `AnimatedHourglass` (`correction-summary/AnimatedHourglass.tsx`) : le sablier
/// animé du bilan — le sable noir se verse de l'ampoule haute vers le tas bas,
/// en boucle, **sans lien avec un temps restant**. Le dessin vit dans le repère
/// 64×64 de la source, mis à l'échelle du cadre carré demandé.
struct ExGAnimatedHourglass: View {
    /// `HOURGLASS_ANIMATED_SIZE` : taille par défaut, comme l'icône remplacée.
    static let defaultSize: CGFloat = 22

    var size: CGFloat = ExGAnimatedHourglass.defaultSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `FRAME_STROKE` : épaisseur du contour de verre.
    private static let frameStroke: CGFloat = 3.4
    /// `SAND_TOP` / `SAND_BOTTOM` : bornes du sable de l'ampoule haute.
    private static let sandTop: CGFloat = 9
    private static let sandBottom: CGFloat = 33
    /// `DRAIN_CYCLE_MS` : un cycle de vidage dure 2,6 s.
    private static let drainSeconds: Double = 2.6
    /// `STREAM_CYCLE_MS` : le filet de sable défile toutes les 450 ms.
    private static let streamSeconds: Double = 0.45
    /// Course du filet (`strokeDashoffset` de 0 à −12).
    private static let streamTravel: CGFloat = 12

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
            drawing(at: context.date)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func drawing(at date: Date) -> some View {
        let scale = size / 64
        // Mouvement réduit : la boucle ne démarre jamais, le sable reste plein
        // (surface au bord haut) et le filet garde son décalage initial.
        let surfaceY = reduceMotion
            ? Self.sandTop
            : Self.sandTop + (Self.sandBottom - Self.sandTop)
                * CGFloat(phase(at: date, seconds: Self.drainSeconds))
        let dashPhase = reduceMotion
            ? 0
            : -Self.streamTravel * CGFloat(phase(at: date, seconds: Self.streamSeconds))
        return ZStack {
            // Le sable est découpé au verre ; le contour est tracé par-dessus,
            // sans découpe, comme les `clipPath` de la source.
            ZStack {
                ExGAnimatedHourglassShape(kind: .topSand(surfaceY: surfaceY)).fill(Theme.ink)
                ExGAnimatedHourglassShape(kind: .bottomSand).fill(Theme.ink)
            }
            .clipShape(ExGAnimatedHourglassShape(kind: .glass))
            ExGAnimatedHourglassShape(kind: .stream)
                .stroke(Theme.ink, style: streamStyle(scale: scale, dashPhase: dashPhase))
            ExGAnimatedHourglassShape(kind: .glass)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: Self.frameStroke * scale,
                                                      lineCap: .round, lineJoin: .round))
        }
    }

    /// `strokeDashoffset = streamOffset` : le motif avance du col vers le tas ;
    /// la boucle linéaire de 450 ms reprend à chaque tour.
    private func streamStyle(scale: CGFloat, dashPhase: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: 1.7 * scale, lineCap: .round,
                    dash: [2.6 * scale, 3.4 * scale], dashPhase: dashPhase * scale)
    }

    /// Part du cycle écoulée, entre 0 et 1 (`Animated.loop` linéaire).
    private func phase(at date: Date, seconds: Double) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
        return elapsed.truncatingRemainder(dividingBy: seconds) / seconds
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
            let remaining = seconds > 0
                ? ExGFormat.duration(seconds)
                : "quelques instants"
            HStack(spacing: 8) {
                ExGAnimatedHourglass(size: 22)
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
