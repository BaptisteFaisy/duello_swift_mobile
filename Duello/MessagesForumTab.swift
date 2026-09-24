import SwiftUI

extension MessagesView {
    // MARK: - Onglet Forum

    var forumTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                forumHero

                listHeader(title: "Discussions récentes", pill: "\(ForumTopic.samples.count) sujets")

                LazyVStack(spacing: 10) {
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
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Forums des préparationnaires")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Pose une question et partage une méthode avec ta filière.")
                    .font(.system(size: 10, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
    }

    private func topicRow(_ topic: ForumTopic) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(topic.color)
                    .frame(width: 44, height: 44)
                Image(systemName: topic.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(topic.category)
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink)
                Text(topic.title)
                    .font(.system(size: 12, weight: .heavy))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 5)
                Text("\(topic.author) · \(topic.replies) réponses · \(topic.time)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(15)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .shadow(color: Color(hex: 0x0A0D0C).opacity(0.04), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
    }
}
