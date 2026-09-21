import SwiftUI

extension MessagesView {
    // MARK: - Onglet Direct

    var directTab: some View {
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
}
