// [ProgramECGLangues] Programme ECG : chapitres de langues vivantes (anglais, LV2).
import Foundation

extension DuelloProgram {

    enum Langues {
        static let anglaisAnnee1: [TrackChapter] = [
            chapter("temps-aspects", "Grammaire : temps et aspects"),
            chapter("modaux", "Grammaire : modaux et expression de l'hypothèse"),
            chapter("voix-passive", "Grammaire : voix passive et structures complexes"),
            chapter("syntaxe", "Syntaxe de la phrase complexe"),
            chapter("vocabulaire-presse", "Vocabulaire de la presse et de l'actualité"),
            chapter("vocabulaire-economie", "Vocabulaire : économie et entreprise"),
            chapter("vocabulaire-societe", "Vocabulaire : société et politique"),
            chapter("vocabulaire-sciences", "Vocabulaire : sciences et technologies"),
            chapter("version", "Version : méthode et entraînement"),
            chapter("theme-grammatical", "Thème grammatical"),
            chapter("comprehension-orale", "Compréhension orale"),
            chapter("essai", "Essai argumenté"),
            chapter("colle", "Colle : présentation d'un article de presse"),
            chapter("civilisation-britannique", "Civilisation britannique : institutions et société"),
            chapter("civilisation-americaine", "Civilisation américaine : institutions et société"),
        ]

        static let anglaisAnnee2: [TrackChapter] = [
            chapter("grammaire-revisions", "Grammaire : révisions et points difficiles"),
            chapter("vocabulaire-presse", "Vocabulaire de la presse et de l'actualité"),
            chapter("vocabulaire-thematique", "Vocabulaire thématique : dossiers du concours"),
            chapter("version", "Version : textes littéraires et journalistiques"),
            chapter("theme-suivi", "Thème suivi"),
            chapter("theme-grammatical", "Thème grammatical"),
            chapter("synthese", "Synthèse de documents"),
            chapter("essai", "Essai argumenté et expression écrite"),
            chapter("comprehension-orale", "Compréhension orale et actualité"),
            chapter("colle", "Colle : revue de presse et discussion"),
            chapter("civilisation", "Civilisation du monde anglophone : dossiers de fond"),
            chapter("entrainement-ecrit", "Entraînement aux épreuves écrites du concours"),
            chapter("entrainement-oral", "Entraînement aux épreuves orales"),
        ]

        static let lv2Annee1: [TrackChapter] = [
            chapter("grammaire-bases", "Grammaire et conjugaison : bases"),
            chapter("grammaire-syntaxe", "Grammaire : syntaxe et subordination"),
            chapter("vocabulaire-quotidien", "Vocabulaire courant et de l'actualité"),
            chapter("vocabulaire-thematique", "Vocabulaire thématique"),
            chapter("comprehension-ecrite", "Compréhension écrite"),
            chapter("comprehension-orale", "Compréhension orale"),
            chapter("version", "Version"),
            chapter("theme", "Thème"),
            chapter("expression-ecrite", "Expression écrite"),
            chapter("expression-orale", "Expression orale et colle"),
            chapter("civilisation", "Civilisation de l'aire linguistique"),
        ]

        static let lv2Annee2: [TrackChapter] = [
            chapter("grammaire-revisions", "Grammaire : révisions et points difficiles"),
            chapter("vocabulaire-actualite", "Vocabulaire de l'actualité et de la presse"),
            chapter("vocabulaire-thematique", "Vocabulaire thématique : dossiers du concours"),
            chapter("version", "Version"),
            chapter("theme", "Thème"),
            chapter("essai", "Essai et expression écrite"),
            chapter("comprehension-orale", "Compréhension orale"),
            chapter("colle", "Colle : présentation d'article et discussion"),
            chapter("civilisation", "Civilisation : dossiers de fond"),
            chapter("entrainement-concours", "Entraînement aux épreuves du concours"),
        ]
    }
}
