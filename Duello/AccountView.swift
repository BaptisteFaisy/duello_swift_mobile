import SwiftUI

/// Onglet « Mon compte » : profil, parcours, objectifs et déconnexion.
/// Reprend l'esprit de `src/screens/AccountScreen.tsx` (sections en cartes).
struct AccountView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var showProfileEditor = false

    private let tracks = ["ECG", "MPSI", "MP", "PSI"]
    private let years = ["1re année", "2e année"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    profileCard
                    programCard
                    goalCard
                    signOutCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Mon compte")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditorView()
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryLight)
                        .frame(width: 52, height: 52)
                    Text(session.profile.initial)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Theme.inkSoft)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.profile.displayName.isEmpty ? "Élève" : session.profile.displayName)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(session.profile.email)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 16) {
                metric("Parcours", value: session.profile.track.isEmpty ? "—" : session.profile.track)
                metric("Année", value: session.profile.year.isEmpty ? "—" : session.profile.year)
                metric("Prépa", value: session.profile.prepName.isEmpty ? "—" : session.profile.prepName)
            }
        }
        .duelloCard()
    }

    private var programCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Mon parcours")
            Picker("Filière", selection: $session.profile.track) {
                Text("Choisir…").tag("")
                ForEach(tracks, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Année", selection: $session.profile.year) {
                ForEach(years, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            DuelloTextField(title: "Spécialité / option", text: $session.profile.specialty)
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

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Mon objectif")
            DuelloTextField(title: "École visée", text: $session.profile.targetSchool)
            VStack(alignment: .leading, spacing: 6) {
                Text("Objectif personnel")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
                TextField("Pourquoi je travaille…", text: $session.profile.personalGoal, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(12)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
        }
        .duelloCard()
        .onChange(of: session.profile.targetSchool) { _ in session.persistProfile() }
        .onChange(of: session.profile.personalGoal) { _ in session.persistProfile() }
    }

    private var signOutCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await session.signOut() }
            } label: {
                Text("Me déconnecter")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(DuelloPrimaryButton())
        }
        .duelloCard()
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
    }
}

/// Édition du prénom affiché.
struct ProfileEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom affiché") {
                    TextField("Prénom ou pseudo", text: $displayName)
                }
            }
            .navigationTitle("Mes informations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        session.profile.displayName = displayName
                        if session.profile.firstName.isEmpty {
                            session.profile.firstName = displayName
                        }
                        session.persistProfile()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                displayName = session.profile.displayName
            }
        }
    }
}
