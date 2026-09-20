//
//  MathKeyboardView.swift
//  Duello
//
//  Clavier mathématique (barre de symboles + outils guidés), porté depuis
//  l'application Expo / React Native « Duello ».
//
//  Fichiers source portés :
//  - `expo_ref/src/components/MathKeyboard.tsx` — composant `MathKeyboard`,
//    touche `MathKey`, bornes infinies `InfiniteBoundKeys`, éditeurs guidés
//    (matrice, opérateur, intervalle), bandeau d'onglets, rangée d'actions
//    espace / retour / effacer ;
//  - `expo_ref/src/utils/mathKeySections.ts` — `MATH_SECTIONS`,
//    `MATH_KEYBOARD_SECTIONS`, `PYTHON_SECTIONS`, `SUBSCRIPT_SECTIONS` ;
//  - `expo_ref/src/utils/mathKeyboardLayout.ts` — `PYTHON_KEYBOARD_KEYS` ;
//  - `expo_ref/src/utils/mathOperator.ts` — `MATH_OPERATOR_DEFINITIONS`,
//    `INFINITE_BOUNDS`, `formatMathOperator`, `isMathOperatorComplete` ;
//  - `expo_ref/src/utils/mathInterval.ts` — `intervalBrackets`,
//    `formatInterval`, `isInfiniteBound` ;
//  - `expo_ref/src/utils/mathMatrix.ts` — `formatMatrix`, `matrixSides` ;
//  - `expo_ref/src/utils/mathLayout.ts` — `SUPERSCRIPTS`, `SUBSCRIPTS`,
//    `toScript`.
//
//  Spécification de portage : `mk_spec_logic.md` (racine du workspace).
//
//  Notes de portage
//  ----------------
//  - Le clavier insère de l'**Unicode** natif (`∑`, `∫`, `ₙ`, `²`…) et ne
//    convertit aucun LaTeX : comme dans la source, il n'appelle jamais
//    `LatexToUnicode` (voir `mk_spec_logic.md` §3.1).
//  - Le clavier ne se positionne pas lui-même : pas d'`absolute`, pas d'insets,
//    pas de `KeyboardAvoidingView` interne. C'est l'écran parent qui décide du
//    placement (les trois schémas sont décrits au §1.4 de la spécification).
//  - La signature d'intégration `init(mode:onInsert:onBackspace:onClose:)` ne
//    transporte que le texte : les touches qui reculent le curseur après
//    insertion (`back`, ex. `()`, `{}`, `√()`) perdent ce recul. La variante
//    `init(mode:onInsertWithBack:onBackspace:onClose:)` le transmet.
//  - Sans `value` / `selection` dans le contrat d'intégration, l'édition d'une
//    construction **déjà écrite** dans la réponse (parsing inverse
//    `findMatrixAtSelection` / `findMathOperatorAtSelection`, raccourci
//    « Modifier … ») n'est pas portée : les outils guidés composent une
//    construction neuve.
//  - SwiftUI iOS 16 n'expose pas la sélection d'un `TextField`. Là où la source
//    suivait un curseur par champ (`CaretText` : `insertAtCaret` /
//    `deleteAtCaret`, §2.1), les touches maths **s'ajoutent en fin** du champ
//    actif et l'effacement retire son dernier caractère. Les chevrons et la
//    touche retour déplacent le champ actif, pas le curseur.
//  - La rangée de suggestions « propres à l'exercice » (`suggestions` /
//    `pinnedKeys`) n'est pas portée : elle dépend d'une donnée que le contrat
//    d'intégration ne transporte pas.
//

import SwiftUI

// MARK: - Mode de saisie

/// Mode du clavier, repris de `ExerciseAnswerInputMode` côté Expo (`'math'` /
/// `'python'`). `text` privilégie les raccourcis de code (onglet « Python »
/// en tête) ; `math` ouvre sur « Base ».
enum MathKbMode: Hashable {
    case math
    case text
}

// MARK: - Outils guidés

/// Outil ouvert par une touche au lieu d'une insertion : les trois
/// constructions guidées (`'matrix'`, `'interval'`) et les opérateurs
/// mathématiques (`MathOperatorKind`). Cf. `MathKeyAction` de la source.
enum MathKbAction: Hashable {
    case matrix
    case interval
    case exponent
    case limit
    case integral
    case sum
    case product
}

/// Les cinq opérateurs à champs de `mathOperator.ts`.
enum MathKbOperatorKind: String, CaseIterable, Hashable {
    case exponent
    case limit
    case integral
    case sum
    case product

    /// L'outil correspondant, pour `MathKbKey.action`.
    var action: MathKbAction {
        switch self {
        case .exponent: return .exponent
        case .limit: return .limit
        case .integral: return .integral
        case .sum: return .sum
        case .product: return .product
        }
    }
}

// MARK: - Définition d'une touche

/// Une touche du clavier — `MathKey` de `utils/mathKeySections.ts`.
struct MathKbKey: Identifiable, Hashable {
    /// Libellé affiché sur la touche.
    let label: String
    /// Texte inséré s'il diffère du libellé.
    var insert: String? = nil
    /// Recul du curseur après insertion, pour se placer entre les délimiteurs.
    var back: Int = 0
    /// Touche à libellé long : elle occupe plus de largeur.
    var wide: Bool = false
    /// Ouvre un outil du clavier au lieu d'insérer le libellé.
    var action: MathKbAction? = nil

    /// Libellé unique dans une section : sert d'identité à la liste.
    var id: String { label }

    /// Texte réellement inséré quand la touche n'ouvre pas d'outil.
    var text: String { insert ?? label }
}

/// Un onglet du clavier et ses touches — `MathSection` de la source.
struct MathKbSection: Identifiable, Hashable {
    let id: String
    let label: String
    let keys: [MathKbKey]
}

// MARK: - Dispositions de touches

/// Données du clavier : sections mathématiques, raccourcis Python et
/// constantes de comportement. Portées telles quelles depuis
/// `utils/mathKeySections.ts` et `utils/mathKeyboardLayout.ts`.
enum MathKbLayout {

    /// Nombre minimal et maximal de lignes / colonnes de l'éditeur de matrice
    /// (`MATRIX_MIN_SIZE`, `MATRIX_MAX_SIZE`).
    static let matrixMinSize = 1
    static let matrixMaxSize = 4

    /// Bornes infinies proposées par les champs qui les acceptent
    /// (`INFINITE_BOUNDS`) : le moins précède le plus.
    static let infiniteBounds = ["−∞", "+∞"]

    /// Sections dont les caractères ont une forme basse en Unicode : ailleurs,
    /// le mode indice n'aurait rien à abaisser (`SUBSCRIPT_SECTIONS`).
    static let subscriptSectionId = "base"

    /// Sections du mode mathématique, dans l'ordre de la source.
    static let mathSections: [MathKbSection] = [
        baseSection,
        analyseSection,
        ensemblesSection,
        probasSection,
        logiqueSection,
        algebreSection,
        grecSection,
    ]

    /// Onglet des raccourcis de code (`PYTHON_SECTION`).
    static let pythonSection = MathKbSection(
        id: "python",
        label: "Python",
        keys: pythonKeys
    )

    /// `MATH_KEYBOARD_SECTIONS` : le clavier maths, Python en dernier.
    static let mathKeyboardSections: [MathKbSection] = mathSections + [pythonSection]

    /// `PYTHON_SECTIONS` : le même clavier dans un exercice Python, ses
    /// raccourcis prioritaires en tête.
    static let pythonSections: [MathKbSection] = [pythonSection] + mathSections

    /// Les onglets disponibles pour un mode donné.
    static func sections(for mode: MathKbMode) -> [MathKbSection] {
        mode == .text ? pythonSections : mathKeyboardSections
    }

    /// Section d'ouverture du clavier (`mode === 'python' ? 'python' : 'base'`).
    static func initialSectionId(for mode: MathKbMode) -> String {
        mode == .text ? pythonSection.id : baseSection.id
    }

    // MARK: Sections mathématiques

