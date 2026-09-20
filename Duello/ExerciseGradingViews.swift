//
//  ExerciseGradingViews.swift
//  Duello
//
//  Bilan de correction d'un exercice — espace de travail, note, verdicts par
//  question, correction attendue, relance — et célébration de l'exercice
//  parfaitement réussi. Porté du React Native / Expo vers SwiftUI natif.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/SuccessSummary.tsx                (aiguillage du bilan)
//    - src/components/SuccessSummary.types.ts           (SuccessSummaryProps)
//    - src/components/correction-summary/CorrectionSummary.tsx
//    - src/components/correction-summary/CorrectionTopBar.tsx
//    - src/components/correction-summary/CorrectionOverview.tsx
//    - src/components/correction-summary/CorrectionResultTiles.tsx
//    - src/components/correction-summary/CorrectionQuestionList.tsx
//    - src/components/correction-summary/useCorrectionCountdown.ts
//    - src/components/correction-summary/confirmRestartCorrection.ts
//    - src/components/ChallengeExerciseWorkspace.tsx    (espace de travail)
//    - src/components/ExerciseTrophyButton.tsx          (classement du bilan)
//    - src/components/ExerciseBonusProgress.tsx         (bonus d'exercice)
//    - src/components/XpGainProgress.tsx                (compteur d'XP animé)
//    - src/components/GradingRemarkBadge.tsx            (appréciation)
//    - src/components/RevisionSuccessSummary.tsx        (bilan de révision)
//    - src/components/PerfectExerciseCelebration.tsx    (célébration parfaite)
//    - src/components/QuestionNumberBadge.tsx
//    - src/utils/gradingScore.ts, xp.ts, successSummary.ts,
//      exerciseRewardState.ts, exerciseLeaderboard.ts, correctionCountdown.ts
//
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//
//  Cible : iOS 16. Aucune dépendance externe, aucune API iOS 17 (observation
//  par macro, vue d'indisponibilité système et animations par images clés
//  restent écartées).
//  Le correcteur de copies reste celui de l'app : `DuelloAPI.gradeCopyWithAi(…)`
//  rend un `ProductionAssessment` (note sur 100 + commentaire), exposé ici par
//  `ExGSuccessSummary(assessment:expectedAnswer:)` sous le libellé « Compte
//  rendu » / « Correction ».
//

import SwiftUI

// MARK: - Couleurs hors `Theme`

/// `mastery` de `theme.ts` (#22C55E) : particules, icône de vérification et
/// remplissage de la barre d'XP.
private let exgMastery = Color(hex: 0x22C55E)
/// `GOOGLE_G_COLORS.blue` de `PerformanceOverviewBar.tsx` (#4285F4) : couleur
/// du montant d'XP dans le bilan.
private let exgGoogleBlue = Color(hex: 0x4285F4)
/// `likeLight` de `theme.ts` (#FDECEC) : fond des avertissements de correction.
private let exgLikeLight = Color(hex: 0xFDECEC)
/// `cardShadow` iOS de `theme.ts` : ombre de la pastille de célébration.
private let exgCardShadow = Color(hex: 0x0A0D0C).opacity(0.04)

// MARK: - §0.1 / §0.4 — Formatage

/// Équivalents Swift des formateurs Expo (`gradingScore.ts`, `xp.ts`,
/// `successSummary.ts`, `exerciseLeaderboard.ts`). Tous les séparateurs suivent
/// la convention française : virgule décimale, espace insécable des milliers.
private enum ExGFormat {
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
private enum ExGGrading {
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
private enum ExGXp {
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

// MARK: - Bilan de correction : modèles

/// `SuccessSummaryQuestionStatus` de `SuccessSummary.types.ts`.
enum ExGQuestionStatus: String, CaseIterable, Identifiable {
    case pending, perfect, correct, partial, incorrect, error, unanswered

    var id: String { rawValue }

    /// `QUESTION_STATUS` de `CorrectionQuestionList.tsx`.
    var label: String {
        switch self {
        case .pending: return "En correction"
        case .perfect: return "Parfait"
        case .correct: return "Correct"
        case .partial: return "À ajuster"
        case .incorrect: return "Incorrect"
        case .error: return "À relancer"
        case .unanswered: return "Non répondue"
        }
    }

    var foreground: Color {
        switch self {
        case .perfect, .correct: return Theme.gradingPerfectHex.color
        case .partial: return Theme.gradingPartialHex.color
        case .incorrect: return Theme.like
        case .pending, .error, .unanswered: return Theme.inkSoft
        }
    }

