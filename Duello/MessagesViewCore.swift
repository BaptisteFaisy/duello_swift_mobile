import SwiftUI

/// Écran « Messages » : deux onglets, Messages et Forums, repris de
/// `src/screens/MessagesScreen.tsx` de l'application Expo.
/// Conversations, sujets et messages sont des données de démonstration
/// locales : aucun appel réseau, tout l'état vit dans la vue.
///
/// Découpage par responsabilité, sans changement de type ni de signature :
/// ce fichier porte l'état et la coquille (onglets, en-tête de liste) ;
/// `MessagesDirectTab.swift` l'onglet Messages, `MessagesForumTab.swift`
/// l'onglet Forums, `MessagesActions.swift` la recherche, l'ouverture et
/// l'envoi. Les membres partagés entre fichiers sont `internal`.
struct MessagesView: View {
    /// Profil de l'élève connecté (contrat `MessagesScreenProps.profile`).
    var profile: UserProfile = UserProfile()
    /// Non-lus globaux (contrat `MessagesScreenProps.unreadCount`). Le badge
    /// de l'onglet et l'état non-lu des lignes suivent cette valeur fournie
    /// par le parent, pas la somme locale des conversations.
    var unreadCount: Int = DemoConversation.samples.reduce(0) { $0 + $1.unread }
    /// Appelé à l'ouverture d'une conversation (`onClearUnread`) : le parent
    /// remet le badge à zéro.
    var onClearUnread: () -> Void = {}
    /// Onglet affiché.
    @State private var activeTab: MessagesTab = .direct
    /// Conversations directes, avec leur compteur de non-lus.
    @State var conversations: [DemoConversation] = DemoConversation.samples
    /// Conversation ouverte (fil de bulles), `nil` sur la liste.
    @State var selectedConversationId: String?
    /// Sujet de forum ouvert, `nil` sur la liste.
    @State var selectedTopicId: String?
    /// Fils de messages, indexés par identifiant de conversation.
    @State var chats: [String: [ChatMessage]] = ChatMessage.initialChats
    /// Réponses du sujet de forum ouvert.
    @State var forumReplies: [ChatMessage] = ChatMessage.initialForumReplies
    /// Contenu du champ de saisie, partagé par les deux vues détail.
    @State var composer = ""

    /// Initiale de l'élève connecté : premier caractère de
    /// `profile.displayName` en capitale, comme
    /// `profile.displayName.charAt(0).toUpperCase() || 'P'` d'Expo.
    private var myInitial: String {
        profile.displayName.first.map { String($0).uppercased() } ?? "P"
    }

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

    /// Bascule Messages / Forums, sur le motif d'onglets d'Expo.
    private var tabBar: some View {
        HStack(spacing: 5) {
            tabButton(.direct, title: "Messages", icon: "bubble.left", badge: unreadCount)
            tabButton(.forums, title: "Forums", icon: "person.2", badge: 0)
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

    // MARK: - En-tête de liste

    func listHeader(title: String, pill: String) -> some View {
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
}
