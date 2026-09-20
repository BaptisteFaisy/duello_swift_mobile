import SwiftUI

/// Onglet « Mon compte » : profil, parcours, objectifs et déconnexion.
/// Reprend l'esprit de `src/screens/AccountScreen.tsx` (sections en cartes).
struct AccountView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var showProfileEditor = false
    @State private var activeSheet: AccountSheet?

    private let tracks = ["ECG", "MPSI", "MP", "PSI"]
    private let years = ["1re année", "2e année"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    profileCard
                    hubCard
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
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .progress: DuelloProgressView()
                case .annales: AnnalesView()
                case .plan: PlanView()
                case .premium: PremiumView()
                case .messages: MessagesView()
                case .track: TrackSettingsView()
                case .privacy: PrivacyPolicyView()
                case .terms: TermsOfUseView()
                case .feedback: FeedbackView()
                case .blocked: BlockedUsersView()
                }
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

    /// Entrées annexes : suivi, messages, parcours détaillé, pages légales,
    /// avis et comptes bloqués. Chacune s'ouvre en feuille, comme les écrans
    /// secondaires de l'app Expo.
    private var hubCard: some View {
        VStack(spacing: 0) {
            hubRow("Progression", icon: "chart.bar", sheet: .progress)
            hubSeparator
            hubRow("Annales", icon: "doc.text.magnifyingglass", sheet: .annales)
            hubSeparator
            hubRow("Planning", icon: "calendar", sheet: .plan)
            hubSeparator
            hubRow("Premium", icon: "star.circle", sheet: .premium)
            hubSeparator
            hubRow("Messages", icon: "bubble.left.and.bubble.right", sheet: .messages)
            hubSeparator
            hubRow("Mon parcours", icon: "map", sheet: .track)
            hubSeparator
            hubRow("Confidentialité", icon: "lock.shield", sheet: .privacy)
            hubSeparator
            hubRow("Conditions d'utilisation", icon: "doc.text", sheet: .terms)
            hubSeparator
            hubRow("Donner mon avis", icon: "bubble.left", sheet: .feedback)
            hubSeparator
            hubRow("Utilisateurs bloqués", icon: "hand.raised", sheet: .blocked)
        }
        .duelloCard()
    }

    private var hubSeparator: some View {
        Divider().padding(.leading, 40)
    }

    private func hubRow(_ title: String, icon: String, sheet: AccountSheet) -> some View {
        Button {
            activeSheet = sheet
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

/// Écrans secondaires présentés en feuille depuis « Mon compte ».
private enum AccountSheet: String, Identifiable {
    case progress, annales, plan, premium, messages, track, privacy, terms, feedback, blocked

    var id: String { rawValue }
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
