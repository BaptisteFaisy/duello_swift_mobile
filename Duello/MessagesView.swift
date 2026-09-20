import SwiftUI

/// Écran « Messages » : deux onglets, Direct et Forum, repris de
/// `src/screens/MessagesScreen.tsx` de l'application Expo.
/// Conversations, sujets et messages sont des données de démonstration
/// locales : aucun appel réseau, tout l'état vit dans la vue.
struct MessagesView: View {
    /// Onglet affiché.
    @State private var activeTab: MessagesTab = .direct
    /// Conversations directes, avec leur compteur de non-lus.
    @State private var conversations: [DemoConversation] = DemoConversation.samples
    /// Conversation ouverte (fil de bulles), `nil` sur la liste.
    @State private var selectedConversationId: String?
    /// Sujet de forum ouvert, `nil` sur la liste.
    @State private var selectedTopicId: String?
    /// Fils de messages, indexés par identifiant de conversation.
    @State private var chats: [String: [ChatMessage]] = ChatMessage.initialChats
    /// Réponses du sujet de forum ouvert.
    @State private var forumReplies: [ChatMessage] = ChatMessage.initialForumReplies
    /// Contenu du champ de saisie, partagé par les deux vues détail.
    @State private var composer = ""

    /// Initiale de l'élève connecté. L'écran Expo lit `profile.displayName` ;
    /// la vue reste autonome, d'où cette constante (repli « P » d'Expo).
    private let myInitial = "P"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let id = selectedConversationId, let conversation = findConversation(id) {
            ConversationDetailView(
                conversation: conversation,
                messages: chats[id] ?? [],
                myInitial: myInitial,
                composer: $composer,
                onBack: { selectedConversationId = nil },
                onSend: { sendDirectMessage(to: id) }
            )
        } else if let id = selectedTopicId, let topic = findTopic(id) {
            ForumTopicDetailView(
                topic: topic,
                replies: forumReplies,
                myInitial: myInitial,
                composer: $composer,
                onBack: { selectedTopicId = nil },
                onSend: { sendForumReply() }
            )
        } else {
            listScreen
        }
    }

    // MARK: - Liste (onglets)

    private var listScreen: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if activeTab == .direct {
                    directTab
                } else {
                    forumTab
                }
            }
            .background(Theme.background)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// Bascule Direct / Forum, sur le motif d'onglets d'Expo.
    private var tabBar: some View {
        HStack(spacing: 5) {
            tabButton(.direct, title: "Direct", icon: "bubble.left", badge: totalUnread)
            tabButton(.forums, title: "Forum", icon: "person.2", badge: 0)
        }
        .padding(4)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func tabButton(_ tab: MessagesTab, title: String, icon: String, badge: Int) -> some View {
        let selected = activeTab == tab
        return Button {
            activeTab = tab
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: selected ? .black : .bold))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Theme.surface)
                        .frame(minWidth: 20, minHeight: 20)
                        .padding(.horizontal, 5)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(selected ? Theme.surface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : [])
    }

    // MARK: - Onglet Direct

    private var directTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                listHeader(title: "Conversations", pill: "\(conversations.count) actives")

                VStack(spacing: 0) {
                    ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                        Button {
                            open(conversation)
                        } label: {
                            conversationRow(conversation)
                        }
                        .buttonStyle(.plain)

                        if index < conversations.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .duelloCard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func conversationRow(_ conversation: DemoConversation) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(conversation.avatarColor)
                    .frame(width: 48, height: 48)
                Text(conversation.initial)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                if conversation.isOnline {
                    Circle()
                        .fill(Theme.progress)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.name)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text(conversation.time)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }

                HStack(spacing: 7) {
                    Text(conversation.preview)
                        .font(.system(size: 10, weight: conversation.unread > 0 ? .bold : .medium))
                        .foregroundStyle(conversation.unread > 0 ? Theme.ink : Theme.inkSoft)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if conversation.unread > 0 {
                        unreadBadge(conversation.unread)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(Theme.surface)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 5)
            .background(Theme.ink)
            .clipShape(Capsule())
    }

    // MARK: - Onglet Forum

    private var forumTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                forumHero

                listHeader(title: "Discussions récentes", pill: "\(ForumTopic.samples.count) sujets")

                VStack(spacing: 10) {
                    ForEach(ForumTopic.samples) { topic in
                        Button {
                            open(topic)
                        } label: {
                            topicRow(topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var forumHero: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17)
                    .fill(Theme.primaryLight)
                    .frame(width: 48, height: 48)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Forums des préparationnaires")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Pose une question et partage une méthode avec ta filière.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .padding(.bottom, 22)
    }

    private func topicRow(_ topic: ForumTopic) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(topic.color)
                    .frame(width: 44, height: 44)
                Image(systemName: topic.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(topic.category)
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink)
                Text(topic.title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(topic.author) · \(topic.replies) réponses · \(topic.time)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .duelloCard()
        .contentShape(Rectangle())
    }

    // MARK: - En-tête de liste

    private func listHeader(title: String, pill: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(pill)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 11)
                .frame(minHeight: 32)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 12)
    }

    // MARK: - Navigation et envoi

    private var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unread }
    }

    private func findConversation(_ id: String) -> DemoConversation? {
        conversations.first { $0.id == id }
    }

    private func findTopic(_ id: String) -> ForumTopic? {
        ForumTopic.samples.first { $0.id == id }
    }

    private func open(_ conversation: DemoConversation) {
        selectedConversationId = conversation.id
        composer = ""
        // Ouvrir une conversation remet ses non-lus à zéro (`onClearUnread`).
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].unread = 0
        }
    }

    private func open(_ topic: ForumTopic) {
        selectedTopicId = topic.id
        composer = ""
    }

    /// Ajoute le message saisi au fil local de la conversation ouverte.
    private func sendDirectMessage(to id: String) {
        let text = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var messages = chats[id] ?? []
        messages.append(
            ChatMessage(id: "message-\(UUID().uuidString)", author: .me, text: text, time: "Maintenant")
        )
        chats[id] = messages
        composer = ""
    }

    /// Ajoute la réponse saisie aux réponses locales du sujet ouvert.
    private func sendForumReply() {
        let text = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        forumReplies.append(
            ChatMessage(id: "reply-\(UUID().uuidString)", author: .me, text: text, time: "Maintenant")
        )
        composer = ""
    }
}