    private static let baseSection = MathKbSection(
        id: "base",
        label: "Base",
        keys: [
            MathKbKey(label: "+"),
            MathKbKey(label: "−"),
            MathKbKey(label: "×"),
            MathKbKey(label: "÷"),
            MathKbKey(label: "±"),
            MathKbKey(label: "·"),
            MathKbKey(label: "="),
            MathKbKey(label: "≠"),
            MathKbKey(label: "≈"),
            MathKbKey(label: "≤"),
            MathKbKey(label: "≥"),
            MathKbKey(label: "<"),
            MathKbKey(label: ">"),
            MathKbKey(label: "%"),
            MathKbKey(label: "π"),
            MathKbKey(label: "( )", insert: "()", back: 1),
            MathKbKey(label: "[ ]", insert: "[]", back: 1),
            MathKbKey(label: "{ }", insert: "{}", back: 1),
            MathKbKey(label: "| |", insert: "||", back: 1),
            MathKbKey(label: "√", insert: "√()", back: 1),
            MathKbKey(label: "x²", insert: "²"),
            MathKbKey(label: "x³", insert: "³"),
            operatorKey(.exponent),
            MathKbKey(label: "x⁻¹", insert: "⁻¹"),
            MathKbKey(label: "^"),
            MathKbKey(label: "_"),
            MathKbKey(label: "uₙ", insert: "ₙ"),
            MathKbKey(label: "uₙ₊₁", insert: "ₙ₊₁", wide: true),
            MathKbKey(label: "uₙ₋₁", insert: "ₙ₋₁", wide: true),
            MathKbKey(label: "aₖ", insert: "ₖ"),
            MathKbKey(label: "a₀", insert: "₀"),
            MathKbKey(label: "a₁", insert: "₁"),
        ]
    )

    private static let analyseSection = MathKbSection(
        id: "analyse",
        label: "Analyse",
        keys: [
            operatorKey(.limit),
            MathKbKey(label: "→"),
            MathKbKey(label: "↦"),
            MathKbKey(label: "f : x ↦", insert: "f : x ↦ ", wide: true),
            MathKbKey(label: "+∞", wide: true),
            MathKbKey(label: "−∞", wide: true),
            operatorKey(.integral),
            operatorKey(.sum),
            operatorKey(.product),
            MathKbKey(label: "∂"),
            MathKbKey(label: "∇"),
            MathKbKey(label: "f′", insert: "′"),
            MathKbKey(label: "dx", wide: true),
            MathKbKey(label: "dt", wide: true),
            MathKbKey(label: "ln", wide: true),
            MathKbKey(label: "exp", wide: true),
            MathKbKey(label: "cos", wide: true),
            MathKbKey(label: "sin", wide: true),
            MathKbKey(label: "tan", wide: true),
            MathKbKey(label: "O( )", insert: "O()", back: 1, wide: true),
            MathKbKey(label: "o( )", insert: "o()", back: 1, wide: true),
            MathKbKey(label: "∼"),
            MathKbKey(label: "≡"),
            MathKbKey(label: "ε"),
            MathKbKey(label: "δ"),
        ]
    )

    private static let ensemblesSection = MathKbSection(
        id: "ensembles",
        label: "Ensembles",
        keys: [
            MathKbKey(label: "Intervalle", wide: true, action: .interval),
            MathKbKey(label: "∈"),
            MathKbKey(label: "∉"),
            MathKbKey(label: "⊂"),
            MathKbKey(label: "⊄"),
            MathKbKey(label: "⊆"),
            MathKbKey(label: "∪"),
            MathKbKey(label: "∩"),
            MathKbKey(label: "⋃"),
            MathKbKey(label: "⋂"),
            MathKbKey(label: "∖"),
            MathKbKey(label: "∅"),
            MathKbKey(label: "×"),
            MathKbKey(label: "ℕ"),
            MathKbKey(label: "ℤ"),
            MathKbKey(label: "ℚ"),
            MathKbKey(label: "ℝ"),
            MathKbKey(label: "ℂ"),
            MathKbKey(label: "ℕ*"),
            MathKbKey(label: "ℤ*"),
            MathKbKey(label: "ℚ*"),
            MathKbKey(label: "ℝ*"),
            MathKbKey(label: "ℂ*"),
            MathKbKey(label: "ℝ₊"),
            MathKbKey(label: "ℝ₋"),
            MathKbKey(label: "ℝ₊*", wide: true),
            MathKbKey(label: "ℝ₋*", wide: true),
            MathKbKey(label: "card", wide: true),
            MathKbKey(label: "sup", wide: true),
            MathKbKey(label: "inf", wide: true),
            MathKbKey(label: "max", wide: true),
            MathKbKey(label: "min", wide: true),
        ]
    )

    private static let probasSection = MathKbSection(
        id: "probas",
        label: "Probas",
        keys: [
            MathKbKey(label: "ℙ"),
            MathKbKey(label: "𝔼"),
            MathKbKey(label: "𝕍"),
            MathKbKey(label: "σ"),
            MathKbKey(label: "Ω"),
            MathKbKey(label: "P(A)", insert: "ℙ()", back: 1, wide: true),
            MathKbKey(label: "P(A|B)", insert: "ℙ(|)", back: 2, wide: true),
            MathKbKey(label: "𝔼(X)", insert: "𝔼()", back: 1, wide: true),
            MathKbKey(label: "𝕍(X)", insert: "𝕍()", back: 1, wide: true),
            MathKbKey(label: "Cov", wide: true),
            MathKbKey(label: "↪→", insert: " ↪→ ", wide: true),
            MathKbKey(label: "Xₙ", insert: "ₙ"),
            MathKbKey(label: "Xᵢ", insert: "ᵢ"),
            MathKbKey(label: "p.s.", insert: " presque sûrement ", wide: true),
        ]
    )

    private static let logiqueSection = MathKbSection(
        id: "logique",
        label: "Logique",
        keys: [
            MathKbKey(label: "∀"),
            MathKbKey(label: "∃"),
            MathKbKey(label: "∄"),
            MathKbKey(label: "⇒"),
            MathKbKey(label: "⇐"),
            MathKbKey(label: "⇔"),
            MathKbKey(label: "¬"),
            MathKbKey(label: "∧"),
            MathKbKey(label: "∨"),
            MathKbKey(label: "≜"),
            MathKbKey(label: "⊥"),
            MathKbKey(label: "∴"),
            MathKbKey(label: "tq", insert: " tel que ", wide: true),
            MathKbKey(label: "ssi", insert: " si et seulement si ", wide: true),
            MathKbKey(label: "donc", insert: " donc ", wide: true),
            MathKbKey(label: "car", insert: " car ", wide: true),
            MathKbKey(label: "d’où", insert: " d’où ", wide: true),
            MathKbKey(label: "Soit", insert: "Soit ", wide: true),
            MathKbKey(label: "Conclusion", insert: "Conclusion : ", wide: true),
        ]
    )

    private static let algebreSection = MathKbSection(
        id: "algebre",
        label: "Algèbre",
        keys: [
            MathKbKey(label: "Matrice", wide: true, action: .matrix),
            MathKbKey(label: "⟨ ⟩", insert: "⟨⟩", back: 1),
            MathKbKey(label: "‖ ‖", insert: "‖‖", back: 1),
            MathKbKey(label: "⌊ ⌋", insert: "⌊⌋", back: 1),
            MathKbKey(label: "⌈ ⌉", insert: "⌈⌉", back: 1),
            MathKbKey(label: "Mᵀ", insert: "ᵀ"),
            MathKbKey(label: "M⁻¹", insert: "⁻¹"),
            MathKbKey(label: "∘"),
            MathKbKey(label: "⊕"),
            MathKbKey(label: "⊗"),
            MathKbKey(label: "≅"),
            MathKbKey(label: "det", wide: true),
            MathKbKey(label: "tr", wide: true),
            MathKbKey(label: "rg", wide: true),
            MathKbKey(label: "ker", wide: true),
            MathKbKey(label: "Im", wide: true),
            MathKbKey(label: "dim", wide: true),
            MathKbKey(label: "Vect", wide: true),
        ]
    )

