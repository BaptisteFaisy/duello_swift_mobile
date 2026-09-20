//
//  ExerciseRewardViews.swift
//  Duello
//
//  Lot C du portage Expo / React Native → SwiftUI natif : composants de
//  récompense et de gradation de l'espace de travail d'exercice.
//
//  Sources portées (expo_ref/src/) :
//    §0  socle commun — theme.ts, utils/gradingScore.ts, utils/xp.ts,
//        utils/xpLevelProgress.ts, utils/successSummary.ts,
//        utils/exerciseRewardState.ts, components/XpGainProgress.tsx
//    §1  components/ExerciseTrophyButton.tsx
//    §2  components/ExerciseBonusProgress.tsx
//    §3  components/GradingRemarkBadge.tsx
//    §4  components/RevisionSuccessSummary.tsx
//    §5  components/PerfectExerciseCelebration.tsx
//
//  Cible iOS 16 : aucune API iOS 17+ (`KeyframeAnimator` et `PhaseAnimator`
//  sont écartés ; `.onChange` garde sa forme à un seul paramètre).
//
//  Trois écarts entre la spec et les sources ont été tranchés en faveur des
//  sources (voir les commentaires aux points concernés) :
//    - §0.3 annonce une espace insécable U+00A0 comme séparateur de milliers ;
//      `utils/xp.ts` utilise en réalité l'espace fine insécable U+202F.
//    - §4.4 annonce « espace insécable + point médian + espace » pour le
//      suffixe « · provisoire » ; la source utilise des espaces ordinaires.
//    - §1.3 fixe le formatage de la date (`DateFormatter` `fr_FR`,
//      `dd MMM yyyy`), mais la source **lit** la date avec `Date.parse`, bien
//      plus tolérant qu'ISO 8601 : la lecture accepte donc aussi une date sans
//      heure ni fuseau (« 2026-09-15 »), comme `Date.parse`.
//
//  `lineHeight` de React Native n'a pas d'équivalent direct sur `Text` en
//  iOS 16 : les valeurs sont conservées en commentaire à chaque usage.
//

import SwiftUI
import Foundation

// MARK: - §0 Socle : couleurs absentes de `Theme.swift`

/// Couleurs de `theme.ts` consommées par ce lot mais absentes de `Theme.swift`.
///
/// `Theme.swift` est partagé et ce lot ne le modifie pas : ces teintes restent
/// donc locales au fichier.
private enum RewardColors {
    /// `colors.mastery` — particules de célébration, icône de validation, barre d'XP.
    static let mastery = Color(hex: 0x22C55E)
    /// `colors.online` — pastille de présence (même vert que la réussite).
    static let online = Color(hex: 0x22C55E)
    /// `colors.likeLight` — fond de l'appréciation `failing`.
    static let likeLight = Color(hex: 0xFDECEC)
    /// `colors.white` — texte du bouton principal, bord de la pastille de présence.
    static let white = Color(hex: 0xFFFFFF)
    /// `GOOGLE_G_COLORS.blue` de `PerformanceOverviewBar.tsx` — compteur d'XP.
    static let googleBlue = Color(hex: 0x4285F4)
}

// MARK: - §0.2 Socle : notes et appréciations (`utils/gradingScore.ts`)

/// Niveau d'une appréciation : il décide de la couleur de son badge
/// (`GradingRemarkTone`).
enum GradingRemarkTone: Equatable {
    case excellent
    case good
    case fair
    case failing
    case ungraded
}

/// Appréciation d'une note : libellé et niveau (`GradingRemark`).
struct GradingRemark: Equatable {
    let label: String
    let tone: GradingRemarkTone
}

/// Affichage des notes sur 20 (`utils/gradingScore.ts`, partie présentation).
enum GradingScore {
    /// `formatGradingScore` : « 14,5/20 », ou un tiret cadratin sans note.
    ///
    /// `toFixed(1)` puis remplacement du point par une virgule. `String(format:)`
    /// sans locale n'est pas localisé : le séparateur reste le point.
    static func format(_ score: Double?) -> String {
        guard let score else { return "—" }
        return String(format: "%.1f", score).replacingOccurrences(of: ".", with: ",") + "/20"
    }

    /// `gradingScoreRemark` : paliers **descendants**, le premier satisfait gagne.
    static func remark(_ score: Double?) -> GradingRemark {
        guard let score else { return GradingRemark(label: "Non notée", tone: .ungraded) }
        for tier in remarks where score >= tier.minimumScore {
            return GradingRemark(label: tier.label, tone: tier.tone)
        }
        return GradingRemark(label: "Insuffisant", tone: .failing)
    }

    /// `GRADING_SCORE_REMARKS` : de la note minimale la plus haute à la plus basse.
    private static let remarks: [(minimumScore: Double, label: String, tone: GradingRemarkTone)] = [
        (18, "Excellent", .excellent),
        (16, "Très bien", .excellent),
        (14, "Bien", .good),
        (12, "Assez bien", .good),
        (10, "Passable", .fair),
    ]
}

// MARK: - §0.3 Socle : XP (`utils/xp.ts`, `utils/xpLevelProgress.ts`)

/// Courbe de niveaux (`XP_CURVE`).
enum XPCurve {
    /// XP à réunir pour passer du niveau 1 au niveau 2.
    static let base: Double = 250
    /// Chaque niveau coûte 10 % de plus que le précédent.
    static let growth: Double = 1.1
    /// Plafond, pour que la courbe reste bornée.
    static let maxLevel = 50
    /// Les paliers sont arrondis à ce pas pour garder des seuils lisibles.
    static let step: Double = 25
}

/// Totaux réels encadrant les gains présentés dans un bilan
/// (`XpProgressSnapshot` de `utils/xpLevelProgress.ts`).
protocol XpProgressSnapshot {
    var totalBefore: Double { get }
    var totalAfter: Double { get }
}

/// Position exacte dans la courbe pour un total d'XP donné (`XpLevel`).
struct XpLevel: Equatable {
    /// Niveau atteint.
    let level: Int
    /// XP acquis à l'intérieur du niveau courant.
    let intoLevel: Double
    /// XP que coûte le niveau courant en entier.
    let levelSpan: Double
    /// XP restants avant le niveau suivant.
    let toNextLevel: Double
    /// Avancement dans le niveau courant, entre 0 et 1.
    let progress: Double
    /// Le plafond de niveaux est atteint.
    let isMaxLevel: Bool
}

/// Courbe de niveaux et formatage des montants (`utils/xp.ts`).
enum XP {
    /// Séparateur de milliers de `formatXp`.
    ///
    /// La source écrit `' '` — espace **fine** insécable U+202F —, et non
    /// l'espace insécable U+00A0 annoncée par la spec §0.3.
    static let thousandsSeparator = "\u{202F}"

