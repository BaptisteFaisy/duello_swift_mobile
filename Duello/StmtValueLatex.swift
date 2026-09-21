import Foundation

/// Composition LaTeX d'une réponse écrite au clavier maths — port de
/// `src/utils/mathAnswerLatex.ts`.
///
/// Le clavier pose de l'Unicode ; ce module rend en LaTeX les mathématiques
/// d'une réponse, délimite les formules, les réécrit entre `$…$`, et laisse la
/// prose intacte.
enum StmtValueLatex {
    /// Table Unicode → commande LaTeX (inverse de `SYMBOLES` puis `AJOUREES`).
    static let unicodeToLatex: [Character: String] = buildUnicodeToLatex()

    /// Symboles que le clavier pose et que la table LaTeX du dépôt ne connaît pas.
    static let keyboardSymbols: [Character: String] = [
        "𝕍": "\\mathbb{V}", "⟦": "[\\![", "⟧": "]\\!]",
        "⌊": "\\lfloor ", "⌋": "\\rfloor ", "⌈": "\\lceil ", "⌉": "\\rceil ",
        "⟨": "\\langle ", "⟩": "\\rangle ", "‖": "\\|", "│": "|",
        "∴": "\\therefore ", "∁": "\\complement ", "∗": "*",
    ]

    /// Caractères que LaTeX lit comme de la syntaxe.
    static let escaped: [Character: String] = [
        "\\": "\\backslash ", "{": "\\{", "}": "\\}", "$": "\\$",
        "&": "\\&", "#": "\\#", "%": "\\%",
    ]

    /// Fonctions que KaTeX compose déjà droites, sans qu'on les nomme.
    static let builtinFunctions: Set<String> = [
        "ln", "log", "exp", "cos", "sin", "tan", "cosh", "sinh", "tanh",
        "arccos", "arcsin", "arctan", "lim", "sup", "inf", "max", "min",
        "det", "dim", "ker", "deg", "gcd",
    ]

    /// Fonctions de la notation française que KaTeX ne connaît pas.
    static let namedFunctions: Set<String> = [
        "ch", "sh", "th", "rg", "tr", "Tr", "Card", "Vect", "Im", "Re", "Ker",
        "pgcd", "ppcm", "id", "Var", "Cov", "com", "Mat", "rang", "sgn",
    ]

    /// Environnement LaTeX associé à un délimiteur de matrice.
    static let matrixEnvironments: [StmtMatrixDelimiter: String] = [
        .square: "bmatrix", .round: "pmatrix", .braces: "Bmatrix",
        .bars: "vmatrix", .doubleBars: "Vmatrix", .leftBrace: "cases", .none: "matrix",
    ]

    /// Marqueurs à argument : ce qui suit forme un groupe, parenthésé ou non.
    static let argumentMarkers: [Character: (String) -> String] = [
        "^": { "^{\($0)}" },
        "_": { "_{\($0)}" },
        "√": { "\\sqrt{\($0)}" },
    ]

    /// Table de scripts et son marqueur.
    struct ScriptedTable {
        var table: [Character: String]
        var marker: Character
    }

