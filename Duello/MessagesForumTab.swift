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
                IonIcon(name: "people", size: 23, color: Theme.ink)
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
    }

    private func topicRow(_ topic: ForumTopic) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(topic.color)
                    .frame(width: 44, height: 44)
                IonIcon(name: topic.icon, size: 20, color: Theme.ink)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(topic.category)
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink)
                Text(topic.title)
                    .font(.system(size: 12, weight: .heavy))
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

            IonIcon(name: "chevron-forward", size: 17, color: Theme.inkFaint)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .duelloShadow()
        .contentShape(Rectangle())
    }
}
