import SwiftUI

// MARK: - Vue conversation

/// Fil d'une conversation directe : en-tête, bulles puis champ de saisie.
struct ConversationDetailView: View {
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
struct ForumTopicDetailView: View {
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
