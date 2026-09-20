import Foundation

/// LaTeX vers notation mathématique lisible — port fidèle de
/// `src/utils/latexToUnicode.ts` de l'app Expo.
///
/// La réponse d'un duel se rédige dans un champ de texte, et un champ de texte
/// n'affiche pas de math composée : `$\int_{0}^{1} x^{2}\,dx$` y reste du code.
/// Ce module rend la même formule en caractères réels — `∫₀¹ x² dx` — comme le
/// fait l'app Expo sur l'écran du défi (`MathStatementText` compose les mêmes
/// conversions). Ce qu'Unicode ne sait pas empiler — fraction, matrice — est
/// rendu en ligne (`(x + 1)/2`) plutôt que laissé en LaTeX brut.
enum LatexToUnicode {
    /// Remplace chaque formule LaTeX d'un texte par sa notation mathématique.
    /// La prose autour n'est pas touchée, et le contenu des blocs de code
    /// Markdown reste strictement identique (transcriptions photo).
    static func toUnicodeMath(_ texte: String) -> String {
        var rendu = ""
        var position = texte.startIndex

        for range in codeBlockRanges(in: texte) {
            rendu += convertirHorsBlocsDeCode(String(texte[position..<range.lowerBound]))
            rendu += String(texte[range])
            position = range.upperBound
        }
        rendu += convertirHorsBlocsDeCode(String(texte[position...]))
        return rendu
    }

    // MARK: Glyphes privés PDF

    /// Codage privé U+F8xx laissé par certains extracteurs PDF (ancienne
    /// police Adobe Symbol) : rendu avec leur caractère Unicode réel.
    private static let glyphesPrivesPdf: [Character: String] = [
        "\u{F8E5}": "⎷", "\u{F8E6}": "⏐", "\u{F8E7}": "⎯",
        "\u{F8E8}": "®", "\u{F8E9}": "©", "\u{F8EA}": "™",
        "\u{F8EB}": "⎛", "\u{F8EC}": "⎜", "\u{F8ED}": "⎝",
        "\u{F8EE}": "⎡", "\u{F8EF}": "⎢", "\u{F8F0}": "⎣",
        "\u{F8F1}": "⎧", "\u{F8F2}": "⎨", "\u{F8F3}": "⎩",
        "\u{F8F4}": "⎪", "\u{F8F5}": "⎮",
    ]

    // MARK: Tables

