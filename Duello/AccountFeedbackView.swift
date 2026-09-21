import SwiftUI

// MARK: - Retour utilisateur

/// Écran « Un bug ? » : retour d'un élève vers l'équipe Duello.
/// Reprend `FeedbackScreen.tsx`. L'envoi est local — aucun appel réseau n'est
/// émis par cette version : « Envoyer » affiche une confirmation et vide le
/// formulaire.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    private let categories = ["Bug", "Suggestion", "Contenu", "Autre"]

    @State private var category = "Bug"
    @State private var message = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    categoryCard
                    messageCard
                    sendButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Un bug ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .alert("Message envoyé", isPresented: $showConfirmation) {
                Button("OK", role: .cancel) {
                    message = ""
                    category = categories[0]
                }
            } message: {
                Text("Ton retour a bien été transmis à l’équipe Duello. Merci pour ta contribution !")
            }
        }
    }

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Catégorie")
            Picker("Catégorie", selection: $category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .duelloCard()
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Message")
            TextField("Décris ton retour en détail…", text: $message, axis: .vertical)
                .lineLimit(6...12)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(12)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .duelloCard()
    }

    private var sendButton: some View {
        Button {
            showConfirmation = true
        } label: {
            Text("Envoyer")
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(!canSend)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
    }
}
