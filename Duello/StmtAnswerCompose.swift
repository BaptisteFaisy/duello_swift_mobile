import Foundation

/// Composition de la réponse écrite dans le champ texte — port de
/// `src/utils/mathAnswerLatex.ts` (délimitation et rendu des formules).
enum StmtAnswerCompose {
    /// Construction rendue à part : sa source ne repasse pas par la conversion.
    struct MathClaim {
        var range: StmtTextSelection
        var latex: String
        var display: Bool
    }

    /// Formule délimitée, prête à rendre.
    struct MathRegion {
        var start: Int
        var end: Int
        var display: Bool
    }

    /// Symboles qui, seuls, ne prouvent pas une formule.
    static let weakSymbols: Set<Character> = Set("…⋯⋮⋱•°′".map { $0 })
        .union(LatexToUnicode.fractions.values.compactMap { $0.first })
    /// Caractères qu'une formule accepte sans la prouver à elle seule.
    static let neutralCharacters: Set<Character> = Set("+-*/=()[]{}<>|!'^_. ,;:%".map { $0 })
    static let trimmedHead: Set<Character> = Set(" ,;:".map { $0 })
    static let trimmedTail: Set<Character> = Set(" .,;:".map { $0 })
    static let trimmedTailAfterSpace: Set<Character> = Set("([{=+-−*/<>×÷±".map { $0 })

    /// Réponse préparée pour la composition, ou `nil` (`composeMathAnswer`).
    static func composeMathAnswer(_ raw: String) -> String? {
        let answer = raw.replacingOccurrences(of: "$", with: "")
        let structures = mathStructures(answer)
        let groupEnds = Dictionary(structures.groups.map { ($0.start, $0.end) }, uniquingKeysWith: { first, _ in first })
        let regions = mathRegions(answer, structures.claims, groupEnds, formulaMask(answer, structures.claims, groupEnds))
        if regions.isEmpty { return nil }
        let chars = Array(answer)
        var composed = ""
        var read = 0
        for region in regions {
            let delimiter = region.display ? "$$" : "$"
            composed += String(chars[read..<region.start])
            composed += "\(delimiter)\(regionLatex(answer, region, structures.claims))\(delimiter)"
            read = region.end
        }
        return composed + String(chars[read...])
    }

    /// Constructions et groupes du texte (`mathStructures`).
    static func mathStructures(_ answer: String) -> (claims: [MathClaim], groups: [StmtTextSelection]) {
        let kept = buildClaims(answer)
        let chars = Array(answer)
        var groups: [StmtTextSelection] = []
        var index = 0
        while index < chars.count {
            if isClaimed(kept, index) {
                index += 1
                continue
            }
            if let end = StmtAnswerSupport.explicitGroupEnd(chars, index) {
                groups.append(StmtTextSelection(start: index, end: end))
                index = end
                continue
            }
            index += 1
        }
        let filtered = kept.filter { claim in
            !groups.contains { group in group.start < claim.range.start && claim.range.end <= group.end }
        }
        return (filtered, groups)
    }

    /// Constructions retenues, sans chevauchement (`matrices` puis `operators`).
    static func buildClaims(_ answer: String) -> [MathClaim] {
        let chars = Array(answer)
        let matrices = StmtMatrixParse.parseMatrices(answer)
            .filter { $0.rows.count > 1 }
            .map { MathClaim(range: $0.range, latex: StmtValueLatex.matrixToLatex($0), display: true) }
        let operators = StmtOperatorParse.parseMathOperators(answer)
            .filter { $0.kind != .exponent }
            .map { op -> MathClaim in
                let end = (op.range.end - 1 >= 0 && op.range.end - 1 < chars.count && chars[op.range.end - 1] == " ")
                    ? op.range.end - 1
                    : op.range.end
                return MathClaim(
                    range: StmtTextSelection(start: op.range.start, end: end),
                    latex: StmtValueLatex.operatorToLatex(op),
                    display: false
                )
            }
        var kept: [MathClaim] = []
        let sorted = (matrices + operators).sorted { first, second in
            first.range.start != second.range.start ? first.range.start < second.range.start : first.range.end > second.range.end
        }
        for claim in sorted {
            if let previous = kept.last, claim.range.start < previous.range.end { continue }
            kept.append(claim)
        }
        return kept
    }