    /// `xpForLevel` : XP cumulés à réunir pour atteindre `level`.
    /// Le niveau 1 est acquis d'office.
    static func xpForLevel(_ level: Int) -> Double {
        let capped = min(max(level, 1), XPCurve.maxLevel)
        guard capped > 1 else { return 0 }
        let raw = (XPCurve.base * (pow(XPCurve.growth, Double(capped - 1)) - 1)) / (XPCurve.growth - 1)
        return (raw / XPCurve.step).rounded() * XPCurve.step
    }

    /// `xpToClearLevel` : XP que coûte le passage de `level` au niveau suivant.
    static func xpToClearLevel(_ level: Int) -> Double {
        xpForLevel(level + 1) - xpForLevel(level)
    }

    /// `levelForXp` : inverse de la courbe, recalé sur les paliers arrondis.
    static func levelForXp(_ total: Double) -> Int {
        guard total.isFinite, total > 0 else { return 1 }
        let estimate = Int(
            floor(log1p((total * (XPCurve.growth - 1)) / XPCurve.base) / log(XPCurve.growth))
        ) + 1
        var level = min(max(estimate, 1), XPCurve.maxLevel)
        while level < XPCurve.maxLevel && total >= xpForLevel(level + 1) { level += 1 }
        while level > 1 && total < xpForLevel(level) { level -= 1 }
        return level
    }

    /// `describeLevel` : position exacte dans la courbe pour un total donné.
    static func describeLevel(_ total: Double) -> XpLevel {
        let safeTotal = total.isFinite && total > 0 ? (total * 10).rounded() / 10 : 0
        let level = levelForXp(safeTotal)
        let isMaxLevel = level >= XPCurve.maxLevel

        if isMaxLevel {
            let span = xpToClearLevel(XPCurve.maxLevel - 1)
            return XpLevel(
                level: level,
                intoLevel: span,
                levelSpan: span,
                toNextLevel: 0,
                progress: 1,
                isMaxLevel: true
            )
        }

        let levelFloor = xpForLevel(level)
        let span = xpToClearLevel(level)
        let intoLevel = safeTotal - levelFloor
        return XpLevel(
            level: level,
            intoLevel: intoLevel,
            levelSpan: span,
            toNextLevel: span - intoLevel,
            progress: span <= 0 ? 0 : min(intoLevel / span, 1),
            isMaxLevel: false
        )
    }

    /// `formatXp` : arrondi au dixième, milliers groupés, décimale après virgule.
    ///
    /// Exemples de la source : `1250.5` → « 1 250,5 », `30` → « 30 ».
    static func format(_ value: Double) -> String {
        let safeValue = value.isFinite ? (value * 10).rounded() / 10 : 0
        let parts = jsNumber(safeValue).split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let integer = groupedDigits(String(parts[0]))
        guard parts.count > 1 else { return integer }
        return integer + "," + String(parts[1])
    }

    /// Groupe les chiffres par trois depuis la droite, signe laissé en tête
    /// (`integer.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')`).
    private static func groupedDigits(_ digits: String) -> String {
        var grouped = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0 && index % 3 == 0 { grouped += thousandsSeparator }
            grouped.append(character)
        }
        return String(grouped.reversed())
    }
}

/// Rend un nombre comme le ferait JavaScript dans une interpolation
/// (`` `${value}` ``) : jamais de décimale inutile.
private func jsNumber(_ value: Double) -> String {
    guard value.isFinite else { return "0" }
    if value == 0 { return "0" }
    if value == value.rounded() { return String(format: "%.0f", value) }
    return String(value)
}

// MARK: - §0.4 Socle : durées (`utils/successSummary.ts`)