    private static let grecSection = MathKbSection(
        id: "grec",
        label: "Grec",
        keys: [
            MathKbKey(label: "α"),
            MathKbKey(label: "β"),
            MathKbKey(label: "γ"),
            MathKbKey(label: "δ"),
            MathKbKey(label: "ε"),
            MathKbKey(label: "ζ"),
            MathKbKey(label: "η"),
            MathKbKey(label: "θ"),
            MathKbKey(label: "κ"),
            MathKbKey(label: "λ"),
            MathKbKey(label: "μ"),
            MathKbKey(label: "ν"),
            MathKbKey(label: "ξ"),
            MathKbKey(label: "ρ"),
            MathKbKey(label: "σ"),
            MathKbKey(label: "τ"),
            MathKbKey(label: "φ"),
            MathKbKey(label: "χ"),
            MathKbKey(label: "ψ"),
            MathKbKey(label: "ω"),
            MathKbKey(label: "Γ"),
            MathKbKey(label: "Δ"),
            MathKbKey(label: "Θ"),
            MathKbKey(label: "Λ"),
            MathKbKey(label: "Ξ"),
            MathKbKey(label: "Π"),
            MathKbKey(label: "Σ"),
            MathKbKey(label: "Φ"),
            MathKbKey(label: "Ψ"),
            MathKbKey(label: "Ω"),
        ]
    )

    // MARK: Raccourcis Python (`PYTHON_KEYBOARD_KEYS`)

    private static let pythonKeys: [MathKbKey] = [
        MathKbKey(label: "Tab", insert: "    ", wide: true),
        MathKbKey(label: "( )", insert: "()", back: 1),
        MathKbKey(label: "[ ]", insert: "[]", back: 1),
        MathKbKey(label: "{ }", insert: "{}", back: 1),
        MathKbKey(label: "“ ”", insert: "\"\"", back: 1),
        MathKbKey(label: "‘ ’", insert: "''", back: 1),
        MathKbKey(label: ":"),
        MathKbKey(label: "_"),
        MathKbKey(label: "#"),
        MathKbKey(label: ","),
        MathKbKey(label: "."),
        MathKbKey(label: "="),
        MathKbKey(label: "=="),
        MathKbKey(label: "!="),
        MathKbKey(label: "<"),
        MathKbKey(label: "<="),
        MathKbKey(label: ">"),
        MathKbKey(label: ">="),
        MathKbKey(label: "+"),
        MathKbKey(label: "-"),
        MathKbKey(label: "*"),
        MathKbKey(label: "/"),
        MathKbKey(label: "//"),
        MathKbKey(label: "%"),
        MathKbKey(label: "**"),
        MathKbKey(label: "def", insert: "def ", wide: true),
        MathKbKey(label: "return", insert: "return ", wide: true),
        MathKbKey(label: "if", insert: "if ", wide: true),
        MathKbKey(label: "elif", insert: "elif ", wide: true),
        MathKbKey(label: "else", insert: "else:", wide: true),
        MathKbKey(label: "for", insert: "for ", wide: true),
        MathKbKey(label: "while", insert: "while ", wide: true),
        MathKbKey(label: "in", insert: " in ", wide: true),
        MathKbKey(label: "range", insert: "range()", back: 1, wide: true),
        MathKbKey(label: "len", insert: "len()", back: 1, wide: true),
        MathKbKey(label: "import", insert: "import ", wide: true),
        MathKbKey(label: "from", insert: "from ", wide: true),
        MathKbKey(label: "as", insert: " as ", wide: true),
        MathKbKey(label: "numpy as np", wide: true),
        MathKbKey(label: "numpy.random as rd", wide: true),
        MathKbKey(label: "matplotlib.pyplot as plt", wide: true),
        MathKbKey(label: "scipy.special as sp", wide: true),
        MathKbKey(label: "True", wide: true),
        MathKbKey(label: "False", wide: true),
        MathKbKey(label: "None", wide: true),
        MathKbKey(label: "print", insert: "print()", back: 1, wide: true),
        MathKbKey(label: "append", insert: ".append()", back: 1, wide: true),
        MathKbKey(label: "np.array", insert: "np.array()", back: 1, wide: true),
        MathKbKey(label: "np.arange", insert: "np.arange()", back: 1, wide: true),
        MathKbKey(label: "np.linspace", insert: "np.linspace()", back: 1, wide: true),
        MathKbKey(label: "np.zeros", insert: "np.zeros()", back: 1, wide: true),
        MathKbKey(label: "np.ones", insert: "np.ones()", back: 1, wide: true),
        MathKbKey(label: "np.mean", insert: "np.mean()", back: 1, wide: true),
        MathKbKey(label: "np.sum", insert: "np.sum()", back: 1, wide: true),
        MathKbKey(label: "np.min", insert: "np.min()", back: 1, wide: true),
        MathKbKey(label: "np.max", insert: "np.max()", back: 1, wide: true),
        MathKbKey(label: "np.sort", insert: "np.sort()", back: 1, wide: true),
        MathKbKey(label: "np.cumsum", insert: "np.cumsum()", back: 1, wide: true),
        MathKbKey(label: "np.cumprod", insert: "np.cumprod()", back: 1, wide: true),
        MathKbKey(label: "np.dot", insert: "np.dot()", back: 1, wide: true),
        MathKbKey(label: "np.transpose", insert: "np.transpose()", back: 1, wide: true),
        MathKbKey(label: "rd.random", insert: "rd.random()", back: 1, wide: true),
        MathKbKey(label: "rd.randint", insert: "rd.randint()", back: 1, wide: true),
        MathKbKey(label: "rd.binomial", insert: "rd.binomial()", back: 1, wide: true),
        MathKbKey(label: "rd.geometric", insert: "rd.geometric()", back: 1, wide: true),
        MathKbKey(label: "rd.poisson", insert: "rd.poisson()", back: 1, wide: true),
        MathKbKey(label: "rd.normal", insert: "rd.normal()", back: 1, wide: true),
        MathKbKey(label: "rd.exponential", insert: "rd.exponential()", back: 1, wide: true),
        MathKbKey(label: "plt.plot", insert: "plt.plot()", back: 1, wide: true),
        MathKbKey(label: "plt.show", insert: "plt.show()", back: 1, wide: true),
        MathKbKey(label: "plt.hist", insert: "plt.hist()", back: 1, wide: true),
        MathKbKey(label: "plt.bar", insert: "plt.bar()", back: 1, wide: true),
        MathKbKey(label: "plt.step", insert: "plt.step()", back: 1, wide: true),
        MathKbKey(label: "sp.ndtr", insert: "sp.ndtr()", back: 1, wide: true),
        MathKbKey(label: "sp.ndtri", insert: "sp.ndtri()", back: 1, wide: true),
        MathKbKey(label: "np.", wide: true),
    ]

    /// Touche d'ouverture d'un opérateur guidé : libellé court de sa définition,
    /// large, et sans insertion propre (`operatorKey` de la source).
    private static func operatorKey(_ kind: MathKbOperatorKind) -> MathKbKey {
        MathKbKey(
            label: MathKbOperatorCatalog.definition(for: kind).keyLabel,
            wide: true,
            action: kind.action
        )
    }
}

// MARK: - Écriture en exposant / en indice

/// Tables et rendu des scripts Unicode (`SUPERSCRIPTS`, `SUBSCRIPTS`,
/// `toScript` de `utils/mathLayout.ts`).
enum MathKbScript {

    static let superscripts: [Character: String] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ",
        "j": "ʲ", "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ", "r": "ʳ", "s": "ˢ",
        "t": "ᵗ", "u": "ᵘ", "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
        "T": "ᵀ", "N": "ᴺ",
    ]

    static let subscripts: [Character: String] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "−": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ",
        "n": "ₙ", "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
    ]

    /// Un exposant tient en quelques caractères ; au-delà, c'est de la prose.
    private static let maxScriptLength = 4

    /// Rend la mise en Unicode, ou `nil` si un seul caractère résiste ou si le
    /// texte dépasse `maxScriptLength` (`toScript`).
    static func toScript(_ text: String, _ table: [Character: String]) -> String? {
        guard !text.isEmpty, text.count <= maxScriptLength else { return nil }
        return render(text, table)
    }

    /// Même rendu, sans limite de longueur : c'est celui des bornes
    /// d'opérateur (`enScript` de `mathOperator.ts`).
    static func toScriptUnbounded(_ text: String, _ table: [Character: String]) -> String? {
        guard !text.isEmpty else { return nil }
        return render(text, table)
    }

    private static func render(_ text: String, _ table: [Character: String]) -> String? {
        var rendu = ""
        for caractere in text {
            guard let equivalent = table[caractere] else { return nil }
            rendu += equivalent
        }
        return rendu.isEmpty ? nil : rendu
    }
}