    /// Commandes rendues par un caractère unique (table `SYMBOLES`).
    private static let symboles: [String: String] = [
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
    private static let stylesIgnores: Set<String> = [
        "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle",
        "limits", "nolimits", "mathstrut", "strut", "boldsymbol", "mathopen",
        "mathclose", "mathord", "mathbin", "mathrel", "mathpunct",
    ]

    /// `\mathcal{L}` : les lettres de ronde ont leur caractère Unicode.
    private static let rondes: [String: String] = [
        "A": "𝒜", "B": "ℬ", "C": "𝒞", "D": "𝒟", "E": "ℰ", "F": "ℱ", "G": "𝒢", "H": "ℋ",
        "I": "ℐ", "J": "𝒥", "K": "𝒦", "L": "ℒ", "M": "ℳ", "N": "𝒩", "O": "𝒪", "P": "𝒫",
        "Q": "𝒬", "R": "ℛ", "S": "𝒮", "T": "𝒯", "U": "𝒰", "V": "𝒱", "W": "𝒲", "X": "𝒳",
        "Y": "𝒴", "Z": "𝒵",
    ]

    /// Commandes rendues par un mot, écrit en clair.
    private static let operateurs: Set<String> = [
        "sin", "cos", "tan", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh",
        "ln", "log", "exp", "lim", "max", "min", "sup", "inf", "det", "dim",
        "ker", "deg", "gcd", "mod", "Re", "Im",
    ]

    /// `\mathbb{R}` et compagnie : les ensembles usuels ont leur caractère.
    private static let ajourees: [String: String] = [
        "R": "ℝ", "N": "ℕ", "Z": "ℤ", "Q": "ℚ", "C": "ℂ", "P": "ℙ", "E": "𝔼", "K": "𝕂",
    ]

    /// Fractions simples auxquelles Unicode réserve un caractère.
    private static let fractions: [String: String] = [
        "1/2": "½", "1/3": "⅓", "2/3": "⅔", "1/4": "¼", "3/4": "¾",
        "1/5": "⅕", "2/5": "⅖", "3/5": "⅗", "4/5": "⅘", "1/6": "⅙",
        "5/6": "⅚", "1/8": "⅛", "3/8": "⅜", "5/8": "⅝", "7/8": "⅞",
    ]

    /// Espacements LaTeX : une espace ordinaire, ou rien.
    private static let espacements: [String: String] = [
        ",": " ", ";": " ", ":": " ", "!": "", " ": " ",
        "quad": " ", "qquad": "  ", "thinspace": " ", "enspace": " ",
    ]

    /// Délimiteurs nommés, une fois `\left` et `\right` retirés.
    private static let delimiteurs: [String: String] = [
        "lbrace": "{", "rbrace": "}", "langle": "⟨", "rangle": "⟩",
        "lvert": "|", "rvert": "|", "lVert": "‖", "rVert": "‖",
        "vert": "|", "Vert": "‖",
        "lfloor": "⌊", "rfloor": "⌋", "lceil": "⌈", "rceil": "⌉",
    ]

    /// Commandes qui ne font qu'adapter la taille du délimiteur suivant.
    private static let taillesDelimiteur: Set<String> = [
        "big", "Big", "bigg", "Bigg",
        "bigl", "Bigl", "biggl", "Biggl",
        "bigr", "Bigr", "biggr", "Biggr",
        "bigm", "Bigm", "biggm", "Biggm",
    ]

    /// Délimiteur visuel associé aux environnements matriciels usuels.
    private static let environnementsMatrice: [String: String] = [
        "matrix": "none", "smallmatrix": "none", "array": "none",
        "cases": "left-brace", "pmatrix": "round", "bmatrix": "square",
        "Bmatrix": "braces", "vmatrix": "bars", "Vmatrix": "double-bars",
    ]

    /// Exposants et indices disponibles en Unicode (`mathLayout.ts`).
    private static let subscripts: [Character: String] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "−": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ",
        "n": "ₙ", "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
    ]

