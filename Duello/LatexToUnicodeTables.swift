import Foundation

/// Tables de correspondance LaTeX → Unicode. Données pures, aucune logique :
/// elles sont lues par `LatexToUnicodeRendering` (et `LatexToUnicodeScripts`
/// pour les exposants/indices). Élargies de `private` à `internal` parce
/// qu'elles sont désormais partagées entre fichiers — aucune n'est renommée.
extension LatexToUnicode {
    // MARK: Tables

    /// Commandes rendues par un caractère unique (table `SYMBOLES`).
    static let symboles: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "varepsilon": "ε",
        "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ",
        "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "pi": "π", "rho": "ρ", "sigma": "σ",
        "tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π",
        "Sigma": "Σ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        "times": "×", "div": "÷", "pm": "±", "mp": "∓", "cdot": "·", "ast": "∗",
        "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠",
        "leqslant": "≤", "geqslant": "≥", "leqq": "≦", "geqq": "≧",
        "approx": "≈", "simeq": "≃", "sim": "∼", "equiv": "≡", "propto": "∝",
        "ll": "≪", "gg": "≫", "triangleq": "≜",
        "oplus": "⊕", "otimes": "⊗", "wedge": "∧", "vee": "∨",
        "in": "∈", "notin": "∉", "ni": "∋", "subset": "⊂", "subseteq": "⊆",
        "supset": "⊃", "supseteq": "⊇", "cup": "∪", "cap": "∩", "setminus": "∖",
        "emptyset": "∅", "varnothing": "∅", "forall": "∀", "exists": "∃", "nexists": "∄",
        "neg": "¬", "lnot": "¬", "land": "∧", "lor": "∨", "complement": "∁",
        "subsetneq": "⊊", "supsetneq": "⊋",
        "to": "→", "rightarrow": "→", "longrightarrow": "⟶", "leftarrow": "←",
        "longleftarrow": "⟵", "leftrightarrow": "↔", "longleftrightarrow": "⟷",
        "Rightarrow": "⇒", "Leftarrow": "⇐", "Leftrightarrow": "⇔",
        "Longrightarrow": "⟹", "Longleftarrow": "⟸", "Longleftrightarrow": "⟺",
        "implies": "⟹", "impliedby": "⟸",
        "iff": "⟺", "hookrightarrow": "↪", "hookleftarrow": "↩",
        "uparrow": "↑", "downarrow": "↓",
        "nearrow": "↗", "searrow": "↘", "swarrow": "↙", "nwarrow": "↖",
        "mapsto": "↦",
        "int": "∫", "iint": "∬", "oint": "∮", "sum": "∑", "prod": "∏",
        "bigcup": "⋃", "bigcap": "⋂", "bigoplus": "⨁", "bigotimes": "⨂",
        "infty": "∞", "partial": "∂", "nabla": "∇", "angle": "∠", "perp": "⊥",
        "parallel": "∥", "dots": "…", "ldots": "…", "cdots": "⋯", "circ": "∘",
        "ddots": "⋱", "vdots": "⋮",
        "prime": "′", "degree": "°", "star": "⋆", "bullet": "•",
        "ell": "ℓ", "aleph": "ℵ", "hbar": "ℏ",
    ]

    /// Commandes purement typographiques, sans équivalent à rendre.
    static let stylesIgnores: Set<String> = [
        "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle",
        "limits", "nolimits", "mathstrut", "strut", "boldsymbol", "mathopen",
        "mathclose", "mathord", "mathbin", "mathrel", "mathpunct",
    ]

    /// `\mathcal{L}` : les lettres de ronde ont leur caractère Unicode.
    static let rondes: [String: String] = [
        "A": "𝒜", "B": "ℬ", "C": "𝒞", "D": "𝒟", "E": "ℰ", "F": "ℱ", "G": "𝒢", "H": "ℋ",
        "I": "ℐ", "J": "𝒥", "K": "𝒦", "L": "ℒ", "M": "ℳ", "N": "𝒩", "O": "𝒪", "P": "𝒫",
        "Q": "𝒬", "R": "ℛ", "S": "𝒮", "T": "𝒯", "U": "𝒰", "V": "𝒱", "W": "𝒲", "X": "𝒳",
        "Y": "𝒴", "Z": "𝒵",
    ]

    /// Commandes rendues par un mot, écrit en clair.
    static let operateurs: Set<String> = [
        "sin", "cos", "tan", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh",
        "ln", "log", "exp", "lim", "max", "min", "sup", "inf", "det", "dim",
        "ker", "deg", "gcd", "mod", "Re", "Im",
    ]

    /// `\mathbb{R}` et compagnie : les ensembles usuels ont leur caractère.
    static let ajourees: [String: String] = [
        "R": "ℝ", "N": "ℕ", "Z": "ℤ", "Q": "ℚ", "C": "ℂ", "P": "ℙ", "E": "𝔼", "K": "𝕂",
    ]

    /// Fractions simples auxquelles Unicode réserve un caractère.
    static let fractions: [String: String] = [
        "1/2": "½", "1/3": "⅓", "2/3": "⅔", "1/4": "¼", "3/4": "¾",
        "1/5": "⅕", "2/5": "⅖", "3/5": "⅗", "4/5": "⅘", "1/6": "⅙",
        "5/6": "⅚", "1/8": "⅛", "3/8": "⅜", "5/8": "⅝", "7/8": "⅞",
    ]

    /// Espacements LaTeX : une espace ordinaire, ou rien.
    static let espacements: [String: String] = [
        ",": " ", ";": " ", ":": " ", "!": "", " ": " ",
        "quad": " ", "qquad": "  ", "thinspace": " ", "enspace": " ",
    ]

    /// Délimiteurs nommés, une fois `\left` et `\right` retirés.
    static let delimiteurs: [String: String] = [
        "lbrace": "{", "rbrace": "}", "langle": "⟨", "rangle": "⟩",
        "lvert": "|", "rvert": "|", "lVert": "‖", "rVert": "‖",
        "vert": "|", "Vert": "‖",
        "lfloor": "⌊", "rfloor": "⌋", "lceil": "⌈", "rceil": "⌉",
    ]

    /// Commandes qui ne font qu'adapter la taille du délimiteur suivant.
    static let taillesDelimiteur: Set<String> = [
        "big", "Big", "bigg", "Bigg",
        "bigl", "Bigl", "biggl", "Biggl",
        "bigr", "Bigr", "biggr", "Biggr",
        "bigm", "Bigm", "biggm", "Biggm",
    ]

    /// Délimiteur visuel associé aux environnements matriciels usuels.
    static let environnementsMatrice: [String: String] = [
        "matrix": "none", "smallmatrix": "none", "array": "none",
        "cases": "left-brace", "pmatrix": "round", "bmatrix": "square",
        "Bmatrix": "braces", "vmatrix": "bars", "Vmatrix": "double-bars",
    ]
}
