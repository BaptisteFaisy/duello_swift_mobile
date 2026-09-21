//
//  EvEventSubjectCatalog.swift
//  Duello
//
//  Sujets des événements : énoncés, corrigés et barème de chaque question.
//  Source de vérité partagée entre l'application et le serveur, portée depuis
//  `shared/event-catalog.mjs` (relu côté Expo par `src/data/eventSubjects.ts`).
//  Les textes mathématiques sont repris mot pour mot, caractère pour caractère.
//
//  Cible : iOS 16. Fichier de données statiques.
//
import Foundation

enum EvEventSubjectCatalog {
    /// Sujets du catalogue partagé (`EVENT_SUBJECTS`), dans l'ordre du fichier.
    static let all: [EvEventSubject] = [
        EvEventSubject(
            id: "concours-blanc-maths-appro-1a-2026-10-04",
            eventId: "concours-blanc-maths-appro-1a-2026-10-04",
            title: "Maths approfondies — 1re année",
            durationMinutes: 60,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 5,
                    statement: "Pour tout entier naturel n, on pose uₙ = (2n + 1)/(n + 1). Étudier la monotonie de la suite (uₙ), puis déterminer sa limite.",
                    solution: "uₙ₊₁ − uₙ = (2n + 3)/(n + 2) − (2n + 1)/(n + 1) = [(2n + 3)(n + 1) − (2n + 1)(n + 2)] / [(n + 1)(n + 2)] = 1/[(n + 1)(n + 2)] > 0. La suite est strictement croissante. uₙ = 2 − 1/(n + 1), donc lim uₙ = 2."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 5,
                    statement: "Soit f la fonction définie sur ]0, +∞[ par f(x) = x ln x − x + 1. Déterminer les variations de f et la valeur de f(1). En déduire l’inégalité ln x ≥ 1 − 1/x pour tout x > 0.",
                    solution: "f′(x) = ln x, négative sur ]0, 1] et positive sur [1, +∞[ : f décroît puis croît, minimum f(1) = 0. Pour x ≥ 1, f ≥ 0 donne ln x ≥ 1 − 1/x ; pour 0 < x ≤ 1, f(x) ≤ 0 et 1 − 1/x ≤ 0, et la convexité de ln donne le même encadrement : l’inégalité reste valable."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 5,
                    statement: "Résoudre sur ℝ l’équation différentielle y′ + 2y = e⁻²ˣ.",
                    solution: "Solution homogène : y = Ce⁻²ˣ. Une solution particulière s’obtient par variation de la constante : yₚ = xe⁻²ˣ. Solutions générales : y = (x + C)e⁻²ˣ, C ∈ ℝ."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 5,
                    statement: "Soit A la matrice [[1, 2], [0, 1]]. Calculer A² puis Aⁿ pour tout entier n ≥ 1.",
                    solution: "A = I + N avec N = [[0, 2], [0, 0]] et N² = 0. Donc A² = 2A − I = [[1, 4], [0, 1]], et par le binôme de Newton Aⁿ = I + nN = [[1, 2n], [0, 1]]."
                ),
            ]
        ),
        EvEventSubject(
            id: "concours-blanc-maths-appro-2a-2026-10-04",
            eventId: "concours-blanc-maths-appro-2a-2026-10-04",
            title: "Maths approfondies — 2e année",
            durationMinutes: 60,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 5,
                    statement: "Soit (uₙ) la suite définie par u₀ = 1 et uₙ₊₁ = uₙ + uₙ²/3. Étudier la convergence de (uₙ).",
                    solution: "La suite est croissante. Si elle convergeait vers ℓ, alors ℓ = ℓ + ℓ²/3 imposerait ℓ = 0, contradictoire avec u₀ = 1 et la croissance. Donc (uₙ) diverge vers +∞ ; plus précisément 1/uₙ₊₁ ≤ 1/uₙ − 1/(3uₙ(uₙ+1)) montre une explosion en 3/n."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 5,
                    statement: "Déterminer la limite de la série de terme général uₙ = ln(1 + 1/n) − 1/(n + 1), puis donner la valeur de la somme partielle comme limite explicite.",
                    solution: "Les sommes partielles télescopent : ∑ₖ₌₁ⁿ ln(1 + 1/k) = ln(n + 1) et ∑ₖ₌₁ⁿ 1/(k + 1) = Hₙ₊₁ − 1, donc Sₙ = ln(n + 1) − Hₙ₊₁ + 1 → 1 car Hₙ₊₁ − ln(n + 1) → γ. La série converge vers 1 − γ."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 5,
                    statement: "Soit f(x) = e⁻¹/ˣ² pour x ≠ 0 et f(0) = 0. Montrer que f est de classe C∞ sur ℝ et que f′(0) = 0.",
                    solution: "Pour x ≠ 0, f est C∞. En 0 : pour x > 0, f(x)/x = e⁻¹/ˣ²/x → 0 (croissances comparées), donc f′(0) = 0 ; de même f est dérivable à gauche. Par récurrence, les dérivées d’ordre n sont de la forme Pₙ(1/x)e⁻¹/ˣ² avec Pₙ polynôme, et tendent toutes vers 0 en 0 : f est C∞ et f′(0) = 0."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 5,
                    statement: "Soit M une matrice de Mₙ(ℝ) telle que M³ = M. Montrer que M est diagonalisable sur ℝ et que ses valeurs propres appartiennent à {−1, 0, 1}.",
                    solution: "Le polynôme X³ − X = X(X − 1)(X + 1) est scindé à racines simples et annule M : M est diagonalisable et Sp(M) ⊂ {−1, 0, 1}."
                ),
            ]
        ),
        EvEventSubject(
            id: "concours-blanc-maths-appli-1a-2026-10-18",
            eventId: "concours-blanc-maths-appli-1a-2026-10-18",
            title: "Maths appliquées — 1re année",
            durationMinutes: 60,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 5,
                    statement: "On lance deux dés équilibrés à six faces. Calculer la probabilité que la somme des deux résultats soit au moins 9.",
                    solution: "Somme 9 : (3,6),(4,5),(5,4),(6,3) ; somme 10 : (4,6),(5,5),(6,4) ; somme 11 : (5,6),(6,5) ; somme 12 : (6,6). Dix cas favorables sur 36, donc P = 10/36 = 5/18."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 5,
                    statement: "Soit X une variable aléatoire suivant une loi binomiale B(10, 0,3). Calculer E(X), V(X) et P(X = 0) (valeur approchée à 10⁻³).",
                    solution: "E(X) = np = 3, V(X) = np(1 − p) = 2,1 et P(X = 0) = 0,7¹⁰ ≈ 0,028."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 5,
                    statement: "Une urne contient 3 boules rouges et 7 boules noires. On tire successivement et sans remise deux boules. Sachant que la seconde est noire, quelle est la probabilité que la première soit rouge ?",
                    solution: "Par la formule de Bayes : P(R₁|N₂) = P(N₂|R₁)P(R₁)/P(N₂) = (7/9 · 3/10)/(7/10) = 3/9 = 1/3."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 5,
                    statement: "Soit A = [[2, 1], [1, 2]]. Déterminer les valeurs propres de A et une base de vecteurs propres.",
                    solution: "χ_A(X) = (X − 2)² − 1 = (X − 1)(X − 3). Valeurs propres 1 et 3 ; vecteurs propres : (1, −1) pour 1 et (1, 1) pour 3."
                ),
            ]
        ),
        EvEventSubject(
            id: "concours-blanc-maths-appli-2a-2026-10-18",
            eventId: "concours-blanc-maths-appli-2a-2026-10-18",
            title: "Maths appliquées — 2e année",
            durationMinutes: 60,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 5,
                    statement: "Soit X ∼ N(μ, σ²). Exprimer P(X > μ + σ) en fonction de la fonction de répartition Φ de la loi normale centrée réduite.",
                    solution: "P(X > μ + σ) = P(Z > 1) = 1 − Φ(1) ≈ 0,1587 avec Z = (X − μ)/σ."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 5,
                    statement: "Un estimateur θ̂ est sans biais et converge en probabilité vers θ. Rappeler les définitions et montrer que θ̂ − θ → 0 en probabilité.",
                    solution: "Sans biais : E(θ̂) = θ. Convergence en probabilité : ∀ε > 0, P(|θ̂ − θ| > ε) → 0. C’est exactement l’énoncé demandé : la convergence de θ̂ vers θ se réécrit θ̂ − θ → 0 en probabilité (inégalité de Markov ou définition directe)."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 5,
                    statement: "Soit (Xₙ) une chaîne de Markov sur {0, 1} de matrice de transition [[1/2, 1/2], [1/4, 3/4]]. Déterminer sa distribution stationnaire.",
                    solution: "π = πP avec π = (a, 1 − a) : a = a/2 + (1 − a)/4 donne 4a = 2a + 1 − a, d’où a = 1/3. Distribution stationnaire π = (1/3, 2/3)."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 5,
                    statement: "On estime la moyenne d’une population par la moyenne empirique X̄ₙ d’un échantillon i.i.d. de variance σ². Donner la variance de X̄ₙ et l’intervalle de confiance asymptotique de niveau 95 %.",
                    solution: "V(X̄ₙ) = σ²/n. IC asymptotique : X̄ₙ ± 1,96·σ/√n, σ estimé par l’écart-type empirique."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-oral-escp-algebre-2026-09-21",
            eventId: "test-oral-escp-algebre-2026-09-21",
            title: "Test — Oral ESCP : algèbre",
            durationMinutes: 10,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 10,
                    statement: "Soit E un espace vectoriel de dimension finie et u un endomorphisme de E qui commute avec tous les projecteurs de E. Montrer que si x ∈ E avec x ≠ 0, alors x est vecteur propre de u.",
                    solution: "Si u commute avec un projecteur p, alors u stabilise Ker p et Im p. Soit x ≠ 0 : on complète x en une base (x, e₂, …, eₙ) de E et on définit la projection pₓ par pₓ(x) = x et pₓ(eᵢ) = 0 pour i ≥ 2. Alors u(x) = u(pₓ(x)) = pₓ(u(x)) ∈ Im(pₓ) = Vect(x), donc u(x) = λₓx : x est vecteur propre de u."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 10,
                    statement: "En déduire que u est une homothétie, c'est-à-dire qu'il existe λ ∈ ℝ tel que u = λid.",
                    solution: "Tout vecteur non nul de E est vecteur propre de u. Par l'absurde, supposons λ ≠ μ deux valeurs propres distinctes : il existe x, y non nuls et indépendants avec u(x) = λx et u(y) = μy. Alors u(x + y) = λx + μy = α(x + y) impose λ = α = μ, contradiction. Il existe donc λ tel que u(x) = λx pour tout x ∈ E."
                ),
            ]
        ),
    ]
}
