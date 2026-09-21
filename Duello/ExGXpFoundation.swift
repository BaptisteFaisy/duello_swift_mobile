//
//  ExGXpFoundation.swift
//  Duello
//
//  Socle XP du bilan d'exercice : courbe de niveaux (`xp.ts`) et barème des
//  bonus d'exercice (`exerciseRewardState.ts`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/xp.ts, exerciseRewardState.ts
//
//  `ExGXp` perd son `private` (visibilité limitée au fichier d'origine) et
//  devient interne au module — nom, type, corps et signatures inchangés.
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

// MARK: - §0.3 — Courbe de niveaux

/// Position exacte dans la courbe d'XP (`XpLevel` de `utils/xp.ts`).
struct ExGXpLevel: Equatable {
    var level: Int
    var intoLevel: Double
    var levelSpan: Double
    var toNextLevel: Double
    var progress: Double
    var isMaxLevel: Bool
}

/// `XP_CURVE` de `utils/xp.ts` : base 250, croissance 1,1, plafond 50, pas 25.
enum ExGXp {
    static let base = 250.0
    static let growth = 1.1
    static let maxLevel = 50
    static let step = 25.0

    /// `xpForLevel` — XP cumulés pour atteindre un niveau (niveau 1 = 0).
    static func xpForLevel(_ level: Int) -> Double {
        let capped = min(max(level, 1), maxLevel)
        if capped <= 1 { return 0 }
        let raw = (base * (pow(growth, Double(capped - 1)) - 1)) / (growth - 1)
        return (raw / step).rounded() * step
    }

    /// `xpToClearLevel` — coût du passage au niveau suivant.
    static func xpToClearLevel(_ level: Int) -> Double {
        xpForLevel(level + 1) - xpForLevel(level)
    }

    /// `levelForXp` — inverse de la courbe, recalé sur les paliers arrondis.
    static func levelForXp(_ total: Double) -> Int {
        guard total.isFinite, total > 0 else { return 1 }
        let estimate = Int(floor(log1p((total * (growth - 1)) / base) / log(growth))) + 1
        var level = min(max(estimate, 1), maxLevel)
        while level < maxLevel && total >= xpForLevel(level + 1) { level += 1 }
        while level > 1 && total < xpForLevel(level) { level -= 1 }
        return level
    }

    /// `describeLevel` — niveau, progression interne et reste à parcourir.
    static func describe(_ total: Double) -> ExGXpLevel {
        let safe = total.isFinite && total > 0 ? (total * 10).rounded() / 10 : 0
        let level = levelForXp(safe)
        let isMaxLevel = level >= maxLevel

        if isMaxLevel {
            let span = xpToClearLevel(maxLevel - 1)
            return ExGXpLevel(level: level, intoLevel: span, levelSpan: span,
                              toNextLevel: 0, progress: 1, isMaxLevel: true)
        }

        let floorXp = xpForLevel(level)
        let span = xpToClearLevel(level)
        let into = safe - floorXp
        return ExGXpLevel(
            level: level,
            intoLevel: into,
            levelSpan: span,
            toNextLevel: span - into,
            progress: span <= 0 ? 0 : min(into / span, 1),
            isMaxLevel: false
        )
    }
}

// MARK: - §0.5 — Bonus d'exercice

/// Reçu de bonus d'exercice (`ExerciseBonusReceipt` de
/// `utils/exerciseRewardState.ts`). Les deux derniers champs sont les seuls
/// consommés par la barre d'XP animée, comme en TypeScript.
struct ExGBonusReceipt: Equatable {
    var submissionId: String = ""
    var chapterDifficultyKey: String = ""
    var day: String = ""
    var firstOfDay: Double = 0
    var firstChapterDifficulty: Double = 0
    var practiceDays: Int = 0
    var practice: Double = 0
    var gained: Double = 0
    var totalBefore: Double = 0
    var totalAfter: Double = 0

    /// Vue « instantané de progression » attendue par `ExGXpGainProgress`.
    var snapshot: ExGXpSnapshot {
        ExGXpSnapshot(totalBefore: totalBefore, totalAfter: totalAfter)
    }
}

/// `XpProgressSnapshot` réduit à ce que la barre animée consomme.
struct ExGXpSnapshot: Equatable {
    var totalBefore: Double
    var totalAfter: Double
}

/// `EXERCISE_BONUS_RULES` — barème des bonus de fin d'exercice.
enum ExGBonusRules {
    static let successScoreExclusive = 16.0
    static let maximumScore = 20.0
    static let firstSuccessOfDay = 30.0
    static let firstChapterDifficultySuccess = 10.0
    static let perPracticeDay = 1.0
}
