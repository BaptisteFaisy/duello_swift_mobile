import SwiftUI

// MARK: - Parcours

/// Édition fine du parcours : filière, année, option, prépa et ville.
/// Chaque changement est écrit dans `SessionStore.profile` puis persisté, comme
/// la section « Mon parcours » de `AccountScreen.tsx` et `AccountTrackScreen.tsx`.
struct TrackSettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    private let tracks = ["ECG", "MPSI", "MP", "PSI"]
    private let years = ["1re année", "2e année"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    programCard
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Mon parcours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var programCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Filière")
            Picker("Filière", selection: $session.profile.track) {
                Text("Choisir…").tag("")
                ForEach(tracks, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            sectionTitle("Année")
            Picker("Année", selection: $session.profile.year) {
                ForEach(years, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            DuelloTextField(title: "Option", text: $session.profile.specialty)
            DuelloTextField(title: "Prépa", text: $session.profile.prepName)
            DuelloTextField(title: "Ville", text: $session.profile.prepCity)
        }
        .duelloCard()
        .onChange(of: session.profile.track) { _ in session.persistProfile() }
        .onChange(of: session.profile.year) { _ in session.persistProfile() }
        .onChange(of: session.profile.specialty) { _ in session.persistProfile() }
        .onChange(of: session.profile.prepName) { _ in session.persistProfile() }
        .onChange(of: session.profile.prepCity) { _ in session.persistProfile() }
    }

    private var footer: some View {
        Text("Chaque changement est enregistré automatiquement dans ton profil.")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
    }
}
