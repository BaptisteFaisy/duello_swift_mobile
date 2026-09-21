//
//  MathKbLayout.swift
//  Duello
//
//  Dispositions du clavier : sections mathématiques (`MATH_SECTIONS`) et
//  raccourcis Python (`PYTHON_KEYBOARD_KEYS`) — `utils/mathKeySections.ts`,
//  `utils/mathKeyboardLayout.ts`.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import Foundation

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
