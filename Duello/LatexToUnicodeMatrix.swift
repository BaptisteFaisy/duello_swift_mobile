import Foundation

/// Rendu des environnements matriciels : découpe en lignes (`\\`) et cellules
/// (`&`), puis mise en colonnes alignées avec leurs délimiteurs. `decouperMatrice`
/// et `formatMatrix` sont élargis à `internal` (lus par `LatexToUnicodeRendering`) ;
/// aucun membre n'est renommé.
extension LatexToUnicode {
    // MARK: Matrices

    private static func retirerTraitsDeTableau(_ cellule: String) -> String {
        cellule.replacingOccurrences(
            of: "\\\\(?:hline|hdashline)\\b",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }

    /// Découpe le contenu d'une matrice en lignes (`\\`) et cellules (`&`),
    /// au niveau d'imbrication zéro.
    static func decouperMatrice(_ contenu: String) -> [[String]] {
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

    /// Alignement de colonnes, puis délimiteurs, pour une matrice rendue
    /// en ligne par ligne (équivalent de `formatMatrix`).
    static func formatMatrix(_ rows: [[String]], _ delimiter: String) -> String {
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
}

private extension String {
    /// Complète à droite jusqu'à la largeur donnée (alignement de colonnes).
    func padding(toWidth largeur: Int, atStart: Bool) -> String {
        guard count < largeur else { return self }
        let remplissage = String(repeating: " ", count: largeur - count)
        return atStart ? remplissage + self : self + remplissage
    }
}
