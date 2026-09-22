import SwiftUI

/// Onglet « Mon compte » : profil, parcours, objectifs et déconnexion.
/// Reprend l'esprit de `src/screens/AccountScreen.tsx` (sections en cartes).
///
/// `@MainActor` : la vue possède `AcctSearchModel`, isolé au fil principal, et
/// l'initialise dans un initialiseur de propriété (non isolé par défaut) —
/// même motif que `AcctIntDirectorySheet`.
@MainActor
struct AccountView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var showProfileEditor = false
    @State private var activeSheet: AccountSheet?
    @State private var notificationsOpen = false
    /// Annuaire de recherche de la page : la ligne de recherche vit en tête du
    /// profil, comme `searchQuery` / `directoryProfiles` de la source.
    @StateObject private var search = AcctSearchModel()

    private let tracks = ["ECG", "MPSI", "MP", "PSI"]
    private let years = ["1re année", "2e année"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    AcctIntSearchRow(
                        model: search,
                        onOpenNotifications: { notificationsOpen = true },
                        onOpenSettings: { activeSheet = .info }
                    )
                    // Une fiche de membre ouverte remplace le profil affiché,
                    // comme `resolveViewedProfile(profile, selectedMember)` de
                    // la source : le bloc de recherche reste, le corps change.
                    if search.selectedMemberId == nil {
                        AcctIntShowcase()
                        hubCard
                        programCard
                        goalCard
                        signOutCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            // La source n'a pas d'en-tête de navigation : la page commence par
            // la ligne de recherche, sans titre centré.
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditorView()
            }
            .sheet(isPresented: $notificationsOpen) {
                AcctIntNotificationsSheet()
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
                case .info: AcctIntSettingsSheet()
                case .directory: AcctIntDirectorySheet()
                }
            }
        }
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

    /// Une entrée de la carte d'accès : libellé, icône SF Symbol, feuille.
    private struct HubEntry: Identifiable {
        let title: String
        let icon: String
        let sheet: AccountSheet
        var id: String { title }
    }

    /// Les douze entrées annexes, dans l'ordre de la source Expo.
    ///
    /// Décrites en données plutôt qu'énumérées dans le corps de la vue : un
    /// `ViewBuilder` ne construit pas plus de dix enfants, et la carte en
    /// compte douze plus onze séparateurs.
    private static let hubEntries: [HubEntry] = [
        HubEntry(title: "Progression", icon: "chart.bar", sheet: .progress),
        HubEntry(title: "Annales", icon: "doc.text.magnifyingglass", sheet: .annales),
        HubEntry(title: "Planning", icon: "calendar", sheet: .plan),
        HubEntry(title: "Premium", icon: "star.circle", sheet: .premium),
        HubEntry(title: "Messages", icon: "bubble.left.and.bubble.right", sheet: .messages),
        HubEntry(title: "Mon parcours", icon: "map", sheet: .track),
        HubEntry(title: "Confidentialité", icon: "lock.shield", sheet: .privacy),
        HubEntry(title: "Conditions d'utilisation", icon: "doc.text", sheet: .terms),
        HubEntry(title: "Donner mon avis", icon: "bubble.left", sheet: .feedback),
        HubEntry(title: "Utilisateurs bloqués", icon: "hand.raised", sheet: .blocked),
        HubEntry(title: "Mes informations", icon: "gearshape", sheet: .info),
        HubEntry(title: "Annuaire", icon: "magnifyingglass", sheet: .directory),
    ]

    /// Entrées annexes : suivi, messages, parcours détaillé, pages légales,
    /// avis et comptes bloqués. Chacune s'ouvre en feuille, comme les écrans
    /// secondaires de l'app Expo.
    private var hubCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.hubEntries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    hubSeparator
                }
                hubRow(entry.title, icon: entry.icon, sheet: entry.sheet)
            }
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
    }
}

/// Écrans secondaires présentés en feuille depuis « Mon compte ».
private enum AccountSheet: String, Identifiable {
    case progress, annales, plan, premium, messages, track, privacy, terms, feedback, blocked, info, directory

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
