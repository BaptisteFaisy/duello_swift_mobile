//
//  ProgPrereqEcgAdvanced+Semantic.swift
//  Duello
//
//  Phase 1a — section extraite de `ProgPrereqEcgAdvanced.swift` : index du
//  programme approfondies, ventilation sémantique par question, analyse des
//  exercices de révision (`analyse-concours`) et table des notions.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `CHAPTER_TOPIC_PATTERNS` : notion détectable dans le texte d'une question.
struct ChapterTopicPattern {
    var chapterId: String
    var question: String
}

extension ProgPrereqEcgAdvanced {

    // MARK: - Index du programme approfondies

    /// `advancedChapterIndex` : position et amont transitif de chaque chapitre
    /// approfondi, dans l'ordre d'insertion du programme (année 1 puis 2).
    static func advancedChapterIndex() -> AdvancedChapterIndex {
        var keys: [String] = []
        var positions: [String: AdvancedChapterPosition] = [:]
        var directPrerequisites: [String: [SubjChapterPrerequisite]] = [:]
        for year in SubjProgramYear.allCases {
            for (index, chapter) in (ProgPrereqEcgProgram.approfondies[year] ?? []).enumerated() {
                let key = "\(year.rawValue):\(chapter.id)"
                directPrerequisites[key] = chapter.prerequisites
                positions[key] = AdvancedChapterPosition(
                    year: year, id: chapter.id, name: chapter.name, index: index, upstream: []
                )
                keys.append(key)
            }
        }
        for key in keys {
            var pending = directPrerequisites[key] ?? []
            while let parent = pending.popLast() {
                let parentKey = "\(parent.year.rawValue):\(parent.chapterId)"
                if positions[key]?.upstream.contains(parentKey) == true { continue }
                positions[key]?.upstream.insert(parentKey)
                pending.append(contentsOf: directPrerequisites[parentKey] ?? [])
            }
        }
        return AdvancedChapterIndex(keys: keys, positions: positions)
    }

    // MARK: - Ventilation sémantique par question

    /// `semanticQuestionPrerequisites` (version ECG approfondies) : connaissances
    /// supplémentaires qu'une question mobilise. Un chapitre POSTÉRIEUR au
    /// porteur est recevable ; jamais un chapitre de l'année suivante, jamais un
    /// chapitre déjà exigé transitivement.
    static func semanticQuestionPrerequisites(
        year: SubjProgramYear,
        chapterId: String,
        questionText: String
    ) -> [SubjChapterPrerequisite] {
        if questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let index = advancedChapterIndex()
        let carrierKey = "\(year.rawValue):\(chapterId)"
        guard let carrier = index.positions[carrierKey] else { return [] }

        var extras: [SubjChapterPrerequisite] = []
        for key in index.keys {
            guard let candidate = index.positions[key] else { continue }
            if candidate.year.rawValue > carrier.year.rawValue { continue }
            if key == carrierKey || carrier.upstream.contains(key) { continue }
            guard let pattern = chapterTopicPatterns.first(where: {
                matches($0.chapterId, candidate.id, caseInsensitive: false)
            }) else { continue }
            if !matches(pattern.question, questionText) { continue }
            extras.append(
                completedPrerequisite(
                    year: candidate.year,
                    chapterId: candidate.id,
                    reason: "La question mobilise « \(candidate.name) », au-delà du chapitre courant."
                )
            )
        }
        return extras
    }

    // MARK: - Exercices de révision (analyse-concours)

    /// `revisionAnalysisPrerequisites` : prérequis déduits du seul énoncé d'une
    /// question de révision de 1re année.
    static func revisionAnalysisPrerequisites(itemId: String, text: String) -> [SubjChapterPrerequisite] {
        var prerequisites: [SubjChapterPrerequisite] = []
        func add(_ chapterId: String, _ reason: String) {
            prerequisites.append(completedPrerequisite(year: .first, chapterId: chapterId, reason: reason))
        }

        if itemId.contains("c0-suites-") {
            add("suites", "La question étudie une suite numérique.")
        } else if itemId.contains("c5-integration-") {
            add("integration", "La question calcule ou transforme une intégrale.")
        } else {
            add("fonctions-usuelles", "La question mobilise les outils usuels d’étude des fonctions.")
        }

        if matches(#"continuit|prolongement|bijection|point fixe"#, text) {
            add("limites-continuite", "La question utilise la continuité ou le théorème de la bijection.")
        }
        if matches(#"d[ée]riv|convex|concav|accroissements finis|tangente|classe C"#, text) {
            add("derivation", "La question utilise la dérivation.")
        }
        if matches(#"∫|int[ée]grale|somme de Riemann|Wallis"#, text) {
            add("integration", "La question utilise le calcul intégral.")
        }
        if matches(#"impropre|semi-convergente|fonction Γ|∫[^\n]{0,40}(?:\+∞|−∞|-∞)|int[ée]grale[^\n]{0,60}(?:\+∞|−∞|-∞)"#, text) {
            add("integrales-impropres", "La question étudie une intégrale impropre.")
        }
        if matches(#"s[ée]rie|somme partielle|Σ|∑"#, text) {
            add("series", "La question étudie une série numérique.")
        }
        if matches(#"d[ée]veloppement limit[ée]|formule de Taylor"#, text) {
            add("taylor-developpements-limites", "La question utilise un développement limité.")
        } else if matches(#"d[ée]veloppement asymptotique|[ée]quivalent"#, text) {
            add("analyse-asymptotique", "La question recherche un équivalent ou un développement asymptotique.")
        }
        if matches(#"Python|dichotomie|r[ée]solution num[ée]rique"#, text) {
            add("python-approfondies-1-fonctions", "La question demande une mise en œuvre numérique en Python.")
        }
        if matches(#"probabilit|variable al[ée]atoire|loi de"#, text) {
            add("variables-discretes", "La question mobilise une variable aléatoire discrète.")
        }
        return uniquePrerequisites(prerequisites)
    }

