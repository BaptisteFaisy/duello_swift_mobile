//
//  ProgPrereqEcgAdvanced+Annale.swift
//  Duello
//
//  Phase 1a — section extraite de `ProgPrereqEcgAdvanced.swift` : revue des
//  prérequis d'une annale ECG approfondies (`advancedAnnalePrerequisiteReview`),
//  ses tables (`ANNALE_TOPIC_PATTERNS`, `ANNALE_EDITORIAL_CHAPTERS`) et ses
//  helpers (`matchingAnnalePrerequisites`, `annaleCorePrerequisites`,
//  `normalizedAnnalePrerequisites`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `ANNALE_TOPIC_PATTERNS` : notion détectable dans l'énoncé d'une annale.
struct AnnaleTopicPattern {
    var chapter: String
    var statement: String
}

extension ProgPrereqEcgAdvanced {

    // MARK: - Revue d'annale

    /// `advancedAnnalePrerequisiteReview`.
    static func annaleReview(
        year: SubjProgramYear,
        annaleId: String,
        annaleSignature: String,
        prerequisites rawPrerequisites: [SubjChapterPrerequisite],
        questionIds: [String],
        questionPrompts: [String: String] = [:],
        annaleText: String = ""
    ) -> ProgPrereqReview {
        let prerequisites = annaleSubjectMatches(
            year: year,
            annaleId: annaleId,
            annaleText: annaleText,
            normalized: normalizedForAnnale(year: year, prerequisites: rawPrerequisites)
        )
        guard reviewedAdvancedBankSignatures["annale:\(annaleId)"] == annaleSignature else {
            return pendingReview(prerequisites: prerequisites)
        }
        let questionPrerequisites = questionIds.count >= 2
            ? annaleVentilation(
                prerequisites: prerequisites,
                questionIds: questionIds,
                questionPrompts: questionPrompts
            )
            : nil
        return reviewedReview(
            prerequisites: prerequisites,
            questionPrerequisites: questionPrerequisites,
            source: .editorial
        )
    }

    /// `normalizedPrerequisites` : normalisation, ou point d'entrée conservatoire
    /// (`raisonnement` en 1re année, `analyse-concours` en 2e) lorsque la source
    /// n'a fourni aucun prérequis.
    static func normalizedForAnnale(
        year: SubjProgramYear,
        prerequisites: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        guard prerequisites.isEmpty else { return normalizedAnnalePrerequisites(prerequisites) }
        return [
            SubjChapterPrerequisite(
                year: year,
                chapterId: year == .first ? "raisonnement" : "analyse-concours",
                requiredStatus: .completed,
                reason: "Point d'entrée conservatoire en attente de revue."
            ),
        ]
    }

    /// `subjectMatches` puis `prerequisites` de la source : appariement
    /// éditorial (`ANNALE_EDITORIAL_CHAPTERS`) sinon textuel (1re année).
    static func annaleSubjectMatches(
        year: SubjProgramYear,
        annaleId: String,
        annaleText: String,
        normalized: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        let subjectMatches: [SubjChapterPrerequisite]
        if let editorialChapterIds = annaleEditorialChapters[annaleId] {
            subjectMatches = normalized.filter { editorialChapterIds.contains($0.chapterId) }
        } else if year == .first {
            subjectMatches = matchingAnnalePrerequisites(text: annaleText, prerequisites: normalized)
        } else {
            subjectMatches = []
        }
        return subjectMatches.isEmpty ? normalized : subjectMatches
    }

    /// Ventilation par question d'une annale relue (extrait de `annaleReview`).
    static func annaleVentilation(
        prerequisites: [SubjChapterPrerequisite],
        questionIds: [String],
        questionPrompts: [String: String]
    ) -> [String: [SubjChapterPrerequisite]] {
        var previous: [SubjChapterPrerequisite]?
        let corePrerequisites = annaleCorePrerequisites(prerequisites)
        var byQuestion: [String: [SubjChapterPrerequisite]] = [:]
        for questionId in questionIds {
            let direct = matchingAnnalePrerequisites(
                text: questionPrompts[questionId] ?? "",
                prerequisites: prerequisites
            )
            let selected = uniquePrerequisites(
                corePrerequisites + (direct.isEmpty ? (previous ?? prerequisites) : direct)
            )
            previous = selected
            byQuestion[questionId] = selected
        }
        return byQuestion
    }

