//
//  EvEventSubjectFixtures+Part3.swift
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

enum EvEventSubjectFixturesPart3 {
    static let all: [EvEventSubject] = [
        EvEventSubject(
            id: "test-addition-parentheses-22h40-2026-09-27",
            eventId: "test-addition-parentheses-22h40-2026-09-27",
            title: "Additions avec parenthèses",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule (12 + 8) + 5.",
                    solution: "12 + 8 = 20, puis 20 + 5 = 25."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 12 + (8 + 5).",
                    solution: "8 + 5 = 13, puis 12 + 13 = 25."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 7 + (3 + 4) + 2.",
                    solution: "3 + 4 = 7, puis 7 + 7 = 14, puis 14 + 2 = 16."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule (30 − 12) + 8.",
                    solution: "30 − 12 = 18, puis 18 + 8 = 26."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 45 + (10 + 15).",
                    solution: "10 + 15 = 25, puis 45 + 25 = 70."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule (9 + 6) + (4 + 5).",
                    solution: "9 + 6 = 15 et 4 + 5 = 9, puis 15 + 9 = 24."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 100 − (25 + 15).",
                    solution: "25 + 15 = 40, puis 100 − 40 = 60."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule (2 + 3) × 4.",
                    solution: "2 + 3 = 5, puis 5 × 4 = 20."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 6 + (2 × 7).",
                    solution: "La parenthèse se calcule d’abord : 2 × 7 = 14, puis 6 + 14 = 20."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule (50 + 20) − (30 − 10).",
                    solution: "50 + 20 = 70 et 30 − 10 = 20, puis 70 − 20 = 50."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-durees-22h50-2026-09-27",
            eventId: "test-addition-durees-22h50-2026-09-27",
            title: "Additions de durées",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 1 h 20 min + 40 min.",
                    solution: "20 min + 40 min = 60 min = 1 h, donc 2 h 00 min."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 45 min + 15 min.",
                    solution: "45 min + 15 min = 60 min = 1 h 00 min."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 2 h 30 min + 1 h 15 min.",
                    solution: "30 min + 15 min = 45 min et 2 h + 1 h = 3 h, donc 3 h 45 min."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 10 min + 25 min.",
                    solution: "10 min + 25 min = 35 min."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 3 h 05 min + 2 h 55 min.",
                    solution: "05 min + 55 min = 60 min = 1 h, donc 3 h + 2 h + 1 h = 6 h 00 min."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 1 h 12 min + 48 min.",
                    solution: "12 min + 48 min = 60 min = 1 h, donc 2 h 00 min."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 0 h 50 min + 35 min.",
                    solution: "50 min + 35 min = 85 min = 1 h 25 min, donc 1 h 25 min."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 2 h 15 min + 45 min.",
                    solution: "15 min + 45 min = 60 min = 1 h, donc 3 h 00 min."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 5 h 40 min + 1 h 25 min.",
                    solution: "40 min + 25 min = 65 min = 1 h 05 min, donc 7 h 05 min."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule 7 min + 53 min.",
                    solution: "7 min + 53 min = 60 min = 1 h 00 min."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-argent-23h00-2026-09-27",
            eventId: "test-addition-argent-23h00-2026-09-27",
            title: "Additions d’argent",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 2,50 € + 3,50 €.",
                    solution: "2,50 € + 3,50 € = 6,00 €."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 1,20 € + 0,80 €.",
                    solution: "1,20 € + 0,80 € = 2,00 €."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 12,99 € + 7,01 €.",
                    solution: "12,99 € + 7,01 € = 20,00 €."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 4,05 € + 0,95 €.",
                    solution: "4,05 € + 0,95 € = 5,00 €."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 15,00 € + 15,00 €.",
                    solution: "15,00 € + 15,00 € = 30,00 €."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 0,30 € + 0,70 €.",
                    solution: "0,30 € + 0,70 € = 1,00 €."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 8,45 € + 6,55 €.",
                    solution: "8,45 € + 6,55 € = 15,00 €."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 19,90 € + 5,10 €.",
                    solution: "19,90 € + 5,10 € = 25,00 €."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 6,75 € + 3,25 €.",
                    solution: "6,75 € + 3,25 € = 10,00 €."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule 2,10 € + 2,20 € + 2,30 €.",
                    solution: "2,10 € + 2,20 € = 4,30 € puis 4,30 € + 2,30 € = 6,60 €."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-unites-23h10-2026-09-27",
            eventId: "test-addition-unites-23h10-2026-09-27",
            title: "Additions avec des unités de mesure",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 3 m + 4 m.",
                    solution: "3 m + 4 m = 7 m."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule 1 m 50 cm + 2 m 25 cm.",
                    solution: "50 cm + 25 cm = 75 cm, donc 3 m 75 cm."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule 250 g + 175 g.",
                    solution: "250 g + 175 g = 425 g."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 2 km + 3 km 500 m.",
                    solution: "2 km + 3 km = 5 km, donc 5 km 500 m."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule 5 m + 95 cm.",
                    solution: "5 m + 95 cm = 5 m 95 cm."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 1 kg + 250 g.",
                    solution: "1 kg + 250 g = 1 kg 250 g."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule 120 cm + 80 cm.",
                    solution: "120 cm + 80 cm = 200 cm = 2 m."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 7 m 30 cm + 1 m 70 cm.",
                    solution: "30 cm + 70 cm = 100 cm = 1 m, donc 9 m 00 cm."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule 600 g + 400 g.",
                    solution: "600 g + 400 g = 1 000 g = 1 kg."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule 2 m 5 cm + 3 m 95 cm.",
                    solution: "5 cm + 95 cm = 100 cm = 1 m, donc 6 m 00 cm."
                ),
            ]
        ),
        EvEventSubject(
            id: "test-addition-relatifs-23h20-2026-09-27",
            eventId: "test-addition-relatifs-23h20-2026-09-27",
            title: "Additions de nombres relatifs",
            durationMinutes: 5,
            questions: [
                EvEventQuestion(
                    id: "q1",
                    label: "Question 1",
                    points: 2,
                    statement: "Calcule 3 + 4.",
                    solution: "3 + 4 = 7."
                ),
                EvEventQuestion(
                    id: "q2",
                    label: "Question 2",
                    points: 2,
                    statement: "Calcule (−5) + 2.",
                    solution: "(−5) + 2 = −3."
                ),
                EvEventQuestion(
                    id: "q3",
                    label: "Question 3",
                    points: 2,
                    statement: "Calcule (−7) + 3.",
                    solution: "(−7) + 3 = −4."
                ),
                EvEventQuestion(
                    id: "q4",
                    label: "Question 4",
                    points: 2,
                    statement: "Calcule 8 + (−5).",
                    solution: "8 + (−5) = 3."
                ),
                EvEventQuestion(
                    id: "q5",
                    label: "Question 5",
                    points: 2,
                    statement: "Calcule (−10) + 4.",
                    solution: "(−10) + 4 = −6."
                ),
                EvEventQuestion(
                    id: "q6",
                    label: "Question 6",
                    points: 2,
                    statement: "Calcule 6 + (−6).",
                    solution: "6 + (−6) = 0."
                ),
                EvEventQuestion(
                    id: "q7",
                    label: "Question 7",
                    points: 2,
                    statement: "Calcule (−2) + (−9).",
                    solution: "(−2) + (−9) = −11."
                ),
                EvEventQuestion(
                    id: "q8",
                    label: "Question 8",
                    points: 2,
                    statement: "Calcule 15 + (−20).",
                    solution: "15 + (−20) = −5."
                ),
                EvEventQuestion(
                    id: "q9",
                    label: "Question 9",
                    points: 2,
                    statement: "Calcule (−12) + 20.",
                    solution: "(−12) + 20 = 8."
                ),
                EvEventQuestion(
                    id: "q10",
                    label: "Question 10",
                    points: 2,
                    statement: "Calcule (−3) + 3 + 4.",
                    solution: "(−3) + 3 = 0 puis 0 + 4 = 4."
                ),
            ]
        ),
    ]
}