    /// Caractères qui peuvent appartenir à une formule (`formulaMask`).
    static func formulaMask(_ answer: String, _ claims: [MathClaim], _ groups: [Int: Int]) -> [Bool] {
        let chars = Array(answer)
        var mask = [Bool](repeating: false, count: chars.count)
        var index = 0
        while index < chars.count {
            if isClaimed(claims, index) {
                mask[index] = true
                index += 1
                continue
            }
            if let group = groups[index] {
                for at in index..<group { mask[at] = true }
                index = group
                continue
            }
            let character = chars[index]
            if StmtRegex.contains("[a-zA-Z]", in: String(character)) {
                var end = index
                while end < chars.count, StmtRegex.contains("[a-zA-Z]", in: String(chars[end])) { end += 1 }
                let word = String(chars[index..<end])
                let value = word.count == 1
                    || StmtValueLatex.builtinFunctions.contains(word)
                    || StmtValueLatex.namedFunctions.contains(word)
                    || StmtRegex.contains("^d[a-zA-Z]$", in: word)
                for at in index..<end { mask[at] = value }
                index = end
                continue
            }
            mask[index] = character == " "
                ? StmtAnswerSupport.bindsAcrossSpace(chars, index)
                : (StmtRegex.contains("[0-9]", in: String(character)) || neutralCharacters.contains(character) || isMathAtom(character))
            index += 1
        }
        return mask
    }

    /// Formules du texte, délimitées (`mathRegions`).
    static func mathRegions(_ answer: String, _ claims: [MathClaim], _ groups: [Int: Int], _ mask: [Bool]) -> [MathRegion] {
        let chars = Array(answer)
        var regions: [MathRegion] = []
        var index = 0
        while index < chars.count {
            if !mask[index] {
                index += 1
                continue
            }
            var end = index
            while end < chars.count && mask[end] { end += 1 }

            var start = index
            var stop = end
            while start < stop, !isClaimed(claims, start), trimmedHead.contains(chars[start]) { start += 1 }
            while stop > start, !isClaimed(claims, stop - 1) {
                let character = chars[stop - 1]
                if trimmedTail.contains(character) { stop -= 1; continue }
                if trimmedTailAfterSpace.contains(character), stop - 2 >= 0, chars[stop - 2] == " " { stop -= 1; continue }
                break
            }

            var proven = false
            var display = false
            for at in start..<stop {
                if let claim = claims.first(where: { $0.range.start <= at && at < $0.range.end }) {
                    proven = true
                    display = display || claim.display
                    continue
                }
                if groups[at] != nil {
                    proven = true
                } else if isMathAtom(chars[at]) && !weakSymbols.contains(chars[at]) {
                    proven = true
                }
            }
            if proven { regions.append(MathRegion(start: start, end: stop, display: display)) }
            index = end
        }
        return regions
    }

    /// Rend une formule, en gardant les constructions déjà rendues (`regionLatex`).
    static func regionLatex(_ answer: String, _ region: MathRegion, _ claims: [MathClaim]) -> String {
        let chars = Array(answer)
        var latex = ""
        var read = region.start
        for claim in claims {
            if claim.range.start < read || claim.range.end > region.end { continue }
            latex += StmtValueLatex.mathValueToLatex(String(chars[read..<claim.range.start]))
            latex += claim.latex
            read = claim.range.end
        }
        return latex + StmtValueLatex.mathValueToLatex(String(chars[read..<region.end]))
    }

    /// Vrai si la position appartient à l'une des constructions.
    static func isClaimed(_ claims: [MathClaim], _ index: Int) -> Bool {
        claims.contains { $0.range.start <= index && index < $0.range.end }
    }

    /// Vrai si le caractère prouve à lui seul une formule (`isMathAtom`).
    static func isMathAtom(_ character: Character) -> Bool {
        character == "√"
            || StmtValueLatex.unicodeToLatex[character] != nil
            || StmtValueLatex.keyboardSymbols[character] != nil
            || StmtOperatorParse.fromSuperscript[character] != nil
            || StmtOperatorParse.fromSubscript[character] != nil
    }
}