    // MARK: - Table des notions

    /// `CHAPTER_TOPIC_PATTERNS` (18 entrées, ordre et motifs à l'identique).
    /// Les `chapterId` sont des motifs d'identifiant, sensibles à la casse.
    static let chapterTopicPatterns: [ChapterTopicPattern] = [
        ChapterTopicPattern(
            chapterId: #"^suites$"#,
            question: #"(?:la|une|cette)\s+suite|suite r[ée]currente|suite extraite"#
        ),
        ChapterTopicPattern(
            chapterId: #"^limites-continuite$"#,
            question: #"continuit[ée]|prolongement par continuit[ée]|th[ée]or[eè]me de la bijection"#
        ),
        ChapterTopicPattern(
            chapterId: #"^derivation$"#,
            question: #"d[ée]riv[ée]e|d[ée]rivable|accroissements finis|convexit[ée]|concavit[ée]"#
        ),
        ChapterTopicPattern(
            chapterId: #"^integration$"#,
            question: #"int[ée]grale|int[ée]gration par parties|somme de Riemann|changement de variable"#
        ),
        ChapterTopicPattern(
            chapterId: #"^analyse-asymptotique$"#,
            question: #"[ée]quivalent|d[ée]veloppement asymptotique|n[ée]gligeable"#
        ),
        ChapterTopicPattern(
            chapterId: #"^series$"#,
            question: #"s[ée]rie(?:s)?\b|somme partielle|s[ée]rie g[ée]om[ée]trique|crit[eè]re de comparaison"#
        ),
        ChapterTopicPattern(
            chapterId: #"^integrales-impropres$"#,
            question: #"int[ée]grale impropre|int[ée]grale convergente|fonction Γ|∫[^\n]{0,40}(?:\+∞|−∞|-∞)|\\int[^\n]{0,60}\\infty"#
        ),
        ChapterTopicPattern(
            chapterId: #"^taylor-developpements-limites$"#,
            question: #"d[ée]veloppement limit[ée]|formule de Taylor"#
        ),
        ChapterTopicPattern(
            chapterId: #"^matrices$"#,
            question: #"matrice|inversible"#
        ),
        ChapterTopicPattern(
            chapterId: #"^systemes-lineaires$"#,
            question: #"syst[eè]me lin[ée]aire|pivot de Gauss"#
        ),
        ChapterTopicPattern(
            chapterId: #"^polynomes$"#,
            question: #"polyn[oô]me|racine de P"#
        ),
        ChapterTopicPattern(
            chapterId: #"^espaces-vectoriels$"#,
            question: #"espace vectoriel|sous-espace vectoriel|famille libre|famille g[ée]n[ée]ratrice|base de"#
        ),
        ChapterTopicPattern(
            chapterId: #"^applications-lineaires$"#,
            question: #"application lin[ée]aire|endomorphisme|noyau|Ker\("#
        ),
        ChapterTopicPattern(
            chapterId: #"^espaces-probabilises(?:-finis)?$"#,
            question: #"probabilit[ée] conditionnelle|probabilit[ée]s totales|[ée]v[ée]nements ind[ée]pendants"#
        ),
        ChapterTopicPattern(
            chapterId: #"^variables-discretes$"#,
            question: #"variable al[ée]atoire|loi (?:de )?(?:Bernoulli|binomiale|g[ée]om[ée]trique|Poisson)|esp[ée]rance|variance"#
        ),
        ChapterTopicPattern(
            chapterId: #"^valeurs-propres$"#,
            question: #"valeur propre|vecteur propre|sous-espace propre"#
        ),
        ChapterTopicPattern(
            chapterId: #"^diagonalisation$"#,
            question: #"diagonalis"#
        ),
        ChapterTopicPattern(
            chapterId: #"^variables-densite$"#,
            question: #"densit[ée]|loi normale|loi exponentielle|fonction de r[ée]partition"#
        ),
    ]
}
