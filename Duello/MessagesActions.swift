import SwiftUI

extension MessagesView {
    // MARK: - Navigation et envoi

    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unread }
    }

    func findConversation(_ id: String) -> DemoConversation? {
        conversations.first { $0.id == id }
    }

    func findTopic(_ id: String) -> ForumTopic? {
        ForumTopic.samples.first { $0.id == id }
    }

    func open(_ conversation: DemoConversation) {
        selectedConversationId = conversation.id
        composer = ""
        // Ouvrir une conversation remet ses non-lus à zéro (`onClearUnread`).
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].unread = 0
        }
    }

    func open(_ topic: ForumTopic) {
        selectedTopicId = topic.id
        composer = ""
    }

    /// Ajoute le message saisi au fil local de la conversation ouverte.
    func sendDirectMessage(to id: String) {
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
    func sendForumReply() {
        let text = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        forumReplies.append(
            ChatMessage(id: "reply-\(UUID().uuidString)", author: .me, text: text, time: "Maintenant")
        )
        composer = ""
    }
}