    var background: Color {
        switch self {
        case .perfect: return Theme.gradingPerfectLightHex.color
        case .correct: return Theme.progressLight
        case .partial: return Theme.gradingPartialLightHex.color
        case .incorrect: return exgLikeLight
        case .pending, .error, .unanswered: return Theme.surfaceMuted
        }
    }

    /// `VERDICT_SCORE_COEFFICIENT` de `utils/gradingScore.ts` : parfait 1,
    /// correct 0,8, partiel 0,4, incorrect 0. Les statuts sans verdict — en
    /// correction, à relancer, non répondue — ne rapportent rien.
    var pointsCoefficient: Double {
        switch self {
        case .perfect: return 1
        case .correct: return 0.8
        case .partial: return 0.4
        case .incorrect, .pending, .error, .unanswered: return 0
        }
    }
}

/// Une question du bilan (`SuccessSummaryQuestion`), augmentée du barème
/// quand l'écran le connaît : c'est ce qui permet d'afficher les points
/// obtenus critère par critère à côté du verdict.
struct ExGQuestion: Identifiable, Equatable {
    var id: String
    var label: String
    var status: ExGQuestionStatus
    var reportAvailable: Bool = false
    var feedback: String? = nil
    /// Points obtenus sur cette question, quand le barème est connu.
    var earnedPoints: Double? = nil
    /// Barème de la question, quand il est connu.
    var maximumPoints: Double? = nil

    /// `3 / 5 pts`, ou `nil` si le barème n'est pas connu.
    var pointsText: String? {
        guard let earned = earnedPoints, let maximum = maximumPoints, maximum > 0 else { return nil }
        return "\(ExGFormat.xp(earned)) / \(ExGFormat.xp(maximum)) pts"
    }
}

/// Progression d'une correction (`SuccessSummaryCorrection`).
struct ExGCorrection: Equatable {
    /// Instant de soumission, en millisecondes depuis l'époque.
    var startedAt: Double
    /// Durée prudente d'une réponse, apprise des corrections mesurées.
    var questionSeconds: Double
    var completed: Bool
    var done: Int
    var total: Int
    var questions: [ExGQuestion]
}

/// `ExerciseLeaderboardActivity` de `utils/exerciseLeaderboard.ts`.
enum ExGLeaderboardActivity: String {
    case exercice, colle, annale
}

/// Bouton de classement du bilan (`ExerciseTrophyButton.tsx`).
struct ExGTrophy: Equatable {
    var itemId: String
    var subject: String
    var title: String
    var activity: ExGLeaderboardActivity = .exercice
    /// Un sujet d'annales n'a pas de bilan interactif : il garde ses boutons.
    var isAnnale: Bool = false
    /// Masque la fenêtre native pendant la consultation d'un autre onglet.
    var active: Bool = true
}

/// Ligne d'un classement d'exercice (`ExerciseLeaderboardEntry`).
struct ExGLeaderboardEntry: Identifiable, Equatable, Decodable {
    var id: String
    var displayName: String
    var photoUri: String?
    var academicStatus: String?
    var score: Double
    var firstTry: Bool
    var achievedAt: String
    var rank: Int

    enum CodingKeys: String, CodingKey {
        case id, displayName, photoUri, academicStatus, score, firstTry, achievedAt, rank
    }

    /// Décodage tolérant, comme `Models.swift` : le serveur omet parfois un
    /// champ ou en change le type.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        photoUri = try? c.decodeIfPresent(String.self, forKey: .photoUri)
        academicStatus = try? c.decodeIfPresent(String.self, forKey: .academicStatus)
        score = (try? c.decode(Double.self, forKey: .score)) ?? 0
        firstTry = (try? c.decode(Bool.self, forKey: .firstTry)) ?? false
        achievedAt = (try? c.decode(String.self, forKey: .achievedAt)) ?? ""
        rank = (try? c.decode(Int.self, forKey: .rank)) ?? 0
    }

    init(id: String, displayName: String, photoUri: String? = nil,
         academicStatus: String? = nil, score: Double, firstTry: Bool,
         achievedAt: String, rank: Int) {
        self.id = id
        self.displayName = displayName
        self.photoUri = photoUri
        self.academicStatus = academicStatus
        self.score = score
        self.firstTry = firstTry
        self.achievedAt = achievedAt
        self.rank = rank
    }
}

// MARK: - §1 — Espace de travail d'exercice

/// Espace de travail d'un exercice (`ChallengeExerciseWorkspace.tsx`).
///
/// Version téléphone : les trois blocs — introduction, énoncé, réponse —
/// s'empilent dans un seul défilement, aux mêmes marges que la source
/// (`paddingHorizontal 20`, `paddingTop 8`, `paddingBottom 34`).
/// La disposition « bureau installé » (deux volets + séparateur déplaçable) est
/// **hors périmètre** : elle appartient à l'app de bureau, pas au mobile.
struct ExGExerciseWorkspace<Intro: View, Statement: View, Response: View>: View {
    private let intro: Intro
    private let statement: Statement
    private let response: Response