/// Formatage des durées de bilan (`formatSuccessDuration`).
enum SuccessDuration {
    /// « 1 h 05 min », « 3 min 07 s » ou « 42 s ».
    static func format(_ totalSeconds: Double) -> String {
        // Écart assumé : en JS, `Math.max(0, Math.round(NaN))` vaut `NaN` et
        // la source rendrait « NaN s » ; une durée non finie retombe ici sur 0.
        guard totalSeconds.isFinite else { return "0 s" }
        let seconds = max(0, Int(totalSeconds.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let rest = seconds % 60
        if hours > 0 { return "\(hours) h \(padded(minutes)) min" }
        if minutes > 0 { return "\(minutes) min \(padded(rest)) s" }
        return "\(rest) s"
    }

    private static func padded(_ value: Int) -> String { String(format: "%02d", value) }
}

// MARK: - §0.5 Socle : bonus d'exercice (`utils/exerciseRewardState.ts`)

/// Barème des bonus de fin d'exercice (`EXERCISE_BONUS_RULES`).
enum ExerciseBonusRules {
    /// Note strictement supérieure à ce seuil pour compter comme réussite.
    static let successScoreExclusive: Double = 16
    /// Note maximale d'un exercice.
    static let maximumScore: Double = 20
    /// Première réussite de la journée.
    static let firstSuccessOfDay: Double = 30
    /// Première réussite du chapitre à cette difficulté.
    static let firstChapterDifficultySuccess: Double = 10
    /// Gain par jour de pratique cumulé.
    static let perPracticeDay: Double = 1
}

/// Reçu d'un bonus d'exercice (`ExerciseBonusReceipt`).
///
/// Le typage structurel de TypeScript fait passer directement le reçu à la barre
/// d'XP : en Swift, seuls `totalBefore` et `totalAfter` sont réellement
/// consommés, ce que traduit la conformité à `XpProgressSnapshot`.
struct ExerciseBonusReceipt: Identifiable, Equatable, XpProgressSnapshot {
    /// Identifiant idempotent de la soumission qui a produit ce bilan.
    var submissionId: String
    /// Chapitre et difficulté qui ont produit le bonus.
    var chapterDifficultyKey: String
    /// Jour local du reçu, au format `AAAA-MM-JJ`.
    var day: String
    /// Gain de la première réussite de la journée.
    var firstOfDay: Double
    /// Gain de la première réussite du chapitre à cette difficulté.
    var firstChapterDifficulty: Double
    /// Nombre de jours de pratique cumulés.
    var practiceDays: Int
    /// Gain des jours de pratique.
    var practice: Double
    /// Total gagné par ce reçu.
    var gained: Double
    /// Total d'XP du compte avant le reçu.
    var totalBefore: Double
    /// Total d'XP du compte après le reçu.
    var totalAfter: Double

    var id: String { submissionId }
}

// MARK: - §0.6 Socle : XpGainProgress (`components/XpGainProgress.tsx`)

/// Constantes de l'animation du compteur d'XP (`XP_ANIMATION`).
enum XpAnimation {
    /// `duration: 1_800` ms.
    static let duration: Double = 1.8
    /// `delay: 350` ms.
    static let delay: Double = 0.35
}

/// Porteur `Animatable` d'une valeur continue.
///
/// Équivalent SwiftUI d'un `Animated.Value` de React Native : `withAnimation`
/// interpole `animatableData` et le contenu est recalculé à chaque image.
/// (`KeyframeAnimator` est écarté : cible iOS 16.)
private struct RewardAnimatedValue<Content: View>: View, Animatable {
    var value: Double
    let content: (Double) -> Content

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { content(value) }
}

/// Compteur d'XP animé, en tête des gains d'un bilan (`XpGainProgress`).
///
/// Le compteur repart du total enregistré du compte et rejoint le total du reçu
/// en 1,8 s après 350 ms de délai, en `inOut cubic`. L'animation est neutralisée
/// quand « réduire les animations » est actif.
struct XpGainProgress: View {
    let progress: XpProgressSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var total: Double

    init(progress: XpProgressSnapshot) {
        self.progress = progress
        _total = State(initialValue: progress.totalBefore)
    }

    var body: some View {
        RewardAnimatedValue(value: total) { animatedTotal in
            section(animatedTotal: animatedTotal)
        }
        .onAppear(perform: start)
        .onChange(of: progress.totalBefore) { _ in start() }
        .onChange(of: progress.totalAfter) { _ in start() }
    }

    /// `useEffect([totalBefore, totalAfter])` : le compteur est ramené au total
    /// d'avant, puis animé vers le total d'après.
    private func start() {
        total = progress.totalBefore
        guard !reduceMotion else {
            // `duration: 0, delay: 0` quand le reduce-motion est actif.
            total = progress.totalAfter
            return
        }
        withAnimation(.easeInOut(duration: XpAnimation.duration).delay(XpAnimation.delay)) {
            total = progress.totalAfter
        }
    }

    private func section(animatedTotal: Double) -> some View {
        let level = XP.describeLevel(animatedTotal)
        let finalLevel = XP.describeLevel(progress.totalAfter)
        let levelUp = level.level > XP.describeLevel(progress.totalBefore).level

        return VStack(alignment: .leading, spacing: 10) {   // section : width 100 %, gap 10
            HStack(spacing: 12) {                            // heading : row, centre, gap 12
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .fill(levelUp ? Theme.progressLight : Theme.surfaceMuted)
                        .frame(width: 44, height: 44)
                    Image(systemName: "star.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(levelUp ? Theme.gradingPerfectHex.color : Theme.ink)
                }
                VStack(alignment: .leading, spacing: 3) {    // levelHeading : flex 1, gap 3
                    Text(levelUp ? "NOUVEAU NIVEAU !" : "TON NIVEAU ACTUEL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSoft)
                    Text("Niveau \(level.level)")
                        .font(.system(size: 24, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 4)

            HStack(alignment: .firstTextBaseline, spacing: 0) {   // line : space-between
                Text(XP.format(level.intoLevel))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text(" / \(XP.format(level.levelSpan)) XP")
                    .font(.system(size: 11))                      // caption, lineHeight 17
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 10)
                Text(level.isMaxLevel ? "Maximum" : "Niv. \(level.level + 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }

            // absent: `accessibilityRole="progressbar"` — SwiftUI n'a pas de
            // rôle « barre de progression » ; le libellé porte le sens et
            // `aria-valuemin/max/now` est replié dans la valeur.
            track(progress: level.progress)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Progression XP")
                .accessibilityValue(
                    "Niveau \(finalLevel.level), \(XP.format(progress.totalAfter)) XP au total"
                )

            Text(bottomCaption(level: level, animatedTotal: animatedTotal))
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    /// Barre de progression : piste `surfaceMuted`, remplissage `mastery`, reflet.
    private func track(progress fraction: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)
                Capsule()
                    .fill(RewardColors.mastery)
                    // `width: '${progress * 100}%'` ; le bornage est défensif.
                    .frame(width: CGFloat(max(0, min(1, fraction))) * geometry.size.width)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(RewardColors.white.opacity(0.3))
                            .frame(height: 4)
                            .padding(.top, 3)
                            .padding(.horizontal, 6)
                    }
                    .clipShape(Capsule())
            }
            .clipShape(Capsule())
        }
        .frame(height: 18)
    }

    /// Bas de bloc : reste à gagner, puis total courant.
    private func bottomCaption(level: XpLevel, animatedTotal: Double) -> String {
        let head = level.isMaxLevel
            ? "Niveau maximum atteint"
            : "\(XP.format(ceil(level.toNextLevel))) XP avant le niveau \(level.level + 1)"
        return head + " · " + "\(XP.format(animatedTotal)) XP au total"
    }
}

// MARK: - §3 GradingRemarkBadge (`components/GradingRemarkBadge.tsx`)

/// Remarque d'une note sur 20, en badge coloré selon son niveau.
///
/// Les majuscules restent visuelles : le libellé lu par les lecteurs d'écran
/// garde sa casse.
///
/// absent: `gradeBadgeStyles` (StyleSheet exporté, consommé par
/// `GradeEvolutionBadge`) — pas d'équivalent Swift, le style reste local.
struct GradingRemarkBadge: View {
    let score: Double?

    private var remark: GradingRemark { GradingScore.remark(score) }

    var body: some View {
        Text(remark.label)
            .font(.system(size: 13, weight: .bold))   // lineHeight 18
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(tone.background)
            .clipShape(Capsule())                     // radii.pill = 999
            // `alignSelf: 'center'` : en SwiftUI la pastille reste à la taille
            // de son contenu ; le centrage vient du parent (centrage vertical
            // dans une `HStack`, centrage horizontal par défaut d'une `VStack`).
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Remarque : \(remark.label)")
    }

    /// `REMARK_TONE_COLORS` : couleurs des appréciations, dans la gamme des
    /// verdicts de question.
    private var tone: (foreground: Color, background: Color) {
        switch remark.tone {
        case .excellent:
            return (Theme.gradingPerfectHex.color, Theme.gradingPerfectLightHex.color)
        case .good:
            return (Theme.progress, Theme.progressLight)
        case .fair:
            return (Theme.gradingPartialHex.color, Theme.gradingPartialLightHex.color)
        case .failing:
            return (Theme.like, RewardColors.likeLight)
        case .ungraded:
            return (Theme.inkSoft, Theme.surfaceMuted)
        }
    }
}

// MARK: - §2 ExerciseBonusProgress (`components/ExerciseBonusProgress.tsx`)

/// État d'enregistrement des bonus (`status` de `ExerciseBonusStatus`).
enum ExerciseBonusStatusState: Equatable {
    case pending
    case error
}

/// Ligne de bonus, masquée quand le montant est nul (`BonusLine`).
private struct ExerciseBonusLine: View {
    let label: String
    let xp: Double
    let icon: String

    var body: some View {
        // `if (xp === 0) return null`.
        if xp != 0 {
            HStack(spacing: 10) {                    // line : row, centre, space-between
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .fill(Theme.surfaceMuted)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSoft)
                }
                Text(label)
                    .font(.system(size: 12))          // label, lineHeight 18
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("+\(XP.format(xp)) XP")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.gradingPerfectHex.color)
                    .fixedSize()                      // flexShrink: 0
            }
        }
    }
}

/// Bandeau d'état de l'enregistrement des bonus (`ExerciseBonusStatus`).
struct ExerciseBonusStatus: View {
    let status: ExerciseBonusStatusState
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {     // details : width 100 %, gap 13
            Text(
                status == .pending
                    ? "Enregistrement des XP…"
                    : "Les bonus n’ont pas pu être enregistrés."
            )
            .font(.system(size: 12))                   // label, lineHeight 18
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)

            if status == .error, let onRetry {
                Button(action: onRetry) {
                    Text("Réessayer")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.gradingPerfectHex.color)
                        .frame(maxWidth: .infinity, minHeight: 44)   // retry
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(maxWidth: .infinity)
        // absent: accessibilityLiveRegion="polite" — pas d'équivalent SwiftUI ;
        // le trait « contenu mis à jour » en approche l'intention.
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Détail des bonus d'un reçu (`ExerciseBonusLines`).
struct ExerciseBonusLines: View {
    let receipt: ExerciseBonusReceipt
    var questionXp: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let questionXp {
                ExerciseBonusLine(
                    label: "Réponses corrigées",
                    xp: questionXp,
                    icon: "checkmark.circle"          // checkmark-done-outline
                )
            }
            ExerciseBonusLine(
                label: "Première réussite de la journée",
                xp: receipt.firstOfDay,
                icon: "sun.max"                       // sunny-outline
            )
            ExerciseBonusLine(
                label: "Première réussite du chapitre à cette difficulté",
                xp: receipt.firstChapterDifficulty,
                icon: "ribbon"                        // ribbon-outline
            )
            ExerciseBonusLine(
                label: "\(receipt.practiceDays) jour\(receipt.practiceDays > 1 ? "s" : "") de pratique cumulée",
                xp: receipt.practice,
                icon: "calendar"                      // calendar-outline
            )
        }
        .frame(maxWidth: .infinity)
    }
}

/// Progression d'XP puis détail des bonus d'un reçu (`ExerciseBonusProgress`).
///
/// Les anciens bilans conservent la progression issue du reçu de bonus.
struct ExerciseBonusProgress: View {
    let receipt: ExerciseBonusReceipt
    var questionXp: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            XpGainProgress(progress: receipt)
            ExerciseBonusLines(receipt: receipt, questionXp: questionXp)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - §5 PerfectExerciseCelebration (`components/PerfectExerciseCelebration.tsx`)

/// Durée de la célébration (`CELEBRATION_DURATION_MS`), en secondes.
private let celebrationDuration: Double = 1.6

/// Modèle d'une particule de célébration (`CelebrationParticleModel`).
private struct CelebrationParticleModel {
    let color: Color
    let rotation: Double
    let round: Bool
    let size: Double
    let x: Double
    let y: Double

    init(
        color: Color,
        rotation: Double,
        round: Bool = false,
        size: Double,
        x: Double,
        y: Double
    ) {
        self.color = color
        self.rotation = rotation
        self.round = round
        self.size = size
        self.x = x
        self.y = y
    }
}

/// Les douze particules, dans l'ordre exact de `CELEBRATION_PARTICLES`.
private let celebrationParticles: [CelebrationParticleModel] = [
    CelebrationParticleModel(color: RewardColors.mastery, rotation: 130, size: 10, x: -106, y: -52),
    CelebrationParticleModel(color: Theme.ink, rotation: -95, size: 7, x: -70, y: -91),
    CelebrationParticleModel(color: Theme.gradingPerfectHex.color, rotation: 155, size: 9, x: -24, y: -108),
    CelebrationParticleModel(color: RewardColors.mastery, rotation: -120, round: true, size: 8, x: 34, y: -104),
    CelebrationParticleModel(color: Theme.ink, rotation: 105, size: 8, x: 82, y: -76),
    CelebrationParticleModel(color: RewardColors.mastery, rotation: -160, round: true, size: 10, x: 112, y: -28),
    CelebrationParticleModel(color: Theme.gradingPerfectHex.color, rotation: 90, size: 8, x: 104, y: 38),
    CelebrationParticleModel(color: Theme.ink, rotation: -135, round: true, size: 7, x: 64, y: 82),
    CelebrationParticleModel(color: RewardColors.mastery, rotation: 145, size: 10, x: 14, y: 101),
    CelebrationParticleModel(color: Theme.gradingPerfectHex.color, rotation: -100, size: 8, x: -43, y: 91),
    CelebrationParticleModel(color: Theme.ink, rotation: 120, round: true, size: 7, x: -88, y: 62),
    CelebrationParticleModel(color: RewardColors.mastery, rotation: -145, size: 9, x: -116, y: 8),
]

/// Célébration d'un exercice parfaitement réussi (`PerfectExerciseCelebration`).
///
/// Une **seule** valeur pilote `p ∈ [0, 1]`, avec `p(t) = cubicOut(t / 1,6)` :
/// toutes les grandeurs (opacité, translation, rotation, échelle) sont des
/// interpolations linéaires par morceaux sur `p`. Rien n'est affiché si l'option
/// « réduire les animations » est active, comme le `return null` de la source.
///
/// La source ne déclenche ni haptique, ni son, ni Lottie.
struct PerfectExerciseCelebration: View {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        if active && !reduceMotion {
            // `TimelineView(.animation)` remplace Reanimated : le pilote est
            // recalculé à chaque image, puis la vue cesse de redessiner.
            TimelineView(.animation(paused: finished)) { context in
                celebrationOverlay(progress: progress(at: context.date))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)                 // pointerEvents="none"
            .accessibilityHidden(true)               // accessibilityElementsHidden
            .zIndex(3)
            .task(id: active) {
                start = Date()
                finished = false
                try? await Task.sleep(nanoseconds: UInt64(celebrationDuration * 1_000_000_000))
                finished = true
            }
        }
    }

    /// `p(t) = cubicOut(t / 1,6)` — `Easing.out(Easing.cubic)` appliqué au
    /// pilote, et non aux interpolations.
    private func progress(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(start)
        let linear = min(max(elapsed / celebrationDuration, 0), 1)
        return 1 - pow(1 - linear, 3)
    }

    /// `overlay` : remplit le parent, `burst` centré horizontalement à 18 pt du haut.
    private func celebrationOverlay(progress: Double) -> some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .topLeading) {
                // `key={index}` de la source : l'index tient lieu d'identité.
                ForEach(Array(celebrationParticles.indices), id: \.self) { index in
                    particle(model: celebrationParticles[index], progress: progress)
                }
                badge(progress: progress)
                    .frame(width: 224, height: 224, alignment: .center)   // badgeAnchor
            }
            .frame(width: 224, height: 224)                               // burst
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// `CelebrationParticle` : `particle` + `roundParticle` + `animatedStyle`.
    ///
    /// L'ordre des transformations suit celui du tableau de la source
    /// (`translateX, translateY, rotate, scale`) : échelle au plus près du
    /// contenu, puis rotation, puis translation.
    private func particle(model: CelebrationParticleModel, progress: Double) -> some View {
        let rotation = interpolate(progress, [0, 1], [0, model.rotation])
        let opacity = interpolate(progress, [0, 0.08, 0.72, 1], [0, 1, 1, 0])
        let translateX = interpolate(progress, [0, 0.16, 0.82], [0, 0, model.x], clamp: true)
        let translateY = interpolate(progress, [0, 0.16, 0.82], [0, 0, model.y], clamp: true)
        let scale = interpolate(progress, [0, 0.18, 0.7, 1], [0.3, 1.2, 1, 0.7])

        return RoundedRectangle(cornerRadius: model.round ? model.size / 2 : 2)
            .fill(model.color)
            .frame(width: model.size, height: model.size)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: 108 + translateX, y: 108 + translateY)   // particle : left 108, top 108
            .opacity(opacity)
    }

