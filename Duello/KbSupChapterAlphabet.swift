//
//  KbSupChapterAlphabet.swift
//  Duello
//
//  Alphabet mathématique de chaque chapitre — données générées côté Expo par
//  `npm run exercises:math-keys`, portées telles quelles.
//
//  Fichier source Expo porté :
//    - `src/data/mathKeySuggestions.generated.ts` —
//      `MATH_KEY_CHAPTER_SUGGESTIONS`. Un symbole n'y figure qu'à partir de
//      quatre exercices distincts du chapitre : la liste reste donc la même
//      quand on en retire un, celui que l'élève a ouvert.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

/// `MATH_KEY_CHAPTER_SUGGESTIONS` : alphabet commun aux exercices d'un chapitre.
enum KbSupChapterAlphabet {

    /// Alphabet imposé d'un chapitre ; liste vide si le chapitre est inconnu ou
    /// absent — la table générée de la source rend `[]` dans ce cas, et
    /// `suggestMathKeys` enchaîne alors sur les seules suggestions de l'énoncé.
    static func alphabet(chapterId: String?) -> [String] {
        guard let chapterId, !chapterId.isEmpty else { return [] }
        return alphabets[chapterId] ?? []
    }

    /// Les chapitres de la table générée (`mathKeySuggestions.generated.ts`),
    /// dans l'ordre du fichier source.
    static let alphabets: [String: [String]] = [
        "algebre-bilineaire": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "algebre-complements": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "algebre-lineaire": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "analyse-asymptotique": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "analyse-concours": ["lim x→a", "+∞", "ln", "x²", "∈", "∀", "sin", "ℝ", "uₙ", "cos", "→", "a₁", "ℕ", "√", "Intervalle", "≥"],
        "applications-lineaires": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "arithmetique": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "calcul-derivation": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "calcul-differentiel": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "cayley-hamilton": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "changement-base-trace": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "complements-variables-aleatoires": ["aₖ", "ℕ", "uₙ", "∈", "Ω", "ℙ", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "−", "min", "∑ₖ₌ₐᵇ", "x²"],
        "complexes": ["∈", "x²", "ℝ", "ℕ", "∀", "aₖ", "∑ₖ₌ₐᵇ", "a₁", "≥", "uₙ", "≤", "a₀", "x³", "lim x→a", "√", "ln"],
        "concentration": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "convergence-dominee": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "convergences": ["⋂", "ε", "→", "+∞", "lim x→a", "−", "ℕ", "≤", "aₖ", "a₁", "uₙ", "∑ₖ₌ₐᵇ", "≥", "∈", "x²", "∀"],
        "convexite": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "couples-discrets": ["Ω", "−", "∑ₖ₌ₐᵇ", "ℕ", "+∞", "a₁", "∀", "aₖ", "∈", "x²", "uₙ"],
        "couples-independance": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "couples-vecteurs": ["Cov", "Ω", "ℙ", "∈", "a₁", "λ", "𝔼", "∩", "min", "≥", "↪→", "max", "ℕ", "uₙ", "x²", "ρ"],
        "denombrabilite": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "denombrement": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "derivabilite": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "derivation": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "derivation-successive": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "determinants": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "diagonalisation": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "dimension": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "endomorphismes-symetriques": ["Matrice", "Vect", "⟨ ⟩", "λ", "·", "x⁻¹", "ℝ", "∀", "x²", "≤", "√", "a₁", "uₙ", "∑ₖ₌ₐᵇ", "∈", "aₖ"],
        "ensembles": ["∈", "x²", "ℝ", "ℕ", "∀", "aₖ", "∑ₖ₌ₐᵇ", "a₁", "≥", "uₙ", "≤", "a₀", "x³", "lim x→a", "√", "ln"],
        "ensembles-applications": ["∈", "x²", "ℝ", "ℕ", "∀", "aₖ", "∑ₖ₌ₐᵇ", "a₁", "≥", "uₙ", "≤", "a₀", "x³", "lim x→a", "√", "ln"],
        "equations-differentielles": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "espaces-normes": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "espaces-probabilises": ["Ω", "∩", "−", "aₖ", "∑ₖ₌ₐᵇ", "ℕ", "a₁", "∈"],
        "espaces-probabilises-finis": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "espaces-vectoriels": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "estimation-ponctuelle": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "extrema": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "familles-sommables": ["∑ₖ₌ₐᵇ", "uₙ", "+∞", "≥", "a₁", "x²", "∈", "ln", "∼", "aₖ", "ℝ", "≤", "α", "∫ₐᵇ", "a₀", "uₙ₊₁"],
        "fonctions-deux-variables": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "fonctions-generatrices": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "fonctions-plusieurs-variables": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "fonctions-usuelles": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "fonctions-vectorielles": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "fractions-rationnelles": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "integrales-impropres": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "integration": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "integration-annee-2": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "integration-intervalle": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "limites-continuite": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "logique": ["∈", "x²", "ℝ", "ℕ", "∀", "aₖ", "∑ₖ₌ₐᵇ", "a₁", "≥", "uₙ", "≤", "a₀", "x³", "lim x→a", "√", "ln"],
        "matrices": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "matrices-applications-lineaires": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "matrices-determinants": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "polynomes": ["π", "ℝ", "∀", "x⁻¹", "≤", "aₖ", "∈", "x²", "uₙ", "a₀", "a₁"],
        "probabilites": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "raisonnement": ["∈", "x²", "∑ₖ₌ₐᵇ", "aₖ", "ℕ", "ℝ", "a₁", "≥", "∀", "≤", "a₀", "uₙ", "∃", "x³", "x⁻¹", "∏ₖ₌ₐᵇ"],
        "reels": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "series": ["−", "→", "+∞", "≤", "lim x→a", "∑ₖ₌ₐᵇ", "≥", "ℕ", "a₁", "uₙ", "∈"],
        "series-entieres": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "series-numeriques": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "sommes-produits": ["∈", "x²", "ℝ", "ℕ", "∀", "aₖ", "∑ₖ₌ₐᵇ", "a₁", "≥", "uₙ", "≤", "a₀", "x³", "lim x→a", "√", "ln"],
        "structures-algebriques": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "structures-arithmetique": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "suites": ["uₙ", "uₙ₊₁", "a₁", "∈", "ℕ", "a₀", "lim x→a", "∀", "x²", "≥", "≤", "→", "√", "+∞", "aₖ", "∑ₖ₌ₐᵇ"],
        "suites-series-fonctions": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "systemes-differentiels": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "systemes-lineaires": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "taylor": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "taylor-developpements-limites": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "topologie": ["uₙ", "a₁", "uₙ₊₁", "∈", "ℕ", "a₀", "lim x→a", "≥", "x²", "∑ₖ₌ₐᵇ", "+∞", "≤", "∀", "aₖ", "ln", "→"],
        "valeurs-propres": ["Matrice", "x⁻¹", "ker", "ℝ", "λ", "·", "≤", "‖ ‖", "Vect", "∈", "−", "dim", "⟨ ⟩", "∀", "aₖ", "a₁"],
        "variables-aleatoires": ["Ω", "ℙ", "∈", "Cov", "a₁", "∩", "≥", "λ", "𝔼", "ℕ", "uₙ", "−", "min", "∑ₖ₌ₐᵇ", "aₖ", "x²"],
        "variables-densite": ["∫ₐᵇ", "→", "+∞", "ℝ", "lim x→a", "a₀", "x²", "∈"],
        "variables-discretes": ["Ω", "−", "·", "+∞", "∼", "∑ₖ₌ₐᵇ", "≤", "≥", "lim x→a", "aₖ", "→", "a₁", "⋃", "×", "uₙ", "f′"],
    ]
}