    // MARK: - Appariement d'annale

    /// `matchingAnnalePrerequisites`.
    static func matchingAnnalePrerequisites(
        text: String,
        prerequisites: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        prerequisites.filter { required in
            annaleTopicPatterns.contains { topic in
                matches(topic.chapter, required.chapterId, caseInsensitive: false)
                    && matches(topic.statement, text)
            }
        }
    }

    /// `annaleCorePrerequisites`.
    static func annaleCorePrerequisites(_ prerequisites: [SubjChapterPrerequisite]) -> [SubjChapterPrerequisite] {
        let chapterIds = Set(prerequisites.map { $0.chapterId })
        var coreIds = Set<String>()
        if chapterIds.contains("matrices") { coreIds.insert("matrices") }
        if chapterIds.contains("polynomes") && chapterIds.contains("matrices") { coreIds.insert("polynomes") }
        if chapterIds.contains("applications-lineaires") { coreIds.insert("applications-lineaires") }
        if chapterIds.contains("espaces-probabilises") {
            coreIds.insert("espaces-probabilises")
        } else if chapterIds.contains("espaces-probabilises-finis") {
            coreIds.insert("espaces-probabilises-finis")
        } else if chapterIds.contains("variables-discretes") {
            coreIds.insert("variables-discretes")
        }
        if chapterIds.contains("couples-discretes") { coreIds.insert("variables-discretes") }
        return prerequisites.filter { coreIds.contains($0.chapterId) }
    }

    /// `normalizedAnnalePrerequisites`.
    static func normalizedAnnalePrerequisites(_ prerequisites: [SubjChapterPrerequisite]) -> [SubjChapterPrerequisite] {
        prerequisites.map { required in
            SubjChapterPrerequisite(
                year: required.year,
                chapterId: required.chapterId,
                requiredStatus: required.requiredStatus ?? .completed,
                reason: required.reason ?? "Chapitre explicitement mobilisé par l'énoncé de l'annale."
            )
        }
    }

    // MARK: - Tables d'annale