    /// `CelebrationBadge` : halo puis badge, centrés dans le `burst`.
    private func badge(progress: Double) -> some View {
        let badgeOpacity = interpolate(progress, [0, 0.1, 0.72, 1], [0, 1, 1, 0])
        let badgeScale = interpolate(progress, [0, 0.2, 0.38, 1], [0.4, 1.12, 1, 1])
        let badgeTranslateY = interpolate(progress, [0, 0.7, 1], [10, 0, -12])
        let haloOpacity = interpolate(progress, [0, 0.12, 0.6, 0.9], [0, 0.5, 0.18, 0])
        let haloScale = interpolate(progress, [0, 0.8], [0.45, 2.1], clamp: true)

        return ZStack {
            Circle()
                .fill(Theme.progressLight)
                .frame(width: 68, height: 68)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(RewardColors.mastery)
                        .frame(width: 34, height: 34)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22))
                        .foregroundStyle(RewardColors.white)
                }
                Text("Tout est juste !")
                    .font(.system(size: 17, weight: .heavy))   // lineHeight 22
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .background(Theme.surface)
            .clipShape(Capsule())                              // radii.pill
            .overlay(Capsule().stroke(RewardColors.mastery, lineWidth: 1))
            // cardShadow (iOS) : couleur #0A0D0C, décalage (0, 2), opacité 0.04, rayon 8.
            .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
            .scaleEffect(badgeScale)
            .offset(y: badgeTranslateY)
            .opacity(badgeOpacity)
        }
    }
}

