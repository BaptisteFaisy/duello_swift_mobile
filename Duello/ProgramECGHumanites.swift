// [ProgramECGHumanites] Programme ECG : chapitres ESH et HGG (sciences humaines).
import Foundation

extension DuelloProgram {

    enum ESH {
        static let annee1: [TrackChapter] = [
            chapter("objet-economie", "Module 1 — L'objet et les méthodes de l'économie"),
            chapter("courants-pensee", "Module 1 — Les grands courants de la pensée économique"),
            chapter("production-valeur", "Module 1 — Production, valeur ajoutée et répartition"),
            chapter("monnaie", "Module 1 — La monnaie et sa création"),
            chapter("financement", "Module 1 — Le financement de l'économie"),
            chapter("marches-prix", "Module 1 — Les marchés et la formation des prix"),
            chapter("defaillances-marche", "Module 1 — Concurrence, imperfections et défaillances de marché"),
            chapter("fondements-sociologie", "Module 1 — Les fondements de la sociologie et ses grands auteurs"),
            chapter("stratification", "Module 1 — Stratification sociale et mobilité"),
            chapter("croissance", "Module 2 — La croissance économique : sources et mesure"),
            chapter("revolutions-industrielles", "Module 2 — Les révolutions industrielles et l'innovation"),
            chapter("fluctuations", "Module 2 — Fluctuations et crises économiques depuis le XIXe siècle"),
            chapter("developpement", "Module 2 — Le développement et ses indicateurs"),
            chapter("mutations-productives", "Module 2 — Mutations des structures économiques et productives"),
            chapter("mutations-sociales", "Module 2 — Mutations des structures sociales et démographiques"),
            chapter("travail-salariat", "Module 2 — Travail, emploi et transformations du salariat"),
            chapter("role-etat", "Module 2 — Le rôle de l'État dans la croissance"),
            chapter("methode-dissertation", "Méthode de la dissertation d'ESH"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("origines-mondialisation", "Module 3 — Les origines historiques de la mondialisation"),
            chapter("commerce-international", "Module 3 — Le commerce international : théories et politiques"),
            chapter("mondialisation-productive", "Module 3 — Mondialisation productive et firmes multinationales"),
            chapter("mondialisation-financiere", "Module 3 — La mondialisation financière et les marchés de capitaux"),
            chapter("systeme-monetaire", "Module 3 — Le système monétaire international et les changes"),
            chapter("integration-europeenne", "Module 3 — L'intégration européenne et l'union monétaire"),
            chapter("inegalites-mondialisation", "Module 3 — Inégalités et développement dans la mondialisation"),
            chapter("modeles-macro", "Module 4 — Les grands modèles macroéconomiques : classiques et keynésiens"),
            chapter("equilibre-macro", "Module 4 — L'équilibre macroéconomique et ses déséquilibres"),
            chapter("chomage", "Module 4 — Le chômage : mesures, causes et politiques"),
            chapter("inflation", "Module 4 — L'inflation et la déflation"),
            chapter("crises-financieres", "Module 4 — Les crises financières et leur régulation"),
            chapter("politique-monetaire", "Module 4 — La politique monétaire et les banques centrales"),
            chapter("politique-budgetaire", "Module 4 — La politique budgétaire et la dette publique"),
            chapter("politiques-structurelles", "Module 4 — Les politiques structurelles et de l'emploi"),
            chapter("protection-sociale", "Module 4 — La protection sociale et l'État-providence"),
            chapter("croissance-soutenable", "Module 4 — Politiques environnementales et croissance soutenable"),
            chapter("limites-action-publique", "Module 4 — Les limites et contraintes de l'action publique"),
        ]
    }

    enum HGG {
        static let annee1: [TrackChapter] = [
            chapter("tableaux-geopolitiques", "Module 1 — Tableaux géopolitiques du monde en 1913, 1939 et 1945"),
            chapter("guerres-mondiales", "Module 1 — Les deux guerres mondiales et leurs conséquences"),
            chapter("guerre-froide", "Module 1 — La guerre froide : acteurs et espaces"),
            chapter("decolonisation", "Module 1 — Décolonisation et émergence du tiers-monde"),
            chapter("construction-europeenne", "Module 1 — La construction européenne et ses défis"),
            chapter("croissance-1945-1970", "Module 1 — Croissance et types de croissance de 1945 aux années 1970"),
            chapter("crises-1970-1990", "Module 1 — Crises et mutations économiques des années 1970-1990"),
            chapter("france-1945-1990", "Module 1 — La France, une puissance en mutation (1945-1990)"),
            chapter("dynamiques-mondialisation", "Module 2 — Les dynamiques de la mondialisation contemporaine"),
            chapter("acteurs-mondialisation", "Module 2 — Les acteurs : firmes, États, organisations et ONG"),
            chapter("flux-reseaux", "Module 2 — Flux, échanges et réseaux mondiaux"),
            chapter("metropolisation", "Module 2 — Métropolisation, littoralisation et recompositions territoriales"),
            chapter("ressources-energie", "Module 2 — Ressources, énergie et matières premières"),
            chapter("environnement-climat", "Module 2 — Environnement, climat et développement durable"),
            chapter("migrations", "Module 2 — Migrations internationales et enjeux démographiques"),
            chapter("gouvernance-conflits", "Module 2 — Puissance, gouvernance mondiale et conflits"),
            chapter("france-mondialisation", "Module 2 — La France dans la mondialisation"),
            chapter("methode", "Méthode : dissertation et croquis de géopolitique"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("europe-dynamiques", "Module 3 — L'Europe : dynamiques territoriales et puissance"),
            chapter("union-europeenne", "Module 3 — L'Union européenne : intégration, crises et élargissements"),
            chapter("france-puissance", "Module 3 — La France : territoire, puissance et influence"),
            chapter("afrique-dynamiques", "Module 3 — L'Afrique : dynamiques démographiques et économiques"),
            chapter("afrique-mondialisation", "Module 3 — L'Afrique dans la mondialisation : ressources et conflits"),
            chapter("moyen-orient-conflits", "Module 3 — Le Proche et Moyen-Orient : géopolitique des conflits"),
            chapter("moyen-orient-energie", "Module 3 — Le Proche et Moyen-Orient : énergie et recompositions"),
            chapter("russie", "Module 3 — La Russie : puissance eurasiatique et étranger proche"),
            chapter("etats-unis", "Module 4 — Les États-Unis : société et puissance mondiale"),
            chapter("amerique-nord", "Module 4 — Le Canada et l'intégration nord-américaine"),
            chapter("amerique-latine", "Module 4 — L'Amérique latine : dynamiques et intégrations régionales"),
            chapter("bresil", "Module 4 — Le Brésil et les puissances émergentes d'Amérique"),
            chapter("asie-dynamiques", "Module 4 — L'Asie dans la mondialisation : dynamiques régionales"),
            chapter("chine", "Module 4 — La Chine, puissance mondiale"),
            chapter("inde", "Module 4 — L'Inde, puissance émergente"),
            chapter("japon-npi", "Module 4 — Le Japon et les nouveaux pays industrialisés d'Asie"),
            chapter("asie-sud-est", "Module 4 — L'Asie du Sud-Est et les enjeux maritimes"),
            chapter("methode", "Méthode : dissertation et croquis de géopolitique"),
        ]
    }
}
