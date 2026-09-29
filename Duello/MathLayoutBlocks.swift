//
//  MathLayoutBlocks.swift
//  Duello
//
//  Port de `src/utils/mathLayout.ts` (RN) — assemblage des blocs : ordre de
//  lecture, fractions. Les types et `rebuildLine` vivent dans `MathLayout.swift`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension MathLayout {

    /// Numérateur et dénominateur d'une copie manuscrite restent courts.
    static let fractionMaxLength = 24
    /// Part du trait que le terme doit recouvrir pour lui appartenir.
    static let fractionMinOverlap = 0.6
    /// Un trait de fraction est nettement plus large que haut.
    static let fractionMinAspect = 3.0
    /// Deux blocs dont les lignes s'alignent à cette tolérance sont sur la même
    /// rangée.
    static let sameRowRatio = 0.6

    /// `estTraitDeFraction` : que des tirets, et bien plus large que haut.
    static func estTraitDeFraction(_ line: OcrLine) -> Bool {
        let texte = StmtRegex.replaceAll("\\s+", in: line.text, template: "")
        guard StmtRegex.contains("^[-–—_‾]+$", in: texte) else { return false }
        return line.boundingBox.width >= max(line.boundingBox.height, 1) * fractionMinAspect
    }

    /// `recouvrement` : part du plus étroit des deux rectangles couverte par
    /// l'autre, horizontalement.
    static func recouvrement(_ first: OcrBox, _ second: OcrBox) -> Double {
        let gauche = max(first.x, second.x)
        let droite = min(first.x + first.width, second.x + second.width)
        let reference = min(first.width, second.width)
        if reference <= 0 { return 0 }
        return max(0, droite - gauche) / reference
    }

    /// `encadreUneFraction` : le trait sépare-t-il vraiment ces deux lignes ?
    ///
    /// Un soulignement de titre est large et plat lui aussi : on exige que les
    /// deux termes soient courts, centrés sur le trait et collés à lui.
    static func encadreUneFraction(_ trait: OcrLine, _ dessus: OcrLine, _ dessous: OcrLine) -> Bool {
        (dessus.text.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).length
            <= fractionMaxLength
            && (dessous.text.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).length
                <= fractionMaxLength
            && recouvrement(trait.boundingBox, dessus.boundingBox) >= fractionMinOverlap
            && recouvrement(trait.boundingBox, dessous.boundingBox) >= fractionMinOverlap
            && trait.boundingBox.y - bas(dessus.boundingBox) <= dessus.boundingBox.height
            && dessous.boundingBox.y - bas(trait.boundingBox) <= dessous.boundingBox.height
    }

    /// `parentheser` : parenthèse un terme composé ; `a/2` reste plus lisible
    /// que `(a)/(2)`.
    static func parentheser(_ texte: String) -> String {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        if propre.isEmpty { return propre }
        return StmtRegex.contains("^[^\\s+\\-−×÷/=]+$", in: propre) ? propre : "(\(propre))"
    }

    /// `rebuildBlock` : une ligne par entrée, fractions assemblées, traits isolés
    /// écartés.
    static func rebuildBlock(_ block: OcrBlock) -> String {
        let lignes = (block.lines ?? []).filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        var rendu: [String] = []
        /// Indice de la ligne dont le rendu occupe la dernière entrée de `rendu`.
        var dernierIndice = -1
        var index = 0
        while index < lignes.count {
            let ligne = lignes[index]
            if !estTraitDeFraction(ligne) {
                rendu.append(rebuildLine(ligne))
                dernierIndice = index
                index += 1
                continue
            }

            let dessus = index - 1 >= 0 ? lignes[index - 1] : nil
            let dessous = index + 1 < lignes.count ? lignes[index + 1] : nil
            // `dernierIndice` garantit que la dernière entrée est bien le rendu
            // de la ligne du dessus, et non une fraction déjà assemblée.
            if let dessus, let dessous, dernierIndice == index - 1,
               encadreUneFraction(ligne, dessus, dessous) {
                let numerateur = rendu.popLast() ?? ""
                rendu.append("\(parentheser(numerateur))/\(parentheser(rebuildLine(dessous)))")
                dernierIndice = index + 1
                index += 2
                continue
            }

            // Un trait seul n'est pas du texte : le recopier polluerait la
            // lecture.
            index += 1
        }
        return rendu.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// `hauteurDeLigne` : hauteur de la première ligne, sinon du bloc.
    static func hauteurDeLigne(_ block: OcrBlock) -> Double {
        let height = block.lines?.first?.boundingBox.height ?? 0
        return height != 0 ? height : block.boundingBox.height
    }

    /// `comparerBlocs` : ordre de lecture — de haut en bas, puis de gauche à
    /// droite.
    ///
    /// La tolérance vaut une hauteur de ligne, pas la hauteur du bloc : sinon un
    /// long paragraphe engloberait toute la page et tout serait trié par
    /// abscisse.
    static func comparerBlocs(_ first: OcrBlock, _ second: OcrBlock) -> Double {
        let tolerance = min(hauteurDeLigne(first), hauteurDeLigne(second)) * sameRowRatio
        let ecart = first.boundingBox.y - second.boundingBox.y
        if abs(ecart) > tolerance { return ecart }
        return first.boundingBox.x - second.boundingBox.x
    }

    /// `layoutRecognizedText` : assemble la lecture ML Kit en texte, un
    /// paragraphe par bloc.
    static func layoutRecognizedText(_ result: OcrResult) -> String {
        (result.blocks ?? [])
            .sorted { comparerBlocs($0, $1) < 0 }
            .map(rebuildBlock)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
