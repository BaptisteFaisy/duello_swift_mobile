import SwiftUI

extension MessagesView {
    // MARK: - Navigation et envoi

    func findConversation(_ id: String) -> DemoConversation? {
        conversations.first { $0.id == id }
    }

    func findTopic(_ id: String) -> ForumTopic? {
        ForumTopic.samples.first { $0.id == id }
    }

    func open(_ conversation: DemoConversation) {
        selectedConversationId = conversation.id
        composer = ""
        // Ouvrir une conversation remet les non-lus à zéro côté parent
        // (`onClearUnread()`, `MessagesScreen.tsx:185-189`).
        onClearUnread()
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