// MARK: - Opérateurs guidés

/// Un champ obligatoire d'un opérateur guidé (`MathOperatorFieldDefinition`).
struct MathKbOperatorField {
    let id: String
    let label: String
    let placeholder: String
    /// Borne qui peut être infinie : l'éditeur pose alors `−∞` / `+∞` sur place.
    let infinite: Bool
}

/// La définition complète d'un opérateur guidé (`MathOperatorDefinition`).
struct MathKbOperatorDefinition {
    let kind: MathKbOperatorKind
    let keyLabel: String
    let title: String
    let hint: String
    let fields: [MathKbOperatorField]
}

/// Définitions, complétude et rendu Unicode des opérateurs guidés.
enum MathKbOperatorCatalog {

    static func definition(for kind: MathKbOperatorKind) -> MathKbOperatorDefinition {
        switch kind {
        case .exponent:
            return MathKbOperatorDefinition(
                kind: .exponent,
                keyLabel: "x^…",
                title: "Exposant libre",
                hint: "Écris d’abord la base, puis renseigne ici son exposant.",
                fields: [
                    MathKbOperatorField(id: "exponent", label: "Exposant", placeholder: "n+1", infinite: false),
                ]
            )
        case .limit:
            return MathKbOperatorDefinition(
                kind: .limit,
                keyLabel: "lim x→a",
                title: "Limite",
                hint: "Renseigne la variable et la valeur vers laquelle elle tend.",
                fields: [
                    MathKbOperatorField(id: "variable", label: "Variable", placeholder: "x", infinite: false),
                    MathKbOperatorField(id: "target", label: "Tend vers", placeholder: "+∞", infinite: true),
                ]
            )
        case .integral:
            return MathKbOperatorDefinition(
                kind: .integral,
                keyLabel: "∫ₐᵇ",
                title: "Intégrale bornée",
                hint: "Renseigne les deux bornes avant de saisir l’intégrande.",
                fields: [
                    MathKbOperatorField(id: "lower", label: "Borne basse", placeholder: "0", infinite: true),
                    MathKbOperatorField(id: "upper", label: "Borne haute", placeholder: "1", infinite: true),
                ]
            )
        case .sum:
            return MathKbOperatorDefinition(
                kind: .sum,
                keyLabel: "∑ₖ₌ₐᵇ",
                title: "Somme",
                hint: "Renseigne l’indice, sa valeur de départ et la borne supérieure.",
                fields: [
                    MathKbOperatorField(id: "index", label: "Indice", placeholder: "k", infinite: false),
                    MathKbOperatorField(id: "lower", label: "Départ", placeholder: "1", infinite: true),
                    MathKbOperatorField(id: "upper", label: "Arrivée", placeholder: "n", infinite: true),
                ]
            )
        case .product:
            return MathKbOperatorDefinition(
                kind: .product,
                keyLabel: "∏ₖ₌ₐᵇ",
                title: "Produit",
                hint: "Renseigne l’indice, sa valeur de départ et la borne supérieure.",
                fields: [
                    MathKbOperatorField(id: "index", label: "Indice", placeholder: "k", infinite: false),
                    MathKbOperatorField(id: "lower", label: "Départ", placeholder: "1", infinite: true),
                    MathKbOperatorField(id: "upper", label: "Arrivée", placeholder: "n", infinite: true),
                ]
            )
        }
    }

    /// Tous les champs obligatoires sont remplis (`isMathOperatorComplete`).
    static func isComplete(kind: MathKbOperatorKind, values: [String: String]) -> Bool {
        definition(for: kind).fields.allSatisfy { field in
            !normalized(values[field.id]).isEmpty
        }
    }

    /// Rendu Unicode de l'opérateur, ou `nil` tant qu'un champ manque
    /// (`formatMathOperator`). Les bornes simples utilisent les vrais exposants
    /// et indices (`∑ₖ₌₁ⁿ`) ; lorsqu'Unicode ne sait pas représenter un
    /// caractère, la notation explicite reste non ambiguë (`∫_(-∞)^(+∞)`).
    static func format(kind: MathKbOperatorKind, values: [String: String]) -> String? {
        guard isComplete(kind: kind, values: values) else { return nil }

        if kind == .exponent {
            let exponent = compact(values["exponent"])
            return MathKbScript.toScriptUnbounded(exponent, MathKbScript.superscripts)
                ?? "^(\(exponent))"
        }

        if kind == .limit {
            let variable = compact(values["variable"])
            let target = compact(values["target"])
            return "lim_(\(variable)→\(target)) "
        }

        let lower: String
        if kind == .sum || kind == .product {
            lower = "\(compact(values["index"]))=\(compact(values["lower"]))"
        } else {
            lower = compact(values["lower"])
        }
        let symbol: String
        switch kind {
        case .sum: symbol = "∑"
        case .product: symbol = "∏"
        default: symbol = "∫"
        }
        let borneBasse = scriptedBound(lower, marker: "_", table: MathKbScript.subscripts)
        let borneHaute = scriptedBound(values["upper"], marker: "^", table: MathKbScript.superscripts)
        return "\(symbol)\(borneBasse)\(borneHaute) "
    }

    /// Aperçu affiché dans l'éditeur : la forme insérée dès que l'opérateur est
    /// complet, sinon son libellé de touche (`mathOperatorPreview`).
    static func preview(kind: MathKbOperatorKind, values: [String: String]) -> String {
        guard let formatted = format(kind: kind, values: values) else {
            return definition(for: kind).keyLabel
        }
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        return kind == .exponent ? "x\(trimmed)" : trimmed
    }

    /// Une borne : les vrais caractères Unicode si tous existent, sinon la
    /// notation explicite `_(…)` / `^(…)` (`borne` de `mathOperator.ts`).
    private static func scriptedBound(
        _ value: String?,
        marker: String,
        table: [Character: String]
    ) -> String {
        let compacted = compact(value)
        return MathKbScript.toScriptUnbounded(compacted, table) ?? "\(marker)(\(compacted))"
    }

    /// Espaces multiples repliés en une espace, extrémités retirées
    /// (`valeurPropre`).
    private static func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Forme sans aucun blanc (`valeurCompacte`).
    private static func compact(_ value: String?) -> String {
        normalized(value).filter { !$0.isWhitespace }
    }
}

// MARK: - Intervalles

/// Nature de l'intervalle : crochets simples pour les réels, doubles pour les
/// entiers (`IntervalKind`).
enum MathKbIntervalKind: String, CaseIterable, Hashable {
    case real
    case integer

    var label: String {
        switch self {
        case .real: return "Réels"
        case .integer: return "Entiers"
        }
    }
}

/// Un intervalle prêt à être rendu (`MathInterval` de `utils/mathInterval.ts`).
struct MathKbInterval {
    var kind: MathKbIntervalKind = .real
    var lower: String = ""
    var upper: String = ""
    var lowerClosed: Bool = true
    var upperClosed: Bool = true

    /// Une borne infinie n'est jamais atteinte (`isInfiniteBound`).
    static func isInfinite(_ value: String) -> Bool {
        value.contains("∞")
    }

    /// Crochets effectivement écrits de chaque côté (`intervalBrackets`) :
    /// une borne infinie ouvre son crochet quoi qu'ait choisi l'élève.
    var brackets: (lower: String, upper: String) {
        let lowerClosed = self.lowerClosed && !Self.isInfinite(lower)
        let upperClosed = self.upperClosed && !Self.isInfinite(upper)
        switch kind {
        case .real:
            return (lowerClosed ? "[" : "]", upperClosed ? "]" : "[")
        case .integer:
            return (lowerClosed ? "⟦" : "⟧", upperClosed ? "⟧" : "⟦")
        }
    }