    /// `ANNALE_TOPIC_PATTERNS` (35 entrées, ordre et motifs à l'identique).
    static let annaleTopicPatterns: [AnnaleTopicPattern] = [
        AnnaleTopicPattern(
            chapter: #"raisonnement$"#,
            statement: #"raisonnement|r[ée]currence|absurde|quantificateur"#
        ),
        AnnaleTopicPattern(
            chapter: #"ensembles-applications$"#,
            statement: #"injective|surjective|bijection|application (?:de|entre|f\s*:)|composition d.applications"#
        ),
        AnnaleTopicPattern(
            chapter: #"suites$"#,
            statement: #"(?:la|une|cette)\s+suite|u[_ₙn]|v[_ₙn]|r[ée]currence|monoton|suite extraite"#
        ),
        AnnaleTopicPattern(
            chapter: #"limites-continuite$"#,
            statement: #"continuit|limite de [fgh]|prolongement|bijection"#
        ),
        AnnaleTopicPattern(
            chapter: #"fonctions-usuelles$"#,
            statement: #"fonction usuelle|logarithme|exponentielle|trigonom"#
        ),
        AnnaleTopicPattern(
            chapter: #"derivation$"#,
            statement: #"d[ée]riv|convex|concav|tangente|accroissements finis"#
        ),
        AnnaleTopicPattern(
            chapter: #"integration$"#,
            statement: #"int[ée]grale|∫|\\int|somme de Riemann|int[ée]gration par parties"#
        ),
        AnnaleTopicPattern(
            chapter: #"analyse-asymptotique$"#,
            statement: #"[ée]quivalent|asymptotique|n[ée]gligeable"#
        ),
        AnnaleTopicPattern(
            chapter: #"series$"#,
            statement: #"s[ée]rie|somme partielle|∑|Σ|\\sum"#
        ),
        AnnaleTopicPattern(
            chapter: #"integrales-impropres$"#,
            statement: #"int[ée]grale impropre|convergence de l.int[ée]grale|∫[^\n]{0,40}(?:\+∞|−∞|-∞)|int[ée]grale[^\n]{0,60}(?:\+∞|−∞|-∞)|\\int[^\n]{0,60}\\infty"#
        ),
        AnnaleTopicPattern(
            chapter: #"taylor-developpements-limites$"#,
            statement: #"d[ée]veloppement limit[ée]|formule de Taylor"#
        ),
        AnnaleTopicPattern(
            chapter: #"derivation-successive$"#,
            statement: #"d[ée]riv[ée]e n-i[eè]me|d[ée]riv[ée]es successives"#
        ),
        AnnaleTopicPattern(
            chapter: #"^matrices$"#,
            statement: #"matrice|M[_ₙn]?\s*\(ℝ\)|\\mathcal\{M\}[^\n]{0,12}\\mathbb\{R\}|inversib"#
        ),
        AnnaleTopicPattern(
            chapter: #"systemes-lineaires$"#,
            statement: #"syst[eè]me lin[ée]aire|r[ée]soudre le syst[eè]me"#
        ),
        AnnaleTopicPattern(
            chapter: #"polynomes$"#,
            statement: #"polyn[oô]me|ℝ[_ₙn]?\[X\]|\\mathbb\{R\}[^\n]{0,10}\[X\]|racines? de P"#
        ),
        AnnaleTopicPattern(
            chapter: #"espaces-vectoriels$"#,
            statement: #"espace vectoriel|sous-espace|famille libre|une base|dimension"#
        ),
        AnnaleTopicPattern(
            chapter: #"applications-lineaires$"#,
            statement: #"application lin[ée]aire|endomorphisme|noyau|image|Ker\(|Im\("#
        ),
        AnnaleTopicPattern(
            chapter: #"matrices-applications-lineaires$"#,
            statement: #"matrice de l.application|matrice dans la base|matrice repr[ée]sentative"#
        ),
        AnnaleTopicPattern(
            chapter: #"espaces-probabilises-finis$"#,
            statement: #"univers fini|d[ée]nombrement|urne|tirage|lancer"#
        ),
        AnnaleTopicPattern(
            chapter: #"espaces-probabilises$"#,
            statement: #"probabilit[ée]|[ée]v[ée]nement|ind[ée]pendan|conditionnelle"#
        ),
        AnnaleTopicPattern(
            chapter: #"variables-discretes$"#,
            statement: #"variable al[ée]atoire discr[eè]te|loi (?:de )?(?:Bernoulli|binomiale|g[ée]om[ée]trique|Poisson)|esp[ée]rance|variance"#
        ),
        AnnaleTopicPattern(
            chapter: #"couples-discrets$"#,
            statement: #"couple.*variables al[ée]atoires|covariance|loi conjointe|loi marginale"#
        ),
        AnnaleTopicPattern(
            chapter: #"familles-sommables$"#,
            statement: #"famille sommable|sommabilit[ée]|somme double"#
        ),
        AnnaleTopicPattern(
            chapter: #"fonctions-plusieurs-variables$"#,
            statement: #"fonction de (?:deux|plusieurs) variables|couple \(x,\s*y\)"#
        ),
        AnnaleTopicPattern(
            chapter: #"calcul-differentiel$"#,
            statement: #"gradient|hessien|point critique|d[ée]riv[ée]e partielle"#
        ),
        AnnaleTopicPattern(
            chapter: #"changement-base-trace$"#,
            statement: #"changement de base|matrices semblables|trace"#
        ),
        AnnaleTopicPattern(
            chapter: #"valeurs-propres$"#,
            statement: #"valeur propre|vecteur propre|spectre|sous-espace propre"#
        ),
        AnnaleTopicPattern(
            chapter: #"diagonalisation$"#,
            statement: #"diagonalis|matrice diagonale"#
        ),
        AnnaleTopicPattern(
            chapter: #"algebre-bilineaire$"#,
            statement: #"produit scalaire|orthogon|forme bilin[ée]aire|norme euclidienne"#
        ),
        AnnaleTopicPattern(
            chapter: #"endomorphismes-symetriques$"#,
            statement: #"endomorphisme sym[ée]trique|matrice sym[ée]trique"#
        ),
        AnnaleTopicPattern(
            chapter: #"complements-variables-aleatoires$"#,
            statement: #"fonction g[ée]n[ée]ratrice|moment|variable al[ée]atoire"#
        ),
        AnnaleTopicPattern(
            chapter: #"variables-densite$"#,
            statement: #"densit[ée]|loi normale|loi exponentielle|fonction de r[ée]partition"#
        ),
        AnnaleTopicPattern(
            chapter: #"couples-vecteurs$"#,
            statement: #"vecteur al[ée]atoire|couple.*densit[ée]|densit[ée] conjointe|covariance"#
        ),
        AnnaleTopicPattern(
            chapter: #"convergences$"#,
            statement: #"convergence en (?:loi|probabilit[ée])|loi faible|th[ée]or[eè]me central"#
        ),
        AnnaleTopicPattern(
            chapter: #"estimation-ponctuelle$"#,
            statement: #"estimateur|estimation|biais|risque quadratique"#
        ),
    ]

