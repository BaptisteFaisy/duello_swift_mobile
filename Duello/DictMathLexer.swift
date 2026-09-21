//
//  DictMathLexer.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : découpage de la phrase dictée en mots
//  normalisés (`decouper`), après séparation des symboles collés (`separer`).
//
//  Le moteur ne rend pas que des mots : il écrit déjà « + », « = » ou « x² »
//  quand il entend une formule. Ces caractères sont donc détachés des mots,
//  en retenant lesquels étaient collés (`colle`), puis chaque mot reçoit sa clé
//  sans accent, sa minuscule accentuée et sa ponctuation.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Découpage et normalisation lexicale — `decouper`/`separer` de `speechMath.ts`.
enum DictMathLexer {
    /// Minuscules sans accent : la table de correspondance y est insensible.
    static func sansAccent(_ texte: String) -> String {
        var sortie = String.UnicodeScalarView()
        for scalaire in texte.decomposedStringWithCanonicalMapping.unicodeScalars
        where !(0x0300...0x036F).contains(scalaire.value) {
            sortie.append(scalaire)
        }
        return String(sortie)
    }

    /// Le premier caractère est-il une lettre latine ? — `LETTRE` de la source.
    static func estLettre(_ texte: String) -> Bool {
        guard let scalaire = texte.unicodeScalars.first else { return false }
        return estLettreScalaire(scalaire)
    }

    /// Lettre latine de base ou accentuée (`a-z`, `À-Ö`, `Ø-ö`, `ø-ÿ`).
    static func estLettreScalaire(_ scalaire: Unicode.Scalar) -> Bool {
        switch scalaire.value {
        case 0x41...0x5A, 0x61...0x7A, 0xC0...0xD6, 0xD8...0xF6, 0xF8...0xFF:
            return true
        default:
            return false
        }
    }

    /// Le premier caractère est-il un chiffre ASCII ? — `/\d/` de la source.
    static func estChiffre(_ texte: String) -> Bool {
        guard let scalaire = texte.unicodeScalars.first else { return false }
        return (0x30...0x39).contains(scalaire.value)
    }

    /// Ce caractère est-il un opérateur, plutôt qu'un signe du français ?
    ///
    /// « c'est-à-dire » et « et/ou » portent les mêmes caractères qu'une
    /// soustraction et une fraction : entre deux lettres, ils appartiennent au
    /// mot. Un « - » qui ouvre un mot reste le signe d'un nombre négatif.
    static func estOperateur(_ caractere: Character, avant: String, apres: String, debut: Bool) -> Bool {
        if caractere == "-" || caractere == "/" {
            if estLettre(avant) && estLettre(apres) { return false }
            return !(caractere == "-" && debut && estChiffre(apres))
        }
        return DictMathLexicon.symboles[String(caractere)] != nil
    }

    /// Ponctuation initiale d'un mot — `PONCTUATION_INITIALE`.
    static func ponctuationInitiale(_ texte: String) -> String {
        var sortie = ""
        for caractere in texte {
            if DictMathLexicon.ponctuationInitiale.contains(caractere) {
                sortie.append(caractere)
            } else {
                break
            }
        }
        return sortie
    }

    /// Ponctuation finale d'un mot — `PONCTUATION_FINALE`.
    static func ponctuationFinale(_ texte: String) -> String {
        var sortie = ""
        for caractere in texte.reversed() {
            if DictMathLexicon.ponctuationFinale.contains(caractere) {
                sortie.append(caractere)
            } else {
                break
            }
        }
        return String(sortie.reversed())
    }

    /// Sépare les symboles collés aux mots, en retenant lesquels l'étaient.
    static func separer(_ phrase: String) -> [(texte: String, colle: Bool)] {
        var morceaux: [(texte: String, colle: Bool)] = []

        for bloc in phrase.split(whereSeparator: { $0.isWhitespace }) {
            let caracteres = Array(bloc)
            var courant = ""
            var colle = false

            for index in 0..<caracteres.count {
                let avant = index > 0 ? String(caracteres[index - 1]) : ""
                let apres = index + 1 < caracteres.count ? String(caracteres[index + 1]) : ""
                let caractere = caracteres[index]
                if !estOperateur(caractere, avant: avant, apres: apres, debut: index == 0) {
                    courant.append(caractere)
                    continue
                }
                if !courant.isEmpty {
                    morceaux.append((courant, colle))
                    colle = true
                }
                courant = ""
                morceaux.append((String(caractere), colle))
                colle = true
            }
            if !courant.isEmpty { morceaux.append((courant, colle)) }
        }
        return morceaux
    }

    /// Découpe une phrase en mots normalisés — `decouper` de la source.
    static func decouper(_ phrase: String) -> [DictMot] {
        separer(phrase).map { piece in
            // Un symbole isolé n'a ni ponctuation ni préfixe : « ( » ouvre une
            // parenthèse mathématique, il ne fait pas partie d'une citation.
            if DictMathLexicon.symboles[piece.texte] != nil {
                return DictMot(
                    brut: piece.texte, cle: piece.texte, minuscule: piece.texte,
                    noyau: piece.texte, ponctuation: "", prefixe: "", colle: piece.colle
                )
            }
            let prefixe = ponctuationInitiale(piece.texte)
            let sansPrefixe = String(piece.texte.dropFirst(prefixe.count))
            let ponctuation = ponctuationFinale(sansPrefixe)
            let noyau = String(sansPrefixe.dropLast(ponctuation.count))
            let minuscule = noyau.lowercased()
            let cle = sansAccent(minuscule).replacingOccurrences(of: "’", with: "'")
            return DictMot(
                brut: piece.texte, cle: cle, minuscule: minuscule, noyau: noyau,
                ponctuation: ponctuation, prefixe: prefixe, colle: piece.colle
            )
        }
    }
}