/// `interpolate` de Reanimated : linéaire par morceaux, en extension linéaire
/// (`Extrapolation.EXTEND`, défaut) ou bornée (`Extrapolation.CLAMP`).
private func interpolate(
    _ value: Double,
    _ input: [Double],
    _ output: [Double],
    clamp: Bool = false
) -> Double {
    guard input.count == output.count, input.count >= 2 else { return output.first ?? 0 }

    if clamp {
        if value <= input[0] { return output[0] }
        if value >= input[input.count - 1] { return output[output.count - 1] }
    }

    for index in 1..<input.count {
        let lower = input[index - 1]
        let upper = input[index]
        guard value <= upper else { continue }
        let span = upper - lower
        guard span > 0 else { return output[index] }
        let ratio = (value - lower) / span
        return output[index - 1] + (output[index] - output[index - 1]) * ratio
    }

    // Au-delà du dernier palier : prolongement linéaire du dernier segment.
    let last = input.count - 1
    let span = input[last] - input[last - 1]
    guard span > 0 else { return output[last] }
    let ratio = (value - input[last]) / span
    return output[last] + (output[last] - output[last - 1]) * ratio
}

// MARK: - §1 ExerciseTrophyButton (`components/ExerciseTrophyButton.tsx`)

/// Activité d'un classement d'exercice (`ExerciseLeaderboardActivity`).
enum ExerciseLeaderboardActivity: String, Equatable {
    case exercice
    case colle
    case annale
}

/// Statut scolaire affiché dans un classement (`ExerciseLeaderboardAcademicStatus`).
enum ExerciseLeaderboardAcademicStatus: String, Equatable {
    case firstYear = "1re année"
    case secondYear = "2e année"
    case integrated = "A intégré"
}

/// Ligne d'un classement d'exercice (`ExerciseLeaderboardEntry`).
struct ExerciseLeaderboardEntry: Identifiable, Equatable {
    let id: String
    let displayName: String
    let photoUri: String?
    let academicStatus: ExerciseLeaderboardAcademicStatus?
    let score: Double
    let firstTry: Bool
    let achievedAt: String
    let rank: Int
}

/// Métriques figées d'un bilan terminé (`AnnaleMetricHistoryEntry`).
struct AnnaleMetricHistoryEntry: Identifiable, Equatable {
    /// Identifiant idempotent de la soumission qui a produit ce bilan.
    let submissionId: String
    let submittedAt: String
    let score: Double
    let spentSeconds: Double
    let wrongAnswers: Int
    let submissionCounts: [String: Int]
    let xp: Double
    let firstTry: Bool
    let attemptNumber: Int
    let improvementPercentage: Double?
    let rank: Int?

    var id: String { submissionId }
}

/// Bouton trophée du bilan d'exercice : ouvre le classement en plein écran
/// (`ExerciseTrophyButton`).
struct ExerciseTrophyButton: View {
    let activity: ExerciseLeaderboardActivity
    let itemId: String
    let subject: String
    let title: String
    /// Conservé pour la page d'historique : ce lot ne le consomme pas
    /// (voir `metricHistoryPlaceholder`).
    let history: [AnnaleMetricHistoryEntry]
    /// Masque la fenêtre native pendant la consultation d'un autre onglet.
    var active: Bool = true
    var onOpenProfile: ((String) -> Void)? = nil
    /// Un sujet d'annales n'a pas de bilan interactif : il garde ses boutons.
    var isAnnale: Bool = false

    /// absent: `useAccountStorage().accountId` — le compte courant est porté par
    /// `SessionStore`, la session serveur en découle.
    @EnvironmentObject private var session: SessionStore

    @State private var visible = false
    @State private var historyVisible = false
    @State private var entries: [ExerciseLeaderboardEntry] = []
    @State private var viewerPublicId: String? = nil
    @State private var state: LoadState = .idle

    /// `state` de la source : `'idle' | 'loading' | 'ready' | 'error'`.
    private enum LoadState {
        case idle
        case loading
        case ready
        case error
    }

