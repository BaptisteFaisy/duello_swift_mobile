// [ProgramECGCultureGenerale] Programme ECG : chapitres de lettres et de philosophie (culture générale).
import Foundation

extension DuelloProgram {

    enum Lettres {
        static let annee1: [TrackChapter] = [
            chapter("methode-dissertation", "Méthode de la dissertation de culture générale"),
            chapter("explication-texte", "Analyse et explication de texte"),
            chapter("antiquite", "L'Antiquité et ses héritages"),
            chapter("courants-litteraires", "Les grands courants littéraires"),
            chapter("theatre", "Le théâtre : formes et enjeux"),
            chapter("roman", "Le roman et le récit"),
            chapter("poesie", "La poésie"),
            chapter("essai", "L'essai et la littérature d'idées"),
            chapter("mythes", "Mythes et grands récits fondateurs"),
            chapter("rhetorique", "Rhétorique et argumentation"),
            chapter("arts", "Repères artistiques : peinture, musique, cinéma"),
            chapter("carnet-references", "Constitution d'un carnet de références littéraires"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("theme-annee", "Le thème de l'année : approche littéraire"),
            chapter("auteurs-reference", "Œuvres et auteurs de référence sur le thème"),
            chapter("theme-theatre", "Le thème dans le théâtre"),
            chapter("theme-roman", "Le thème dans le roman"),
            chapter("theme-poesie", "Le thème dans la poésie"),
            chapter("theme-essai", "Le thème dans l'essai et la littérature d'idées"),
            chapter("theme-arts", "Le thème dans les arts et le cinéma"),
            chapter("corpus-citations", "Constitution d'un corpus de citations"),
            chapter("methode-dissertation", "Méthode de la dissertation"),
            chapter("entrainement-ecrit", "Entraînement en temps limité"),
        ]
    }

    enum Philosophie {
        static let annee1: [TrackChapter] = [
            chapter("methode-dissertation", "Méthode de la dissertation de philosophie"),
            chapter("problematisation", "Analyse et problématisation d'une notion"),
            chapter("philosophie-antique", "Repères antiques : Platon, Aristote, stoïciens, épicuriens"),
            chapter("philosophie-moderne", "Repères modernes : Descartes, Spinoza, Hume, Kant"),
            chapter("philosophie-19e", "Repères du XIXe siècle : Hegel, Marx, Nietzsche, Freud"),
            chapter("philosophie-contemporaine", "Repères contemporains : phénoménologie et philosophie analytique"),
            chapter("connaissance", "La connaissance, la vérité et la science"),
            chapter("sujet-conscience", "Le sujet, la conscience et l'inconscient"),
            chapter("desir-passions", "Le désir et les passions"),
            chapter("liberte", "La liberté et le déterminisme"),
            chapter("morale-devoir", "La morale et le devoir"),
            chapter("justice-droit", "La justice et le droit"),
            chapter("politique-etat", "La politique, l'État et le pouvoir"),
            chapter("travail", "Le travail et l'échange"),
            chapter("technique", "La technique et le progrès"),
            chapter("nature-culture", "La nature et la culture"),
            chapter("langage", "Le langage"),
            chapter("art-beau", "L'art et le beau"),
            chapter("temps-histoire", "Le temps et l'histoire"),
            chapter("autrui", "Autrui et la reconnaissance"),
            chapter("carnet-references", "Constitution d'un carnet de références philosophiques"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("theme-annee", "Le thème de l'année : enjeux philosophiques"),
            chapter("problematisation", "Problématisation et distinctions conceptuelles"),
            chapter("theme-antiquite", "Le thème chez les Anciens"),
            chapter("theme-moderne", "Le thème dans la philosophie moderne"),
            chapter("theme-contemporain", "Le thème dans la philosophie contemporaine"),
            chapter("concepts-cles", "Les concepts clés du thème"),
            chapter("objections", "Objections, limites et débats autour du thème"),
            chapter("corpus-references", "Constitution d'un corpus de références philosophiques"),
            chapter("methode-dissertation", "Méthode de la dissertation"),
            chapter("entrainement-ecrit", "Entraînement en temps limité"),
            chapter("preparation-oral", "Préparation aux oraux"),
        ]
    }
}