    /// `ANNALE_EDITORIAL_CHAPTERS` (42 entrées, recopiées à l'identique).
    static let annaleEditorialChapters: [String: [String]] = [
        "escp-oral-2023-sujet-1-2": ["polynomes", "matrices"],
        "escp-oral-2023-sujet-1-11": ["matrices", "suites", "series"],
        "escp-oral-2023-sujet-1-17": ["suites", "derivation", "polynomes"],
        "escp-oral-2023-sujet-1-18": ["polynomes", "espaces-vectoriels", "applications-lineaires", "matrices-applications-lineaires"],
        "escp-oral-2023-sujet-2-1": ["suites", "limites-continuite", "integration", "integrales-impropres"],
        "escp-oral-2023-sujet-2-4": ["suites", "integration", "series"],
        "escp-oral-2023-sujet-2-6": ["suites", "integration", "series"],
        "escp-oral-2023-sujet-2-7": ["suites", "integration", "series"],
        "escp-oral-2023-sujet-2-8": ["suites", "derivation", "integration", "integrales-impropres", "analyse-asymptotique"],
        "escp-oral-2023-sujet-2-9": ["suites", "integration", "integrales-impropres", "series"],
        "escp-oral-2023-sujet-2-11": ["suites", "integration", "series"],
        "escp-oral-2023-sujet-2-12": ["raisonnement", "suites", "series"],
        "escp-oral-2023-sujet-3-3": ["suites", "series", "variables-discretes"],
        "escp-oral-2023-sujet-3-12": ["espaces-probabilises-finis", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2022-sujet-1-7": ["applications-lineaires", "matrices-applications-lineaires", "matrices"],
        "escp-oral-2022-sujet-1-55": ["suites", "polynomes", "espaces-vectoriels"],
        "escp-oral-2022-sujet-3-9": ["series", "espaces-probabilises-finis", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2022-sujet-3-10": ["suites", "analyse-asymptotique", "series", "espaces-probabilises-finis", "espaces-probabilises"],
        "escp-oral-2022-sujet-3-17": ["suites", "analyse-asymptotique", "series", "variables-discretes", "couples-discrets"],
        "escp-oral-2022-sujet-3-19": ["suites", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2022-sujet-3-25": ["espaces-probabilises", "variables-discretes"],
        "escp-oral-2022-sujet-3-53": ["suites", "series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2022-sujet-3-59": ["fonctions-usuelles", "derivation", "variables-discretes"],
        "escp-oral-2022-sujet-3-61": ["suites", "series", "taylor-developpements-limites", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2021-sujet-3-9": ["suites", "analyse-asymptotique", "series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2021-sujet-3-13": ["suites", "series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2021-sujet-3-16": ["suites", "series", "espaces-probabilises-finis", "espaces-probabilises"],
        "escp-oral-2021-sujet-3-18": ["suites", "series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2021-sujet-3-19": ["suites", "series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2019-sujet-3-2": ["series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2019-sujet-3-3": ["suites", "polynomes", "variables-discretes", "couples-discrets"],
        "escp-oral-2019-sujet-3-18": ["suites", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2019-sujet-3-19": ["suites", "espaces-probabilises-finis", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2019-sujet-3-21": ["suites", "derivation", "series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2018-sujet-2-2": ["suites", "matrices"],
        "escp-oral-2018-sujet-2-7": ["suites", "matrices"],
        "escp-oral-2018-sujet-3-2": ["suites", "series", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2018-sujet-3-10": ["suites", "integration", "integrales-impropres", "variables-discretes"],
        "escp-oral-2018-sujet-3-11": ["suites", "series", "espaces-probabilises-finis", "variables-discretes"],
        "escp-oral-2018-sujet-3-13": ["suites", "espaces-probabilises-finis", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2018-sujet-3-16": ["suites", "espaces-probabilises", "variables-discretes"],
        "escp-oral-2018-sujet-3-17": ["suites", "series", "espaces-probabilises", "variables-discretes"],
    ]
}