    private static let superscripts: [Character: String] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ",
        "j": "ʲ", "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ", "r": "ʳ", "s": "ˢ",
        "t": "ᵗ", "u": "ᵘ", "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
        "T": "ᵀ", "N": "ᴺ",
    ]

    // MARK: Regex

    /// Les délimiteurs `$`, `$$`, `\( \)` et `\[ \]` encadrent les formules.
    private static let formuleRegex = try! NSRegularExpression(
        pattern: "\\$\\$([\\s\\S]*?)\\$\\$|\\\\\\[([\\s\\S]*?)\\\\\\]|\\\\\\(([\\s\\S]*?)\\\\\\)|\\$([^\\$]*)\\$"
    )

    /// Commande ou script LaTeX reçu sans les délimiteurs normalement attendus.
    private static let scriptNonDelimiteRegex = try! NSRegularExpression(
        pattern: "(?:^|[^A-Za-zÀ-ÖØ-öø-ÿΑ-ω0-9])(?:lim|det|ker|max|min|sup|inf|sin|cos|tan|ln|exp|[A-Za-zÀ-ÖØ-öø-ÿΑ-ω])[_^](?:\\{[^{}\\n]*\\}|\\\\[a-zA-Z]+|[A-Za-z0-9])"
    )

    /// Blocs de code Markdown : ```lang\n … ```\n
    private static let blocCodeRegex = try! NSRegularExpression(
        pattern: "^```[^\\S\\r\\n]*[a-zA-Z0-9_-]*[^\\S\\r\\n]*\\r?\\n[\\s\\S]*?^```[^\\S\\r\\n]*(?:\\r?\\n|$)",
        options: [.anchorsMatchLines, .dotMatchesLineSeparators]
    )

    private static func codeBlockRanges(in texte: String) -> [Range<String.Index>] {
        let full = texte.startIndex..<texte.endIndex
        return blocCodeRegex.matches(in: texte, range: NSRange(full, in: texte))
            .compactMap { Range($0.range, in: texte) }
    }

    private static func contientLatexNonDelimite(_ texte: String) -> Bool {
        if texte.contains("\\") { return true }
        let full = NSRange(texte.startIndex..., in: texte)
        return scriptNonDelimiteRegex.firstMatch(in: texte, range: full) != nil
    }

    // MARK: Conversion hors blocs de code

    private static func normaliserGlyphesPrivesPdf(_ texte: String) -> String {
        guard texte.contains(where: { glyphesPrivesPdf[$0] != nil }) else { return texte }
        return String(texte.map { glyphesPrivesPdf[$0] ?? String($0) })
    }

    /// Les espaces alignant une matrice multiligne sont significatifs ; pour
    /// une formule ordinaire, l'espacement est ramené à une seule espace.
    private static func nettoyerFormuleConvertie(_ converti: String) -> String {
        let propre = converti.trimmingCharacters(in: .whitespacesAndNewlines)
        guard propre.contains("\n") else {
            return propre.replacingOccurrences(
                of: "\\s+", with: " ",
                options: .regularExpression
            )
        }
        let lignes = propre
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression) }
        return lignes.joined(separator: "\n")
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    }

    private static func convertirHorsBlocsDeCode(_ texte: String) -> String {
        let texteNormalise = normaliserGlyphesPrivesPdf(texte)

        if !texteNormalise.contains("$") && !contientLatexNonDelimite(texteNormalise) {
            return texteNormalise
        }

        var avecFormulesConverties = ""
        var position = texteNormalise.startIndex
        let full = NSRange(texteNormalise.startIndex..., in: texteNormalise)
        for match in formuleRegex.matches(in: texteNormalise, range: full) {
            guard let matchRange = Range(match.range, in: texteNormalise) else { continue }
            avecFormulesConverties += String(texteNormalise[position..<matchRange.lowerBound])
            // Groupes : 1 = $$…$$, 2 = \[…\], 3 = \(…\), 4 = $…$
            var formule = ""
            for group in 1...4 {
                let ns = match.range(at: group)
                if ns.location != NSNotFound, let range = Range(ns, in: texteNormalise) {
                    formule = String(texteNormalise[range])
                    break
                }
            }
            avecFormulesConverties += nettoyerFormuleConvertie(convertirExpression(formule))
            position = matchRange.upperBound
        }
        avecFormulesConverties += String(texteNormalise[position...])

        if !contientLatexNonDelimite(avecFormulesConverties) {
            return avecFormulesConverties
        }

        // Dans les banques historiques, `ℝ \ {0}` désigne une différence
        // d'ensembles et non l'espacement LaTeX `\ `. On rend le signe.
        let latexNormalise = avecFormulesConverties.replacingOccurrences(
            of: "\\\\\\s+(?=\\{)",
            with: "\\\\setminus ",
            options: .regularExpression
        )
        return convertirExpression(latexNormalise, preserverAccoladesLitterales: true)
    }

    // MARK: Lecture structurée

    private static func estEspace(_ c: Character) -> Bool {
        c == " " || c == "\t" || c == "\n" || c == "\r"
    }

    /// Lit `{...}` en respectant l'imbrication, ou le seul caractère qui suit.
    private static func lireGroupe(_ latex: [Character], _ depart: Int) -> (contenu: String, suivant: Int) {
        var index = depart
        while index < latex.count && estEspace(latex[index]) { index += 1 }
        guard index < latex.count else { return ("", index) }

        if latex[index] != "{" {
            // `x^2` ou `x^\alpha` : l'argument est le caractère, ou la commande.
            if latex[index] == "\\" {
                let suite = String(latex[index...])
                if let commande = lireCommande(suite) {
                    return (commande, index + commande.count)
                }
            }
            return (String(latex[index]), index + 1)
        }

        var profondeur = 0
        var position = index
        while position < latex.count {
            let c = latex[position]
            if c == "\\" {
                position += 2
                continue
            }
            if c == "{" { profondeur += 1 }
            if c == "}" {
                profondeur -= 1
                if profondeur == 0 {
                    return (String(latex[(index + 1)..<position]), position + 1)
                }
            }
            position += 1
        }
        // Accolade jamais refermée : on prend le reste plutôt que d'abandonner.
        return (String(latex[(index + 1)...]), latex.count)
    }

    /// `\begin{...}` ou `\end{...}` : lit le nom entre accolades.
    private static func lireNomEnvironnement(_ latex: [Character], _ apres: Int) -> (nom: String, suivant: Int) {
        let groupe = lireGroupe(latex, apres)
        return (groupe.contenu.trimmingCharacters(in: .whitespacesAndNewlines), groupe.suivant)
    }

    /// Trouve la fermeture d'un environnement, y compris imbriqué.
    private static func lireEnvironnement(_ latex: [Character], _ depart: Int, _ nomRecherche: String) -> (contenu: String, suivant: Int)? {
        var profondeur = 1
        var index = depart
        while index < latex.count {
            guard latex[index] == "\\" else { index += 1; continue }
            let suite = String(latex[index...])
            guard suite.hasPrefix("\\begin") || suite.hasPrefix("\\end") else { index += 2; continue }
            let estDebut = suite.hasPrefix("\\begin")
            let apresMot = index + (estDebut ? 6 : 4)
            let (nom, suivant) = lireNomEnvironnement(latex, apresMot)
            if nom == nomRecherche {
                profondeur += estDebut ? 1 : -1
                if profondeur == 0 {
                    return (String(latex[depart..<index]), suivant)
                }
            }
            index = suivant
        }
        return nil
    }

    /// `\frac{a}{b}` : lit une commande après une position donnée.
    private static func lireCommande(_ suite: String) -> String? {
        guard suite.hasPrefix("\\") else { return nil }
        let chars = Array(suite)
        guard chars.count > 1 else { return nil }
        var fin = 1
        while fin < chars.count, chars[fin].isLetter, chars[fin].isASCII { fin += 1 }
        if fin > 1 { return String(chars[0..<fin]) }
        return String(chars[0...1])
    }

    private static func retirerTraitsDeTableau(_ cellule: String) -> String {
        cellule.replacingOccurrences(
            of: "\\\\(?:hline|hdashline)\\b",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }

    /// Découpe le contenu d'une matrice en lignes (`\\`) et cellules (`&`),
    /// au niveau d'imbrication zéro.
    private static func decouperMatrice(_ contenu: String) -> [[String]] {
        let chars = Array(contenu)
        var lignes: [[String]] = [[]]
        var cellule = ""
        var profondeur = 0
        var index = 0
        while index < chars.count {
            let c = chars[index]
            if c == "\\" && index + 1 < chars.count {
                let suivant = chars[index + 1]
                if suivant == "\\" && profondeur == 0 {
                    lignes[lignes.count - 1].append(cellule)
                    cellule = ""
                    lignes.append([])
                    index += 2
                    continue
                }
                // Commande : elle appartient à la cellule, sans découpage.
                if let commande = lireCommande(String(chars[index...])) {
                    cellule += commande
                    index += commande.count
                    continue
                }
                cellule.append(c)
                index += 1
                continue
            }
            if c == "{" { profondeur += 1 }
            if c == "}" { profondeur -= 1 }
            if c == "&" && profondeur == 0 {
                lignes[lignes.count - 1].append(cellule)
                cellule = ""
                index += 1
                continue
            }
            cellule.append(c)
            index += 1
        }
        if !cellule.isEmpty || !lignes[lignes.count - 1].isEmpty {
            lignes[lignes.count - 1].append(cellule)
        }
        let utiles = lignes
            .map { $0.map(retirerTraitsDeTableau) }
            .filter { rangee in rangee.contains { !$0.isEmpty } }
        return utiles
    }

    // MARK: Rendu

    /// Rend en exposant ou en indice, ou `nil` si un caractère résiste.
    private static func enScript(_ texte: String, _ table: [Character: String]) -> String? {
        if texte.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        var rendu = ""
        for caractere in texte {
            if estEspace(caractere) { continue }
            guard let equivalent = table[caractere] else { return nil }
            rendu += equivalent
        }
        return rendu
    }

    /// Un terme composé se parenthèse avant d'entrer dans une fraction.
    private static func grouper(_ texte: String) -> String {
        let propre = texte.trimmingCharacters(in: .whitespaces)
        if propre.isEmpty { return propre }
        let separateurs: Set<Character> = [" ", "+", "-", "−", "×", "÷", "/", "="]
        if !propre.contains(where: { separateurs.contains($0) }) { return propre }
        if propre.hasPrefix("(") && propre.hasSuffix(")") { return propre }
        return "(\(propre))"
    }

    private static func fraction(_ numerateur: String, _ denominateur: String) -> String {
        let haut = numerateur.trimmingCharacters(in: .whitespaces)
        let bas = denominateur.trimmingCharacters(in: .whitespaces)
        if let caractere = fractions["\(haut)/\(bas)"] { return caractere }
        return "\(grouper(haut))/\(grouper(bas))"
    }

    /// Rend le délimiteur lu après `\left`, `\right`, `\bigl`, etc.
    private static func rendreDelimiteur(_ contenu: String) -> String {
        if contenu == "." { return "" }
        // `\|` est la forme courte de la double barre d'une norme.
        if contenu == "\\|" { return "‖" }
        let nom = contenu.hasPrefix("\\") ? String(contenu.dropFirst()) : contenu
        return delimiteurs[nom] ?? contenu
    }

    /// Alignement de colonnes, puis délimiteurs, pour une matrice rendue
    /// en ligne par ligne (équivalent de `formatMatrix`).
    private static func formatMatrix(_ rows: [[String]], _ delimiter: String) -> String {
        let colonnes = rows.map(\.count).max() ?? 0
        guard colonnes > 0 else { return "" }
        let aligned = rows.map { rangee in
            (0..<colonnes).map { colonne in colonne < rangee.count ? rangee[colonne] : "" }
        }
        let largeurs = (0..<colonnes).map { colonne in
            aligned.compactMap { $0[colonne].isEmpty ? nil : $0[colonne].count }.max() ?? 0
        }
        let corps = aligned.map { rangee in
            (0..<colonnes).map { colonne in
                rangee[colonne].padding(toWidth: largeurs[colonne], atStart: false)
            }.joined(separator: "  ")
        }
        func envelopper(_ gauche: String, _ droite: String) -> String {
            corps.map { "\(gauche) \($0) \(droite)" }.joined(separator: "\n")
        }
        switch delimiter {
        case "none": return corps.joined(separator: "\n")
        case "round": return envelopper("(", ")")
        case "square": return envelopper("[", "]")
        case "braces": return envelopper("{", "}")
        case "bars": return envelopper("|", "|")
        case "double-bars": return envelopper("‖", "‖")
        // `cases` : convention écrite française, une accolade par ligne.
        case "left-brace": return corps.map { "{ \($0)" }.joined(separator: "\n")
        default: return corps.joined(separator: "\n")
        }
    }

    // MARK: Conversion d'une expression

    /// Convertit une expression LaTeX, délimiteurs déjà retirés. Récursive :
    /// les arguments d'une fraction ou d'une racine sont eux-mêmes des
    /// expressions, et une puissance peut porter une lettre grecque.
    static func convertirExpression(_ latexSource: String, preserverAccoladesLitterales: Bool = false) -> String {
        let latex = Array(latexSource)
        var rendu = ""
        var index = 0

        while index < latex.count {
            let caractere = latex[index]

            if caractere == "\\" {
                guard let commande = lireCommande(String(latex[index...])) else {
                    index += 1
                    continue
                }
                let nom = String(commande.dropFirst())
                index += commande.count

                if nom == "begin" {
                    let (nomEnvironnement, apresNom) = lireNomEnvironnement(latex, index)
                    let nomNormalise = nomEnvironnement.hasSuffix("*")
                        ? String(nomEnvironnement.dropLast()) : nomEnvironnement

                    if let delimiteur = environnementsMatrice[nomNormalise] {
                        var debutContenu = apresNom
                        // `array` porte ensuite son descriptif de colonnes : `{ccr}`.
                        if nomNormalise == "array" {
                            while debutContenu < latex.count && estEspace(latex[debutContenu]) {
                                debutContenu += 1
                            }
                            if debutContenu < latex.count && latex[debutContenu] == "{" {
                                debutContenu = lireGroupe(latex, debutContenu).suivant
                            }
                        }
                        if let environnement = lireEnvironnement(latex, debutContenu, nomEnvironnement) {
                            let lignes = decouperMatrice(environnement.contenu)
                            if !lignes.isEmpty {
                                let matrice = formatMatrix(
                                    lignes.map { rangee in
                                        rangee.map { cellule in
                                            convertirExpression(cellule)
                                                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                                .trimmingCharacters(in: .whitespaces)
                                        }
                                        .map { $0.isEmpty ? "[illisible]" : $0 }
                                    },
                                    delimiteur
                                )
                                if matrice.contains("\n") && rendu.contains(where: { !estEspace($0) }) {
                                    while rendu.last == " " || rendu.last == "\t" { rendu.removeLast() }
                                    rendu += "\n"
                                }
                                rendu += matrice
                                index = environnement.suivant
                                continue
                            }
                        }
                    }
                    // Environnement inconnu ou incomplet : son nom disparaît,
                    // mais son contenu continue d'être lu.
                    index = apresNom
                    continue
                }
                if nom == "end" {
                    index = lireGroupe(latex, index).suivant
                    continue
                }
                if nom == "\\" {
                    rendu += "\n"
                    continue
                }
                if nom == "frac" || nom == "dfrac" || nom == "tfrac" {
                    let numerateur = lireGroupe(latex, index)
                    let denominateur = lireGroupe(latex, numerateur.suivant)
                    index = denominateur.suivant
                    rendu += fraction(
                        convertirExpression(numerateur.contenu),
                        convertirExpression(denominateur.contenu)
                    )
                    continue
                }
                if nom == "sqrt" {
                    // Racine n-ième : `\sqrt[3]{x}` porte son indice en exposant.
                    var indice = ""
                    if index < latex.count && latex[index] == "[" {
                        if let fin = latex[index...].firstIndex(of: "]") {
                            indice = enScript(String(latex[(index + 1)..<fin]), superscripts) ?? ""
                            index = fin + 1
                        }
                    }
                    let argument = lireGroupe(latex, index)
                    index = argument.suivant
                    rendu += "\(indice)√\(grouper(convertirExpression(argument.contenu)))"
                    continue
                }
                if nom == "mathbb" || nom == "mathbf" || nom == "mathrm" || nom == "text"
                    || nom == "mathcal" || nom == "mathscr" || nom == "operatorname" {
                    let argument = lireGroupe(latex, index)
                    index = argument.suivant
                    let contenu = argument.contenu.trimmingCharacters(in: .whitespacesAndNewlines)
                    if nom == "mathbb" {
                        rendu += ajourees[contenu] ?? argument.contenu
                    } else if nom == "mathcal" || nom == "mathscr" {
                        rendu += rondes[contenu] ?? argument.contenu
                    } else {
                        rendu += convertirExpression(argument.contenu)
                    }
                    continue
                }
                if stylesIgnores.contains(nom) { continue }
                if nom == "xrightarrow" || nom == "xleftarrow" {
                    var sous = ""
                    if index < latex.count && latex[index] == "[" {
                        if let fin = latex[index...].firstIndex(of: "]") {
                            sous = enScript(String(latex[(index + 1)..<fin]), subscripts) ?? ""
                            index = fin + 1
                        }
                    }
                    let sur = lireGroupe(latex, index)
                    index = sur.suivant
                    rendu += "\(nom == "xrightarrow" ? "⟶" : "⟵")\(sous)\(enScript(convertirExpression(sur.contenu), superscripts) ?? "")"
                    continue
                }
                // Une accolade horizontale n'a pas d'équivalent en ligne : seul
                // son contenu compte.
                if nom == "underbrace" || nom == "overbrace" {
                    let argument = lireGroupe(latex, index)
                    index = argument.suivant
                    rendu += grouper(convertirExpression(argument.contenu))
                    continue
                }
                // `\underset{sous}{base}` : la base porte le sens, l'étiquette suit.
                if nom == "underset" || nom == "overset" {
                    let etiquette = lireGroupe(latex, index)
                    let base = lireGroupe(latex, etiquette.suivant)
                    index = base.suivant
                    let table = nom == "underset" ? subscripts : superscripts
                    rendu += "\(convertirExpression(base.contenu))\(enScript(convertirExpression(etiquette.contenu), table) ?? "")"
                    continue
                }
                if nom == "binom" || nom == "dbinom" || nom == "tbinom" {
                    let haut = lireGroupe(latex, index)
                    let bas = lireGroupe(latex, haut.suivant)
                    index = bas.suivant
                    rendu += "C(\(convertirExpression(haut.contenu)), \(convertirExpression(bas.contenu)))"
                    continue
                }
                if nom == "left" || nom == "right" || nom == "middle" || taillesDelimiteur.contains(nom) {
                    // Ces commandes ne font que dimensionner le délimiteur suivant.
                    let groupe = lireGroupe(latex, index)
                    index = groupe.suivant
                    rendu += rendreDelimiteur(groupe.contenu)
                    continue
                }
                if nom == "overline" || nom == "bar" || nom == "widehat" || nom == "hat"
                    || nom == "tilde" || nom == "widetilde" {
                    let argument = lireGroupe(latex, index)
                    index = argument.suivant
                    // Diacritique combinant : il se pose sur le caractère précédent.
                    let marque: String
                    if nom == "overline" || nom == "bar" {
                        marque = "\u{0304}"
                    } else if nom == "tilde" || nom == "widetilde" {
                        marque = "\u{0303}"
                    } else {
                        marque = "\u{0302}"
                    }
                    rendu += convertirExpression(argument.contenu).map { "\($0)\(marque)" }.joined()
                    continue
                }
                if let espacement = espacements[nom] {
                    rendu += espacement
                    continue
                }
                if let symbole = symboles[nom] {
                    rendu += symbole
                    continue
                }
                if let delimiteur = delimiteurs[nom] {
                    rendu += delimiteur
                    continue
                }
                if nom == "|" {
                    rendu += "‖"
                    continue
                }
                if operateurs.contains(nom) {
                    rendu += nom
                    continue
                }
                // Commande inconnue : son nom vaut mieux qu'une barre oblique
                // orpheline.
                rendu += nom
                continue
            }

            if caractere == "^" || caractere == "_" {
                let argument = lireGroupe(latex, index + 1)
                index = argument.suivant
                let converti = convertirExpression(argument.contenu)
                let table = caractere == "^" ? superscripts : subscripts
                let script = enScript(converti, table)
                // Sans équivalent Unicode — `lim` sous condition, exposant en
                // lettres — la notation reste explicite : `lim_(x→+∞)`.
                rendu += script ?? "\(caractere)(\(converti.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)))"
                continue
            }

            if caractere == "{" || caractere == "}" {
                if preserverAccoladesLitterales { rendu += caractere }
                index += 1
                continue
            }
            if caractere == "~" {
                rendu += " "
                index += 1
                continue
            }
            if caractere == "&" {
                rendu += " "
                index += 1
                continue
            }

            rendu += caractere
            index += 1
        }

        return rendu
    }
}

private extension String {
    /// Complète à droite jusqu'à la largeur donnée (alignement de colonnes).
    func padding(toWidth largeur: Int, atStart: Bool) -> String {
        guard count < largeur else { return self }
        let remplissage = String(repeating: " ", count: largeur - count)
        return atStart ? remplissage + self : self + remplissage
    }
}
