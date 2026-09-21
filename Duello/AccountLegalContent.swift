import SwiftUI

/// Contenu juridique embarqué, repris mot pour mot des fichiers Expo
/// (`src/legal/privacyPolicy.generated.ts`, `src/legal/termsOfUse.generated.ts`).
enum LegalContent {
    static let privacyPolicy: LegalDocument = LegalDocument(
        title: "Politique de confidentialité",
        updatedAt: "1er septembre 2026",
        sections: [
            LegalSection(
                id: "responsable",
                title: "1. Responsable et contact",
                paragraphs: [
                    "Duello est responsable des traitements décrits dans cette politique pour l’application mobile et le service duello.fr.",
                    "Pour toute question, demande d’accès, de portabilité, d’opposition ou d’effacement, écris à contact@duello.fr. Les mentions légales sont disponibles sur duello.fr/mentions-legales.",
                ]
            ),
            LegalSection(
                id: "donnees",
                title: "2. Données traitées",
                paragraphs: [
                    "Duello limite les données à celles qui sont nécessaires au compte, à l’entraînement, aux fonctions sociales, à la sécurité et aux fonctions que tu déclenches.",
                ],
                bullets: [
                    "Compte et authentification : adresse e-mail, pseudo, nom et prénom lorsqu’ils sont renseignés, identifiants techniques Google ou Apple si tu choisis ces connexions, empreinte salée du mot de passe, condensats des jetons de session et, pendant la livraison d’un e-mail de réinitialisation, adresse et jeton chiffrés.",
                    "Profil et organisation : année, filière, option, prépa, ville et classe, zone de vacances, école visée, objectif personnel, photo facultative, tâches, planning et préférences renseignées pour le sommeil, le réveil, les repas et la douche.",
                    "Apprentissage : progression, réponses, notes et moyennes scolaires saisies, commentaires, temps de résolution, XP, Elo, résultats de défis, carnets synchronisés et corrections conservées dans ton espace de compte.",
                    "Contenus choisis : textes, copies, photos, enregistrements vocaux en transit et documents envoyés lorsque tu demandes une transcription, une analyse, une génération ou une correction.",
                    "Communauté et assistance : abonnements, blocages, signalements, feedbacks, défis de classe et éléments nécessaires à la modération.",
                    "Technique : adresse IP observée à l’inscription, empreinte hachée de l’appareil, jeton de notification si tu l’actives, journaux de sécurité et mesures d’usage bornées.",
                    "Site et liste d’attente : adresse e-mail, prépa facultative, rang, code et relations de parrainage ; le site mesure aussi les ouvertures par nom d’hôte avec une empreinte de navigateur aléatoire, sans conserver cet identifiant en clair ni l’adresse IP.",
                ]
            ),
            LegalSection(
                id: "finalites",
                title: "3. Finalités et bases juridiques",
                paragraphs: [
                    "Le compte, la liste d’attente, la progression, les corrections, la synchronisation, les défis et l’assistance sont traités pour fournir le service demandé. La sécurité, la prévention de la fraude, la modération et l’amélioration interne reposent sur l’intérêt légitime de maintenir un service fiable, avec des données proportionnées.",
                    "Les notifications et le partage de contenus avec les prestataires d’intelligence artificielle reposent sur ton choix. Tu peux les refuser ou retirer ce choix sans perdre ton compte. Certaines données financières peuvent être conservées lorsqu’une obligation légale l’impose.",
                ]
            ),
            LegalSection(
                id: "ia",
                title: "4. Intelligence artificielle et consentement",
                paragraphs: [
                    "Avant le premier envoi à un prestataire d’IA, l’application présente les catégories de contenus concernées, les finalités et les prestataires possibles, puis demande une autorisation explicite. Un refus empêche l’envoi et ne lance pas la fonction distante.",
                    "Selon l’outil, Duello peut transmettre le contenu que tu as sélectionné à OpenAI, Anthropic, Mathpix, Zhipu AI (z.ai), Alibaba Cloud ou ElevenLabs. Le relais choisit uniquement les services nécessaires à la correction, à la lecture mathématique, à la transcription vocale ou à la génération demandée.",
                    "Duello n’utilise pas ces contenus pour la publicité et ne les rend pas publics. Les réponses des prestataires reviennent par le relais Duello. Leurs journaux techniques éventuels suivent leurs conditions de service et les accords applicables.",
                ]
            ),
            LegalSection(
                id: "photos-audio-documents",
                title: "5. Photos, audio et documents",
                paragraphs: [
                    "La caméra, la photothèque, le microphone et le sélecteur de documents ne sont sollicités qu’après une action visible de ta part. Le système de ton téléphone gère les permissions correspondantes.",
                    "Les photos de copies et les documents sont compressés ou découpés avant leur envoi au relais. Les photos transférées entre un ordinateur et le téléphone restent dans un stockage éphémère, au plus trente minutes. Les travaux de flashcards expirent après trente minutes d’inactivité ; un dépôt d’annale incomplet expire après une heure et un travail d’annale après vingt-quatre heures.",
                    "L’audio de la dictée distante transite en temps réel et n’est pas enregistré durablement par les serveurs Duello. Si l’autorisation IA est refusée, la dictée peut utiliser le moteur du téléphone lorsqu’il est disponible. La biométrie reste entièrement gérée par le système de l’appareil et ne quitte jamais celui-ci.",
                ]
            ),
            LegalSection(
                id: "authentification",
                title: "6. Connexions Google et Apple",
                paragraphs: [
                    "Si tu choisis Google ou Apple, Duello vérifie la preuve de connexion et conserve l’identifiant stable du fournisseur ainsi que l’adresse e-mail certifiée nécessaire au compte. Le jeton d’identité brut n’est pas conservé. Pour Apple, le code éphémère est échangé côté serveur contre un jeton de révocation, chiffré avant son stockage et utilisé uniquement pour gérer cette autorisation.",
                    "Duello ne demande aucun accès à Google Drive, à tes contacts ou à d’autres services de ces comptes. Supprimer ton compte retire les liaisons enregistrées par Duello et révoque l’autorisation Apple associée lorsqu’elle existe ; tu peux aussi gérer les autorisations depuis ton compte Google ou Apple.",
                ]
            ),
            LegalSection(
                id: "social",
                title: "7. Profil public et communauté",
                paragraphs: [
                    "Les profils élèves sont publics par conception. L’annuaire, les recherches, les classements et les défis peuvent afficher le pseudo, la photo facultative, l’année, la filière, l’option, la ligue, l’Elo, les XP hebdomadaires, la pastille Premium et certains succès d’exercices difficiles.",
                    "L’adresse e-mail, les réponses, les copies, les documents, les corrections détaillées et les notes privées ne sont jamais publiés. Un blocage masque réciproquement les profils et empêche leurs interactions sans avertir l’autre personne. Les signalements restent réservés à la modération.",
                ]
            ),
            LegalSection(
                id: "notifications-analytics",
                title: "8. Notifications et mesures d’usage",
                paragraphs: [
                    "Si tu actives les notifications, Duello enregistre un jeton d’appareil et passe par Expo, Firebase Cloud Messaging sur Android et Apple Push Notification service sur iOS. Le contenu d’une notification ne contient ni copie, ni réponse, ni document.",
                    "Les mesures internes couvrent le temps actif, les visites, les actions et les exercices ouverts ou terminés. Sur le site public, elles comptent seulement les ouvertures par nom d’hôte et empreinte de navigateur. Elles ne contiennent aucun brouillon, aucune réponse et aucune copie. Duello n’intègre aucun SDK publicitaire, n’affiche aucune publicité et ne vend ni ne loue les données personnelles.",
                ]
            ),
            LegalSection(
                id: "paiements",
                title: "9. Abonnements et affiliation",
                paragraphs: [
                    "Lorsqu’un paiement est activé, le prestataire d’achat confirme à Duello le compte concerné, la période ouverte, une référence anti-doublon et le fournisseur. Duello ne reçoit ni numéro de carte ni coordonnées bancaires. Les achats intégrés sont gérés par Apple ou Google selon la plateforme.",
                    "Lorsqu’un code public d’affiliation member-… est enregistré, Duello conserve le lien entre le compte affilié, le compte bénéficiaire et la date. Aucun montant n’est ajouté à cette étape. Après validation d’un paiement Premium hebdomadaire ou annuel, Duello utilise sa référence anti-doublon et ajoute 3 € au solde de l’affilié.",
                    "Pour les versements d’affiliation, Stripe Connect héberge la saisie des coordonnées bancaires et les vérifications d’identité. Duello conserve les identifiants opaques, montants, statuts et références nécessaires à la comptabilité et aux versements.",
                ]
            ),
            LegalSection(
                id: "prestataires",
                title: "10. Destinataires et prestataires",
                paragraphs: [
                    "Seules les personnes autorisées de Duello et les prestataires nécessaires à la fonction demandée reçoivent les données correspondantes.",
                ],
                bullets: [
                    "Cloudflare : site, protection, réseau, API et relais.",
                    "Neon/PostgreSQL et le stockage Redis compatible, dont Upstash lorsqu’il est activé : données durables et états temporaires.",
                    "OpenAI, Anthropic, Mathpix et Zhipu AI (z.ai) : correction, lecture de copies et analyse de documents demandées.",
                    "Alibaba Cloud et ElevenLabs : reconnaissance vocale demandée.",
                    "Expo, Google et Apple : mises à jour, authentification choisie et notifications selon la plateforme.",
                    "Brevo : e-mails transactionnels de réinitialisation du mot de passe.",
                    "Stripe : vérification et versements du programme d’affiliation.",
                ]
            ),
            LegalSection(
                id: "transferts",
                title: "11. Transferts internationaux",
                paragraphs: [
                    "Certains prestataires opèrent depuis ou hors de l’Espace économique européen. Duello limite chaque transfert aux données nécessaires à la fonction choisie et s’appuie sur les mécanismes juridiques et contractuels proposés pour le service concerné. Tu peux demander des informations sur un transfert précis à contact@duello.fr.",
                ]
            ),
            LegalSection(
                id: "conservation",
                title: "12. Durées de conservation",
                paragraphs: [
                    "Les durées ci-dessous sont celles appliquées par Duello. Les sauvegardes de sécurité peuvent conserver une copie inaccessible au service courant pendant au plus quatorze jours avant rotation.",
                ],
                bullets: [
                    "Compte, profil, progression, données sociales et contenus synchronisés : jusqu’à la suppression du compte.",
                    "Sessions : trente jours au maximum, ou révocation anticipée lors d’une déconnexion, d’un changement sensible ou d’une suppression.",
                    "Réinitialisation du mot de passe : l’adresse et le jeton nécessaires à une livraison en attente sont stockés uniquement chiffrés puis effacés de la file dès qu’elle n’est plus à reprendre ; les métadonnées pseudonymes d’une livraison terminée sont supprimées après trente jours. Le lien reste utilisable pendant trente minutes et une seule fois ; son empreinte cryptographique et ses horodatages sont conservés avec le compte jusqu’à sa suppression.",
                    "Mesures d’usage de l’application : fenêtre glissante de cent vingt jours, avec au plus deux mille événements récents ; mesures de visite du site : cent vingt jours après la dernière ouverture.",
                    "Inscription à la liste d’attente : jusqu’à ta demande de retrait, la suppression du compte Duello portant la même adresse ou la fin de l’utilité de cette liste.",
                    "Feedbacks, signalements d’exercice, périodes d’abonnement et défis de classe : jusqu’à la suppression du compte ou leur éviction par les limites opérationnelles du service.",
                    "Photos de liaison PC : trente minutes ; travaux IA Duello : de trente minutes à vingt-quatre heures selon le parcours décrit à la section 5.",
                    "Jeton push : jusqu’à la désactivation des notifications ou la suppression du compte.",
                    "Empreinte hachée de l’appareil : après suppression, elle reste sans adresse IP ni identifiant de compte pendant la durée nécessaire à l’application de la règle d’un seul essai gratuit par appareil.",
                    "Pièces et références financières : pendant la durée imposée par les obligations comptables, fiscales, de lutte contre la fraude ou de règlement des litiges.",
                ]
            ),
            LegalSection(
                id: "securite",
                title: "13. Sécurité",
                paragraphs: [
                    "Les communications utilisent HTTPS ou WSS. Les mots de passe sont salés et hachés, les sessions sont représentées en base par des condensats et les clés des prestataires restent côté serveur. Les contrôles d’accès vérifient le compte à chaque lecture ou écriture privée.",
                    "Aucune sécurité n’est absolue. En cas d’incident présentant un risque pour tes droits, Duello applique les obligations de notification et de remédiation pertinentes.",
                ]
            ),
            LegalSection(
                id: "suppression",
                title: "14. Suppression du compte",
                paragraphs: [
                    "Dans l’application, ouvre Mon compte, Paramètres, puis Mes informations. Descends jusqu’à Supprimer mon compte et confirme. La session active autorise une suppression immédiate du compte serveur ; l’application efface ensuite le registre, les données locales du compte et la session de cet appareil.",
                    "Sans accès à l’application, utilise la page duello.fr/suppression-compte ou écris depuis l’adresse du compte à contact@duello.fr. Une vérification d’identité peut être demandée. Les exceptions de conservation sont limitées aux sauvegardes temporaires, à l’empreinte d’appareil anonymisée décrite plus haut et aux obligations légales.",
                ]
            ),
            LegalSection(
                id: "droits",
                title: "15. Tes choix et tes droits",
                paragraphs: [
                    "Tu peux corriger les informations du profil dans Mes informations, désactiver les notifications, retirer l’autorisation de traitement par l’IA, gérer tes blocages et supprimer ton compte directement.",
                    "Selon le droit applicable, tu peux demander l’accès, la rectification, l’effacement, la limitation, l’opposition et la portabilité, ainsi que retirer un consentement. Duello répond en principe sous un mois. Tu peux saisir la CNIL ou l’autorité de protection compétente.",
                ]
            ),
            LegalSection(
                id: "evolution",
                title: "16. Évolution de la politique",
                paragraphs: [
                    "La date et la version figurent en tête de page. Une modification importante est signalée dans l’application ou par un moyen adapté avant son entrée en vigueur lorsque la loi l’exige. La version publiée sur duello.fr/confidentialite est la référence publique.",
                ]
            ),
        ]
    )