// MARK: - Onglet actif

/// Onglet actif de l'écran Messages.
private enum MessagesTab {
    case direct
    case forums
}

// MARK: - Auteur d'un message

/// Côté d'où part un message : moi à droite, l'interlocuteur à gauche.
private enum MessageAuthor {
    case me
    case other
}

// MARK: - Données de démonstration

/// Conversation de l'onglet Direct, reprise telle quelle d'Expo.
private struct DemoConversation: Identifiable {
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
private struct ChatMessage: Identifiable {
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
private struct ForumTopic: Identifiable {
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

// MARK: - Vue conversation

/// Fil d'une conversation directe : en-tête, bulles puis champ de saisie.
private struct ConversationDetailView: View {
    let conversation: DemoConversation
    let messages: [ChatMessage]
    let myInitial: String
    @Binding var composer: String
    let onBack: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title: conversation.name,
                subtitle: conversation.meta,
                avatar: .initial(conversation.initial, background: conversation.avatarColor),
                onBack: onBack
            )

            ScrollView {
                VStack(spacing: 0) {
                    Text("AUJOURD’HUI")
                        .font(.system(size: 8, weight: .black))
                        .tracking(1)
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.bottom, 17)

                    ForEach(messages) { message in
                        MessageBubbleRow(
                            message: message,
                            myInitial: myInitial,
                            peerInitial: conversation.initial
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 17)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            ComposerBar(placeholder: "Écrire un message…", text: $composer, onSend: onSend)
        }
        .background(Theme.background)
    }
}

// MARK: - Vue sujet de forum

/// Fil d'un sujet de forum : la question, puis les réponses.
private struct ForumTopicDetailView: View {
    let topic: ForumTopic
    let replies: [ChatMessage]
    let myInitial: String
    @Binding var composer: String
    let onBack: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title: topic.category,
                subtitle: "\(topic.replies) réponses",
                avatar: .symbol(topic.icon, background: topic.color),
                onBack: onBack
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    questionCard

                    ForEach(replies) { reply in
                        MessageBubbleRow(message: reply, myInitial: myInitial, peerInitial: "L")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 17)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            ComposerBar(placeholder: "Répondre à la discussion…", text: $composer, onSend: onSend)
        }
        .background(Theme.background)
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(topic.category)
                .font(.system(size: 8, weight: .black))
                .tracking(1)
                .foregroundStyle(Theme.ink)
            Text(topic.title)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Text("Question de \(topic.author)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .padding(.bottom, 18)
    }
}

// MARK: - En-tête de vue détail

/// Bandeau de tête commun aux deux vues détail : retour, avatar, libellés.
private struct DetailHeader: View {
    enum Avatar {
        case initial(String, background: Color)
        case symbol(String, background: Color)
    }

    let title: String
    let subtitle: String
    let avatar: Avatar
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            DetailBackButton(action: onBack)
            avatarView

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 63)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            switch avatar {
            case .initial(let letter, let background):
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
                    .frame(width: 39, height: 39)
                Text(letter)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
            case .symbol(let name, let background):
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
                    .frame(width: 39, height: 39)
                Image(systemName: name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

/// Bouton de retour en pastille, comme le `BackButton` d'Expo.
private struct DetailBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour")
    }
}

// MARK: - Bulle de message

/// Une bulle de message : initiale à droite pour moi, à gauche pour l'autre.
private struct MessageBubbleRow: View {
    let message: ChatMessage
    let myInitial: String
    let peerInitial: String

    private var isMine: Bool { message.author == .me }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !isMine {
                avatar(peerInitial, background: Theme.surfaceMuted, foreground: Theme.inkSoft)
                    .padding(.trailing, 7)
            } else {
                Spacer(minLength: 48)
            }

            bubble

            if isMine {
                avatar(myInitial, background: Theme.primaryLight, foreground: Theme.ink)
                    .padding(.leading, 7)
            } else {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    private var bubble: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 5) {
            Text(message.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isMine ? Theme.surface : Theme.ink)
                .multilineTextAlignment(isMine ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(message.time)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(isMine ? Theme.primaryLight : Theme.inkFaint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .background(isMine ? Theme.ink : Theme.surface)
        .clipShape(bubbleShape)
        .overlay(bubbleBorder)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 17,
            bottomLeadingRadius: isMine ? 17 : 5,
            bottomTrailingRadius: isMine ? 5 : 17,
            topTrailingRadius: 17
        )
    }

    @ViewBuilder
    private var bubbleBorder: some View {
        if !isMine {
            bubbleShape.stroke(Theme.border, lineWidth: 1)
        }
    }

    private func avatar(_ initial: String, background: Color, foreground: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(background)
                .frame(width: 29, height: 29)
            Text(initial)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(foreground)
        }
    }
}

// MARK: - Champ de saisie

/// Barre de saisie avec bouton d'envoi, style de la `Composer` d'Expo.
private struct ComposerBar: View {
    let placeholder: String
    @Binding var text: String
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...5)
                .padding(.vertical, 9)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.surface)
                    .frame(width: 40, height: 40)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.35)
            .accessibilityLabel("Envoyer")
        }
        .padding(.vertical, 7)
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
