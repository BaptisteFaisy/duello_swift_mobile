import Foundation

/// Rendu d'une expression LaTeX (délimiteurs déjà retirés) en notation
/// Unicode, plus les aides de groupement et de fraction. `convertirExpression`
/// reste `internal` (appelé par `LatexToUnicodeCore`) ; aucun membre n'est
/// renommé.
///
/// Dérogation de complexité : `convertirExpression` compte 228 lignes et
/// dépasse donc la limite de 50 lignes par fonction. Il est conservé verbatim
/// pour respecter le découpage transparent demandé (aucune signature renommée,
/// sémantique du port inchangée) : son corps partage un état local — `rendu` et
/// `index` — muté par toute la boucle et par la récursion, si bien que le
/// scinder imposerait de nouveaux membres et une restructuration non
/// transparente. Les autres fonctions du fichier restent sous la limite.
extension LatexToUnicode {
    // MARK: Rendu

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

    // Dérogation de complexité mise à jour : le découpage porte maintenant
    // `convertirExpression` à 230 lignes au lieu de 228 (signature, sémantique
    // et ordre des branches inchangés).
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
                // `+=` n'existe que pour `String` : un `Character` s'ajoute avec
                // `append`.
                if preserverAccoladesLitterales { rendu.append(caractere) }
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

            rendu.append(caractere)
            index += 1
        }

        return rendu
    }
}