    static let termsOfUse: LegalDocument = LegalDocument(
        title: "Conditions d’utilisation",
        updatedAt: "11 septembre 2026",
        sections: [
            LegalSection(
                id: "acceptation",
                title: "Acceptation des conditions",
                paragraphs: [
                    "En créant un compte ou en utilisant Duello, tu acceptes les présentes conditions d’utilisation. Si tu n’en veux pas, ne crée pas de compte et cesse d’utiliser l’application.",
                    "Duello peut faire évoluer le service et ces conditions. Les modifications importantes sont signalées dans l’application et la version en vigueur reste consultable dans les paramètres.",
                ]
            ),
            LegalSection(
                id: "compte",
                title: "Compte et inscription",
                paragraphs: [
                    "Le service s’adresse aux élèves préparant les concours et examens couverts par Duello, notamment les classes préparatoires économiques et commerciales, ainsi qu’aux personnes qui les accompagnent.",
                    "Tu fournis des informations exactes lors de l’inscription (filière, option, année) et tu es responsable de la confidentialité de tes identifiants. Un compte par personne : le partage de compte est interdit.",
                    "Tu peux supprimer ton compte à tout moment depuis les paramètres ; la politique de confidentialité détaille les données effacées et les délais de suppression.",
                ],
                bullets: [
                    "Responsable de la confidentialité de tes identifiants.",
                    "Un compte par personne, pas de partage ni de revente.",
                    "Suppression du compte possible à tout moment.",
                ]
            ),
            LegalSection(
                id: "abonnement",
                title: "Abonnement et paiement",
                paragraphs: [
                    "L’accès à l’intégralité du service (corrections illimitées, annales, statistiques avancées) requiert un abonnement Premium. Les tarifs, la durée et le contenu de chaque offre sont affichés au moment du paiement.",
                    "Le paiement est traité par les boutiques Apple App Store et Google Play, selon leurs conditions. L’abonnement se renouvelle automatiquement tant qu’il n’est pas annulé au plus tard 24 heures avant la fin de la période en cours.",
                    "L’annulation et le remboursement suivent les règles de la boutique utilisée pour l’achat. Duello ne stocke aucune donnée bancaire.",
                ],
                bullets: [
                    "Paiement et renouvellement gérés par l’App Store ou le Play Store.",
                    "Résiliable à tout moment depuis la boutique, effet à la fin de la période payée.",
                    "Aucune donnée bancaire n’est stockée par Duello.",
                ]
            ),
            LegalSection(
                id: "usage",
                title: "Utilisation du service",
                paragraphs: [
                    "Duello te donne accès à des sujets, exercices, corrections et outils d’entraînement pour un usage strictement personnel et pédagogique. Cet usage ne remplace pas le travail en classe ni les conseils de tes enseignants.",
                    "Les corrections assistées par intelligence artificielle sont des aides à la rédaction et à la compréhension : elles peuvent contenir des erreurs et ne constituent pas un corrigé officiel. Vérifie toujours auprès de tes sources et de tes professeurs.",
                    "Les contenus (sujets, corrigés, méthodes, illustrations, marques Duello) sont protégés. Toute reproduction, extraction massive ou redistribution hors du service est interdite, sauf copie privée strictement personnelle.",
                ],
                bullets: [
                    "Usage personnel et pédagogique uniquement.",
                    "Les corrections IA peuvent comporter des erreurs.",
                    "Contenus protégés, extraction et redistribution interdites.",
                ]
            ),
            LegalSection(
                id: "communaute",
                title: "Communauté et défis",
                paragraphs: [
                    "Les fonctions sociales (profils, abonnements entre membres, défis, classements hebdomadaires) doivent rester respectueuses et orientées entraide. Sont notamment interdits : la triche, le partage de solutions pendant les devoirs surveillés, les contenus injurieux, discriminatoires, illégaux ou détournés de l’objet du service.",
                    "Tu peux signaler un comportement ou un contenu via la fonction « Un bug ? » et les comptes en cause peuvent être signalés et bloqués. Duello peut suspendre ou supprimer un compte qui enfreint ces règles, après t'avoir laissé, dans la mesure du possible, la possibilité d'expliquer ta situation.",
                ],
                bullets: [
                    "Respect et fair-play obligatoires dans les défis et classements.",
                    "Signalement possible des contenus et comportements inadaptés.",
                    "Suspension ou suppression possible en cas de manquement.",
                ]
            ),
            LegalSection(
                id: "ia",
                title: "Intelligence artificielle",
                paragraphs: [
                    "Certaines fonctions (correction de copies, transcription, génération d’exercices) s’appuient sur des prestataires d’intelligence artificielle. Le traitement ne démarre qu’avec ton autorisation expresse, révocable à tout moment dans la politique de confidentialité.",
                    "Seul le contenu que tu choisis d’envoyer est transmis aux prestataires nécessaires, uniquement pour produire le résultat demandé.",
                ],
                bullets: [
                    "Traitement IA uniquement avec ton accord, révocable à tout moment.",
                    "Transmission limitée au strict nécessaire pour la fonction demandée.",
                ]
            ),
            LegalSection(
                id: "responsabilite",
                title: "Disponibilité et responsabilité",
                paragraphs: [
                    "Duello s’efforce d’assurer un service de qualité et disponible, mais l’accès peut être interrompu pour maintenance, évolutions ou événements indépendants de notre volonté, sans droit à indemnisation.",
                    "Le service est fourni en l’état. Dans la limite autorisée par la loi, la responsabilité de Duello ne peut être engagée pour les dommages indirects, la perte de progression due à une cause externe, ni pour les résultats académiques obtenus avec l’aide du service.",
                ]
            ),
            LegalSection(
                id: "droits",
                title: "Droit applicable et contact",
                paragraphs: [
                    "Les présentes conditions sont soumises au droit français. Pour toute question, réclamation ou demande relative à ton compte, écris à contact@duello.fr ; la politique de confidentialité détaille aussi l’exercice de tes droits sur tes données.",
                ]
            ),
        ]
    )
}
