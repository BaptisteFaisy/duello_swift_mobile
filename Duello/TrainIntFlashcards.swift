//
//  TrainIntFlashcards.swift
//  Duello
//
//  Lot 16 « intégration de l'onglet Entraînement » (préfixe `TrainInt`).
//
//  Surface « Cartes du cours » d'une matière : menus de sélection du paquet et
//  des chapitres, puis éditeur d'une carte. Présentée en feuille depuis le
//  catalogue, elle n'alourdit pas la liste des chapitres.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 8530-8770) : `FlashcardDropdown`,
//      `FlashcardChapterDropdown` et `FlashcardEditorFields` du panneau
//      « flashcards » du cours.
//
//  Limite assumée : aucune banque de cartes n'est chargée dans cet écran (les
//  cartes d'un cours sont produites à partir du document de cours, hors
//  périmètre du lot). Les menus s'ouvrent donc sur leurs états vides, exactement
//  comme la source tant que le cours n'a pas de flashcards, et l'éditeur permet
//  de composer une carte sans encore la persister.
//
//  Non porté ici : `SubjFlashcardReviewModal` (la révision a besoin d'une file
//  de cartes et du verdict, hors de cette surface).
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Panneau des cartes d'un cours (`CourseFlashcardsPanel`).
struct TrainIntFlashcardsSection: View {
    /// Nom de la matière, transmis à l'éditeur.
    let subjectName: String
    /// Chapitre rattaché à la carte composée.
    let chapterId: String
    let chapterName: String

    @State private var deck = SubjFlashcardSelectionKey.all
    @State private var chapterSelection: SubjFlashcardChapterSelection = .all
    @State private var front = ""
    @State private var back = ""

    /// Paquets de cartes connus de la surface : aucun tant que le cours n'a pas
    /// produit de flashcards.
    private var decks: [CollDeckDefinition] { [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DuelloSectionHeader(title: "Cartes du cours")
            SubjFlashcardChapterDropdown(
                options: [],
                selected: chapterSelection,
                loading: false,
                onSelect: { chapterSelection = $0 }
            )
            SubjFlashcardDropdown(
                label: "Type de flashcards",
                options: decks,
                selected: deck,
                onSelect: { deck = $0 },
                allowAll: true,
                allowNone: true,
                allowCreate: true
            )
            SubjFlashcardEditor(
                front: front,
                back: back,
                chapterId: chapterId,
                chapterName: chapterName,
                subject: subjectName,
                onChangeFront: { front = $0 },
                onChangeBack: { back = $0 }
            )
        }
        .padding(20)
    }
}
