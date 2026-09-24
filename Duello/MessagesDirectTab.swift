import SwiftUI

extension MessagesView {
    // MARK: - Onglet Direct

    var directTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                listHeader(title: "Conversations", pill: "\(conversations.count) actives")

                LazyVStack(spacing: 0) {
                    ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                        Button {
                            open(conversation)
                        } label: {
                            conversationRow(conversation)
                        }
                        .buttonStyle(.plain)

                        if index < conversations.count - 1 {
                            HairlineDivider().padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal, 15)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
                .shadow(color: Color(hex: 0x0A0D0C).opacity(0.04), radius: 8, x: 0, y: 2)
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
                        .fill(Theme.primaryLight)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
                        .offset(x: 1, y: 1)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
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
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(Theme.ink)
            .clipShape(Capsule())
    }
}

/// Filet de séparation épais d'une ligne physique, couleur de bordure du thème
/// (`StyleSheet.hairlineWidth` + `colors.border` de la source Expo).
private struct HairlineDivider: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1 / displayScale)
    }
}
