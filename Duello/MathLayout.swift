//
//  MathLayout.swift
//  Duello
//
//  Port de `src/utils/mathLayout.ts` (RN) — reconstruction de la mise en page
//  d'une lecture ML Kit.
//
//  ML Kit rend des lignes de texte : il ignore qu'un « 2 » plus petit et plus
//  haut que ses voisins est un exposant, ou qu'un trait horizontal sépare un
//  numérateur d'un dénominateur. Cette couche relit les boîtes englobantes pour
//  rétablir ce que la géométrie de la copie disait déjà. Elle reste prudente :
//  chaque règle exige plusieurs indices concordants et rend la ligne inchangée
//  au moindre doute.
//
//  Ce fichier porte les types de la lecture et `rebuildLine` (scripts) ;
//  `MathLayoutBlocks.swift` assemble les blocs et les fractions,
//  `MathLayoutNormalize.swift` remet la notation ASCII en notation
//  mathématique. Découpage imposé par le ratchet (≤ 10 fonctions par fichier).
//
//  Les tables `SUPERSCRIPTS`/`SUBSCRIPTS` et `toScript` sont déjà portées par
//  `MathKbScript.swift` : elles ne sont pas dupliquées ici.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Boîte englobante d'un élément de lecture (`OcrBox`).
struct OcrBox: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

/// Élément d'une ligne (`OcrElement`).
struct OcrElement: Equatable {
    var text: String
    var boundingBox: OcrBox
}

/// Ligne de lecture (`OcrLine`).
struct OcrLine: Equatable {
    var text: String
    var boundingBox: OcrBox
    var elements: [OcrElement]?
}

/// Bloc de lecture (`OcrBlock`).
struct OcrBlock: Equatable {
    var text: String
    var boundingBox: OcrBox
    var lines: [OcrLine]?
}

/// Résultat complet d'une lecture (`OcrResult`).
struct OcrResult: Equatable {
    var blocks: [OcrBlock]?
}

/// Nature d'un caractère décalé par rapport au corps de la ligne.
enum MathLayoutScriptKind {
    case exposant
    case indice
}

/// Reconstruction de la mise en page d'une lecture ML Kit (`mathLayout.ts`).
enum MathLayout {

    /// Au-delà de cette part de la hauteur du corps, le caractère est sur la
    /// ligne.
    static let scriptMaxHeightRatio = 0.78
    /// Décalage vertical minimal exigé, en fraction de la hauteur du corps.
    static let scriptMinShiftRatio = 0.16

    /// `rebuildLine` : recolle exposants et indices sur le terme qui les porte.
    ///
    /// Rend `line.text` tel quel dès qu'aucun caractère n'a été reconnu comme
    /// script : la lecture ML Kit reste la référence, on ne la réécrit que pour
    /// gagner quelque chose.
    static func rebuildLine(_ line: OcrLine) -> String {
        let brut = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let elements = (line.elements ?? []).filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if elements.count < 2 { return brut }

        let ordonnes = elements.sorted { $0.boundingBox.x < $1.boundingBox.x }
        let hauteurCorps = median(ordonnes.map { $0.boundingBox.height })
        let centreCorps = median(
            ordonnes.map { $0.boundingBox.y + $0.boundingBox.height / 2 })
        if hauteurCorps <= 0 { return brut }

        var rendu = ""
        var reconstruit = false
        for (index, element) in ordonnes.enumerated() {
            let texte = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Le premier élément d'une ligne ne peut pas être l'exposant de quoi
            // que ce soit : sans terme à sa gauche, c'est une lecture ordinaire.
            let script = index == 0
                ? nil
                : scriptKind(element, bodyHeight: hauteurCorps, bodyCenter: centreCorps)
            let converti = script.flatMap { kind in
                MathKbScript.toScript(
                    texte,
                    kind == .exposant ? MathKbScript.superscripts : MathKbScript.subscripts
                )
            }
            if let converti {
                rendu += converti
                reconstruit = true
                continue
            }
            rendu += rendu.isEmpty ? texte : " \(texte)"
        }
        return reconstruit ? rendu : brut
    }

    /// `median` : médiane d'une liste de nombres (`0` si la liste est vide).
    ///
    /// La médiane sert de référence plutôt que la moyenne : un seul exposant ne
    /// doit pas déplacer la ligne de corps qu'il est censé quitter.
    static func median(_ values: [Double]) -> Double {
        if values.isEmpty { return 0 }
        let ordonnees = values.sorted()
        let milieu = ordonnees.count / 2
        return ordonnees.count % 2 == 1
            ? ordonnees[milieu]
            : (ordonnees[milieu - 1] + ordonnees[milieu]) / 2
    }

    /// `bas` : bas d'une boîte.
    static func bas(_ box: OcrBox) -> Double { box.y + box.height }

    /// `repererScript` : caractère petit et décalé verticalement par rapport au
    /// corps de la ligne.
    static func scriptKind(
        _ element: OcrElement,
        bodyHeight: Double,
        bodyCenter: Double
    ) -> MathLayoutScriptKind? {
        let height = element.boundingBox.height
        if height <= 0 || height > bodyHeight * scriptMaxHeightRatio { return nil }

        let centre = element.boundingBox.y + height / 2
        let decalage = bodyCenter - centre // positif : au-dessus du corps
        let minimum = bodyHeight * scriptMinShiftRatio

        if decalage >= minimum { return .exposant }
        if -decalage >= minimum { return .indice }
        return nil
    }
}
