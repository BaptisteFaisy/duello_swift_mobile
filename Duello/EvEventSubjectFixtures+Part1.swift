//
//  EvEventSubjectFixtures+Part1.swift
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

enum EvEventSubjectFixturesPart1 {
    static let all: [EvEventSubject] = [
        EvEventSubject(
            id: "test-evenement-20h00-mpsi-2026-09-23",
            eventId: "test-evenement-20h00-mpsi-2026-09-23",
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
            id: "test-evenement-20h00-mp2i-2026-09-23",
            eventId: "test-evenement-20h00-mp2i-2026-09-23",
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
            id: "test-evenement-20h00-pcsi-2026-09-23",
            eventId: "test-evenement-20h00-pcsi-2026-09-23",
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
            id: "test-evenement-20h00-ptsi-2026-09-23",
            eventId: "test-evenement-20h00-ptsi-2026-09-23",
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
            id: "test-evenement-20h00-mp-2026-09-23",
            eventId: "test-evenement-20h00-mp-2026-09-23",
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
            id: "test-evenement-20h00-mpi-2026-09-23",
            eventId: "test-evenement-20h00-mpi-2026-09-23",
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
            id: "test-evenement-20h00-pc-2026-09-23",
            eventId: "test-evenement-20h00-pc-2026-09-23",
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
            id: "test-evenement-20h00-pt-2026-09-23",
            eventId: "test-evenement-20h00-pt-2026-09-23",
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
            id: "test-evenement-20h00-psi-2026-09-23",
            eventId: "test-evenement-20h00-psi-2026-09-23",
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
            id: "test-evenement-20h00-bcpst-2026-09-23",
            eventId: "test-evenement-20h00-bcpst-2026-09-23",
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
            id: "test-evenement-20h00-bl-2026-09-23",
            eventId: "test-evenement-20h00-bl-2026-09-23",
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
            id: "test-evenement-20h00-ecg-2026-09-23",
            eventId: "test-evenement-20h00-ecg-2026-09-23",
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
            id: "test-evenement-20h00-lycee-2026-09-23",
            eventId: "test-evenement-20h00-lycee-2026-09-23",
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
            id: "test-evenement-15h00-bcpst-2026-09-24",
            eventId: "test-evenement-15h00-bcpst-2026-09-24",
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
            id: "test-evenement-15h00-bl-2026-09-24",
            eventId: "test-evenement-15h00-bl-2026-09-24",
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
            id: "test-evenement-15h00-ecg-2026-09-24",
            eventId: "test-evenement-15h00-ecg-2026-09-24",
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
            id: "test-evenement-15h00-mp-2026-09-24",
            eventId: "test-evenement-15h00-mp-2026-09-24",
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
            id: "test-evenement-15h00-mp2i-2026-09-24",
            eventId: "test-evenement-15h00-mp2i-2026-09-24",
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
            id: "test-evenement-15h00-mpi-2026-09-24",
            eventId: "test-evenement-15h00-mpi-2026-09-24",
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
    ]
}