    init(@ViewBuilder intro: () -> Intro,
         @ViewBuilder statement: () -> Statement,
         @ViewBuilder response: () -> Response) {
        self.intro = intro()
        self.statement = statement()
        self.response = response()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                intro
                statement
                response
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 34)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - §3 — Appréciation de la note

/// `GradingRemarkBadge` : l'appréciation en pastille, casse d'origine.
///
/// Les majuscules restent visuelles (`textCase`) : le libellé lu par les
/// lecteurs d'écran garde sa casse, comme le commentaire de la source.
struct ExGRemarkBadge: View {
    let score: Double?

    private var remark: ExGRemark { ExGGrading.remark(score) }

    var body: some View {
        Text(remark.label)
            .font(.system(size: 13, weight: .bold))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(remark.tone.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(remark.tone.background)
            .clipShape(Capsule())
            .accessibilityLabel("Remarque : \(remark.label)")
    }
}

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
                .foregroundStyle(levelUp ? Theme.gradingPerfectHex.color : Theme.ink)
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
                    .foregroundStyle(Theme.gradingPerfectHex.color)
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
                        .foregroundStyle(Theme.gradingPerfectHex.color)
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

// MARK: - Bilan de correction : blocs

/// `CorrectionResultTiles` : l'appréciation, puis note, XP gagnés et rang.
///
/// Les trois mesures réutilisent `DuelloStatTile` du kit (la source les
/// réunit dans un bloc bordé à séparateurs ; la tuile porte les mêmes
/// libellés, la casse majuscule restant purement visuelle).
struct ExGCorrectionResultTiles: View {
    var scoreOn20: Double? = nil
    var xp: Double = 0
    var exerciseRank: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExGRemarkBadge(score: scoreOn20)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(alignment: .top, spacing: 8) {
                DuelloStatTile(label: "Note", value: ExGFormat.score(scoreOn20))
                DuelloStatTile(label: "XP gagnés", value: "+\(ExGFormat.xp(xp)) XP")
                DuelloStatTile(label: "Rang", value: ExGFormat.rank(exerciseRank))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `QuestionNumberBadge` : numéro de question, gris sur pastille grise.
private struct ExGQuestionNumberBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 6)
            .frame(minWidth: 26, minHeight: 26)
            .background(Theme.border)
            .clipShape(Capsule())
    }
}

/// `VerdictBadge` : le verdict d'une question, couleur par statut.
private struct ExGQuestionVerdictBadge: View {
    let status: ExGQuestionStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.background)
            .clipShape(Capsule())
    }
}

/// Une ligne du bilan : numéro, verdict, puis l'emplacement du compte rendu.
private struct ExGCorrectionQuestionRow: View {
    let question: ExGQuestion
    var onOpenQuestionReport: ((String) -> Void)? = nil
    /// Vrai quand la ligne peut déplier le compte rendu (app de bureau) : la
    /// version mobile se contente du verdict centré, comme la source.
    var inline: Bool = false
    var ongoing: Bool = false

    private var available: Bool {
        question.reportAvailable && onOpenQuestionReport != nil
    }

    private var accessibilityText: String {
        if ongoing {
            return "Question \(question.label) : \(question.status.label)"
        }
        return available
            ? "Voir le compte rendu de la question \(question.label)"
            : "Question \(question.label) : \(question.status.label), compte rendu indisponible"
    }