    var body: some View {
        // absent: `DesktopLeaderboardLauncher` — no-op natif qui renvoie ses
        // enfants, sans contrepartie Swift.
        // absent: `hitSlop={8}` — pas d'équivalent direct ; la zone tactile
        // reste celle du bouton.
        // absent: `pressed` (opacité 0.72) — `AppPressable` résout l'appui sur
        // l'état au repos, l'état pressé n'est donc jamais rendu.
        Button(action: { visible = true }) {
            Image(systemName: "trophy")               // trophy-outline
                .font(.system(size: 17))
                .foregroundStyle(Theme.primary)
                .frame(width: 32, height: 32)         // trigger
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(triggerLabel)
        .accessibilityAddTraits(.isButton)
        // `Modal` de React Native → `fullScreenCover`.
        // absent: `LeaderboardModal` — animations d'entrée (260 ms `out cubic`),
        // de sortie (200 ms), ressort de fermeture (damping 33, stiffness 500,
        // mass 0.55) et geste de swipe : non portés, `fullScreenCover` fournit
        // sa propre transition et n'a pas de fermeture interactive.
        .fullScreenCover(isPresented: coverBinding, onDismiss: requestClose) {
            leaderboardPage
        }
        .task(id: loadKey) { await loadLeaderboard() }
    }

    /// Clé du `useEffect` de la source : `[activity, itemId, storage, subject,
    /// visible]` — le chargement se relance dès que l'un d'eux change.
    private struct LoadKey: Equatable {
        let activity: ExerciseLeaderboardActivity
        let itemId: String
        let subject: String
        let visible: Bool
    }

    private var loadKey: LoadKey {
        LoadKey(activity: activity, itemId: itemId, subject: subject, visible: visible)
    }

    /// `visible={visible && active}` : la fenêtre est masquée quand l'onglet
    /// consulté n'est pas actif.
    private var coverBinding: Binding<Bool> {
        Binding(
            get: { visible && active },
            set: { visible = $0 }
        )
    }

    /// `onRequestClose` de la modale : referme d'abord l'historique, sinon la page.
    private func requestClose() {
        if historyVisible {
            historyVisible = false
        } else {
            close()
        }
    }

    /// `close()` : referme l'historique puis la fenêtre.
    private func close() {
        historyVisible = false
        visible = false
    }

    private var triggerLabel: String {
        "Ouvrir le classement \(activity == .colle ? "de la colle" : "de l’exercice")"
    }

    private var eyebrowLabel: String {
        isAnnale ? "Classement de l’annale" : "Classement de la colle"
    }

    /// `useEffect` déclenché à l'ouverture : classement puis session serveur.
    ///
    /// absent: `serverSessionForAccount(storage.accountId)` — l'équivalent Swift
    /// est la session courante de `SessionStore`.
    private func loadLeaderboard() async {
        guard visible else { return }
        state = .loading
        do {
            let nextEntries = try await ExerciseLeaderboardClient.fetch(
                activity: activity,
                itemId: itemId,
                subject: subject
            )
            guard !Task.isCancelled else { return }
            entries = nextEntries
            viewerPublicId = session.session?.publicId
            state = .ready
        } catch {
            guard !Task.isCancelled else { return }
            state = .error
        }
    }

    // MARK: Page plein écran

    private var leaderboardPage: some View {
        VStack(spacing: 0) {
            if historyVisible {
                metricHistoryPlaceholder
            } else {
                header
                switch state {
                case .idle:
                    // La source ne rend rien tant que le chargement n'a pas
                    // commencé (ses quatre branches sont des gardes `state === …`).
                    EmptyView()
                case .loading:
                    loadingState
                case .error:
                    errorState
                case .ready:
                    if entries.isEmpty { emptyState } else { entryList }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        // `paddingTop: insets.top` : le contenu d'un `fullScreenCover` est déjà
        // posé sous la zone sûre, ce qui remplace l'insertion manuelle.
    }

    private var header: some View {
        HStack(spacing: 12) {                                  // header : gap 12
            RewardBackButton(label: "Fermer le classement", action: close)

            // L'en-tête centré n'existe que pour une colle ou une annale.
            if activity == .colle || isAnnale {
                VStack(spacing: 2) {                           // heading : flex 1, gap 2
                    Text(eyebrowLabel)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                    Text(title)
                        .font(.system(size: 17, weight: .black))   // lineHeight 21
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                Color.clear.frame(width: 42)                   // headerSpacer
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 74)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {                                  // state : gap 10
            ProgressView()
                .controlSize(.large)                           // ActivityIndicator large
                .tint(Theme.primary)
            Text("Chargement du classement…")
                .font(.system(size: 14))                       // stateText
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "icloud.slash")                  // cloud-offline-outline
                .font(.system(size: 30))
                .foregroundStyle(Theme.inkSoft)
            Text("Classement indisponible")
                .font(.system(size: 19, weight: .black))       // stateTitle
                .foregroundStyle(Theme.ink)
            Text("Réessaie dans quelques instants.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `ExercisePageEmptyState icon="trophy-outline" title="Aucun classement"`.
    private var emptyState: some View {
        RewardPageEmptyState(icon: "trophy", title: "Aucun classement")
    }

    private var entryList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {                          // list : gap 10
                ForEach(entries) { entry in
                    row(entry)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    /// Une ligne de classement (`row`) : rang, avatar, identité, note, historique.
    private func row(_ entry: ExerciseLeaderboardEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.rank)")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 20)                              // rank

            // absent: `usePresence()` / `PresenceProvider` — présence temps réel
            // (socket) hors périmètre : la pastille reste éteinte.
            RewardPresenceAvatar(entry: entry, online: false)

            // `identity` (flex 1, minWidth 0) : la largeur s'ajuste et le nom
            // se tronque (`name`, flexShrink 1) au profit des pastilles.
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {                           // nameLine
                    Text(entry.displayName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if let status = entry.academicStatus {
                        Text(status.rawValue)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.surfaceMuted)
                            .clipShape(Capsule())
                            .fixedSize()                       // flexShrink: 0
                    }
                    if entry.firstTry {
                        Text("1er coup")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.primaryLight)
                            .clipShape(Capsule())
                            .fixedSize()
                    }
                }
                Text("Meilleure note obtenue le \(achievementDate(entry.achievedAt))")
                    .font(.system(size: 11))                   // date, lineHeight 14
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {         // rowActions
                Text(GradingScore.format(entry.score))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.primary)
                // Le bouton n'apparaît que sur sa propre ligne.
                if entry.id == viewerPublicId {
                    historyButton
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(minHeight: 76)
        .background(RewardColors.white)                        // colors.white
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        // absent: `pressed` (opacité 0.72) sur la ligne — l'état pressé est
        // inopérant dans la source (`AppPressable` rend l'état au repos).
        .contentShape(Rectangle())
        // `disabled={!onOpenProfile}` : sans profil ouvrable le tap reste sans
        // effet, ce qui évite de désactiver le bouton « Historique » imbriqué.
        .onTapGesture { onOpenProfile?(entry.id) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rowLabel(entry))
        .accessibilityAddTraits(.isButton)
    }

    private func rowLabel(_ entry: ExerciseLeaderboardEntry) -> String {
        "Voir le profil de \(entry.displayName), rang \(entry.rank), note \(GradingScore.format(entry.score))"
    }

    /// `event.stopPropagation()` : le bouton imbriqué absorbe son propre tap.
    private var historyButton: some View {
        Button(action: { historyVisible = true }) {
            HStack(spacing: 4) {
                Image(systemName: "clock")                     // time-outline
                    .font(.system(size: 13))
                Text("Historique")
                    .font(.system(size: 10, weight: .black))
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(RewardColors.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        // absent: `pressed` (opacité 0.72) — inopérant dans la source.
        .accessibilityLabel("Voir mon historique de métriques")
    }

    /// absent: `ExerciseMetricHistoryPage` (`components/ExerciseMetricHistory.tsx`)
    /// — page des essais, hors périmètre de ce lot : seule la barre de retour
    /// « Revenir au classement » est câblée ici.
    private var metricHistoryPlaceholder: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RewardBackButton(label: "Revenir au classement") {
                    historyVisible = false
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 74)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - §1 Composants partagés repris localement

/// Bouton de retour de la page de classement (`BackButton`).
///
/// absent: `BackButton` / `AndroidBackNavigation` — composants partagés hors
/// périmètre ; la version locale garde le chevron, la zone tactile et le fond.
private struct RewardBackButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")              // chevron-back
                .font(.system(size: 22))
                .foregroundStyle(Theme.ink)
                .offset(x: -4)                                 // icon : translateX -4
                .frame(width: 42, height: 42)                  // backButton
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        // absent: `pressed: { opacity: 0.6 }` et `hitSlop = 8` du `BackButton`.
        .accessibilityLabel(label)
    }
}

/// État vide d'une page de classement (`ExercisePageEmptyState`).
private struct RewardPageEmptyState: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Theme.primary)
            Text(title)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Avatar du classement et sa pastille de présence (`Avatar` de la source,
/// enveloppé par `AvatarPresence` / `OnlineDot`).
private struct RewardPresenceAvatar: View {
    let entry: ExerciseLeaderboardEntry
    let online: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let photoUri = entry.photoUri, let url = URL(string: photoUri) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .frame(width: 42, height: 42)                  // avatar : 42×42, rayon 21
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Theme.surfaceMuted)          // avatarFallback
                    Image(systemName: "person.fill")           // person
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(width: 42, height: 42)
            }

            if online {
                Circle()
                    .fill(RewardColors.online)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(RewardColors.white, lineWidth: 2))
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)               // pointerEvents="none"
            }
        }
    }
}

/// « 15 sept. 2026 » : `Intl.DateTimeFormat('fr-FR', { day: '2-digit',
/// month: 'short', year: 'numeric' })`.
private func achievementDate(_ value: String) -> String {
    guard let date = parsedDate(value) else { return "" }
    return achievementDateFormatter.string(from: date)
}

/// Lecture d'une date comme `new Date(value)` : un instant ISO complet, ou une
/// date sans heure ni fuseau (« 2026-09-15 », minuit UTC).
private func parsedDate(_ value: String) -> Date? {
    if let date = ISO8601DateFormatter.date(fromISO: value) { return date }
    return plainDateFormatter.date(from: value)
}

/// Repli de `Date.parse` pour les dates calendaires nues.
private let plainDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let achievementDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = "dd MMM yyyy"
    return formatter
}()

// MARK: - §1 Réseau

/// Classement d'un exercice, d'une colle ou d'une annale.
///
/// Helper local : `DuelloAPI` n'expose pas `fetchExerciseLeaderboard`
/// (`utils/socialApi.ts`), l'endpoint est donc appelé directement.
enum ExerciseLeaderboardClient {
    /// `fetchExerciseLeaderboard` :
    /// `GET /exercise-leaderboard?subject=…&itemId=…&activity=…`.
    static func fetch(
        activity: ExerciseLeaderboardActivity,
        itemId: String,
        subject: String
    ) async throws -> [ExerciseLeaderboardEntry] {
        let query = [
            URLQueryItem(name: "subject", value: trimmed(subject)),
            URLQueryItem(name: "itemId", value: trimmed(itemId)),
            URLQueryItem(name: "activity", value: activity.rawValue),
        ]
        let data = try await DuelloAPI.request("exercise-leaderboard", query: query)
        let payload = try DuelloAPI.decoder.decode(Payload.self, from: data)
        return parse(payload.entries)
    }

    // absent: `enrichExerciseLeaderboardAcademicStatuses` /
    // `fetchSocialProfilesByIds` (`utils/socialApi.ts`) — l'enrichissement du
    // statut scolaire par l'annuaire des profils reste hors périmètre.

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Décodage

    private struct Payload: Decodable {
        var entries: [Failable<Entry>]?
    }

    /// Ligne décodée sans échec bloquant : la source écarte les entrées
    /// inexploitables une à une (`parseExerciseLeaderboardEntries`), une seule
    /// ligne mal formée ne doit donc pas faire tomber tout le classement.
    private struct Failable<Wrapped: Decodable>: Decodable {
        let value: Wrapped?

        init(from decoder: Decoder) throws {
            value = try? Wrapped(from: decoder)
        }
    }

    private struct Entry: Decodable {
        var id: String?
        var displayName: String?
        var photoUri: String?
        var academicStatus: String?
        var year: String?
        var score: Double?
        var firstTry: Bool?
        var achievedAt: String?
        /// Le serveur peut envoyer un rang non entier : la validation se fait
        /// après décodage, comme `Number.isInteger(rank) && rank > 0`.
        var rank: Double?
    }

    /// `parseExerciseLeaderboardEntries` : écarte les lignes inexploitables,
    /// borne la note à [0, 20] et retombe sur le rang de la ligne quand le
    /// serveur ne l'a pas attribué.
    private static func parse(_ payload: [Failable<Entry>]?) -> [ExerciseLeaderboardEntry] {
        guard let payload else { return [] }
        var entries: [ExerciseLeaderboardEntry] = []

        // `index` reste celui de la réponse du serveur, lignes écartées
        // comprises : c'est le repli de rang de la source.
        for (index, wrapper) in payload.enumerated() {
            guard
                let candidate = wrapper.value,
                let id = candidate.id,
                let displayName = candidate.displayName,
                !trimmed(displayName).isEmpty,
                let score = clampedScore(candidate.score),
                let achievedAt = candidate.achievedAt,
                parsedDate(achievedAt) != nil
            else { continue }

            let rawRank = candidate.rank ?? 0
            let parsedRank = rawRank.isFinite && rawRank > 0 && rawRank == rawRank.rounded()
                ? Int(rawRank)
                : 0
            entries.append(
                ExerciseLeaderboardEntry(
                    id: id,
                    displayName: String(trimmed(displayName).prefix(80)),
                    photoUri: photoUri(candidate.photoUri),
                    academicStatus: academicStatus(candidate.academicStatus)
                        ?? academicStatus(candidate.year),
                    score: score,
                    firstTry: candidate.firstTry == true,
                    achievedAt: achievedAt,
                    rank: parsedRank > 0 ? parsedRank : index + 1
                )
            )
        }
        return entries
    }

    /// `score(value)` : nombre fini dans [0, 20], arrondi au dixième.
    private static func clampedScore(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0.0...20.0).contains(value) else { return nil }
        return (value * 10).rounded() / 10
    }

    /// `photoUri` : une chaîne vide vaut absence.
    private static func photoUri(_ value: String?) -> String? {
        guard let value, !trimmed(value).isEmpty else { return nil }
        return value
    }

    /// `parseExerciseLeaderboardAcademicStatus` : seuls les trois statuts connus
    /// sont retenus, une ancienne « 3e année » n'étant jamais une intégration.
    private static func academicStatus(_ value: String?) -> ExerciseLeaderboardAcademicStatus? {
        value.flatMap(ExerciseLeaderboardAcademicStatus.init(rawValue:))
    }
}

// MARK: - §4 RevisionSuccessSummary (`components/RevisionSuccessSummary.tsx`)

/// `REVISION_XP_FLIGHT_DURATION_MS = 1_400`.
private let revisionXpFlightDuration: Double = 1.4
/// `REVISION_XP_RESULT_HOLD_MS = 900`.
private let revisionXpResultHold: Double = 0.9

/// Bilan de fin d'exercice, présentation compacte et collecte animée
/// (`RevisionSuccessSummary`).
struct RevisionSuccessSummary: View {
    var title: String? = nil
    let xp: Double
    var exerciseBonus: ExerciseBonusReceipt? = nil
    var bonusStatus: ExerciseBonusStatusState? = nil
    var onRetryBonus: (() -> Void)? = nil
    var scoreOn20: Double? = nil
    var scoreComplete: Bool = true
    var seconds: Double
    var chapterMastery: Double? = nil
    let onClaimXp: () -> Void
    var onRetry: (() -> Void)? = nil
    var revision: Bool = false

    // absent: champs de `SuccessSummaryProps` non consommés par ce composant —
    // `xpProgress`, `scoreImprovementPercentage`, `exerciseRank`, `correction`,
    // `onOpenQuestionReport`, `onResume`, `onQuit`, `profile`, `trophy`.

    @State private var claiming = false
    /// Pilote de la collecte (`Animated.Value`), de 0 à 1.
    @State private var animation: Double = 0
    @State private var claimTask: Task<Void, Never>? = nil

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {                      // content : gap 20
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: revision ? 15 : 28,
                                          weight: revision ? .regular : .heavy))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                    }

                    // revisionMetrics : flex 1, centré ; revisionContinueButton :
                    // marginTop auto. La métrique prend l'espace libre, ce qui
                    // repousse le bouton principal en bas.
                    if revision {
                        metrics.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        metrics
                    }

                    continueButton

                    if let onRetry {
                        retryButton(action: onRetry)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, revision ? 42 : 28)
                .padding(.bottom, revision ? 22 : 28)
                // flexGrow 1 + justifyContent center : le contenu court reste
                // centré verticalement.
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .background(Theme.background)
        .onDisappear { claimTask?.cancel() }
    }

