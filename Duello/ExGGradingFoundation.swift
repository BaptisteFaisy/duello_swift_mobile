//
//  ExGGradingFoundation.swift
//  Duello
//
//  Socle de notation du bilan d'exercice : couleurs hors `Theme`, formatage
//  français des notes et durées (`gradingScore.ts`, `xp.ts`, `successSummary.ts`)
//  et barème des appréciations (`GradingRemarkBadge.tsx`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/gradingScore.ts, xp.ts, successSummary.ts
//    - src/components/GradingRemarkBadge.tsx            (appréciation)
//
//  Six déclarations partagées par plusieurs fichiers issus du découpage perdent
//  leur `private` (visibilité limitée au fichier d'origine) et deviennent
//  internes au module : `ExGFormat`, `ExGGrading`, `exgMastery`, `exgGoogleBlue`,
//  `exgLikeLight` et `exgCardShadow` — nom, type, corps et signatures inchangés.
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

// MARK: - Couleurs hors `Theme`

/// `mastery` de `theme.ts` (#22C55E) : particules, icône de vérification et
/// remplissage de la barre d'XP.
let exgMastery = Color(hex: 0x22C55E)
/// `GOOGLE_G_COLORS.blue` de `PerformanceOverviewBar.tsx` (#4285F4) : couleur
/// du montant d'XP dans le bilan.
let exgGoogleBlue = Color(hex: 0x4285F4)
/// `likeLight` de `theme.ts` (#FDECEC) : fond des avertissements de correction.
let exgLikeLight = Color(hex: 0xFDECEC)
/// `cardShadow` iOS de `theme.ts` : ombre de la pastille de célébration.
let exgCardShadow = Color(hex: 0x0A0D0C).opacity(0.04)

// MARK: - §0.1 / §0.4 — Formatage

/// Équivalents Swift des formateurs Expo (`gradingScore.ts`, `xp.ts`,
/// `successSummary.ts`, `exerciseLeaderboard.ts`). Tous les séparateurs suivent
/// la convention française : virgule décimale, espace insécable des milliers.
enum ExGFormat {
    private static let posix = Locale(identifier: "en_US_POSIX")

    /// `formatXp` — arrondi au dixième, milliers séparés par une espace
    /// insécable (U+00A0), décimale virgule. `1250.5` → `« 1 250,5 »`.
    static func xp(_ value: Double) -> String {
        let safe = value.isFinite ? value : 0
        let rounded = (safe * 10).rounded() / 10
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00A0}"
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    }

    /// `formatGradingScore` — `14.5` → `« 14,5/20 »`, `nil` → `« — »`.
    static func score(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        let text = String(format: "%.1f", locale: posix, value)
        return text.replacingOccurrences(of: ".", with: ",") + "/20"
    }

    /// `formatExerciseRank` — `#4`, ou `« — »` quand le rang est inconnu.
    static func rank(_ value: Int?) -> String {
        guard let value, value != 0 else { return "—" }
        return "#\(value)"
    }

    /// `formatSuccessDuration` — `« 1 h 05 min »`, `« 3 min 07 s »`, `« 42 s »`.
    static func duration(_ totalSeconds: Double) -> String {
        let seconds = max(0, Int((totalSeconds.isFinite ? totalSeconds : 0).rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let rest = seconds % 60
        if hours > 0 { return "\(hours) h \(pad(minutes)) min" }
        if minutes > 0 { return "\(minutes) min \(pad(rest)) s" }
        return "\(rest) s"
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// `Intl.DateTimeFormat('fr-FR', { day:'2-digit', month:'short',
    /// year:'numeric' })` → `« 15 sept. 2026 »`. La chaîne brute est rendue
    /// telle quelle si elle n'est pas datable.
    static func achievementDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: trimmed)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: trimmed)
        }
        if date == nil {
            iso.formatOptions = [.withFullDate]
            date = iso.date(from: trimmed)
        }
        guard let parsed = date else { return trimmed }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: parsed)
    }

    /// Millisecondes d'un `Date` : les instants de la correction viennent du
    /// serveur en millisecondes (`CorrectionProgress`).
    static func milliseconds(_ date: Date) -> Double {
        date.timeIntervalSince1970 * 1000
    }
}

// MARK: - §0.2 — Notes et appréciations

/// Niveau d'une appréciation (`GradingRemarkTone` de `utils/gradingScore.ts`).
enum ExGRemarkTone {
    case excellent, good, fair, failing, ungraded

    var foreground: Color {
        switch self {
        case .excellent: return Theme.gradingPerfectHex.color
        case .good: return Theme.progress
        case .fair: return Theme.gradingPartialHex.color
        case .failing: return Theme.like
        case .ungraded: return Theme.inkSoft
        }
    }

    var background: Color {
        switch self {
        case .excellent: return Theme.gradingPerfectLightHex.color
        case .good: return Theme.progressLight
        case .fair: return Theme.gradingPartialLightHex.color
        case .failing: return exgLikeLight
        case .ungraded: return Theme.surfaceMuted
        }
    }
}

/// Appréciation d'une note (`GradingRemark`) : libellé et ton.
struct ExGRemark: Equatable {
    let label: String
    let tone: ExGRemarkTone
}

/// Barème et appréciations (`utils/gradingScore.ts`).
enum ExGGrading {
    /// Seuils **descendants** : premier palier dont `score >= minimumScore`.
    private static let tiers: [(minimum: Double, label: String, tone: ExGRemarkTone)] = [
        (18, "Excellent", .excellent),
        (16, "Très bien", .excellent),
        (14, "Bien", .good),
        (12, "Assez bien", .good),
        (10, "Passable", .fair),
    ]

    /// `gradingScoreRemark` — `nil` → `« Non notée »`, sous 10 → `« Insuffisant »`.
    static func remark(_ score: Double?) -> ExGRemark {
        guard let score, score.isFinite else {
            return ExGRemark(label: "Non notée", tone: .ungraded)
        }
        for tier in tiers where score >= tier.minimum {
            return ExGRemark(label: tier.label, tone: tier.tone)
        }
        return ExGRemark(label: "Insuffisant", tone: .failing)
    }

    /// `roundScore` — note bornée `[0, 20]`, arrondie au dixième.
    static func roundScore(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (min(20, max(0, value)) * 10).rounded() / 10
    }
}