    var body: some View {
        Button(action: { if available { onOpenQuestionReport?(question.id) } }) {
            HStack(spacing: 10) {
                ExGQuestionNumberBadge(label: question.label)

                if inline {
                    ExGQuestionVerdictBadge(status: question.status)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(question.feedback
                             ?? (available ? "Voir le compte rendu" : "Compte rendu indisponible"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let pointsText = question.pointsText {
                            Text(pointsText)
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ExGQuestionVerdictBadge(status: question.status)
                        if let pointsText = question.pointsText {
                            Text(pointsText)
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if question.status == .pending {
                    // Correction en cours : l'emplacement du compte rendu porte
                    // l'indicateur d'activité, comme `OngoingQuestion`.
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 30, height: 30)
                } else if ongoing {
                    // Pendant la correction, l'emplacement reste vide : aucun
                    // compte rendu n'est encore ouvert (`reportSlot` 30×30).
                    Color.clear.frame(width: 30, height: 30)
                } else {
                    Image(systemName: "eye")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(available ? Theme.ink : Theme.inkFaint)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                        .opacity(available ? 1 : 0.45)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .background(Theme.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityLabel(accessibilityText)
    }
}

/// `CorrectionQuestionList` : toutes les questions, dans l'ordre du sujet.
struct ExGCorrectionQuestionList: View {
    let correction: ExGCorrection
    var onOpenQuestionReport: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(correction.questions) { question in
                ExGCorrectionQuestionRow(
                    question: question,
                    onOpenQuestionReport: onOpenQuestionReport,
                    ongoing: !correction.completed
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// `CorrectionOverview` : les résultats, puis les réponses à relancer.
struct ExGCorrectionOverview: View {
    let correction: ExGCorrection
    var scoreOn20: Double? = nil
    var xp: Double = 0
    var exerciseRank: Int? = nil

    private var errorCount: Int {
        correction.questions.filter { $0.status == .error }.count
    }

    private var errorText: String {
        errorCount > 1
            ? "\(errorCount) réponses n’ont pas pu être corrigées. Reprends la copie pour les relancer."
            : "\(errorCount) réponse n’a pas pu être corrigée. Reprends la copie pour les relancer."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExGCorrectionResultTiles(scoreOn20: scoreOn20, xp: xp, exerciseRank: exerciseRank)

            if errorCount > 0 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.like)
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.like)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(exgLikeLight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compte rendu du correcteur et correction attendue.
///
/// Les libellés « Compte rendu » et « Correction » sont la reprise des termes
/// de la source (`Voir le compte rendu`, étape `Correction` du parcours
/// d'entraînement) ; le texte attendu s'affiche en serif, comme un manuel.
struct ExGAssessmentCard: View {
    var assessment: ProductionAssessment? = nil
    var expectedAnswer: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let assessment {
                VStack(alignment: .leading, spacing: 6) {
                    DuelloSectionHeader(title: "Compte rendu")
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(assessment.score)/100")
                            .font(.system(size: 15, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                        Text(assessment.note)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if let expectedAnswer, !expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    DuelloSectionHeader(title: "Correction")
                    Text(expectedAnswer)
                        .font(Theme.readingFont)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .duelloCard()
    }
}

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

/// Sablier et temps restant avant la correction complète.
private struct ExGCorrectionCountdownView: View {
    let correction: ExGCorrection

    @State private var completedAt: [Double] = []

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            // `Math.ceil(useCorrectionCountdown(correction))` : le décompte est
            // arrondi à la seconde supérieure, comme la valeur affichée.
            let seconds = ExGCorrectionCountdown.remainingSeconds(
                ExGCorrectionProgress(
                    startedAt: correction.startedAt,
                    total: correction.total,
                    completedAt: completedAt
                ),
                questionSeconds: correction.questionSeconds,
                now: ExGFormat.milliseconds(context.date)
            ).rounded(.up)
            let remaining = seconds > 0
                ? ExGFormat.duration(seconds)
                : "quelques instants"
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
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
                .foregroundStyle(Theme.surface)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - §1 — Classement d'exercice

/// `fetchExerciseLeaderboard` de `utils/socialApi.ts`.
///
/// L'annuaire social n'est pas exposé par `DuelloAPI` : ce client local
/// réutilise le relais (`DuelloAPI.request`) sur `exercise-leaderboard`.
/// L'enrichissement des statuts scolaires par l'annuaire des profils n'est pas
/// repris — le serveur sert déjà `academicStatus` quand il le connaît.
private enum ExGLeaderboardClient {
    private struct Payload: Decodable {
        var entries: [ExGLeaderboardEntry]?
    }

    static func fetch(activity: ExGLeaderboardActivity, itemId: String,
                      subject: String, token: String?) async throws -> [ExGLeaderboardEntry] {
        let query = [
            URLQueryItem(name: "activity", value: activity.rawValue),
            URLQueryItem(name: "itemId", value: itemId),
            URLQueryItem(name: "subject", value: subject),
        ]
        let payload = try await DuelloAPI.request(
            Payload.self,
            "exercise-leaderboard",
            token: token,
            query: query
        )
        return payload.entries ?? []
    }
}

/// `ExerciseTrophyButton` : le déclencheur du classement.
///
/// La présence temps réel (`usePresence`, socket) n'est pas portée : la
/// pastille « en ligne » du classement est laissée de côté, faute de source de
/// présence côté natif. L'historique des métriques
/// (`ExerciseMetricHistoryPage`) appartient à un autre écran : il est exposé
/// par `onOpenHistory`, appelé depuis la ligne du joueur lui-même.
struct ExGTrophyButton: View {
    let trophy: ExGTrophy
    var onOpenProfile: ((String) -> Void)? = nil
    var onOpenHistory: ((String) -> Void)? = nil

    @State private var visible = false

    private var triggerLabel: String {
        trophy.activity == .colle
            ? "Ouvrir le classement de la colle"
            : "Ouvrir le classement de l’exercice"
    }

    var body: some View {
        Button(action: { visible = true }) {
            Image(systemName: "trophy")
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
        .accessibilityLabel(triggerLabel)
        .sheet(isPresented: $visible) {
            ExGLeaderboardSheet(
                trophy: trophy,
                onOpenProfile: onOpenProfile,
                onOpenHistory: onOpenHistory
            )
        }
    }
}

/// Fenêtre du classement : en-tête, états de chargement, liste des rangs.
struct ExGLeaderboardSheet: View {
    let trophy: ExGTrophy
    var onOpenProfile: ((String) -> Void)? = nil
    var onOpenHistory: ((String) -> Void)? = nil

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState = .idle
    @State private var entries: [ExGLeaderboardEntry] = []

    private var viewerPublicId: String? {
        if let publicId = session.session?.publicId, !publicId.isEmpty { return publicId }
        let email = session.profile.email
        return email.isEmpty ? nil : DuelloAPI.publicProfileId(email: email)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.background.ignoresSafeArea())
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer le classement")

            if trophy.activity == .colle || trophy.isAnnale {
                VStack(spacing: 2) {
                    Text(trophy.isAnnale ? "Classement de l’annale" : "Classement de la colle")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                    Text(trophy.title)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                Color.clear.frame(width: 42, height: 42)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 74)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Chargement du classement…")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            VStack(spacing: 10) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text("Classement indisponible")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Réessaie dans quelques instants.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            if entries.isEmpty {
                DuelloEmptyState(icon: "trophy", title: "Aucun classement")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            row(entry)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private func row(_ entry: ExGLeaderboardEntry) -> some View {
        Button(action: { onOpenProfile?(entry.id) }) {
            HStack(spacing: 10) {
                Text("\(entry.rank)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 20)

                avatar(entry)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(entry.displayName)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        if let status = entry.academicStatus, !status.isEmpty {
                            // `DuelloPill` du kit : la casse majuscule reste
                            // purement visuelle, le libellé serveur est rendu
                            // tel quel à la lecture d'écran.
                            DuelloPill(text: status, tone: .neutral)
                        }
                        if entry.firstTry {
                            Text("1er coup")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Theme.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.primaryLight)
                                .clipShape(Capsule())
                        }
                    }
                    Text("Meilleure note obtenue le \(ExGFormat.achievementDate(entry.achievedAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(ExGFormat.score(entry.score))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.primary)

                if entry.id == viewerPublicId, let onOpenHistory {
                    Button(action: { onOpenHistory(entry.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Historique")
                                .font(.system(size: 10, weight: .black))
                        }
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 28)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                .stroke(Theme.primary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Voir mon historique de métriques")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minHeight: 76)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onOpenProfile == nil)
        .accessibilityLabel("Voir le profil de \(entry.displayName), rang \(entry.rank), note \(ExGFormat.score(entry.score))")
    }

    private func avatar(_ entry: ExGLeaderboardEntry) -> some View {
        Group {
            if let photoUri = entry.photoUri, let url = URL(string: photoUri) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Theme.surfaceMuted)
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Theme.surfaceMuted)
                    Image(systemName: "person.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(width: 42, height: 42)
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            entries = try await ExGLeaderboardClient.fetch(
                activity: trophy.activity,
                itemId: trophy.itemId,
                subject: trophy.subject,
                token: session.token
            )
            state = .ready
        } catch {
            state = .error
        }
    }
}

// MARK: - §5 — Célébration de l'exercice parfait

/// Interpolation linéaire par morceaux, comme `interpolate` de Reanimated.
/// `clamped` reproduit `Extrapolation.CLAMP` ; sinon la courbe prolonge la
/// dernière pente, comportement par défaut de la source.
private func exgInterpolate(_ value: Double, _ input: [Double], _ output: [Double],
                            clamped: Bool = false) -> Double {
    guard input.count >= 2, input.count == output.count else { return output.first ?? 0 }
    if value <= input[0] {
        return clamped ? output[0]
            : exgLinear(value, input[0], input[1], output[0], output[1])
    }
    let last = input.count - 1
    if value >= input[last] {
        return clamped ? output[last]
            : exgLinear(value, input[last - 1], input[last], output[last - 1], output[last])
    }
    for index in 1...last where value <= input[index] {
        return exgLinear(value, input[index - 1], input[index], output[index - 1], output[index])
    }
    return output[last]
}

private func exgLinear(_ value: Double, _ x0: Double, _ x1: Double,
                       _ y0: Double, _ y1: Double) -> Double {
    guard x1 > x0 else { return y1 }
    return y0 + (y1 - y0) * (value - x0) / (x1 - x0)
}

/// `CelebrationParticleModel` : couleur, rotation, forme, taille et éclatement.
private struct ExGCelebrationParticleModel: Identifiable {
    let id: Int
    let colorHex: Int
    let rotation: Double
    let round: Bool
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// `CELEBRATION_PARTICLES` — les 12 particules, dans l'ordre exact.
private let exgCelebrationParticles: [ExGCelebrationParticleModel] = [
    ExGCelebrationParticleModel(id: 0, colorHex: 0x22C55E, rotation: 130, round: false, size: 10, x: -106, y: -52),
    ExGCelebrationParticleModel(id: 1, colorHex: 0x0A0D0C, rotation: -95, round: false, size: 7, x: -70, y: -91),
    ExGCelebrationParticleModel(id: 2, colorHex: 0x166534, rotation: 155, round: false, size: 9, x: -24, y: -108),
    ExGCelebrationParticleModel(id: 3, colorHex: 0x22C55E, rotation: -120, round: true, size: 8, x: 34, y: -104),
    ExGCelebrationParticleModel(id: 4, colorHex: 0x0A0D0C, rotation: 105, round: false, size: 8, x: 82, y: -76),
    ExGCelebrationParticleModel(id: 5, colorHex: 0x22C55E, rotation: -160, round: true, size: 10, x: 112, y: -28),
    ExGCelebrationParticleModel(id: 6, colorHex: 0x166534, rotation: 90, round: false, size: 8, x: 104, y: 38),
    ExGCelebrationParticleModel(id: 7, colorHex: 0x0A0D0C, rotation: -135, round: true, size: 7, x: 64, y: 82),
    ExGCelebrationParticleModel(id: 8, colorHex: 0x22C55E, rotation: 145, round: false, size: 10, x: 14, y: 101),
    ExGCelebrationParticleModel(id: 9, colorHex: 0x166534, rotation: -100, round: false, size: 8, x: -43, y: 91),
    ExGCelebrationParticleModel(id: 10, colorHex: 0x0A0D0C, rotation: 120, round: true, size: 7, x: -88, y: 62),
    ExGCelebrationParticleModel(id: 11, colorHex: 0x22C55E, rotation: -145, round: false, size: 9, x: -116, y: 8),
]

/// `CelebrationParticle` : une particule, projetée par `p ∈ [0, 1]`.
private struct ExGCelebrationParticle: View {
    let model: ExGCelebrationParticleModel
    let p: Double

    private var rotation: Double { exgInterpolate(p, [0, 1], [0, model.rotation]) }
    private var opacity: Double { exgInterpolate(p, [0, 0.08, 0.72, 1], [0, 1, 1, 0]) }
    private var translateX: CGFloat {
        CGFloat(exgInterpolate(p, [0, 0.16, 0.82], [0, 0, Double(model.x)], clamped: true))
    }
    private var translateY: CGFloat {
        CGFloat(exgInterpolate(p, [0, 0.16, 0.82], [0, 0, Double(model.y)], clamped: true))
    }
    private var scale: Double { exgInterpolate(p, [0, 0.18, 0.7, 1], [0.3, 1.2, 1, 0.7]) }

    var body: some View {
        RoundedRectangle(cornerRadius: model.round ? model.size / 2 : 2)
            .fill(Color(hex: model.colorHex))
            .frame(width: model.size, height: model.size)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: 108 + model.size / 2 + translateX,
                      y: 108 + model.size / 2 + translateY)
    }
}

/// `CelebrationBadge` : le halo, puis la pastille « Tout est juste ! ».
private struct ExGCelebrationBadge: View {
    let p: Double

    private var badgeOpacity: Double { exgInterpolate(p, [0, 0.1, 0.72, 1], [0, 1, 1, 0]) }
    private var badgeScale: Double { exgInterpolate(p, [0, 0.2, 0.38, 1], [0.4, 1.12, 1, 1]) }
    private var badgeOffset: CGFloat { CGFloat(exgInterpolate(p, [0, 0.7, 1], [10, 0, -12])) }
    private var haloOpacity: Double { exgInterpolate(p, [0, 0.12, 0.6, 0.9], [0, 0.5, 0.18, 0]) }
    private var haloScale: Double { exgInterpolate(p, [0, 0.8], [0.45, 2.1], clamped: true) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.progressLight)
                .frame(width: 68, height: 68)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(exgMastery)
                        .frame(width: 34, height: 34)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Tout est juste !")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .background(Theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(exgMastery, lineWidth: 1))
            .shadow(color: exgCardShadow, radius: 8, x: 0, y: 2)
            .scaleEffect(badgeScale)
            .offset(y: badgeOffset)
            .opacity(badgeOpacity)
        }
        .frame(width: 224, height: 224)
    }
}

/// `PerfectExerciseCelebration` : éclatement de 12 particules et pastille
/// centrale, déclenché par `active`.
///
/// Une seule valeur pilote `p ∈ [0, 1]`, avec `p(t) = cubicOut(t / 1,6 s)` ;
/// toutes les grandeurs sont des interpolations linéaires par morceaux sur `p`.
/// `TimelineView(.animation)` remplace le thread UI de Reanimated — les
/// animations par images clés (iOS 17) sont volontairement écartées. Si
/// « réduire les animations » est actif, rien n'est affiché, comme le
/// `return null` de la source.
struct ExGPerfectCelebration: View {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        Group {
            if active && !reduceMotion {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    let clamped = min(max(elapsed / 1.6, 0), 1)
                    let p = 1 - pow(1 - clamped, 3)
                    ZStack {
                        ForEach(exgCelebrationParticles) { model in
                            ExGCelebrationParticle(model: model, p: p)
                        }
                        ExGCelebrationBadge(p: p)
                    }
                    .frame(width: 224, height: 224)
                }
                .onAppear { startedAt = Date() }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - §4 — Bilan de révision et §Correction — point d'entrée

/// Une mesure du bilan de révision (`RevisionMetric`).
private struct ExGRevisionMetric: View {
    let icon: String
    let revision: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: revision ? 16 : 22, weight: .semibold))
                .foregroundStyle(revision ? Theme.ink : Theme.primary)
            Text(text)
                .font(.system(size: revision ? 15 : 20, weight: revision ? .regular : .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Bilan de fin d'exercice : correction détaillée, ou célébration de la
/// révision.
///
/// Une seule entrée publique, comme `SuccessSummary.tsx` : quand `correction`
/// est fourni, c'est le bilan de correction (appréciation, note, XP, rang,
/// verdict par question, correction attendue, relance) ; sinon, c'est le bilan
/// de révision (`RevisionSuccessSummary`) — mesures, collecte des XP, reprise.
/// `perfect` superpose la célébration de l'exercice parfaitement réussi.
struct ExGSuccessSummary: View {
    // Aligné sur `SuccessSummaryProps` de `SuccessSummary.types.ts`.
    var title: String? = nil
    var xp: Double = 0
    var exerciseBonus: ExGBonusReceipt? = nil
    var bonusStatus: ExGBonusStatus.Kind? = nil
    var onRetryBonus: (() -> Void)? = nil
    var scoreOn20: Double? = nil
    var scoreComplete: Bool = true
    var exerciseRank: Int? = nil
    var seconds: Int = 0
    var chapterMastery: Int? = nil
    var revision: Bool = false
    /// Bilan de correction : progression et questions corrigées.
    var correction: ExGCorrection? = nil
    /// Note sur 100 et commentaire du correcteur
    /// (`DuelloAPI.gradeCopyWithAi(…)` → `ProductionAssessment`).
    var assessment: ProductionAssessment? = nil
    /// Corrigé attendu, affiché en serif sous le compte rendu.
    var expectedAnswer: String? = nil
    var onClaimXp: () -> Void = {}
    var onRetry: (() -> Void)? = nil
    var onResume: (() -> Void)? = nil
    var onQuit: (() -> Void)? = nil
    var onOpenQuestionReport: ((String) -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var trophy: ExGTrophy? = nil
    /// Exercice parfaitement réussi : lance la célébration.
    var perfect: Bool = false

    @State private var claiming = false
    @State private var xpOffset: CGFloat = 0
    @State private var xpOpacity: Double = 1

    /// Note sur 20 du bilan : celle fournie par l'écran, ou celle déduite de la
    /// note sur 100 du correcteur (`DuelloAPI.gradeCopyWithAi(…)` →
    /// `ProductionAssessment`, ramenée sur 20 et arrondie au dixième).
    private var displayedScoreOn20: Double? {
        if let scoreOn20 { return scoreOn20 }
        guard let assessment else { return nil }
        return ExGGrading.roundScore(Double(assessment.score) / 5)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let correction {
                correctionLayout(correction)
            } else {
                revisionLayout
            }
        }
        .overlay(alignment: .top) {
            if perfect {
                ExGPerfectCelebration(active: true)
                    .padding(.top, 18)
            }
        }
    }

    // MARK: Bilan de correction

    @ViewBuilder
    private func correctionLayout(_ correction: ExGCorrection) -> some View {
        VStack(spacing: 0) {
            ExGCorrectionTopBar(
                correction: correction,
                trophy: trophy,
                onResume: onResume,
                onReport: onReport
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                    }

                    if correction.completed {
                        ExGCorrectionOverview(
                            correction: correction,
                            scoreOn20: displayedScoreOn20,
                            xp: xp,
                            exerciseRank: exerciseRank
                        )
                    }

                    if !correction.questions.isEmpty {
                        ExGCorrectionQuestionList(
                            correction: correction,
                            onOpenQuestionReport: onOpenQuestionReport
                        )
                    }

                    if assessment != nil || expectedAnswer != nil {
                        ExGAssessmentCard(assessment: assessment, expectedAnswer: expectedAnswer)
                    }
                }
                .frame(maxWidth: 880, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }

            if correction.completed {
                ExGCorrectionActions(onResume: onResume, onRetry: onRetry, onQuit: onQuit)
            }
        }
    }

    // MARK: Bilan de révision

    private var revisionLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: revision ? 15 : 28,
                                      weight: revision ? .regular : .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 14) {
                    if let scoreOn20 {
                        ExGRevisionMetric(
                            icon: "graduationcap",
                            revision: revision,
                            text: ExGFormat.score(scoreOn20)
                                + (scoreComplete ? "" : "\u{00A0}· provisoire")
                        )
                    }

                    xpSection

                    ExGRevisionMetric(
                        icon: "timer",
                        revision: revision,
                        text: "\(ExGFormat.duration(Double(seconds))) au total"
                    )

                    if revision, let chapterMastery {
                        ExGRevisionMetric(
                            icon: "graduationcap",
                            revision: revision,
                            text: "\(chapterMastery)% du cours maîtrisé"
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                claimButton

                if let onRetry {
                    retryButton(onRetry)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, revision ? 42 : 28)
            .padding(.bottom, revision ? 22 : 28)
            .frame(maxWidth: .infinity)
        }
    }

    private var xpSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: revision ? 16 : 22, weight: .semibold))
                    .foregroundStyle(revision ? Theme.ink : exgGoogleBlue)
                Text("+\(ExGFormat.xp(xp)) XP gagnés")
                    .font(.system(size: revision ? 15 : 20,
                                  weight: revision ? .regular : .bold))
                    .foregroundStyle(revision ? Theme.ink : exgGoogleBlue)
            }
            .frame(maxWidth: .infinity)

            if let exerciseBonus {
                ExGBonusProgress(receipt: exerciseBonus)
            }
            if let bonusStatus {
                ExGBonusStatus(status: bonusStatus, onRetry: onRetryBonus)
            }
        }
        .frame(maxWidth: 560)
        .offset(y: xpOffset)
        .opacity(xpOpacity)
    }

    private var claimButton: some View {
        Button(action: claimXp) {
            Text(claiming ? "XP reçus" : "Recevoir mes XP")
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(claiming)
    }

    private func retryButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 19, weight: .semibold))
                Text("Recommencer l’exercice")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// `useRevisionClaim` — hors révision, la collecte est immédiate ; en
    /// révision, la section XP se soulève de 90 pt et s'efface en 1 400 ms,
    /// puis l'appel part après 900 ms de maintien.
    ///
    /// Limite documentée : la source maintient l'opacité à 1 jusqu'à 72 % puis
    /// la fond (`interpolate([0, 0.72, 1] → [1, 1, 0])`) ; ici un seul
    /// `withAnimation` en `easeInOut` approche la séquence sans animation par
    /// images clés (iOS 17).
    private func claimXp() {
        if !revision {
            onClaimXp()
            return
        }
        if claiming { return }
        claiming = true
        withAnimation(.easeInOut(duration: 1.4)) {
            xpOffset = -90
            xpOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            onClaimXp()
        }
    }
}