    /// `claimXp()` : hors révision la collecte est immédiate ; en révision la
    /// section XP se soulève de 90 pt et s'efface en 1,4 s, puis `onClaimXp` est
    /// appelé après 900 ms de maintien.
    private func claimXp() {
        guard revision else {
            onClaimXp()
            return
        }
        guard !claiming else { return }
        claiming = true
        withAnimation(.easeInOut(duration: revisionXpFlightDuration)) { animation = 1 }
        claimTask = Task { @MainActor in
            let total = revisionXpFlightDuration + revisionXpResultHold
            try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
            guard !Task.isCancelled else { return }
            onClaimXp()
        }
    }

    // MARK: Contenu

    private var metrics: some View {
        VStack(spacing: 14) {                              // metrics : gap 14
            if let scoreOn20 {
                RevisionMetric(
                    icon: "graduationcap",                 // school-outline
                    revision: revision,
                    // `scoreComplete ? '' : ' · provisoire'`.
                    text: GradingScore.format(scoreOn20) + (scoreComplete ? "" : " · provisoire")
                )
            }

            RewardAnimatedValue(value: animation) { value in
                xpSection
                    .opacity(revision ? interpolate(value, [0, 0.72, 1], [1, 1, 0]) : 1)
                    .offset(y: revision ? interpolate(value, [0, 1], [0, -90]) : 0)
            }

            RevisionMetric(
                icon: "timer",                             // timer-outline
                revision: revision,
                text: "\(SuccessDuration.format(seconds)) au total"
            )

            if revision, let chapterMastery {
                RevisionMetric(
                    icon: "graduationcap",
                    revision: true,
                    text: "\(jsNumber(chapterMastery))% du cours maîtrisé"
                )
            }
        }
    }