    /// `[0, 1]`, `]−∞, 0]`, `⟦1, n⟧`… (`formatInterval`).
    var formatted: String {
        let left = lower.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = upper.trimmingCharacters(in: .whitespacesAndNewlines)
        let pair = brackets
        return "\(pair.lower)\(left), \(right)\(pair.upper)"
    }

    /// Aperçu : tant qu'une borne manque, `a` et `b` tiennent sa place plutôt
    /// que de laisser un trou dans l'intervalle.
    var preview: String {
        var copie = self
        if copie.lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copie.lower = "a"
        }
        if copie.upper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copie.upper = "b"
        }
        return copie.formatted
    }
}

// MARK: - Matrices

/// Délimiteur de matrice (`MatrixDelimiter` de `utils/mathMatrix.ts`).
enum MathKbMatrixDelimiter: String, CaseIterable, Hashable {
    case square
    case round
    case braces
    case leftBrace
    case bars
    case doubleBars
    case none
}

/// Rendu d'une matrice en texte Unicode : les morceaux de crochets gardent les
/// lignes et les colonnes visibles tout en restant du texte modifiable
/// (`formatMatrix`).
enum MathKbMatrixFormatter {

    /// Colonnes alignées à droite sur la largeur visible la plus grande, deux
    /// espaces entre les colonnes. `nil` si une case est vide ou si les lignes
    /// n'ont pas toutes la même longueur.
    static func format(
        rows: [[String]],
        delimiter: MathKbMatrixDelimiter = .square
    ) -> String? {
        guard let firstRow = rows.first, !firstRow.isEmpty else { return nil }
        let columnCount = firstRow.count
        guard rows.allSatisfy({ $0.count == columnCount }) else { return nil }

        var values: [[String]] = []
        for row in rows {
            var cleaned: [String] = []
            for value in row {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                cleaned.append(
                    value
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .joined(separator: " ")
                )
            }
            values.append(cleaned)
        }

        let widths: [Int] = (0..<columnCount).map { column in
            values.map { $0[column].count }.max() ?? 0
        }

        let contents: [String] = values.map { row in
            row.enumerated()
                .map { index, value in alignRight(value, width: widths[index]) }
                .joined(separator: "  ")
        }

        let lines: [String] = contents.enumerated().map { index, content in
            let sides = sides(delimiter, row: index, rowCount: contents.count)
            return "\(sides.0)\(content)\(sides.1)"
        }
        return lines.joined(separator: "\n")
    }

    /// Crochets d'une ligne de matrice (`matrixSides`).
    static func sides(
        _ delimiter: MathKbMatrixDelimiter,
        row: Int,
        rowCount: Int
    ) -> (String, String) {
        switch delimiter {
        case .none:
            return ("", "")
        case .bars:
            return ("│", "│")
        case .doubleBars:
            return ("‖", "‖")
        case .leftBrace:
            if rowCount == 1 { return ("{", "") }
            if row == 0 { return ("⎧", "") }
            if row == rowCount - 1 { return ("⎩", "") }
            if rowCount % 2 == 1 && row == rowCount / 2 { return ("⎨", "") }
            return ("⎪", "")
        case .round:
            if rowCount == 1 { return ("(", ")") }
            if row == 0 { return ("⎛", "⎞") }
            if row == rowCount - 1 { return ("⎝", "⎠") }
            return ("⎜", "⎟")
        case .braces:
            if rowCount == 1 { return ("{", "}") }
            if row == 0 { return ("⎧", "⎫") }
            if row == rowCount - 1 { return ("⎩", "⎭") }
            if rowCount % 2 == 1 && row == rowCount / 2 { return ("⎨", "⎬") }
            return ("⎪", "⎪")
        case .square:
            if rowCount == 1 { return ("[", "]") }
            if row == 0 { return ("⎡", "⎤") }
            if row == rowCount - 1 { return ("⎣", "⎦") }
            return ("⎢", "⎥")
        }
    }

    private static func alignRight(_ value: String, width: Int) -> String {
        String(repeating: " ", count: max(0, width - value.count)) + value
    }
}

// MARK: - Brouillons des outils guidés

/// Brouillon de l'éditeur de matrice (`MatrixDraft`).
struct MathKbMatrixDraft {
    var rows: Int
    var columns: Int
    var cells: [String]
    var active: Int
    var delimiter: MathKbMatrixDelimiter

    /// Deux lignes, deux colonnes, délimiteur carré — valeurs par défaut de
    /// `createMatrixDraft` quand aucune matrice n'est sélectionnée.
    static func initial() -> MathKbMatrixDraft {
        MathKbMatrixDraft(
            rows: 2,
            columns: 2,
            cells: ["", "", "", ""],
            active: 0,
            delimiter: .square
        )
    }

    /// Toutes les cases sont remplies (`matrixComplete`).
    var isComplete: Bool {
        cells.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Redimensionne en conservant les cases qui restent dans la nouvelle
    /// grille et en reculant le curseur dans les bornes (`resizeMatrixDraft`).
    mutating func resize(rows newRows: Int, columns newColumns: Int) {
        let nextRows = min(max(newRows, MathKbLayout.matrixMinSize), MathKbLayout.matrixMaxSize)
        let nextColumns = min(max(newColumns, MathKbLayout.matrixMinSize), MathKbLayout.matrixMaxSize)
        guard nextRows != rows || nextColumns != columns else { return }

        var nextCells: [String] = []
        nextCells.reserveCapacity(nextRows * nextColumns)
        for index in 0..<(nextRows * nextColumns) {
            let row = index / nextColumns
            let column = index % nextColumns
            if row < rows, column < columns, row * columns + column < cells.count {
                nextCells.append(cells[row * columns + column])
            } else {
                nextCells.append("")
            }
        }

        let activeRow = min(active / max(columns, 1), nextRows - 1)
        let activeColumn = min(active % max(columns, 1), nextColumns - 1)

        rows = nextRows
        columns = nextColumns
        cells = nextCells
        active = activeRow * nextColumns + activeColumn
    }

    /// La grille telle qu'attendue par le formateur.
    var grid: [[String]] {
        (0..<rows).map { row in
            (0..<columns).map { column in
                let index = row * columns + column
                return index < cells.count ? cells[index] : ""
            }
        }
    }
}

/// Brouillon de l'éditeur d'opérateur (`MathOperatorDraft`).
struct MathKbOperatorDraft {
    var kind: MathKbOperatorKind
    var values: [String]
    var active: Int

    init(kind: MathKbOperatorKind) {
        self.kind = kind
        self.values = Array(
            repeating: "",
            count: MathKbOperatorCatalog.definition(for: kind).fields.count
        )
        self.active = 0
    }

    /// Champs nommés, pour le formateur et le test de complétude.
    var valueMap: [String: String] {
        var map: [String: String] = [:]
        for (index, field) in MathKbOperatorCatalog.definition(for: kind).fields.enumerated() {
            map[field.id] = index < values.count ? values[index] : ""
        }
        return map
    }

    var isComplete: Bool {
        MathKbOperatorCatalog.isComplete(kind: kind, values: valueMap)
    }

    var preview: String {
        MathKbOperatorCatalog.preview(kind: kind, values: valueMap)
    }
}

/// Brouillon de l'éditeur d'intervalle (`IntervalDraft`).
struct MathKbIntervalDraft {
    var kind: MathKbIntervalKind = .real
    var lower: String = ""
    var upper: String = ""
    var lowerClosed: Bool = true
    var upperClosed: Bool = true
    var active: Int = 0

