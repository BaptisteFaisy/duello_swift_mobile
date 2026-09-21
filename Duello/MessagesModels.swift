import SwiftUI

// MARK: - Onglet actif

/// Onglet actif de l'écran Messages.
enum MessagesTab {
    case direct
    case forums
}

// MARK: - Auteur d'un message

/// Côté d'où part un message : moi à droite, l'interlocuteur à gauche.
enum MessageAuthor {
    case me
    case other
}

// MARK: - Données de démonstration

/// Conversation de l'onglet Direct, reprise telle quelle d'Expo.
struct DemoConversation: Identifiable {
    let id: String
    let name: String
    let initial: String
    let meta: String
    let preview: String
    let time: String
    var unread: Int
    let isOnline: Bool
    let avatarColor: Color

    static let samples: [DemoConversation] = [
        DemoConversation(
            id: "lea",
            name: "Léa M.",
            initial: "L",
            meta: "MPSI · En ligne",
            preview: "On compare nos méthodes après le défi ?",
            time: "14:32",
            unread: 2,
            isOnline: true,
            avatarColor: Theme.surfaceMuted
        ),
        DemoConversation(
            id: "mathis",
            name: "Mathis D.",
            initial: "M",
            meta: "PCSI · Il y a 8 min",
            preview: "Bien joué pour le dernier exercice !",
            time: "13:48",
            unread: 1,
            isOnline: false,
            avatarColor: Theme.primaryLight
        ),
        DemoConversation(
            id: "nina",
            name: "Nina B.",
            initial: "N",
            meta: "MPSI · Hier",
            preview: "Je t’envoie ma fiche sur les applications linéaires.",
            time: "Hier",
            unread: 0,
            isOnline: false,
            avatarColor: Theme.primaryLight
        ),
    ]
}

/// Message d'un fil (conversation directe ou sujet de forum).
struct ChatMessage: Identifiable {
    let id: String
    let author: MessageAuthor
    let text: String
    let time: String

    /// Fils initiaux, identiques à `initialChats` du fichier Expo.
    static let initialChats: [String: [ChatMessage]] = [
        "lea": [
            ChatMessage(id: "lea-1", author: .other, text: "Salut ! Tu participes au défi de maths dimanche ?", time: "14:25"),
            ChatMessage(id: "lea-2", author: .me, text: "Oui, je pars sur le format 20 minutes.", time: "14:28"),
            ChatMessage(id: "lea-3", author: .other, text: "On compare nos méthodes après le défi ?", time: "14:32"),
        ],
        "mathis": [
            ChatMessage(id: "mathis-1", author: .other, text: "Bien joué pour le dernier exercice !", time: "13:48"),
        ],
        "nina": [
            ChatMessage(id: "nina-1", author: .other, text: "Je t’envoie ma fiche sur les applications linéaires.", time: "Hier"),
        ],
    ]

    /// Réponses initiales du sujet de forum, comme `forumReplies` d'Expo.
    static let initialForumReplies: [ChatMessage] = [
        ChatMessage(
            id: "reply-1",
            author: .other,
            text: "Je commence toujours par chercher le polynôme caractéristique et les dimensions des sous-espaces propres.",
            time: "14:04"
        ),
        ChatMessage(
            id: "reply-2",
            author: .me,
            text: "Le rang de A − λI permet aussi de gagner du temps dans certains cas.",
            time: "14:11"
        ),
    ]
}

/// Sujet de l'onglet Forum. `icon` porte un symbole SF équivalent à
/// l'ionone d'Expo (`calculator-outline`, `flask-outline`, `book-outline`).
struct ForumTopic: Identifiable {
    let id: String
    let category: String
    let title: String
    let author: String
    let replies: Int
    let time: String
    let icon: String
    let color: Color

    static let samples: [ForumTopic] = [
        ForumTopic(
            id: "matrices",
            category: "MATHÉMATIQUES",
            title: "Comment reconnaître rapidement une matrice diagonalisable ?",
            author: "Nina B.",
            replies: 24,
            time: "Il y a 12 min",
            icon: "function",
            color: Theme.primaryLight
        ),
        ForumTopic(
            id: "mecanique",
            category: "PHYSIQUE",
            title: "Méthode propre pour les bilans de forces en mécanique",
            author: "Alex T.",
            replies: 18,
            time: "Il y a 35 min",
            icon: "flask",
            color: Theme.surfaceMuted
        ),
        ForumTopic(
            id: "dissertation",
            category: "FRANÇAIS-PHILO",
            title: "Vos meilleures techniques pour construire un plan en dix minutes",
            author: "Sarah L.",
            replies: 31,
            time: "Hier",
            icon: "book",
            color: Theme.primaryLight
        ),
    ]
}