    private var xpSection: some View {
        VStack(spacing: 12) {                              // xpSection : gap 12, maxWidth 560
            HStack(spacing: 8) {                           // metricLine : gap 8
                Image(systemName: "sparkles")
                    .font(.system(size: revision ? 16 : 22))
                    .foregroundStyle(revision ? Theme.ink : RewardColors.googleBlue)
                Text("+\(XP.format(xp)) XP gagnés")
                    .font(.system(size: revision ? 15 : 20,
                                  weight: revision ? .regular : .heavy))
                    .foregroundStyle(revision ? Theme.ink : RewardColors.googleBlue)
                    .multilineTextAlignment(.center)
            }
            if let exerciseBonus {
                ExerciseBonusProgress(receipt: exerciseBonus)
            }
            if let bonusStatus {
                ExerciseBonusStatus(status: bonusStatus, onRetry: onRetryBonus)
            }
        }
        .frame(maxWidth: 560)
    }

    private var continueButton: some View {
        Button(action: claimXp) {
            Text(claiming ? "XP reçus" : "Recevoir mes XP")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(RewardColors.white)
                .frame(maxWidth: .infinity, minHeight: 54)   // continueButton
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        }
        .buttonStyle(.plain)
        .disabled(claiming)
        .accessibilityAddTraits(.isButton)
    }

    private func retryButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {                             // retryButton : gap 9
                Image(systemName: "arrow.clockwise")         // refresh
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.ink)
                Text("Recommencer l’exercice")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

/// Ligne de métrique du bilan (`RevisionMetric`).
private struct RevisionMetric: View {
    let icon: String
    let revision: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {                                 // metricLine : gap 8
            Image(systemName: icon)
                .font(.system(size: revision ? 16 : 22))
                .foregroundStyle(revision ? Theme.ink : Theme.primary)
            Text(text)
                .font(.system(size: revision ? 15 : 20,
                              weight: revision ? .regular : .heavy))   // lineHeight 20
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
    }
}