    /// Rend en LaTeX une valeur courte écrite au clavier maths (`mathValueToLatex`).
    static func mathValueToLatex(_ value: String) -> String {
        let characters = Array(value)
        var latex = ""
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if StmtRegex.contains("[a-zA-Z]", in: String(character)) {
                let run = letterRun(characters, index)
                latex += run.text
                index = run.next
                continue
            }
            if let scripted = scriptedTable(for: character) {
                let run = scriptRun(characters, index, scripted)
                latex += run.text
                index = run.next
                continue
            }
            if let marker = argumentMarkers[character] {
                let argument = argumentAt(characters, index + 1)
                latex += marker(mathValueToLatex(argument.value))
                index = argument.next
                continue
            }
            latex += plainLatex(character)
            index += 1
        }
        return latex
    }

    /// Groupe entre parenthèses, sinon le caractère suivant (`argumentAt`).
    static func argumentAt(_ characters: [Character], _ index: Int) -> (value: String, next: Int) {
        if index >= characters.count { return ("", index) }
        if characters[index] != "(" { return (String(characters[index]), index + 1) }
        var depth = 0
        var end = index
        while end < characters.count {
            if characters[end] == "(" { depth += 1 }
            if characters[end] == ")" {
                depth -= 1
                if depth == 0 { return (String(characters[(index + 1)..<end]), end + 1) }
            }
            end += 1
        }
        return (String(characters[(index + 1)...]), characters.count)
    }

    /// Rendu LaTeX d'une matrice (`matrixToLatex`).
    static func matrixToLatex(_ matrix: StmtParsedMatrix) -> String {
        let environment = matrixEnvironments[matrix.delimiter] ?? "matrix"
        let rows = matrix.rows
            .map { row in row.map { mathValueToLatex($0) }.joined(separator: " & ") }
            .joined(separator: " \\\\ ")
        return "\\begin{\(environment)}\(rows)\\end{\(environment)}"
    }

    /// Rendu LaTeX d'un opérateur guidé (`operatorToLatex`).
    static func operatorToLatex(_ op: StmtParsedMathOperator) -> String {
        let values = op.values
        if op.kind == .limit {
            return "\\lim\\limits_{\(mathValueToLatex(values["variable"] ?? "")) \\to \(mathValueToLatex(values["target"] ?? ""))}"
        }
        if op.kind == .exponent {
            return "^{\(mathValueToLatex(values["exponent"] ?? ""))}"
        }
        if op.kind == .integral {
            return "\\int_{\(mathValueToLatex(values["lower"] ?? ""))}^{\(mathValueToLatex(values["upper"] ?? ""))}"
        }
        let symbol = op.kind == .sum ? "\\sum" : "\\prod"
        return "\(symbol)\\limits_{\(mathValueToLatex(values["index"] ?? "")) = \(mathValueToLatex(values["lower"] ?? ""))}^{\(mathValueToLatex(values["upper"] ?? ""))}"
    }

    // MARK: Internes

    /// Construit la table Unicode → LaTeX (`SYMBOLES` puis `AJOUREES`).
    static func buildUnicodeToLatex() -> [Character: String] {
        var map: [Character: String] = [:]
        for (name, character) in LatexToUnicode.symboles where character.count == 1 {
            guard let key = character.first else { continue }
            if map[key] == nil { map[key] = "\\\(name)" }
        }
        for (name, character) in LatexToUnicode.ajourees where character.count == 1 {
            guard let key = character.first else { continue }
            if map[key] == nil { map[key] = "\\mathbb{\(name)}" }
        }
        map["−"] = "-"
        map["′"] = "'"
        for (ratio, character) in LatexToUnicode.fractions where character.count == 1 {
            guard let key = character.first else { continue }
            let parts = ratio.components(separatedBy: "/")
            if map[key] == nil, parts.count == 2 { map[key] = "\\frac{\(parts[0])}{\(parts[1])}" }
        }
        return map
    }

    /// Table de scripts applicable à un caractère, ou `nil`.
    static func scriptedTable(for character: Character) -> ScriptedTable? {
        if StmtOperatorParse.fromSuperscript[character] != nil {
            return ScriptedTable(table: StmtOperatorParse.fromSuperscript, marker: "^")
        }
        if StmtOperatorParse.fromSubscript[character] != nil {
            return ScriptedTable(table: StmtOperatorParse.fromSubscript, marker: "_")
        }
        return nil
    }

    /// Suite de lettres : fonction connue, ou lettre isolée.
    static func letterRun(_ characters: [Character], _ index: Int) -> (text: String, next: Int) {
        var end = index
        while end < characters.count && StmtRegex.contains("[a-zA-Z]", in: String(characters[end])) { end += 1 }
        let word = String(characters[index..<end])
        if builtinFunctions.contains(word) { return ("\\\(word) ", end) }
        if namedFunctions.contains(word) { return ("\\operatorname{\(word)}", end) }
        return (String(characters[index]), index + 1)
    }

    /// Suite de caractères scriptés, rendue en un seul groupe.
    static func scriptRun(_ characters: [Character], _ index: Int, _ scripted: ScriptedTable) -> (text: String, next: Int) {
        var run = ""
        var cursor = index
        while cursor < characters.count, let plain = scripted.table[characters[cursor]] {
            run += plain
            cursor += 1
        }
        return ("\(scripted.marker){\(mathValueToLatex(run))}", cursor)
    }

    /// Rendu LaTeX d'un caractère isolé, hors lettre et hors script.
    static func plainLatex(_ character: Character) -> String {
        if let command = unicodeToLatex[character] {
            return StmtRegex.contains("[a-zA-Z]$", in: command) ? command + " " : command
        }
        if let symbol = keyboardSymbols[character] { return symbol }
        if let escaped = escaped[character] { return escaped }
        if let scalar = character.unicodeScalars.first, scalar.value > 127 { return "\\text{\(character)}" }
        return String(character)
    }
}
