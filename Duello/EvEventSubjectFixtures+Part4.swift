//
//  EvEventSubjectFixtures+Part4.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : sujets d'événements de
//  test (fixtures `test-*`), portés depuis `shared/event-catalog.mjs` (relu
//  côté Expo par `src/data/eventSubjects.ts`). Textes mathématiques repris mot
//  pour mot, caractère pour caractère.
//
//  Découpé en parties pour tenir le budget de 500 lignes par fichier ; l'union
//  vit dans `EvEventSubjectFixtures.swift`.
//
//  Cible : iOS 16. Fichier de données statiques.
//
import Foundation

enum EvEventSubjectFixturesPart4 {
    static let all: [EvEventSubject] = [
        EvEventSubject(
            id: "test-addition-multiples-23h30-2026-09-27",
            eventId: "test-addition-multiples-23h30-2026-09-27",
            title: "Additions de multiples",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 2 × 3 + 3 × 4.",
                    solution: "2 × 3 = 6 et 3 × 4 = 12, donc 6 + 12 = 18."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 5 × 6 + 5 × 4.",
                    solution: "5 × 6 = 30 et 5 × 4 = 20, donc 30 + 20 = 50."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 7 × 2 + 8.",
                    solution: "7 × 2 = 14, donc 14 + 8 = 22."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 10 × 4 + 10 × 6.",
                    solution: "10 × 4 = 40 et 10 × 6 = 60, donc 40 + 60 = 100."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 3 × 5 + 3 × 5.",
                    solution: "3 × 5 = 15, donc 15 + 15 = 30."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 4 × 12 + 4 × 8.",
                    solution: "4 × 12 = 48 et 4 × 8 = 32, donc 48 + 32 = 80."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 2 × 21 + 2 × 9.",
                    solution: "2 × 21 = 42 et 2 × 9 = 18, donc 42 + 18 = 60."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 6 × 3 + 6 × 3 + 6.",
                    solution: "6 × 3 = 36, donc 36 + 36 = 72 puis 72 + 6 = 78."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 25 + 25 + 25 + 25.",
                    solution: "25 + 25 = 50, 50 + 25 = 75 et 75 + 25 = 100."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule 9 × 2 + 9 × 8.",
                    solution: "9 × 2 = 18 et 9 × 8 = 72, donc 18 + 72 = 90."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-moyenne-23h40-2026-09-27",
            eventId: "test-addition-moyenne-23h40-2026-09-27",
            title: "Additions et moyenne",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 2, 4 et 6.",
                    solution: "2 + 4 + 6 = 12 et 12 / 3 = 4. La moyenne vaut 4."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 1, 2 et 3.",
                    solution: "1 + 2 + 3 = 6 et 6 / 3 = 2. La moyenne vaut 2."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 5, 5 et 8.",
                    solution: "5 + 5 + 8 = 18 et 18 / 3 = 6. La moyenne vaut 6."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 10, 20 et 30.",
                    solution: "10 + 20 + 30 = 60 et 60 / 3 = 20. La moyenne vaut 20."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 4, 4 et 7.",
                    solution: "4 + 4 + 7 = 15 et 15 / 3 = 5. La moyenne vaut 5."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 3, 6 et 9.",
                    solution: "3 + 6 + 9 = 18 et 18 / 3 = 6. La moyenne vaut 6."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 12, 15 et 18.",
                    solution: "12 + 15 + 18 = 45 et 45 / 3 = 15. La moyenne vaut 15."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 6, 8 et 10.",
                    solution: "6 + 8 + 10 = 24 et 24 / 3 = 8. La moyenne vaut 8."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 2, 3, 4 et 6.",
                    solution: "2 + 3 + 4 + 6 = 15 et 15 / 4 = 3,75. La moyenne vaut 3,75."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule la moyenne des nombres 9, 9, 9 et 3.",
                    solution: "9 + 9 + 9 + 3 = 30 et 30 / 4 = 7,5. La moyenne vaut 7,5."
                ),
            ]
        ),
    ]
}
