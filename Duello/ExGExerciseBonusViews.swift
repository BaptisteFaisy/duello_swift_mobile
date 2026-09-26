//
//  ExGExerciseBonusViews.swift
//  Duello
//
//  Bonus d'exercice : compteur d'XP animé (`XpGainProgress.tsx`) et détail des
//  bonus (`ExerciseBonusProgress.tsx`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/XpGainProgress.tsx                (compteur d'XP animé)
//    - src/components/ExerciseBonusProgress.tsx         (bonus d'exercice)
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - §0.6 — Compteur d'XP animé

/// `XpGainProgress` : le total d'XP monte du niveau précédent au nouveau.
///
/// Le compteur est une vue `Animatable` : la valeur intermédiaire est calculée
/// image par image, comme le `Animated.Value` + listener de la source.
/// Réduction des animations : `accessibilityReduceMotion` court-circuite la
/// transition (durée et délai nuls, comme `duration: 0, delay: 0`).
struct ExGXpGainProgress: View {
    let progress: ExGXpSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated: Double

    init(progress: ExGXpSnapshot) {
        self.progress = progress
        _animated = State(initialValue: progress.totalBefore)
    }

    var body: some View {
        ExGXpCounter(total: animated, before: progress.totalBefore, after: progress.totalAfter)
            .onAppear { run() }
            .onChange(of: progress) { _ in
                animated = progress.totalBefore
                run()
            }
    }

    /// `Animated.timing` : 1 800 ms, délai 350 ms, `inOut cubic`.
    private func run() {
        if reduceMotion {
            animated = progress.totalAfter
        } else {
            withAnimation(.easeInOut(duration: 1.8).delay(0.35)) {
                animated = progress.totalAfter
            }
        }
    }
}

/// Bloc d'XP complet, recalculé pour chaque valeur intermédiaire du compteur.
private struct ExGXpCounter: View, Animatable {
    var total: Double
    let before: Double
    let after: Double

    var animatableData: Double {
        get { total }
        set { total = newValue }
    }

    private var level: ExGXpLevel { ExGXp.describe(total) }
    private var finalLevel: ExGXpLevel { ExGXp.describe(after) }
    private var levelUp: Bool { level.level > ExGXp.describe(before).level }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading
            line
            track
            caption
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heading: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(levelUp ? Theme.gradingPerfect : Theme.ink)
                .frame(width: 44, height: 44)
                .background(levelUp ? Theme.progressLight : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            VStack(alignment: .leading, spacing: 3) {
                Text(levelUp ? "NOUVEAU NIVEAU !" : "TON NIVEAU ACTUEL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.inkSoft)
                Text("Niveau \(level.level)")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private var line: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(ExGFormat.xp(level.intoLevel))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(" / \(ExGFormat.xp(level.levelSpan)) XP")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            .monospacedDigit()
            Spacer(minLength: 8)
            Text(level.isMaxLevel ? "Maximum" : "Niv. \(level.level + 1)")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// Barre d'XP : `DuelloProgressTrack` du kit porte la même progression et
    /// le même vert de maîtrise. Limite documentée : la source dessine un fond
    /// `surfaceMuted` et un reflet blanc à 30 % (`shine`), que le kit n'expose
    /// pas — la piste reprend donc le fond bordure du kit.
    private var track: some View {
        DuelloProgressTrack(fraction: level.progress, tint: exgMastery, height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Progression XP")
            .accessibilityValue("Niveau \(finalLevel.level), \(ExGFormat.xp(after)) XP au total")
    }

    private var caption: some View {
        let head = level.isMaxLevel
            ? "Niveau maximum atteint"
            : "\(ExGFormat.xp(level.toNextLevel.rounded(.up))) XP avant le niveau \(level.level + 1)"
        return Text(head + " · \(ExGFormat.xp(total)) XP au total")
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSoft)
    }
}

// MARK: - §2 — Bonus d'exercice

/// `BonusLine` : une ligne de bonus, masquée quand le gain est nul.
private struct ExGBonusLine: View {
    let icon: String
    let label: String
    let xp: Double

    var body: some View {
        if xp == 0 {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 28, height: 28)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("+\(ExGFormat.xp(xp)) XP")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.gradingPerfect)
            }
        }
    }
}

/// `ExerciseBonusLines` : le détail des bonus, dans l'ordre de la source.
struct ExGBonusLines: View {
    let receipt: ExGBonusReceipt
    var questionXp: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let questionXp {
                ExGBonusLine(icon: "checkmark.circle", label: "Réponses corrigées", xp: questionXp)
            }
            ExGBonusLine(icon: "sun.max", label: "Première réussite de la journée",
                         xp: receipt.firstOfDay)
            ExGBonusLine(icon: "ribbon",
                         label: "Première réussite du chapitre à cette difficulté",
                         xp: receipt.firstChapterDifficulty)
            ExGBonusLine(icon: "calendar",
                         label: "\(receipt.practiceDays) jour\(receipt.practiceDays > 1 ? "s" : "") de pratique cumulée",
                         xp: receipt.practice)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `ExerciseBonusStatus` : enregistrement des bonus en cours, ou en échec.
struct ExGBonusStatus: View {
    enum Kind { case pending, error }

    let status: Kind
    var onRetry: (() -> Void)? = nil

    private var message: String {
        status == .pending
            ? "Enregistrement des XP…"
            : "Les bonus n’ont pas pu être enregistrés."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
            if status == .error, let onRetry {
                Button(action: onRetry) {
                    Text("Réessayer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.gradingPerfect)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `ExerciseBonusProgress` : la barre d'XP, puis le détail des bonus.
///
/// « Les anciens bilans conservent la progression issue du reçu de bonus. »
struct ExGBonusProgress: View {
    let receipt: ExGBonusReceipt
    var questionXp: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ExGXpGainProgress(progress: receipt.snapshot)
            ExGBonusLines(receipt: receipt, questionXp: questionXp)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
