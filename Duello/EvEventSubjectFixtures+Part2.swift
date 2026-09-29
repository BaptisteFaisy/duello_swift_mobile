//
//  EvEventSubjectFixtures+Part2.swift
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

enum EvEventSubjectFixturesPart2 {
    static let all: [EvEventSubject] = [
        EvEventSubject(
            id: "test-evenement-15h00-mpsi-2026-09-24",
            eventId: "test-evenement-15h00-mpsi-2026-09-24",
            title: "evenementTEST",
            durationMinutes: 10,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 10,
                    statement: "Soit f la fonction définie sur ℝ par f(x) = x²·eˣ. Calculer f′(x).",
                    solution: "f′(x) = 2x·eˣ + x²·eˣ = eˣ(2x + x²) = x(x + 2)eˣ."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 10,
                    statement: "Résoudre sur ℝ l’équation 2x + 3 = 11.",
                    solution: "2x = 8, donc x = 4. Solution unique : 4."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-evenement-15h00-pc-2026-09-24",
            eventId: "test-evenement-15h00-pc-2026-09-24",
            title: "evenementTEST",
            durationMinutes: 10,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 10,
                    statement: "Soit f la fonction définie sur ℝ par f(x) = x²·eˣ. Calculer f′(x).",
                    solution: "f′(x) = 2x·eˣ + x²·eˣ = eˣ(2x + x²) = x(x + 2)eˣ."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 10,
                    statement: "Résoudre sur ℝ l’équation 2x + 3 = 11.",
                    solution: "2x = 8, donc x = 4. Solution unique : 4."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-evenement-15h00-pcsi-2026-09-24",
            eventId: "test-evenement-15h00-pcsi-2026-09-24",
            title: "evenementTEST",
            durationMinutes: 10,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 10,
                    statement: "Soit f la fonction définie sur ℝ par f(x) = x²·eˣ. Calculer f′(x).",
                    solution: "f′(x) = 2x·eˣ + x²·eˣ = eˣ(2x + x²) = x(x + 2)eˣ."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 10,
                    statement: "Résoudre sur ℝ l’équation 2x + 3 = 11.",
                    solution: "2x = 8, donc x = 4. Solution unique : 4."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-evenement-15h00-psi-2026-09-24",
            eventId: "test-evenement-15h00-psi-2026-09-24",
            title: "evenementTEST",
            durationMinutes: 10,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 10,
                    statement: "Soit f la fonction définie sur ℝ par f(x) = x²·eˣ. Calculer f′(x).",
                    solution: "f′(x) = 2x·eˣ + x²·eˣ = eˣ(2x + x²) = x(x + 2)eˣ."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 10,
                    statement: "Résoudre sur ℝ l’équation 2x + 3 = 11.",
                    solution: "2x = 8, donc x = 4. Solution unique : 4."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-evenement-15h00-pt-2026-09-24",
            eventId: "test-evenement-15h00-pt-2026-09-24",
            title: "evenementTEST",
            durationMinutes: 10,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 10,
                    statement: "Soit f la fonction définie sur ℝ par f(x) = x²·eˣ. Calculer f′(x).",
                    solution: "f′(x) = 2x·eˣ + x²·eˣ = eˣ(2x + x²) = x(x + 2)eˣ."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 10,
                    statement: "Résoudre sur ℝ l’équation 2x + 3 = 11.",
                    solution: "2x = 8, donc x = 4. Solution unique : 4."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-evenement-15h00-ptsi-2026-09-24",
            eventId: "test-evenement-15h00-ptsi-2026-09-24",
            title: "evenementTEST",
            durationMinutes: 10,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 10,
                    statement: "Soit f la fonction définie sur ℝ par f(x) = x²·eˣ. Calculer f′(x).",
                    solution: "f′(x) = 2x·eˣ + x²·eˣ = eˣ(2x + x²) = x(x + 2)eˣ."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 10,
                    statement: "Résoudre sur ℝ l’équation 2x + 3 = 11.",
                    solution: "2x = 8, donc x = 4. Solution unique : 4."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-entiers-22h10-2026-09-27",
            eventId: "test-addition-entiers-22h10-2026-09-27",
            title: "Additions d’entiers naturels",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 12 + 7.",
                    solution: "12 + 7 = 19."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 45 + 23.",
                    solution: "45 + 23 = 68."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 86 + 14.",
                    solution: "86 + 14 = 100."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 137 + 62.",
                    solution: "137 + 62 = 199."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 250 + 175.",
                    solution: "250 + 175 = 425."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 308 + 92.",
                    solution: "308 + 92 = 400."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 476 + 524.",
                    solution: "476 + 524 = 1 000."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 615 + 285.",
                    solution: "615 + 285 = 900."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 1 000 + 999.",
                    solution: "1 000 + 999 = 1 999."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule 4 827 + 3 173.",
                    solution: "4 827 + 3 173 = 8 000."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-decimaux-22h20-2026-09-27",
            eventId: "test-addition-decimaux-22h20-2026-09-27",
            title: "Additions de nombres décimaux",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 0,5 + 0,25.",
                    solution: "0,5 + 0,25 = 0,75."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 1,2 + 0,8.",
                    solution: "1,2 + 0,8 = 2."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 3,45 + 2,55.",
                    solution: "3,45 + 2,55 = 6."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 0,7 + 0,03.",
                    solution: "0,7 + 0,03 = 0,73."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 12,5 + 7,5.",
                    solution: "12,5 + 7,5 = 20."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 5,25 + 4,75.",
                    solution: "5,25 + 4,75 = 10."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 2,9 + 0,1.",
                    solution: "2,9 + 0,1 = 3."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 18,35 + 6,65.",
                    solution: "18,35 + 6,65 = 25."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 0,05 + 0,95.",
                    solution: "0,05 + 0,95 = 1."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule 14,2 + 5,8.",
                    solution: "14,2 + 5,8 = 20."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-fractions-22h30-2026-09-27",
            eventId: "test-addition-fractions-22h30-2026-09-27",
            title: "Additions de fractions de même dénominateur",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 1/5 + 2/5.",
                    solution: "Les dénominateurs sont égaux : 1/5 + 2/5 = 3/5."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 1/4 + 2/4.",
                    solution: "1/4 + 2/4 = 3/4."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 2/7 + 3/7.",
                    solution: "2/7 + 3/7 = 5/7."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 3/10 + 5/10.",
                    solution: "3/10 + 5/10 = 8/10 = 4/5."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 1/3 + 1/3.",
                    solution: "1/3 + 1/3 = 2/3."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 5/9 + 4/9.",
                    solution: "5/9 + 4/9 = 9/9 = 1."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 2/6 + 3/6.",
                    solution: "2/6 + 3/6 = 5/6."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 1/8 + 6/8.",
                    solution: "1/8 + 6/8 = 7/8."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 3/11 + 8/11.",
                    solution: "3/11 + 8/11 = 11/11 = 1."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule 7/12 + 5/12.",
                    solution: "7/12 + 5/12 = 12/12 = 1."
                ),
            ]
        ),
    ]
}