    /// Les deux bornes sont remplies (`intervalComplete`).
    var isComplete: Bool {
        !lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !upper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var interval: MathKbInterval {
        MathKbInterval(
            kind: kind,
            lower: lower,
            upper: upper,
            lowerClosed: lowerClosed,
            upperClosed: upperClosed
        )
    }

    /// Bornes nommées de l'éditeur (`INTERVAL_BOUNDS`).
    static let boundLabels = ["Borne gauche", "Borne droite"]

    /// Bornes vides de l'éditeur (`createIntervalDraft`).
    static func initial() -> MathKbIntervalDraft {
        MathKbIntervalDraft()
    }
}

// MARK: - Clavier

/// Barre de symboles mathématiques, posée par l'écran parent au-dessus du
/// clavier système (les deux cohabitent : lettres et chiffres en bas, symboles
/// ici). Portée depuis `components/MathKeyboard.tsx`.
///
/// ```swift
/// MathKeyboardView(
///     mode: .math,
///     onInsert: { texte in réponse.insert(texte) },
///     onBackspace: { réponse.deleteBackward() },
///     onClose: { clavierOuvert = false }
/// )
/// ```
struct MathKeyboardView: View {

    // MARK: Contrat d'intégration

    private let mode: MathKbMode
    private let insertText: (String, Int) -> Void
    private let backspace: () -> Void
    private let close: () -> Void

    /// Signature d'intégration : `onInsert` ne transporte que le texte. Les
    /// touches à recul de curseur (`back`) sont insérées sans ce recul ; pour le
    /// conserver, utiliser `init(mode:onInsertWithBack:onBackspace:onClose:)`.
    init(
        mode: MathKbMode,
        onInsert: @escaping (String) -> Void,
        onBackspace: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mode = mode
        self.insertText = { text, _ in onInsert(text) }
        self.backspace = onBackspace
        self.close = onClose
        _sectionId = State(initialValue: MathKbLayout.initialSectionId(for: mode))
    }

    /// Variante qui transmet aussi le recul du curseur demandé par la touche
    /// (`back`), pour se placer entre les délimiteurs après un `()` ou un `{}`.
    init(
        mode: MathKbMode,
        onInsertWithBack: @escaping (String, Int) -> Void,
        onBackspace: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mode = mode
        self.insertText = onInsertWithBack
        self.backspace = onBackspace
        self.close = onClose
        _sectionId = State(initialValue: MathKbLayout.initialSectionId(for: mode))
    }

    // MARK: État

    @State private var sectionId: String
    @State private var subscriptMode = false
    @State private var matrixDraft: MathKbMatrixDraft?
    @State private var operatorDraft: MathKbOperatorDraft?
    @State private var intervalDraft: MathKbIntervalDraft?

    @FocusState private var matrixFocus: Int?
    @FocusState private var operatorFocus: Int?
    @FocusState private var intervalFocus: Int?

    // MARK: Dérivés

    private var sections: [MathKbSection] { MathKbLayout.sections(for: mode) }

    private var currentSection: MathKbSection {
        sections.first { $0.id == sectionId } ?? sections[0]
    }

    /// Un outil guidé est ouvert : il absorbe la frappe et la rangée de touches
    /// s'affiche un peu plus basse.
    private var draftOpen: Bool {
        matrixDraft != nil || operatorDraft != nil || intervalDraft != nil
    }

    /// Le mode indice n'existe que là où les caractères ont une forme basse.
    private var lowering: Bool {
        subscriptMode && currentSection.id == MathKbLayout.subscriptSectionId
    }

    // MARK: Corps

    var body: some View {
        VStack(spacing: 0) {
            tabsRow

            if let draft = matrixDraft {
                matrixEditor(draft)
            }
            if let draft = operatorDraft {
                operatorEditor(draft)
            }
            if let draft = intervalDraft {
                intervalEditor(draft)
            }

            keysScroll
            actionsRow
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Theme.surfaceMuted)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    // MARK: Bandeau d'onglets et fermeture

    private var tabsRow: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(sections) { item in
                        tabButton(item)
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 2)
            }
            closeButton
        }
    }

