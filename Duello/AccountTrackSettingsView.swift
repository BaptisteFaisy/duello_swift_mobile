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

    /// Ouverture du sélecteur de prépa (`Ui2PrepaSearchSheet`, feuille
    /// **partagée** — cf. rapport de lot : câblage décrit, feuille non éditée).
    @State private var prepaSearchOpen = false

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
            prepaField
            DuelloTextField(title: "Ville", text: $session.profile.prepCity)
        }
        .duelloCard()
        .sheet(isPresented: $prepaSearchOpen) {
            Ui2PrepaSearchSheet(
                onSelect: { prepa in
                    // RN `handlePrepaSelect` : nom, ville et nature de la prépa.
                    session.profile.prepName = prepa.name
                    session.profile.prepCity = prepa.city
                    session.profile.prepType = prepa.type.rawValue
                    session.persistProfile()
                    prepaSearchOpen = false
                },
                onUseCustom: { name in
                    // RN `onUseCustom` : nom saisi à la main, sans nature.
                    session.profile.prepName = name
                    session.profile.prepType = nil
                    session.persistProfile()
                    prepaSearchOpen = false
                },
                onClose: { prepaSearchOpen = false }
            )
        }
        .onChange(of: session.profile.track) { _ in session.persistProfile() }
        .onChange(of: session.profile.year) { _ in session.persistProfile() }
        .onChange(of: session.profile.specialty) { _ in session.persistProfile() }
        .onChange(of: session.profile.prepName) { _ in session.persistProfile() }
        .onChange(of: session.profile.prepCity) { _ in session.persistProfile() }
    }

    /// Champ « Prépa » structuré : bouton ouvrant `Ui2PrepaSearchSheet`
    /// (`PrepaSearchModal.tsx`) au lieu d'un texte libre (écart U08#28).
    private var prepaField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prépa")
                .font(.system(size: 13, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
            Button { prepaSearchOpen = true } label: {
                HStack(spacing: 10) {
                    IonIcon(name: "search-outline", size: 18, color: Theme.inkSoft)
                    Text(session.profile.prepName.isEmpty ? "Rechercher ma prépa" : session.profile.prepName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(session.profile.prepName.isEmpty ? Theme.inkFaint : Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    IonIcon(name: "chevron-forward", size: 18, color: Theme.inkFaint)
                }
                .frame(minHeight: 48)
                .padding(.horizontal, 12)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rechercher ma prépa")
        }
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