    private func tabButton(_ item: MathKbSection) -> some View {
        let selected = item.id == currentSection.id
        return Button {
            sectionId = item.id
        } label: {
            Text(item.label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .padding(.vertical, 4)
                .padding(.horizontal, 9)
                .background(selected ? Theme.ink : Theme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Onglet \(item.label)")
    }

    private var closeButton: some View {
        Button {
            close()
        } label: {
            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 28, height: 24)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fermer le clavier maths")
    }

    // MARK: Grille de touches

    private var keysScroll: some View {
        ScrollView(.vertical, showsIndicators: true) {
            MathKbFlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(currentSection.keys) { key in
                    keyButton(key)
                }
            }
            .padding(.bottom, 1)
        }
        .frame(maxHeight: draftOpen ? 66 : 70)
    }

    private func keyButton(_ key: MathKbKey) -> some View {
        let base = key.text
        let lowered = lowering ? MathKbScript.toScript(base, MathKbScript.subscripts) : nil
        let muted = lowering && lowered == nil
        let shown = lowered ?? base
        return Button {
            if let action = key.action {
                startTool(action)
            } else {
                insertDraftText(shown, back: key.back)
            }
        } label: {
            Text(shown)
                .font(.system(size: key.wide ? 11 : 14, weight: key.wide ? .heavy : .bold))
                .foregroundStyle(muted ? Theme.inkFaint : Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, key.wide ? 8 : 4)
                .frame(minWidth: 32, minHeight: 30)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: key, muted: muted))
    }

    private func accessibilityLabel(for key: MathKbKey, muted: Bool) -> String {
        if let action = key.action {
            switch action {
            case .matrix:
                return "Créer une matrice"
            case .interval:
                return "Construire un intervalle de réels ou d’entiers"
            case .exponent, .limit, .integral, .sum, .product:
                if let kind = operatorKind(for: action) {
                    return "Construire \(MathKbOperatorCatalog.definition(for: kind).title.lowercased())"
                }
                return "Insérer \(key.label)"
            }
        }
        return muted ? "Insérer \(key.label), sans indice possible" : "Insérer \(key.label)"
    }

    private func operatorKind(for action: MathKbAction?) -> MathKbOperatorKind? {
        guard let action = action else { return nil }
        switch action {
        case .exponent: return .exponent
        case .limit: return .limit
        case .integral: return .integral
        case .sum: return .sum
        case .product: return .product
        case .matrix, .interval: return nil
        }
    }

    // MARK: Rangée d'actions

    private var actionsRow: some View {
        HStack(spacing: 5) {
            if operatorDraft == nil, currentSection.id == MathKbLayout.subscriptSectionId {
                MathKbActionKey(
                    accessibility: subscriptMode ? "Écrire sur la ligne" : "Écrire en indice",
                    label: "xₙ",
                    highlighted: subscriptMode,
                    labelSize: 15
                ) {
                    subscriptMode.toggle()
                }
            }

            MathKbActionKey(accessibility: "Espace", label: "espace") {
                insertDraftText(" ")
            }

            MathKbActionKey(
                accessibility: returnAccessibilityLabel,
                systemImage: draftOpen ? "chevron.forward" : "return"
            ) {
                handleReturn()
            }

            MathKbActionKey(accessibility: "Effacer", systemImage: "delete.left") {
                handleBackspace()
            }
        }
        .padding(.top, 5)
    }

    private var returnAccessibilityLabel: String {
        if operatorDraft != nil { return "Champ suivant" }
        if intervalDraft != nil { return "Borne suivante" }
        if matrixDraft != nil { return "Case suivante" }
        return "Nouvelle ligne"
    }

    // MARK: Frappe

    /// Ouvre un outil guidé — un seul à la fois, sinon deux panneaux se
    /// disputeraient les touches (`startTool`).
    private func startTool(_ action: MathKbAction) {
        matrixDraft = nil
        operatorDraft = nil
        intervalDraft = nil

        switch action {
        case .matrix:
            matrixDraft = MathKbMatrixDraft.initial()
            matrixFocus = 0
        case .interval:
            intervalDraft = MathKbIntervalDraft.initial()
            intervalFocus = 0
        case .exponent, .limit, .integral, .sum, .product:
            guard let kind = operatorKind(for: action) else { return }
            operatorDraft = MathKbOperatorDraft(kind: kind)
            operatorFocus = 0
        }
    }

    /// Une touche pressée alors qu'un outil est ouvert écrit dans son champ
    /// actif ; sinon l'insertion part vers la réponse, avec le recul demandé.
    private func insertDraftText(_ text: String, back: Int = 0) {
        if var draft = matrixDraft, draft.active < draft.cells.count {
            draft.cells[draft.active] += text
            matrixDraft = draft
            return
        }
        if var draft = operatorDraft, draft.active < draft.values.count {
            draft.values[draft.active] += text
            operatorDraft = draft
            return
        }
        if var draft = intervalDraft {
            if draft.active == 0 { draft.lower += text } else { draft.upper += text }
            intervalDraft = draft
            return
        }
        insertText(text, back)
    }

    /// Efface le dernier caractère du champ actif, ou délègue à la réponse.
    private func handleBackspace() {
        if var draft = matrixDraft, draft.active < draft.cells.count {
            if !draft.cells[draft.active].isEmpty { draft.cells[draft.active].removeLast() }
            matrixDraft = draft
            return
        }
        if var draft = operatorDraft, draft.active < draft.values.count {
            if !draft.values[draft.active].isEmpty { draft.values[draft.active].removeLast() }
            operatorDraft = draft
            return
        }
        if var draft = intervalDraft {
            if draft.active == 0 {
                if !draft.lower.isEmpty { draft.lower.removeLast() }
            } else if !draft.upper.isEmpty {
                draft.upper.removeLast()
            }
            intervalDraft = draft
            return
        }
        backspace()
    }

    /// Touche retour contextuelle (`handleReturn`) : champ suivant, borne
    /// suivante, case suivante, sinon une nouvelle ligne.
    private func handleReturn() {
        if let draft = operatorDraft {
            focusOperatorField(draft.active + 1)
            return
        }
        if intervalDraft != nil {
            moveIntervalBound(1)
            return
        }
        if matrixDraft != nil {
            moveMatrixCell(1)
            return
        }
        insertText("\n", 0)
    }

    // MARK: Éditeur de matrice

    private func matrixEditor(_ draft: MathKbMatrixDraft) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Matrice \(draft.rows) × \(draft.columns)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("Choisis une case, puis utilise les touches.")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    Text("Les touches s’ajoutent en fin de case.")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    MathKbStepper(
                        label: "Lignes",
                        value: draft.rows,
                        canDecrease: draft.rows > MathKbLayout.matrixMinSize,
                        canIncrease: draft.rows < MathKbLayout.matrixMaxSize,
                        decrease: { resizeMatrix(rows: draft.rows - 1, columns: draft.columns) },
                        increase: { resizeMatrix(rows: draft.rows + 1, columns: draft.columns) }
                    )
                    MathKbStepper(
                        label: "Colonnes",
                        value: draft.columns,
                        canDecrease: draft.columns > MathKbLayout.matrixMinSize,
                        canIncrease: draft.columns < MathKbLayout.matrixMaxSize,
                        decrease: { resizeMatrix(rows: draft.rows, columns: draft.columns - 1) },
                        increase: { resizeMatrix(rows: draft.rows, columns: draft.columns + 1) }
                    )
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 4) {
                    ForEach(0..<draft.rows, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<draft.columns, id: \.self) { column in
                                matrixCell(row: row, column: column, draft: draft)
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxHeight: 70)

            HStack(spacing: 4) {
                Text("Case \(draft.active + 1)/\(max(draft.cells.count, 1))")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                MathKbMiniButton(
                    systemImage: "chevron.backward",
                    enabled: draft.active > 0
                ) {
                    moveMatrixCell(-1)
                }
                MathKbMiniButton(
                    systemImage: "chevron.forward",
                    enabled: draft.active < draft.cells.count - 1
                ) {
                    moveMatrixCell(1)
                }
                Spacer(minLength: 4)
                MathKbMiniButton(label: "Annuler") {
                    matrixDraft = nil
                }
                MathKbMiniButton(label: "Insérer", wide: true, prominent: true, enabled: draft.isComplete) {
                    commitMatrix()
                }
            }
        }
        .padding(8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func matrixCell(row: Int, column: Int, draft: MathKbMatrixDraft) -> some View {
        let index = row * draft.columns + column
        let selected = index == draft.active
        return TextField("…", text: matrixCellBinding(index))
            .font(.system(size: 12, weight: .heavy))
            .multilineTextAlignment(.center)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($matrixFocus, equals: index)
            .frame(width: 56, height: 30)
            .background(selected ? Theme.primaryLight : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
            )
            .onTapGesture {
                matrixDraft?.active = index
                matrixFocus = index
            }
            .accessibilityLabel(
                "Case ligne \(row + 1), colonne \(column + 1)"
            )
    }

    private func matrixCellBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let draft = matrixDraft, index < draft.cells.count else { return "" }
                return draft.cells[index]
            },
            set: { newValue in
                guard var draft = matrixDraft, index < draft.cells.count else { return }
                draft.cells[index] = newValue
                matrixDraft = draft
            }
        )
    }

    private func resizeMatrix(rows: Int, columns: Int) {
        guard var draft = matrixDraft else { return }
        draft.resize(rows: rows, columns: columns)
        matrixDraft = draft
    }

    private func moveMatrixCell(_ step: Int) {
        guard var draft = matrixDraft, !draft.cells.isEmpty else { return }
        let active = max(0, min(draft.cells.count - 1, draft.active + step))
        guard active != draft.active else { return }
        draft.active = active
        matrixDraft = draft
        matrixFocus = active
    }

    private func commitMatrix() {
        guard let draft = matrixDraft, draft.isComplete else { return }
        guard let text = MathKbMatrixFormatter.format(
            rows: draft.grid,
            delimiter: draft.delimiter
        ) else { return }
        insertText(text, 0)
        matrixDraft = nil
        sectionId = "algebre"
    }

    // MARK: Éditeur d'opérateur

    private func operatorEditor(_ draft: MathKbOperatorDraft) -> some View {
        let definition = MathKbOperatorCatalog.definition(for: draft.kind)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Text(draft.preview)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 86, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.title)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text(definition.hint)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    Text("Champs obligatoires · touche une valeur pour la corriger.")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 4)
            }

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(definition.fields.indices, id: \.self) { index in
                    operatorField(index: index, field: definition.fields[index], draft: draft)
                }
            }

            if let activeField = operatorActiveField(draft), activeField.infinite {
                infiniteBoundKeys(target: activeField.label.lowercased())
            }

            HStack(spacing: 4) {
                Text("Champ \(draft.active + 1)/\(definition.fields.count)")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                MathKbMiniButton(systemImage: "chevron.backward", enabled: draft.active > 0) {
                    focusOperatorField(draft.active - 1)
                }
                MathKbMiniButton(
                    systemImage: "chevron.forward",
                    enabled: draft.active < definition.fields.count - 1
                ) {
                    focusOperatorField(draft.active + 1)
                }
                Spacer(minLength: 4)
                MathKbMiniButton(label: "Annuler") {
                    operatorDraft = nil
                }
                MathKbMiniButton(label: "Insérer", wide: true, prominent: true, enabled: draft.isComplete) {
                    commitOperator()
                }
            }
        }
        .padding(8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func operatorField(
        index: Int,
        field: MathKbOperatorField,
        draft: MathKbOperatorDraft
    ) -> some View {
        let selected = index == draft.active
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(field.label) *")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            TextField("ex. \(field.placeholder)", text: operatorFieldBinding(index))
                .font(.system(size: 12, weight: .heavy))
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($operatorFocus, equals: index)
                .frame(height: 34)
                .padding(.horizontal, 4)
                .background(selected ? Theme.primaryLight : Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
                .onTapGesture {
                    operatorDraft?.active = index
                    operatorFocus = index
                }
                .accessibilityLabel(field.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func operatorFieldBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let draft = operatorDraft, index < draft.values.count else { return "" }
                return draft.values[index]
            },
            set: { newValue in
                guard var draft = operatorDraft, index < draft.values.count else { return }
                draft.values[index] = newValue
                operatorDraft = draft
            }
        )
    }

    private func operatorActiveField(_ draft: MathKbOperatorDraft) -> MathKbOperatorField? {
        let fields = MathKbOperatorCatalog.definition(for: draft.kind).fields
        return draft.active < fields.count ? fields[draft.active] : nil
    }

    private func focusOperatorField(_ index: Int) {
        guard var draft = operatorDraft else { return }
        let count = MathKbOperatorCatalog.definition(for: draft.kind).fields.count
        let active = max(0, min(count - 1, index))
        draft.active = active
        operatorDraft = draft
        operatorFocus = active
    }

    private func commitOperator() {
        guard let draft = operatorDraft, draft.isComplete else { return }
        guard let text = MathKbOperatorCatalog.format(kind: draft.kind, values: draft.valueMap) else {
            return
        }
        insertText(text, 0)
        operatorDraft = nil
        sectionId = draft.kind == .exponent ? "base" : "analyse"
    }

    // MARK: Éditeur d'intervalle

    private func intervalEditor(_ draft: MathKbIntervalDraft) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Text(draft.interval.preview)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 86, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Intervalle")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("Touche un crochet pour inclure ou exclure sa borne.")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    HStack(spacing: 4) {
                        ForEach(MathKbIntervalKind.allCases, id: \.self) { kind in
                            intervalKindButton(kind, selected: kind == draft.kind)
                        }
                    }
                }
                Spacer(minLength: 4)
            }

            HStack(alignment: .bottom, spacing: 5) {
                intervalBracketButton(index: 0)
                intervalBoundField(index: 0)
                Text(",")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 9)
                intervalBoundField(index: 1)
                intervalBracketButton(index: 1)
            }

            infiniteBoundKeys(
                target: MathKbIntervalDraft.boundLabels[min(max(draft.active, 0), 1)].lowercased()
            )

            HStack(spacing: 4) {
                Text(MathKbIntervalDraft.boundLabels[min(max(draft.active, 0), 1)])
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                MathKbMiniButton(systemImage: "chevron.backward", enabled: draft.active > 0) {
                    moveIntervalBound(-1)
                }
                MathKbMiniButton(systemImage: "chevron.forward", enabled: draft.active < 1) {
                    moveIntervalBound(1)
                }
                Spacer(minLength: 4)
                MathKbMiniButton(label: "Annuler") {
                    intervalDraft = nil
                }
                MathKbMiniButton(label: "Insérer", wide: true, prominent: true, enabled: draft.isComplete) {
                    commitInterval()
                }
            }
        }
        .padding(8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func intervalKindButton(_ kind: MathKbIntervalKind, selected: Bool) -> some View {
        Button {
            intervalDraft?.kind = kind
        } label: {
            Text(kind.label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .padding(.vertical, 3)
                .padding(.horizontal, 9)
                .background(selected ? Theme.ink : Theme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Intervalle de \(kind.label.lowercased())")
    }

    private func intervalBracketButton(index: Int) -> some View {
        let interval = intervalDraft?.interval ?? MathKbInterval()
        let value = index == 0 ? interval.lower : interval.upper
        let infinite = MathKbInterval.isInfinite(value)
        let closed = index == 0 ? interval.lowerClosed : interval.upperClosed
        let symbol = index == 0 ? interval.brackets.lower : interval.brackets.upper
        let accessibility: String
        if infinite {
            accessibility = index == 0
                ? "Borne gauche infinie, toujours exclue"
                : "Borne droite infinie, toujours exclue"
        } else if closed {
            accessibility = index == 0 ? "Exclure la borne gauche" : "Exclure la borne droite"
        } else {
            accessibility = index == 0 ? "Inclure la borne gauche" : "Inclure la borne droite"
        }
        return Button {
            toggleIntervalBound(index)
        } label: {
            Text(symbol)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 30, height: 34)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(closed && !infinite ? Theme.ink : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(infinite)
        .opacity(infinite ? 0.48 : 1)
        .accessibilityLabel(accessibility)
    }

    private func intervalBoundField(index: Int) -> some View {
        let label = MathKbIntervalDraft.boundLabels[min(max(index, 0), 1)]
        let placeholder = index == 0 ? "0" : "1"
        let selected = (intervalDraft?.active ?? 0) == index
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(label) *")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            TextField("ex. \(placeholder)", text: intervalBoundBinding(index))
                .font(.system(size: 12, weight: .heavy))
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($intervalFocus, equals: index)
                .frame(height: 34)
                .padding(.horizontal, 4)
                .background(selected ? Theme.primaryLight : Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
                .onTapGesture {
                    intervalDraft?.active = index
                    intervalFocus = index
                }
                .accessibilityLabel(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func intervalBoundBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let draft = intervalDraft else { return "" }
                return index == 0 ? draft.lower : draft.upper
            },
            set: { newValue in
                guard var draft = intervalDraft else { return }
                if index == 0 { draft.lower = newValue } else { draft.upper = newValue }
                intervalDraft = draft
            }
        )
    }

    private func toggleIntervalBound(_ index: Int) {
        guard var draft = intervalDraft else { return }
        if index == 0 {
            draft.lowerClosed.toggle()
        } else {
            draft.upperClosed.toggle()
        }
        intervalDraft = draft
    }

    private func moveIntervalBound(_ step: Int) {
        guard var draft = intervalDraft else { return }
        let active = max(0, min(1, draft.active + step))
        guard active != draft.active else { return }
        draft.active = active
        intervalDraft = draft
        intervalFocus = active
    }

    private func commitInterval() {
        guard let draft = intervalDraft, draft.isComplete else { return }
        insertText(draft.interval.formatted, 0)
        intervalDraft = nil
        sectionId = "ensembles"
    }

    // MARK: Bornes infinies

    /// Bornes infinies posées à côté du champ ouvert (`InfiniteBoundKeys`) :
    /// elles ne sont pas une touche de plus dans une section.
    private func infiniteBoundKeys(target: String) -> some View {
        HStack(spacing: 5) {
            Text("Borne infinie")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            ForEach(MathKbLayout.infiniteBounds, id: \.self) { bound in
                Button {
                    insertDraftText(bound)
                } label: {
                    Text(bound)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 9)
                        .frame(minWidth: 46)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Écrire \(bound == "+∞" ? "plus l’infini" : "moins l’infini") dans le champ \(target)"
                )
            }
        }
    }
}

// MARK: - Boutons du clavier

/// Touche de la rangée d'actions (espace, retour, effacer) et du mode indice.
private struct MathKbActionKey: View {
    let accessibility: String
    var label: String? = nil
    var systemImage: String? = nil
    var highlighted: Bool = false
    var labelSize: CGFloat = 11
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: labelSize, weight: .heavy))
                }
            }
            .foregroundStyle(highlighted ? Theme.surface : Theme.ink)
            .frame(minWidth: 42, minHeight: 30)
            .padding(.horizontal, 8)
            .background(highlighted ? Theme.ink : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}

/// Petit bouton d'éditeur : navigation entre champs, secondaire, primaire.
private struct MathKbMiniButton: View {
    var systemImage: String? = nil
    var label: String? = nil
    var wide: Bool = false
    var prominent: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 8, weight: prominent ? .black : .heavy))
                }
            }
            .foregroundStyle(prominent ? Theme.surface : Theme.ink)
            .frame(minWidth: systemImage != nil ? 27 : 0, minHeight: 26)
            .padding(.horizontal, wide ? 9 : 6)
            .background(prominent ? Theme.ink : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(prominent ? Theme.ink : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
    }
}

/// Compteur d'une dimension de matrice : libellé, `−`, valeur, `+`.
private struct MathKbStepper: View {
    let label: String
    let value: Int
    let canDecrease: Bool
    let canIncrease: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 43, alignment: .leading)
            button("−", enabled: canDecrease, action: decrease)
            Text("\(value)")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 13)
            button("+", enabled: canIncrease, action: increase)
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(width: 24, height: 22)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
    }
}

// MARK: - Disposition en flux

/// Disposition des touches : elles s'enroulent ligne à ligne selon leur largeur
/// propre, comme le `flexWrap` de la source (une touche large occupe plus de
/// place, une touche courte moins).
private struct MathKbFlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            widest = max(widest, x + size.width)
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }
    }
}
